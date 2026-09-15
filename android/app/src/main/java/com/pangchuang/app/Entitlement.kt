package com.pangchuang.app

import android.content.Context

/**
 * Unlimited real-screen companion requires a one-time Play purchase.
 * Debug builds are auto-unlocked so sideload tests skip the trial counter.
 * Demo overlay stays free. Locked Play builds may still use a 6-glance trial
 * via [CapturePolicy.mayStartCapture].
 */
object Entitlement {
    fun isUnlocked(context: Context): Boolean {
        if (BuildConfig.DEBUG) return true
        return Prefs(context).isPremiumUnlocked
    }
}
