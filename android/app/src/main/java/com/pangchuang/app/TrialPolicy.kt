package com.pangchuang.app

/**
 * Lifelong true-screen trial for users who have not purchased.
 *
 * Successful live vision bubbles, counted on this device in
 * SharedPreferences. Same forgeability as [Prefs.isPremiumUnlocked]:
 * a local boolean/int the user can edit; Play purchase is the real unlock.
 *
 * Why 20, not 6: default interval is 15s with change detection, so 6
 * successful glances is only about 1–2 minutes of active use — too short
 * to feel the companion. 20 is several minutes of real “it saw my screen”
 * moments without becoming a free daily companion.
 *
 * Debug builds are auto-unlocked via [Entitlement], so the counter is
 * irrelevant there.
 */
object TrialPolicy {
    const val LIFETIME_SUCCESS_QUOTA = 20

    fun remaining(successCount: Int): Int =
        (LIFETIME_SUCCESS_QUOTA - successCount.coerceAtLeast(0)).coerceAtLeast(0)

    fun remaining(unlocked: Boolean, successCount: Int): Int =
        if (unlocked) Int.MAX_VALUE else remaining(successCount)

    fun isUnlimited(unlocked: Boolean): Boolean = unlocked
}
