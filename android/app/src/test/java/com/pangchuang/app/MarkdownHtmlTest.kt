package com.pangchuang.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MarkdownHtmlTest {
    @Test
    fun headingsBecomeHtmlNotRawHash() {
        val html = MarkdownHtml.convert("# 隐私政策\n\n## 数据\n\n正文。")
        assertTrue(html.contains("<h1>"))
        assertTrue(html.contains("<h2>"))
        assertFalse(html.contains("# 隐私"))
    }

    @Test
    fun listsAndBoldRender() {
        val html = MarkdownHtml.convert("- **截图**不会保存")
        assertTrue(html.contains("<ul>"))
        assertTrue(html.contains("<strong>截图</strong>"))
    }

    @Test
    fun wrapHasDarkThemeAndNoRawHeadingMarksInBody() {
        val page = MarkdownHtml.render("# Title\n\nHello")
        assertTrue(page.contains("<h1>Title</h1>"))
        assertTrue(page.contains("#1A1218"))
        assertFalse(page.substringAfter("<body>").contains("# Title"))
    }
}
