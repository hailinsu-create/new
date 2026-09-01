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
            else -> "legal/privacy_policy.md"
        }
        val title = when (mode) {
            MODE_LICENSES -> "开源与素材许可"
            else -> "隐私政策"
        }
        binding.legalTitle.text = title
        binding.legalBody.text = loadAsset(assetPath)
        binding.btnLegalClose.setOnClickListener { finish() }
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
    }

    private fun loadAsset(path: String): String {
        return runCatching {
            assets.open(path).use { stream ->
                stream.readBytes().toString(Charset.forName("UTF-8"))
            }
        }.getOrElse { "无法加载 $path" }
    }

    companion object {
        const val EXTRA_MODE = "mode"
        const val MODE_PRIVACY = "privacy"
        const val MODE_LICENSES = "licenses"
    }
}
