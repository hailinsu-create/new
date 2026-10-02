package com.pangchuang.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EndpointPolicyTest {
    @Test
    fun httpsIsAllowed() {
        assertTrue(EndpointPolicy.isAllowedBaseUrl("https://api.siliconflow.cn/v1"))
        assertTrue(EndpointPolicy.isAllowedBaseUrl("HTTPS://example.com"))
    }

    @Test
    fun loopbackHttpIsAllowed() {
        assertTrue(EndpointPolicy.isAllowedBaseUrl("http://127.0.0.1:11434/v1"))
        assertTrue(EndpointPolicy.isAllowedBaseUrl("http://localhost:11434/v1"))
        assertTrue(EndpointPolicy.isAllowedBaseUrl("http://10.0.2.2:11434/v1"))
    }

    @Test
    fun cleartextLanIsBlocked() {
        assertFalse(EndpointPolicy.isAllowedBaseUrl("http://192.168.1.8:11434/v1"))
        assertFalse(EndpointPolicy.isAllowedBaseUrl("http://example.com/v1"))
        assertFalse(EndpointPolicy.isAllowedBaseUrl(""))
    }

    @Test
    fun redactStripsBearerAndKeys() {
        val raw = "Authorization: Bearer sk-abc123456789 and api_key=\"r8_secretvalue\""
        val redacted = EndpointPolicy.redact(raw)
        assertFalse(redacted.contains("sk-abc"))
        assertFalse(redacted.contains("r8_secret"))
        assertTrue(redacted.contains("***"))
        assertEquals("Bearer ***", EndpointPolicy.redact("Bearer tokentokentoken"))
    }
}
