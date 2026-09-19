package com.pangchuang.app

/**
 * Map the overlay window onto a MediaProjection frame so vision never sees 小旁.
 *
 * VirtualDisplay has no public “exclude this window” flag, and hiding the
 * overlay for ~180ms blanks the character. Masking the JPEG is the honest
 * path: the user still sees 小旁; the API image does not.
 */
object OverlayCaptureMask {
    data class Rect(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val isEmpty: Boolean get() = right <= left || bottom <= top
    }

    fun windowScreenLeft(x: Int, viewW: Int, screenW: Int, startIsRight: Boolean): Int =
        if (startIsRight) (screenW - x - viewW).coerceAtLeast(0) else x.coerceAtLeast(0)

    fun overlayOnFrame(
        overlayX: Int,
        overlayY: Int,
        overlayW: Int,
        overlayH: Int,
        screenW: Int,
        screenH: Int,
        frameW: Int,
        frameH: Int,
        startIsRight: Boolean,
        padPx: Int = 8
    ): Rect {
        if (screenW <= 0 || screenH <= 0 || frameW <= 0 || frameH <= 0) {
            return Rect(0, 0, 0, 0)
        }
        if (overlayW <= 0 || overlayH <= 0) return Rect(0, 0, 0, 0)
        val left = windowScreenLeft(overlayX, overlayW, screenW, startIsRight)
        val top = overlayY.coerceAtLeast(0)
        val scaleX = frameW.toFloat() / screenW.toFloat()
        val scaleY = frameH.toFloat() / screenH.toFloat()
        val l = (((left - padPx) * scaleX).toInt()).coerceIn(0, frameW)
        val t = (((top - padPx) * scaleY).toInt()).coerceIn(0, frameH)
        val r = (((left + overlayW + padPx) * scaleX).toInt()).coerceIn(0, frameW)
        val b = (((top + overlayH + padPx) * scaleY).toInt()).coerceIn(0, frameH)
        return Rect(l, t, r, b)
    }
}
