package com.pangchuang.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OverlayCaptureMaskTest {
    @Test
    fun ltrWindowMapsOntoScaledFrame() {
        val rect = OverlayCaptureMask.overlayOnFrame(
            overlayX = 100,
            overlayY = 200,
            overlayW = 96,
            overlayH = 96,
            screenW = 1080,
            screenH = 1920,
            frameW = 540,
            frameH = 960,
            startIsRight = false,
            padPx = 0
        )
        assertEquals(50, rect.left)
        assertEquals(100, rect.top)
        assertEquals(98, rect.right)
        assertEquals(148, rect.bottom)
        assertFalse(rect.isEmpty)
    }

    @Test
    fun rtlWindowOriginIsFromTheRight() {
        assertEquals(
            1080 - 40 - 96,
            OverlayCaptureMask.windowScreenLeft(40, 96, 1080, startIsRight = true)
        )
        assertEquals(40, OverlayCaptureMask.windowScreenLeft(40, 96, 1080, startIsRight = false))
    }

    @Test
    fun emptyOverlayDoesNotMask() {
        val rect = OverlayCaptureMask.overlayOnFrame(
            0, 0, 0, 0, 1080, 1920, 720, 1280, false
        )
        assertTrue(rect.isEmpty)
    }
}
