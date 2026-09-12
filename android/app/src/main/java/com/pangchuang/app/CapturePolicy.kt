package com.pangchuang.app

/**
 * Rules for when capture / vision may run. Kept Android-free for JVM tests.
 */
object CapturePolicy {
    enum class Mode { IDLE, DEMO, FULL }

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
