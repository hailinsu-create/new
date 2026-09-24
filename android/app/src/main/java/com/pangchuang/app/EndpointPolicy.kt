package com.pangchuang.app

/**
 * HTTPS-only vision endpoints except loopback for local Ollama / emulator.
 * Pure so it can be unit-tested without OkHttp.
 */
object EndpointPolicy {
    fun isAllowedBaseUrl(url: String): Boolean {
        val u = url.trim()
        if (u.isEmpty()) return false
        if (u.startsWith("https://", ignoreCase = true)) return true
        val lower = u.lowercase()
        return lower.startsWith("http://127.0.0.1") ||
            lower.startsWith("http://localhost") ||
            lower.startsWith("http://[::1]") ||
            lower.startsWith("http://10.0.2.2")
    }

    /** Strip secrets from log/error fragments. Never log raw keys. */
    fun redact(text: String): String {
        var s = text
        s = s.replace(Regex("(?i)Bearer\\s+[A-Za-z0-9._\\-]+"), "Bearer ***")
        s = s.replace(Regex("(?i)(sk-|sk-or-|r8_|key-)[A-Za-z0-9._\\-]{6,}"), "***")
        s = s.replace(Regex("(?i)(api[_-]?key\"?\\s*[:=]\\s*\")[^\"]+\""), "$1***\"")
        s = s.replace(Regex("(?i)(Authorization\"?\\s*[:=]\\s*\")[^\"]+\""), "$1***\"")
        return s
    }
}
