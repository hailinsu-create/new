package com.pangchuang.app

/**
 * Rules for when capture / vision may run. Kept Android-free for JVM tests.
 */
object CapturePolicy {
    enum class Mode { IDLE, DEMO, FULL }

    /**
     * Gate order for starting real-screen companion (after privacy + overlay):
     * 1. demo-lines pref blocks true-screen jokes
     * 2. empty API key blocks BYOK path (trial included)
     * 3. paywall only when not unlocked and trial remaining is 0
     *
     * Never show the paywall while trial remaining > 0.
     */
    enum class FullStartGate { ALLOW, BLOCK_MOCK_LINES, BLOCK_EMPTY_KEY, BLOCK_PAYWALL }

    fun fullStartGate(
        mockLines: Boolean,
        apiKeyBlank: Boolean,
        unlocked: Boolean,
        trialRemaining: Int
    ): FullStartGate {
        if (mockLines) return FullStartGate.BLOCK_MOCK_LINES
        if (apiKeyBlank) return FullStartGate.BLOCK_EMPTY_KEY
        if (!unlocked && trialRemaining <= 0) return FullStartGate.BLOCK_PAYWALL
        return FullStartGate.ALLOW
    }

    fun mayStartCapture(unlocked: Boolean, trialRemaining: Int): Boolean =
        unlocked || trialRemaining > 0

    fun mayCallLiveVision(unlocked: Boolean, trialRemaining: Int, demo: Boolean): Boolean {
        if (demo) return true
        return unlocked || trialRemaining > 0
    }

    /**
     * Count only successful true-screen vision replies.
     * Unchanged-frame skip, lock, sensitive skip, thinking placeholder,
     * demo lines, and source=error/mock never reach this with source=api.
     */
    fun countsTowardTrial(unlocked: Boolean, demo: Boolean, source: String): Boolean {
        if (unlocked || demo) return false
        return source == "api"
    }

    fun shouldTearDownCaptureAfterTrial(unlocked: Boolean, remainingAfter: Int): Boolean =
        !unlocked && remainingAfter <= 0

    fun shouldSkipTick(locked: Boolean, demo: Boolean, sensitiveForeground: Boolean): Boolean {
        if (locked) return true
        if (!demo && sensitiveForeground) return true
        return false
    }

    /** Live capture must never speak canned mock lines. */
    fun liveVisionMayUseMock(): Boolean = false

    fun fullCompanionBlockedByDemoLines(demoLinesPref: Boolean): Boolean = demoLinesPref

    fun shouldResumeMirroring(
        companionRunning: Boolean,
        demo: Boolean,
        locked: Boolean
    ): Boolean = companionRunning && !demo && !locked

    fun shouldReleaseMirroringOnLock(demo: Boolean): Boolean = !demo

    /** Sensitive apps must pause VirtualDisplay, not only skip JPEG/API. */
    fun shouldPauseMirroringOnSensitive(demo: Boolean, sensitive: Boolean): Boolean =
        !demo && sensitive

    fun shouldResumeMirroringAfterSensitive(
        companionRunning: Boolean,
        demo: Boolean,
        locked: Boolean,
        sensitive: Boolean
    ): Boolean = companionRunning && !demo && !locked && !sensitive

    /** Leaving a sensitive app must not force a roast (same as unlock). */
    fun shouldForceRoastAfterSensitiveLeave(): Boolean = false

    fun shouldForceRoastAfterUnlock(): Boolean = false
}
