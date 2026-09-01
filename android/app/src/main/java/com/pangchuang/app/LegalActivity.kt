package com.pangchuang.app

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
        val assetPath = when (mode) {
            MODE_LICENSES -> "legal/open_source_licenses.txt"
            MODE_TERMS -> "legal/terms_of_use.md"
            else -> "legal/privacy_policy.md"
        }
        val title = when (mode) {
            MODE_LICENSES -> getString(R.string.legal_licenses_title)
            MODE_TERMS -> getString(R.string.legal_terms_title)
            else -> getString(R.string.legal_privacy_title)
        }
        binding.legalTitle.text = title
        binding.legalBody.text = loadAsset(assetPath)
        binding.btnLegalClose.setOnClickListener { finish() }
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
    }

    private fun loadAsset(path: String): String {
        val lang = resources.configuration.locales[0].language
        val localized = if (lang == "zh") {
            path
        } else {
            path.replace(".md", "_en.md").replace(".txt", ".txt")
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
