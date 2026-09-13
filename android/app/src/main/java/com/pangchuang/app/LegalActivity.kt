package com.pangchuang.app

import android.graphics.Color
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.pangchuang.app.databinding.ActivityLegalBinding
import java.nio.charset.Charset

class LegalActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val binding = ActivityLegalBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_PRIVACY
        val pageTitle = when (mode) {
            MODE_LICENSES -> getString(R.string.legal_licenses_title)
            MODE_TERMS -> getString(R.string.legal_terms_title)
            else -> getString(R.string.legal_privacy_title)
        }
        binding.legalTitle.text = pageTitle
        binding.legalTitle.contentDescription = pageTitle
        setTitle(pageTitle)
        binding.legalVersion.text = getString(R.string.legal_about_version, BuildConfig.VERSION_NAME)
        binding.btnLegalClose.contentDescription = getString(R.string.legal_up_cd)

        val web = binding.legalWeb
        web.setBackgroundColor(Color.parseColor("#1A1218"))
        web.settings.javaScriptEnabled = false
        web.settings.defaultTextEncodingName = "utf-8"
        web.isVerticalScrollBarEnabled = true

        val html = when (mode) {
            MODE_LICENSES -> MarkdownHtml.wrapPlain(loadAsset("legal/open_source_licenses.txt"))
            MODE_TERMS -> MarkdownHtml.render(loadMarkdown("legal/terms_of_use.md"))
            else -> MarkdownHtml.render(loadMarkdown("legal/privacy_policy.md"))
        }
        web.clearHistory()
        web.loadDataWithBaseURL(null, html, "text/html", "utf-8", null)
        web.webViewClient = object : android.webkit.WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: android.webkit.WebView?,
                request: android.webkit.WebResourceRequest?
            ): Boolean {
                val uri = request?.url ?: return true
                if (uri.scheme == "https") {
                    runCatching {
                        startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, uri))
                    }
                }
                return true
            }
        }
        binding.btnLegalClose.setOnClickListener { finish() }
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.setHomeActionContentDescription(R.string.legal_up_cd)
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    private fun loadMarkdown(path: String): String = loadAsset(path)

    private fun loadAsset(path: String): String {
        val lang = resources.configuration.locales[0].language
        val localized = if (lang == "zh") {
            path
        } else {
            path.replace(".md", "_en.md")
        }
        val tryPaths = if (localized == path) listOf(path) else listOf(localized, path)
        for (candidate in tryPaths) {
            val text = runCatching {
                assets.open(candidate).use { stream ->
                    stream.readBytes().toString(Charset.forName("UTF-8"))
                }
            }.getOrNull()
            if (text != null) return text
        }
        return getString(R.string.legal_load_failed, path)
    }

    companion object {
        const val EXTRA_MODE = "mode"
        const val MODE_PRIVACY = "privacy"
        const val MODE_LICENSES = "licenses"
        const val MODE_TERMS = "terms"
    }
}
