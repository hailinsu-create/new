package com.pangchuang.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ForegroundAppResolverTest {
    @Test
    fun ignoresLaunchersSystemUiAndSelf() {
        assertTrue(ForegroundAppResolver.isIgnorable("com.pangchuang.app", "com.pangchuang.app"))
        assertTrue(ForegroundAppResolver.isIgnorable("com.pangchuang.app", "com.android.systemui"))
        assertTrue(ForegroundAppResolver.isIgnorable("com.pangchuang.app", "com.google.android.apps.nexuslauncher"))
        assertFalse(ForegroundAppResolver.isIgnorable("com.pangchuang.app", "com.tencent.mm"))
        assertFalse(ForegroundAppResolver.isIgnorable("com.pangchuang.app", "com.android.chrome"))
    }
}
