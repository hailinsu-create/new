package com.pangchuang.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SensitiveAppsTest {
    @Test
    fun skipsImeAndPasswordManagers() {
        assertTrue(SensitiveApps.shouldSkip("com.google.android.inputmethod.latin"))
        assertTrue(SensitiveApps.shouldSkip("com.sohu.inputmethod.sogou"))
        assertTrue(SensitiveApps.shouldSkip("com.1password.android"))
        assertTrue(SensitiveApps.shouldSkip("com.bitwarden.android"))
        assertTrue(SensitiveApps.shouldSkip("com.google.android.apps.authenticator2"))
        assertTrue(SensitiveApps.shouldSkip("com.beemdevelopment.aegis"))
        assertTrue(SensitiveApps.shouldSkip("com.jb.gokeyboard"))
        assertTrue(SensitiveApps.shouldSkip("me.proton.pass.android"))
    }

    @Test
    fun skipsBankingByPackageAndKeyword() {
        assertTrue(SensitiveApps.shouldSkip("com.eg.android.AlipayGphone"))
        assertTrue(SensitiveApps.shouldSkip("com.unionpay"))
        assertTrue(SensitiveApps.shouldSkip("com.paypal.android.p2pmobile"))
        assertTrue(SensitiveApps.shouldSkip("com.example.alipay.wallet"))
        assertTrue(SensitiveApps.shouldSkip("com.kakaobank.channel"))
        assertTrue(SensitiveApps.shouldSkip("com.google.android.apps.nbu.paisa.user"))
        assertTrue(SensitiveApps.shouldSkip("com.samsung.android.spay"))
    }

    @Test
    fun doesNotSkipOrdinaryChatOrThisApp() {
        assertFalse(SensitiveApps.shouldSkip("com.tencent.mm"))
        assertFalse(SensitiveApps.shouldSkip("com.pangchuang.app"))
        assertFalse(SensitiveApps.shouldSkip("com.android.chrome"))
        assertFalse(SensitiveApps.shouldSkip(null))
        assertFalse(SensitiveApps.shouldSkip(""))
    }
}
