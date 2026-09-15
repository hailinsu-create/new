package com.pangchuang.app

import org.junit.Assert.assertEquals
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
    fun trialGateOrderMockThenKeyThenPaywall() {
        assertEquals(
            CapturePolicy.FullStartGate.BLOCK_MOCK_LINES,
            CapturePolicy.fullStartGate(
                mockLines = true,
                apiKeyBlank = true,
                unlocked = false,
                trialRemaining = 0
            )
        )
        assertEquals(
            CapturePolicy.FullStartGate.BLOCK_EMPTY_KEY,
            CapturePolicy.fullStartGate(
                mockLines = false,
                apiKeyBlank = true,
                unlocked = false,
                trialRemaining = 6
            )
        )
        assertEquals(
            CapturePolicy.FullStartGate.BLOCK_PAYWALL,
            CapturePolicy.fullStartGate(
                mockLines = false,
                apiKeyBlank = false,
                unlocked = false,
                trialRemaining = 0
            )
        )
        assertEquals(
            CapturePolicy.FullStartGate.ALLOW,
            CapturePolicy.fullStartGate(
                mockLines = false,
                apiKeyBlank = false,
                unlocked = false,
                trialRemaining = 1
            )
        )
        assertEquals(
            CapturePolicy.FullStartGate.ALLOW,
            CapturePolicy.fullStartGate(
                mockLines = false,
                apiKeyBlank = false,
                unlocked = true,
                trialRemaining = 0
            )
        )
    }

    @Test
    fun trialDoesNotChargeWhileRemaining() {
        assertTrue(CapturePolicy.mayStartCapture(unlocked = false, trialRemaining = 6))
        assertTrue(CapturePolicy.mayStartCapture(unlocked = false, trialRemaining = 1))
        assertFalse(CapturePolicy.mayStartCapture(unlocked = false, trialRemaining = 0))
        assertTrue(CapturePolicy.mayStartCapture(unlocked = true, trialRemaining = 0))
    }

    @Test
    fun trialCountsOnlySuccessfulLiveApi() {
        assertTrue(CapturePolicy.countsTowardTrial(unlocked = false, demo = false, source = "api"))
        assertFalse(CapturePolicy.countsTowardTrial(unlocked = true, demo = false, source = "api"))
        assertFalse(CapturePolicy.countsTowardTrial(unlocked = false, demo = true, source = "api"))
        assertFalse(CapturePolicy.countsTowardTrial(unlocked = false, demo = false, source = "error"))
        assertFalse(CapturePolicy.countsTowardTrial(unlocked = false, demo = false, source = "mock"))
        assertFalse(CapturePolicy.countsTowardTrial(unlocked = false, demo = true, source = "mock"))
    }

    @Test
    fun trialQuotaMathAndTearDown() {
        assertEquals(6, TrialPolicy.LIFETIME_SUCCESS_QUOTA)
        assertEquals(6, TrialPolicy.remaining(0))
        assertEquals(1, TrialPolicy.remaining(5))
        assertEquals(0, TrialPolicy.remaining(6))
        assertEquals(0, TrialPolicy.remaining(99))
        assertEquals(Int.MAX_VALUE, TrialPolicy.remaining(unlocked = true, successCount = 6))
        assertTrue(CapturePolicy.mayCallLiveVision(false, 1, demo = false))
        assertFalse(CapturePolicy.mayCallLiveVision(false, 0, demo = false))
        assertTrue(CapturePolicy.mayCallLiveVision(false, 0, demo = true))
        assertTrue(CapturePolicy.shouldTearDownCaptureAfterTrial(false, 0))
        assertFalse(CapturePolicy.shouldTearDownCaptureAfterTrial(true, 0))
        assertFalse(CapturePolicy.shouldTearDownCaptureAfterTrial(false, 1))
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
