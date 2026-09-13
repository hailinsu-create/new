package com.pangchuang.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BatteryPolicyTest {
    @Test
    fun unknownBatteryDoesNotSkip() {
        assertFalse(BatteryPolicy.shouldSkipTick(null, charging = false))
        assertEquals(1, BatteryPolicy.intervalMultiplier(null, charging = false, powerSave = false))
        assertEquals(720, BatteryPolicy.captureMaxWidth(false, null, false))
    }

    @Test
    fun criticalBatterySkipsWhenNotCharging() {
        assertTrue(BatteryPolicy.shouldSkipTick(4, charging = false))
        assertFalse(BatteryPolicy.shouldSkipTick(4, charging = true))
        assertFalse(BatteryPolicy.shouldSkipTick(15, charging = false))
    }

    @Test
    fun lowBatteryLengthensIntervalAndDropsTo540p() {
        assertEquals(3, BatteryPolicy.intervalMultiplier(5, charging = false, powerSave = false))
        assertEquals(2, BatteryPolicy.intervalMultiplier(18, charging = false, powerSave = false))
        assertEquals(1, BatteryPolicy.intervalMultiplier(18, charging = true, powerSave = true))
        assertEquals(540, BatteryPolicy.captureMaxWidth(false, 12, false))
        assertEquals(540, BatteryPolicy.captureMaxWidth(true, 80, true))
        assertEquals(720, BatteryPolicy.captureMaxWidth(false, 80, false))
    }
}
