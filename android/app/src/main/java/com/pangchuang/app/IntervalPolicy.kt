package com.pangchuang.app

/**
 * Companion interval bounds. Reject 0 and out-of-range instead of silently clamping.
 */
object IntervalPolicy {
    const val MIN_SEC = 5
    const val MAX_SEC = 120
    val PRESETS_SEC: IntArray = intArrayOf(10, 15, 30, 60)

    fun parse(raw: String?): Int? {
        val n = raw?.trim()?.toIntOrNull() ?: return null
        if (n < MIN_SEC || n > MAX_SEC) return null
        return n
    }

    fun isPreset(sec: Int): Boolean = PRESETS_SEC.contains(sec)
}
