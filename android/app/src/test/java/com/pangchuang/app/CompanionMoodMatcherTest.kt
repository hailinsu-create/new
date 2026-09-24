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
        assertEquals(CompanionMood.CARE, CompanionMoodMatcher.fromText("休んで、今夜は眠って"))
        assertEquals(CompanionMood.SHY, CompanionMoodMatcher.fromText("ありがとう、恥ずかしい"))
        assertEquals(CompanionMood.THINK, CompanionMoodMatcher.fromText("잠깐, 생각 중"))
    }

    @Test
    fun fallbackDrawablesAreTwoPosesNotFour() {
        val rest = CompanionMoodMatcher.restingDrawable(CompanionMood.IDLE)
        val talk = CompanionMoodMatcher.restingDrawable(CompanionMood.TALK)
        assertNotEquals(rest, talk)
        assertEquals(rest, CompanionMoodMatcher.restingDrawable(CompanionMood.HAPPY))
        assertEquals(rest, CompanionMoodMatcher.restingDrawable(CompanionMood.SHY))
        assertEquals(talk, CompanionMoodMatcher.restingDrawable(CompanionMood.SURPRISE))
        assertEquals(talk, CompanionMoodMatcher.restingDrawable(CompanionMood.CARE))
    }
}
