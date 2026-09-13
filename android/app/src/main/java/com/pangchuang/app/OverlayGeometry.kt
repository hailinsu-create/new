package com.pangchuang.app

/**
 * Overlay window math. Pure so it can be unit-tested without WindowManager.
 * Coordinates are TOP|START offsets in pixels.
 */
object OverlayGeometry {
    fun clamp(
        x: Int,
        y: Int,
        viewW: Int,
        viewH: Int,
        screenW: Int,
        screenH: Int,
        pad: Int
    ): Pair<Int, Int> {
        val maxX = (screenW - viewW - pad).coerceAtLeast(pad)
        val maxY = (screenH - viewH - pad).coerceAtLeast(pad)
        val minX = if (viewW + 2 * pad >= screenW) 0 else pad
        val minY = if (viewH + 2 * pad >= screenH) 0 else pad
        return x.coerceIn(minX, maxX) to y.coerceIn(minY, maxY)
    }

    fun snapX(x: Int, viewW: Int, screenW: Int, pad: Int): Int {
        val maxX = (screenW - viewW - pad).coerceAtLeast(pad)
        val center = x + viewW / 2
        return if (center < screenW / 2) pad.coerceAtMost(maxX) else maxX
    }

    fun snapAndClamp(
        x: Int,
        y: Int,
        viewW: Int,
        viewH: Int,
        screenW: Int,
        screenH: Int,
        pad: Int
    ): Pair<Int, Int> {
        val snappedX = snapX(x, viewW, screenW, pad)
        return clamp(snappedX, y, viewW, viewH, screenW, screenH, pad)
    }

    /** Close chip sits on the start (outer) edge so RTL puts it on the right in Arabic. */
    fun closeGravityStart(): Boolean = true

    fun minTouchTargetDp(): Int = 48

    fun avatarSizeDp(): Int = 96

    /**
     * After rotation, [screenW]/[screenH] swap. Re-clamp saved x/y so the window
     * stays on-screen.
     */
    fun clampAfterRotation(
        x: Int,
        y: Int,
        viewW: Int,
        viewH: Int,
        screenW: Int,
        screenH: Int,
        pad: Int
    ): Pair<Int, Int> = clamp(x, y, viewW, viewH, screenW, screenH, pad)

    fun restoreClamped(
        savedX: Int,
        savedY: Int,
        viewW: Int,
        viewH: Int,
        screenW: Int,
        screenH: Int,
        pad: Int
    ): Pair<Int, Int> {
        if (savedX < 0 || savedY < 0) {
            return pad to 180.coerceAtMost((screenH - viewH - pad).coerceAtLeast(pad))
        }
        return clamp(savedX, savedY, viewW, viewH, screenW, screenH, pad)
    }
}
