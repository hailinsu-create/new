package com.pangchuang.app

/**
 * Best-effort skip list for full companion capture.
 *
 * When Usage Access is granted, [shouldSkip] looks at the foreground package
 * and skips that tick (same as lock: no VirtualDisplay frame is sent, no API).
 * If Usage Access is off, this is a silent no-op — we never prompt.
 *
 * This is not an exploit and not complete. Package names change; banking apps
 * vary by country. WeChat / ordinary chat / browsers are intentionally NOT
 * listed: that is the product.
 *
 * Documented categories:
 * - IME / keyboards
 * - Password managers
 * - Authenticators / OTP
 * - Banking, wallets, Alipay, UnionPay, common US banks
 */
object SensitiveApps {
    val PACKAGES: Set<String> = setOf(
        // IME
        "com.google.android.inputmethod.latin",
        "com.google.android.inputmethod.pinyin",
        "com.android.inputmethod.latin",
        "com.samsung.android.honeyboard",
        "com.touchtype.swiftkey",
        "com.baidu.input",
        "com.sohu.inputmethod.sogou",
        "com.sohu.inputmethod.sogou.xiaomi",
        "com.iflytek.inputmethod",
        "com.tencent.qqpinyin",
        "com.tencent.wetype",
        "com.sina.input",
        "com.htc.sense.ime",
        "com.sonyericsson.textinput.uxp",
        "com.google.android.inputmethod.japanese",
        "com.google.android.inputmethod.korean",
        "com.samsung.android.svoiceime",
        "com.huawei.ohos.inputmethod",
        "com.baidu.input_huawei",
        "com.iflytek.inputmethod.google",
        "com.emoji.keyboard.touchpal",
        "com.jb.gokeyboard",
        "org.pocketworkstation.pckeyboard",
        "com.menny.android.anysoftkeyboard",
        "com.syntellicore.ime",
        // Password managers
        "com.1password.android",
        "com.lastpass.lpandroid",
        "com.bitwarden.android",
        "com.x8bit.bitwarden",
        "com.dashlane",
        "com.keepersecurity.android",
        "com.kunzisoft.keepass.free",
        "org.keepassdroid",
        "com.lyndir.masterpassword",
        "com.enpass.android",
        "com.nordpass.android",
        "com.sovell.password",
        "com.agilebits.onepassword",
        "me.proton.pass.android",
        "com.kunzisoft.keepass.pro",
        "com.samsung.android.authfw",
        // Authenticators
        "com.google.android.apps.authenticator2",
        "com.azure.authenticator",
        "com.authy.authy",
        "com.duosecurity.duomobile",
        "com.bitwarden.authenticator",
        "com.snowballtech.otpauthenticator",
        "org.fedorahosted.freeotp",
        "com.google.android.apps.authenticator",
        "com.beemdevelopment.aegis",
        "org.liberty.android.freeotpplus",
        "com.twofasapp",
        // Wallets / banking (CN + common global)
        "com.eg.android.AlipayGphone",
        "com.eg.android.AlipayGphoneRC",
        "com.unionpay",
        "com.unionpay.tsmservice",
        "com.chinamworld.main",
        "com.chinamworld.bocmbci",
        "com.icbc",
        "com.icbc.androidclient",
        "com.android.bankabc",
        "com.bankcomm.Bankcomm",
        "cmb.pb",
        "com.cmbchina.ccd.pluto.cmbActivity",
        "com.cs_credit_bank",
        "cn.com.cmbc.newmbank",
        "com.spdbccc.app",
        "com.pingan.paces.ccms",
        "com.tencent.unipay",
        "com.google.android.apps.walletnfcrel",
        "com.paypal.android.p2pmobile",
        "com.venmo",
        "com.squareup.cash",
        "com.chase.sig.android",
        "com.wf.wellsfargomobile",
        "com.infonow.bofa",
        "com.konylabs.capitalone",
        "com.usaa.mobile.android.usaa",
        "com.citi.citimobile",
        "com.revolut.revolut",
        "com.starlingbank.android",
        "com.binance.dev",
        "com.coinbase.android",
        "com.google.android.apps.nbu.paisa.user",
        "net.one97.paytm",
        "com.phonepe.app",
        "com.samsung.android.spay",
        "com.ccb.android",
        "jp.co.rakuten.bank",
        "jp.mufg.bk.android",
        "com.kakaobank.channel",
        "com.shinhan.sbank",
        "com.wooribank.smart",
        "com.wise.android"
    )

    val KEYWORDS: List<String> = listOf(
        "inputmethod",
        ".ime",
        "ime.",
        "password",
        "keepass",
        "1password",
        "lastpass",
        "bitwarden",
        "dashlane",
        "authenticator",
        "authy",
        "alipay",
        "unionpay",
        "bankofamerica",
        "wellsfargo",
        "capitalone",
        "spay",
        "gopay",
        "phonepe",
        "paytm",
        "coinbase",
        "binance",
        "gokeyboard",
        "anysoftkeyboard",
        "kakaobank",
        "freeotp",
        "aegis"
    )

    fun shouldSkip(packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return false
        val p = packageName.lowercase()
        if (p in PACKAGES) return true
        return KEYWORDS.any { p.contains(it) }
    }
}
