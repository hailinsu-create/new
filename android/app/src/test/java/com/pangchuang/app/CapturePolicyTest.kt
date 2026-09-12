package com.pangchuang.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CapturePolicyTest {
    @Test
    fun lockSkipsEveryTick() {
        assertTrue(CapturePolicy.shouldSkipTick(locked = true, demo = false, sensitiveForeground = false))
        assertTrue(CapturePolicy.shouldSkipTick(locked = true, demo = true, sensitiveForeground = false))
    }

    @Test
    fun sensitiveForegroundSkipsLiveCaptureOnly() {
        assertTrue(CapturePolicy.shouldSkipTick(locked = false, demo = false, sensitiveForeground = true))
        assertFalse(CapturePolicy.shouldSkipTick(locked = false, demo = true, sensitiveForeground = true))
    }

    @Test
    fun liveVisionNeverMocks() {
        assertFalse(CapturePolicy.liveVisionMayUseMock())
    }

    @Test
    fun demoLinesPrefBlocksFullCompanion() {
        assertTrue(CapturePolicy.fullCompanionBlockedByDemoLines(true))
        assertFalse(CapturePolicy.fullCompanionBlockedByDemoLines(false))
    }

    @Test
    fun unlockResumesMirroringOnlyForLiveCompanion() {
        assertTrue(
            CapturePolicy.shouldResumeMirroring(
                companionRunning = true,
                demo = false,
                locked = false
            )
        )
        assertFalse(
            CapturePolicy.shouldResumeMirroring(
                companionRunning = true,
                demo = true,
                locked = false
            )
        )
        assertFalse(
            CapturePolicy.shouldResumeMirroring(
                companionRunning = false,
                demo = false,
                locked = false
            )
        )
        assertFalse(
            CapturePolicy.shouldResumeMirroring(
                companionRunning = true,
                demo = false,
                locked = true
            )
        )
    }

    @Test
    fun lockReleasesMirroringOnlyWhenNotDemo() {
        assertTrue(CapturePolicy.shouldReleaseMirroringOnLock(demo = false))
        assertFalse(CapturePolicy.shouldReleaseMirroringOnLock(demo = true))
    }

    @Test
    fun sensitivePausesMirroringLikeLockForLiveOnly() {
        assertTrue(CapturePolicy.shouldPauseMirroringOnSensitive(demo = false, sensitive = true))
        assertFalse(CapturePolicy.shouldPauseMirroringOnSensitive(demo = true, sensitive = true))
        assertFalse(CapturePolicy.shouldPauseMirroringOnSensitive(demo = false, sensitive = false))
    }

    @Test
    fun leavingSensitiveResumesOnlyWhenUnlockedLiveCompanion() {
        assertTrue(
            CapturePolicy.shouldResumeMirroringAfterSensitive(
                companionRunning = true,
                demo = false,
                locked = false,
                sensitive = false
            )
        )
        assertFalse(
            CapturePolicy.shouldResumeMirroringAfterSensitive(
                companionRunning = true,
                demo = false,
                locked = false,
                sensitive = true
            )
        )
        assertFalse(
            CapturePolicy.shouldResumeMirroringAfterSensitive(
                companionRunning = true,
                demo = false,
                locked = true,
                sensitive = false
            )
        )
    }

    @Test
    fun lockSensitiveAndDemoCombinations() {
        assertTrue(CapturePolicy.shouldSkipTick(true, false, false))
        assertTrue(CapturePolicy.shouldSkipTick(true, true, true))
        assertTrue(CapturePolicy.shouldSkipTick(false, false, true))
        assertFalse(CapturePolicy.shouldSkipTick(false, true, true))
        assertFalse(CapturePolicy.shouldSkipTick(false, false, false))
        assertFalse(CapturePolicy.shouldForceRoastAfterSensitiveLeave())
        assertFalse(CapturePolicy.shouldForceRoastAfterUnlock())
    }
}
