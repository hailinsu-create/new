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

    @Test
    fun clampAfterRotationKeepsNinetySixDpAvatarOnScreen() {
        val view = 96
        val (x, y) = OverlayGeometry.clampAfterRotation(
            x = 700,
            y = 1800,
            viewW = view,
            viewH = view,
            screenW = 1920,
            screenH = 1080,
            pad = 8
        )
        assertTrue(x + view <= 1920)
        assertTrue(y + view <= 1080)
        assertTrue(x >= 0)
        assertTrue(y >= 0)
    }

    @Test
    fun restoreClampedUsesDefaultWhenUnset() {
        val (x, y) = OverlayGeometry.restoreClamped(
            savedX = -1,
            savedY = -1,
            viewW = 96,
            viewH = 160,
            screenW = 1080,
            screenH = 1920,
            pad = 8
        )
        assertEquals(8, x)
        assertTrue(y >= 8)
        assertTrue(y + 160 <= 1920)
    }

    @Test
    fun restoreClampedPullsOffScreenSavedPointBack() {
        val (x, y) = OverlayGeometry.restoreClamped(
            savedX = 5000,
            savedY = 9000,
            viewW = 96,
            viewH = 96,
            screenW = 720,
            screenH = 1280,
            pad = 8
        )
        assertEquals(720 - 96 - 8, x)
        assertEquals(1280 - 96 - 8, y)
    }

    @Test
    fun closeChipIsStartSideAndAtLeast48dp() {
        assertTrue(OverlayGeometry.closeGravityStart())
        assertTrue(OverlayGeometry.minTouchTargetDp() >= 48)
        assertEquals(96, OverlayGeometry.avatarSizeDp())
    }
}
