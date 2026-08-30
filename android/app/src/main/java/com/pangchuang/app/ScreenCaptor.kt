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
import java.util.concurrent.atomic.AtomicReference

/**
 * Continuously mirrors the phone screen via MediaProjection into bitmaps
 * suitable for vision-model roasting.
 */
class ScreenCaptor(
    context: Context,
    private val mediaProjection: MediaProjection
) {
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null
    private val latestBitmap = AtomicReference<Bitmap?>(null)

    private val width: Int
    private val height: Int
    private val density: Int

    init {
        val metrics = DisplayMetrics()
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        val maxW = 720
        val scale = maxW.toFloat() / metrics.widthPixels.coerceAtLeast(1)
        width = maxW
        height = (metrics.heightPixels * scale).toInt().coerceAtLeast(1)
        density = metrics.densityDpi
    }

    fun start() {
        val thread = HandlerThread("pangchuang-capture").also { it.start() }
        workerThread = thread
        val handler = Handler(thread.looper)
        workerHandler = handler

        val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
        imageReader = reader
        reader.setOnImageAvailableListener({ r ->
            val image = r.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val bmp = imageToBitmap(image) ?: return@setOnImageAvailableListener
                latestBitmap.getAndSet(bmp)?.recycle()
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
    }

    /**
     * Returns a copy of the newest frame, waiting briefly if the pipeline is still warming up.
     */
    fun captureBitmap(waitMs: Long = 800): Bitmap? {
        val deadline = System.currentTimeMillis() + waitMs
        while (System.currentTimeMillis() < deadline) {
            val current = latestBitmap.get()
            if (current != null && !current.isRecycled) {
                return current.copy(Bitmap.Config.ARGB_8888, false)
            }
            try {
                Thread.sleep(40)
            } catch (_: InterruptedException) {
                break
            }
        }
        val fallback = latestBitmap.get()
        return if (fallback != null && !fallback.isRecycled) {
            fallback.copy(Bitmap.Config.ARGB_8888, false)
        } else {
            null
        }
    }

    fun release() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.setOnImageAvailableListener(null, null)
        imageReader?.close()
        imageReader = null
        latestBitmap.getAndSet(null)?.recycle()
        workerThread?.quitSafely()
        workerThread = null
        workerHandler = null
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
