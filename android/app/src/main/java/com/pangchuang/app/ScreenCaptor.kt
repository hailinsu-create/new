package com.pangchuang.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.HandlerThread
import android.util.DisplayMetrics
import android.view.WindowManager

/**
 * Continuously mirrors the phone screen via MediaProjection into bitmaps
 * suitable for the vision companion.
 *
 * [latestBitmap] is only recycled while holding [frameLock], and callers
 * receive a copy made under that lock so a recycle cannot race a copy.
 */
class ScreenCaptor(
    context: Context,
    private val mediaProjection: MediaProjection,
    maxWidth: Int = 720
) {
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null
    private val frameLock = Any()
    private var latestBitmap: Bitmap? = null
    @Volatile
    private var mirroring = false

    private val width: Int
    private val height: Int
    private val density: Int

    init {
        val metrics = DisplayMetrics()
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        val maxW = maxWidth.coerceIn(360, 720)
        val scale = maxW.toFloat() / metrics.widthPixels.coerceAtLeast(1)
        width = maxW
        height = (metrics.heightPixels * scale).toInt().coerceAtLeast(1)
        density = metrics.densityDpi
    }

    fun start() {
        ensureWorker()
        startMirroring()
    }

    /** Release VirtualDisplay and drop any held frames (lock screen). */
    fun pauseMirroring() {
        stopMirroring(recycleFrames = true)
    }

    /** Recreate the mirror if the companion is still running. */
    fun resumeMirroring() {
        if (mirroring) return
        ensureWorker()
        startMirroring()
    }

    fun isMirroring(): Boolean = mirroring

    /** Drop the cached frame on every pause path (lock, sensitive, stop). */
    fun dropLatest() {
        synchronized(frameLock) {
            latestBitmap?.let { if (!it.isRecycled) it.recycle() }
            latestBitmap = null
        }
    }

    /**
     * Returns a copy of the newest frame, waiting briefly if the pipeline is still warming up.
     * The copy is taken while holding [frameLock] so the original cannot be recycled mid-copy.
     */
    fun captureBitmap(waitMs: Long = 800): Bitmap? {
        val deadline = System.currentTimeMillis() + waitMs
        while (System.currentTimeMillis() < deadline) {
            copyLatest()?.let { return it }
            try {
                Thread.sleep(40)
            } catch (_: InterruptedException) {
                break
            }
        }
        return copyLatest()
    }

    fun release() {
        stopMirroring(recycleFrames = true)
        workerThread?.quitSafely()
        workerThread = null
        workerHandler = null
    }

    private fun copyLatest(): Bitmap? = synchronized(frameLock) {
        val current = latestBitmap
        if (current != null && !current.isRecycled) {
            current.copy(Bitmap.Config.ARGB_8888, false)
        } else {
            null
        }
    }

    private fun ensureWorker() {
        if (workerThread != null && workerHandler != null) return
        val thread = HandlerThread("pangchuang-capture").also { it.start() }
        workerThread = thread
        workerHandler = Handler(thread.looper)
    }

    private fun startMirroring() {
        if (mirroring) return
        val handler = workerHandler ?: return
        val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
        imageReader = reader
        reader.setOnImageAvailableListener({ r ->
            if (!mirroring) {
                runCatching { r.acquireLatestImage()?.close() }
                return@setOnImageAvailableListener
            }
            val image = r.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val bmp = imageToBitmap(image) ?: return@setOnImageAvailableListener
                synchronized(frameLock) {
                    val old = latestBitmap
                    latestBitmap = bmp
                    if (old != null && old !== bmp && !old.isRecycled) {
                        old.recycle()
                    }
                }
            } finally {
                image.close()
            }
        }, handler)

        virtualDisplay = mediaProjection.createVirtualDisplay(
            "pangchuang-capture",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            reader.surface,
            null,
            handler
        )
        mirroring = true
    }

    private fun stopMirroring(recycleFrames: Boolean) {
        mirroring = false
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.setOnImageAvailableListener(null, null)
        imageReader?.close()
        imageReader = null
        if (recycleFrames) {
            synchronized(frameLock) {
                latestBitmap?.let { if (!it.isRecycled) it.recycle() }
                latestBitmap = null
            }
        }
    }

    private fun imageToBitmap(image: Image): Bitmap? {
        val plane = image.planes.getOrNull(0) ?: return null
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * width
        val full = Bitmap.createBitmap(
            width + rowPadding / pixelStride,
            height,
            Bitmap.Config.ARGB_8888
        )
        buffer.rewind()
        full.copyPixelsFromBuffer(buffer)
        return if (full.width == width) {
            full
        } else {
            Bitmap.createBitmap(full, 0, 0, width, height).also { full.recycle() }
        }
    }
}

fun screenChanged(a: Bitmap?, b: Bitmap, threshold: Float = 10f): Boolean {
    if (a == null) return true
    val aw = 48
    val ah = 48
    val sa = Bitmap.createScaledBitmap(a, aw, ah, true)
    val sb = Bitmap.createScaledBitmap(b, aw, ah, true)
    var diff = 0L
    val n = aw * ah
    for (y in 0 until ah) {
        for (x in 0 until aw) {
            val pa = sa.getPixel(x, y)
            val pb = sb.getPixel(x, y)
            val da = ((pa shr 16) and 0xFF) - ((pb shr 16) and 0xFF)
            val dg = ((pa shr 8) and 0xFF) - ((pb shr 8) and 0xFF)
            val db = (pa and 0xFF) - (pb and 0xFF)
            diff += kotlin.math.abs(da) + kotlin.math.abs(dg) + kotlin.math.abs(db)
        }
    }
    if (sa !== a) sa.recycle()
    if (sb !== b) sb.recycle()
    val avg = diff.toFloat() / (n * 3f)
    return avg >= threshold
}
