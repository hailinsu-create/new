package com.pangchuang.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class CompanionMoodMatcherTest {
    @Test
    fun thinkCareShyAreDistinctMoods() {
        assertEquals(CompanionMood.THINK, CompanionMoodMatcher.fromText("让我看看你在干嘛"))
        assertEquals(CompanionMood.CARE, CompanionMoodMatcher.fromText("夜里别熬太晚，歇一歇眼睛"))
        assertEquals(CompanionMood.SHY, CompanionMoodMatcher.fromText("谢谢你夸，有点害羞"))
        assertEquals(CompanionMood.HAPPY, CompanionMoodMatcher.fromText("耶，这一把打得真棒"))
    }

    @Test
    fun fallbackDrawablesAreNotAllTheSame() {
        val think = CompanionMoodMatcher.restingDrawable(CompanionMood.THINK)
        val care = CompanionMoodMatcher.restingDrawable(CompanionMood.CARE)
        val surprise = CompanionMoodMatcher.restingDrawable(CompanionMood.SURPRISE)
        val happy = CompanionMoodMatcher.restingDrawable(CompanionMood.HAPPY)
        assertNotEquals(think, care)
        assertNotEquals(think, surprise)
        assertNotEquals(care, surprise)
        assertEquals(happy, CompanionMoodMatcher.restingDrawable(CompanionMood.SHY))
    }
}
