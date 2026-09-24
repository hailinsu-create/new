package com.pangchuang.app

/**
 * Low-battery capture rules. Pure for JVM tests.
 * Unknown / missing battery info must not skip ticks (no crash, no surprise pause).
 */
object BatteryPolicy {
    fun intervalMultiplier(percent: Int?, charging: Boolean, powerSave: Boolean): Int {
        if (charging) return 1
        val pct = percent ?: return if (powerSave) 2 else 1
        return when {
            pct <= 8 -> 3
            pct <= 20 || powerSave -> 2
            else -> 1
        }
    }

    fun shouldSkipTick(percent: Int?, charging: Boolean): Boolean {
        if (charging) return false
        val pct = percent ?: return false
        return pct in 1..5
    }

    fun useLowResCapture(lowRamDevice: Boolean, percent: Int?, charging: Boolean): Boolean {
        if (lowRamDevice) return true
        if (charging) return false
        val pct = percent ?: return false
        return pct in 1..20
    }

    fun captureMaxWidth(lowRamDevice: Boolean, percent: Int?, charging: Boolean): Int {
        return if (useLowResCapture(lowRamDevice, percent, charging)) 540 else 720
    }
}
