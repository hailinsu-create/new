package com.pangchuang.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class IntervalPolicyTest {
    @Test
    fun rejectsZeroAndOutOfRange() {
        assertNull(IntervalPolicy.parse("0"))
        assertNull(IntervalPolicy.parse("4"))
        assertNull(IntervalPolicy.parse("121"))
        assertNull(IntervalPolicy.parse(""))
        assertNull(IntervalPolicy.parse("abc"))
        assertNull(IntervalPolicy.parse(null))
    }

    @Test
    fun acceptsPresetsAndCustomInRange() {
        assertEquals(10, IntervalPolicy.parse("10"))
        assertEquals(15, IntervalPolicy.parse("15"))
        assertEquals(30, IntervalPolicy.parse("30"))
        assertEquals(60, IntervalPolicy.parse("60"))
        assertEquals(8, IntervalPolicy.parse("8"))
        assertEquals(120, IntervalPolicy.parse("120"))
        assertTrue(IntervalPolicy.isPreset(15))
        assertFalse(IntervalPolicy.isPreset(8))
    }
}
