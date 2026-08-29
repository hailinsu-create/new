package com.pangchuang.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager

class ScreenCaptor(
    private val context: Context,
    private val mediaProjection: MediaProjection
) {
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val width: Int
    private val height: Int
    private val density: Int

    init {
        val metrics = DisplayMetrics()
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        // Capture at a modest size for bandwidth + privacy.
        val maxW = 720
        val scale = maxW.toFloat() / metrics.widthPixels.coerceAtLeast(1)
        width = maxW
        height = (metrics.heightPixels * scale).toInt().coerceAtLeast(1)
        density = metrics.densityDpi
    }

    fun start() {
        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        virtualDisplay = mediaProjection.createVirtualDisplay(
            "pangchuang-capture",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader!!.surface,
            null,
            mainHandler
        )
    }

    fun captureBitmap(): Bitmap? {
        val reader = imageReader ?: return null
        val image = reader.acquireLatestImage() ?: return null
        image.use { img ->
            val plane = img.planes[0]
            val buffer = plane.buffer
            val pixelStride = plane.pixelStride
            val rowStride = plane.rowStride
            val rowPadding = rowStride - pixelStride * width
            val bitmap = Bitmap.createBitmap(
                width + rowPadding / pixelStride,
                height,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)
            return Bitmap.createBitmap(bitmap, 0, 0, width, height).also {
                if (it !== bitmap) bitmap.recycle()
            }
        }
    }

    fun release() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
    }
}

fun screenChanged(a: Bitmap?, b: Bitmap, threshold: Float = 12f): Boolean {
    if (a == null) return true
    val aw = 32
    val ah = 32
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
