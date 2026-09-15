package com.pangchuang.app

/**
 * Lifelong true-screen trial for users who have not purchased.
 *
 * Six successful live vision bubbles, counted on this device in
 * SharedPreferences. Same forgeability as [Prefs.isPremiumUnlocked]:
 * a local boolean/int the user can edit; Play purchase is the real unlock.
 *
 * Debug builds are auto-unlocked via [Entitlement], so the counter is
 * irrelevant there.
 */
object TrialPolicy {
    const val LIFETIME_SUCCESS_QUOTA = 6

    fun remaining(successCount: Int): Int =
        (LIFETIME_SUCCESS_QUOTA - successCount.coerceAtLeast(0)).coerceAtLeast(0)

    fun remaining(unlocked: Boolean, successCount: Int): Int =
        if (unlocked) Int.MAX_VALUE else remaining(successCount)

    fun isUnlimited(unlocked: Boolean): Boolean = unlocked
}
