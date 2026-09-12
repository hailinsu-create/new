package com.pangchuang.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OverlayGeometryTest {
    @Test
    fun clampKeepsWindowOnScreen() {
        val (x, y) = OverlayGeometry.clamp(
            x = 5000,
            y = -400,
            viewW = 200,
            viewH = 180,
            screenW = 1080,
            screenH = 1920,
            pad = 8
        )
        assertEquals(1080 - 200 - 8, x)
        assertEquals(8, y)
    }

    @Test
    fun clampDoesNotGoNegative() {
        val (x, y) = OverlayGeometry.clamp(-80, -80, 96, 96, 720, 1280, 8)
        assertTrue(x >= 0)
        assertTrue(y >= 0)
    }

    @Test
    fun snapGoesLeftWhenCenterIsLeft() {
        val x = OverlayGeometry.snapX(40, viewW = 96, screenW = 720, pad = 8)
        assertEquals(8, x)
    }

    @Test
    fun snapGoesRightWhenCenterIsRight() {
        val x = OverlayGeometry.snapX(500, viewW = 96, screenW = 720, pad = 8)
        assertEquals(720 - 96 - 8, x)
    }

    @Test
    fun snapAndClampNeverLosesTheWindow() {
        val (x, y) = OverlayGeometry.snapAndClamp(
            x = -2000,
            y = 9000,
            viewW = 260,
            viewH = 220,
            screenW = 1080,
            screenH = 1920,
            pad = 8
        )
        assertTrue(x >= 0)
        assertTrue(y >= 0)
        assertTrue(x + 260 <= 1080)
        assertTrue(y + 220 <= 1920)
    }
}
