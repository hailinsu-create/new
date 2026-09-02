package com.pangchuang.app

import android.content.Context
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat

object AppLanguages {
    data class Choice(val tag: String, val label: String)

    fun choices(context: Context): List<Choice> {
        val tags = context.resources.getStringArray(R.array.language_tags)
        val labels = context.resources.getStringArray(R.array.language_labels)
        return tags.zip(labels).map { Choice(it.first, it.second) }
    }

    fun currentTag(): String = AppCompatDelegate.getApplicationLocales().toLanguageTags()

    fun apply(tag: String) {
        val locales = if (tag.isBlank()) {
            LocaleListCompat.getEmptyLocaleList()
        } else {
            LocaleListCompat.forLanguageTags(tag)
        }
        AppCompatDelegate.setApplicationLocales(locales)
    }

    fun indexOfCurrent(choices: List<Choice>): Int {
        val cur = currentTag()
        if (cur.isBlank()) return 0
        val n = normalize(cur)
        val exact = choices.indexOfFirst { it.tag.isNotEmpty() && n == normalize(it.tag) }
        if (exact >= 0) return exact
        if (n.startsWith("zh-hant") || n.startsWith("zh-tw")) {
            val tw = choices.indexOfFirst { normalize(it.tag) == "zh-tw" }
            if (tw >= 0) return tw
        }
        if (n.startsWith("zh")) {
            val hans = choices.indexOfFirst { normalize(it.tag) == "zh" }
            if (hans >= 0) return hans
        }
        val lang = n.substringBefore('-')
        val loose = choices.indexOfFirst {
            it.tag.isNotEmpty() && normalize(it.tag).substringBefore('-') == lang
        }
        return if (loose >= 0) loose else 0
    }

    internal fun normalize(tag: String): String {
        val t = tag.trim().replace('_', '-').lowercase()
        return when {
            t == "in" || t.startsWith("in-") -> "id" + t.removePrefix("in")
            t == "iw" || t.startsWith("iw-") -> "he" + t.removePrefix("iw")
            else -> t
        }
    }
}
