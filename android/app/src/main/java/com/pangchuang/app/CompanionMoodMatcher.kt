package com.pangchuang.app

/**
 * Maps companion line text to a facial mood for the floating avatar.
 * Keyword scoring is intentionally simple and local (no network).
 */
enum class CompanionMood {
    IDLE,
    THINK,
    HAPPY,
    CARE,
    SURPRISE,
    SHY,
    TALK
}

object CompanionMoodMatcher {
    private data class Rule(val mood: CompanionMood, val words: List<String>, val weight: Int = 2)

    private val rules = listOf(
        Rule(
            CompanionMood.THINK,
            listOf("看看", "让我", "好像", "嗯", "判断", "想想", "准备", "等一下", "等我", "干嘛")
        ),
        Rule(
            CompanionMood.CARE,
            listOf(
                "歇", "休息", "夜里", "深夜", "眼睛", "慢慢", "陪着", "不急", "累", "保重",
                "早点睡", "眨眼", "熬夜", "心疼", "温柔"
            ),
            weight = 3
        ),
        Rule(
            CompanionMood.HAPPY,
            listOf(
                "开心", "喜欢", "加油", "真棒", "发光", "耶", "嘿嘿", "陪你", "好看",
                "顺利", "胜利", "可爱", "棒", "欢呼", "亮晶晶"
            ),
            weight = 3
        ),
        Rule(
            CompanionMood.SURPRISE,
            listOf("哇", "好多", "闪", "急", "连跪", "又", "居然", "突然", "购物车", "凑单"),
            weight = 2
        ),
        Rule(
            CompanionMood.SHY,
            listOf("害羞", "脸红", "不好意思", "夸", "谢谢", "喜欢你", "贴在", "身边"),
            weight = 3
        )
    )

    fun fromText(text: String): CompanionMood {
        val t = text.trim()
        if (t.isEmpty()) return CompanionMood.IDLE
        // Short system status lines
        if (t.contains("让我看看") || t.contains("正在") || t.contains("准备")) {
            return CompanionMood.THINK
        }
        var best = CompanionMood.TALK
        var bestScore = 0
        for (rule in rules) {
            var score = 0
            for (w in rule.words) {
                if (t.contains(w)) score += rule.weight
            }
            if (score > bestScore) {
                bestScore = score
                best = rule.mood
            }
        }
        return if (bestScore == 0) CompanionMood.TALK else best
    }

    fun restingDrawable(mood: CompanionMood): Int = when (mood) {
        CompanionMood.THINK -> R.drawable.companion_avatar_think
        CompanionMood.HAPPY -> R.drawable.companion_avatar_happy
        CompanionMood.CARE -> R.drawable.companion_avatar_care
        CompanionMood.SURPRISE -> R.drawable.companion_avatar_surprise
        CompanionMood.SHY -> R.drawable.companion_avatar_shy
        CompanionMood.TALK -> R.drawable.companion_avatar_talk
        CompanionMood.IDLE -> R.drawable.companion_avatar_idle
    }
}
