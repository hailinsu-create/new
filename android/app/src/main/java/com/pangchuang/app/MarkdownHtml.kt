package com.pangchuang.app

/**
 * Small markdown-to-HTML renderer for in-app legal pages.
 * Handles headings, lists, bold, inline code, tables, and paragraphs.
 * Not a full CommonMark implementation.
 */
object MarkdownHtml {
    fun render(markdown: String): String {
        val body = convert(markdown)
        return wrap(body)
    }

    fun wrapPlain(text: String): String {
        val escaped = escape(text)
        return wrap("<pre style=\"white-space:pre-wrap;font-family:ui-monospace,monospace;font-size:13px;\">$escaped</pre>")
    }

    fun wrap(body: String): String = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width, initial-scale=1"/>
          <style>
            body { font-family: system-ui, sans-serif; color: #FFF7F5; background: #1A1218;
                   line-height: 1.65; padding: 4px 2px 24px; margin: 0; }
            h1, h2, h3 { color: #FFC8D4; font-weight: 650; }
            h1 { font-size: 1.45rem; }
            h2 { font-size: 1.15rem; margin-top: 1.4em; }
            h3 { font-size: 1.02rem; }
            a { color: #F2A7B8; }
            code { color: #FFC8D4; font-size: 0.92em; }
            table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 0.92em; }
            td, th { border: 1px solid #4a3340; padding: 8px; text-align: left; }
            th { color: #FFC8D4; }
            ul { padding-left: 1.2em; }
            p { margin: 0.7em 0; }
          </style>
        </head>
        <body>$body</body>
        </html>
    """.trimIndent()

    internal fun convert(markdown: String): String {
        val lines = markdown.replace("\r\n", "\n").split('\n')
        val out = StringBuilder()
        var i = 0
        var inList = false
        while (i < lines.size) {
            val raw = lines[i]
            val line = raw.trimEnd()
            when {
                line.startsWith("|") && i + 1 < lines.size && lines[i + 1].contains("---") -> {
                    closeList(out, inList); inList = false
                    val rows = mutableListOf(line)
                    i++
                    while (i < lines.size && lines[i].trim().startsWith("|")) {
                        rows.add(lines[i].trimEnd())
                        i++
                    }
                    out.append(tableHtml(rows))
                    continue
                }
                line.startsWith("### ") -> {
                    closeList(out, inList); inList = false
                    out.append("<h3>").append(inline(line.removePrefix("### ").trim())).append("</h3>")
                }
                line.startsWith("## ") -> {
                    closeList(out, inList); inList = false
                    out.append("<h2>").append(inline(line.removePrefix("## ").trim())).append("</h2>")
                }
                line.startsWith("# ") -> {
                    closeList(out, inList); inList = false
                    out.append("<h1>").append(inline(line.removePrefix("# ").trim())).append("</h1>")
                }
                line.startsWith("- ") || line.startsWith("* ") -> {
                    if (!inList) {
                        out.append("<ul>")
                        inList = true
                    }
                    out.append("<li>").append(inline(line.substring(2).trim())).append("</li>")
                }
                line.isBlank() -> {
                    closeList(out, inList); inList = false
                }
                else -> {
                    closeList(out, inList); inList = false
                    out.append("<p>").append(inline(line.trim())).append("</p>")
                }
            }
            i++
        }
        closeList(out, inList)
        return out.toString()
    }

    private fun closeList(out: StringBuilder, inList: Boolean) {
        if (inList) out.append("</ul>")
    }

    private fun tableHtml(rows: List<String>): String {
        val parsed = rows
            .filter { !it.contains("---") }
            .map { row ->
                row.trim().trim('|').split('|').map { inline(it.trim()) }
            }
        if (parsed.isEmpty()) return ""
        val sb = StringBuilder("<table>")
        parsed.forEachIndexed { idx, cols ->
            sb.append("<tr>")
            val tag = if (idx == 0) "th" else "td"
            cols.forEach { sb.append('<').append(tag).append('>').append(it).append("</").append(tag).append('>') }
            sb.append("</tr>")
        }
        sb.append("</table>")
        return sb.toString()
    }

    private fun inline(text: String): String {
        var s = escape(text)
        s = s.replace(Regex("\\*\\*(.+?)\\*\\*"), "<strong>$1</strong>")
        s = s.replace(Regex("`([^`]+)`"), "<code>$1</code>")
        s = s.replace(Regex("\\[([^\\]]+)]\\(([^)]+)\\)"), "<a href=\"$2\">$1</a>")
        return s
    }

    private fun escape(text: String): String =
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
}
