package com.pangchuang.app

import android.content.Context

/** Full companion (real screen capture) requires a one-time Play purchase; demo stays free. */
object Entitlement {
    fun isUnlocked(context: Context): Boolean {
        if (BuildConfig.DEBUG) return true
        return Prefs(context).isPremiumUnlocked
    }
}
