package com.pangchuang.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.ArrayAdapter
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.pangchuang.app.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity(), BillingManager.Listener {
    private lateinit var binding: ActivityMainBinding
    private lateinit var prefs: Prefs
    private var billingManager: BillingManager? = null
    private var displayedPrice: String? = null

    private val overlaySettingsLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            refreshPermissionLabels()
        }

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* no-op */ }

    private val captureLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode != Activity.RESULT_OK || result.data == null) {
                Toast.makeText(this, R.string.toast_need_capture, Toast.LENGTH_SHORT).show()
                return@registerForActivityResult
            }
            saveForm()
            RoastService.start(this, result.resultCode, result.data!!)
            Toast.makeText(this, R.string.toast_companion_ready, Toast.LENGTH_SHORT).show()
            moveTaskToBack(true)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        prefs = Prefs(this)
        prefs.migrateForPlayReadiness()

        binding.inputBaseUrl.setText(prefs.baseUrl)
        binding.inputApiKey.setText(prefs.apiKey)
        binding.inputModel.setText(prefs.model)
        binding.inputInterval.setText(prefs.intervalSec.toString())
        binding.switchMock.isChecked = prefs.mockApi
        setupLanguagePicker()

        binding.btnOverlay.setOnClickListener { openOverlaySettings() }
        binding.btnUsage.setOnClickListener { openUsageAccessSettings() }
        binding.btnPrivacy.setOnClickListener { openLegal(LegalActivity.MODE_PRIVACY) }
        binding.btnLicenses.setOnClickListener { openLegal(LegalActivity.MODE_LICENSES) }
        binding.btnTerms.setOnClickListener { openLegal(LegalActivity.MODE_TERMS) }
        binding.btnResetModel.setOnClickListener {
            prefs.useStableModel()
            binding.inputModel.setText(Prefs.MODEL_STABLE)
            Toast.makeText(this, R.string.toast_reset_model, Toast.LENGTH_SHORT).show()
        }
        binding.btnPurchase.setOnClickListener { billingManager?.launchPurchase() }
        binding.btnRestorePurchase.setOnClickListener { billingManager?.restorePurchases() }
        binding.btnStart.setOnClickListener { startRoastFlow() }
        binding.btnDemo.setOnClickListener { startDemoFlow() }
        binding.btnStop.setOnClickListener {
            RoastService.stop(this)
            Toast.makeText(this, R.string.toast_stopped, Toast.LENGTH_SHORT).show()
        }

        maybeAskNotificationPermission()
        refreshPermissionLabels()
        updatePrivacyStatus()
        updatePurchaseUi()
        billingManager = BillingManager(this, prefs, this).also { it.start() }

        if (intent?.getBooleanExtra(EXTRA_AUTO_DEMO, false) == true) {
            binding.root.post { startDemoFlow() }
        } else {
            maybeShowPrivacyConsent()
        }
    }

    private fun setupLanguagePicker() {
        val choices = AppLanguages.choices(this)
        binding.inputLanguage.setAdapter(
            ArrayAdapter(this, android.R.layout.simple_list_item_1, choices.map { it.label })
        )
        val index = AppLanguages.indexOfCurrent(choices).coerceIn(choices.indices)
        binding.inputLanguage.setText(choices[index].label, false)
        binding.inputLanguage.setOnClickListener { binding.inputLanguage.showDropDown() }
        binding.inputLanguage.setOnItemClickListener { _, _, pos, _ ->
            val chosen = choices[pos]
            val current = AppLanguages.currentTag()
            val same = if (chosen.tag.isBlank()) {
                current.isBlank()
            } else {
                current.equals(chosen.tag, ignoreCase = true)
            }
            if (same) return@setOnItemClickListener
            AppLanguages.apply(chosen.tag)
        }
    }

    override fun onDestroy() {
        billingManager?.stop()
        billingManager = null
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        refreshPermissionLabels()
        updatePrivacyStatus()
        updatePurchaseUi()
        billingManager?.start()
    }

    override fun onBillingReady(priceLabel: String?) {
        displayedPrice = priceLabel
        runOnUiThread { updatePurchaseUi() }
    }

    override fun onPurchaseStateChanged(unlocked: Boolean) {
        runOnUiThread { updatePurchaseUi() }
    }

    override fun onPurchaseMessage(message: String) {
        runOnUiThread {
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            updatePurchaseUi()
        }
    }

    private fun updatePurchaseUi() {
        val unlocked = Entitlement.isUnlocked(this)
        binding.purchaseStatus.text = if (unlocked) {
            getString(R.string.purchase_status_unlocked)
        } else {
            getString(R.string.purchase_status_locked)
        }
        binding.btnPurchase.isEnabled = !unlocked
        binding.btnRestorePurchase.isEnabled = !unlocked
        binding.btnPurchase.text = if (unlocked) {
            getString(R.string.purchase_unlocked_button)
        } else {
            val price = displayedPrice ?: getString(R.string.purchase_price_fallback)
            getString(R.string.purchase_buy_with_price, price)
        }
        if (BuildConfig.DEBUG) {
            binding.purchaseDebugNote.visibility = android.view.View.VISIBLE
        } else {
            binding.purchaseDebugNote.visibility = android.view.View.GONE
        }
    }

    private fun maybeAskNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            if (!granted) {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    private fun refreshPermissionLabels() {
        val overlayOk = Settings.canDrawOverlays(this)
        binding.overlayStatus.text = if (overlayOk) {
            getString(R.string.overlay_on)
        } else {
            getString(R.string.overlay_hint)
        }
        binding.btnOverlay.isEnabled = !overlayOk
        binding.captureStatus.text = getString(R.string.capture_hint)
        val usageOk = ForegroundAppResolver.hasUsageAccess(this)
        binding.usageStatus.text = if (usageOk) {
            getString(R.string.usage_on)
        } else {
            getString(R.string.usage_hint)
        }
        binding.btnUsage.isEnabled = !usageOk
    }

    private fun updatePrivacyStatus() {
        binding.privacyStatus.text = if (prefs.hasPrivacyConsent) {
            getString(R.string.privacy_accepted)
        } else {
            getString(R.string.privacy_required)
        }
    }

    private fun maybeShowPrivacyConsent() {
        if (prefs.hasPrivacyConsent) return
        val message = getString(R.string.privacy_consent_message)
        val dialog = MaterialAlertDialogBuilder(this)
            .setTitle(R.string.privacy_consent_title)
            .setMessage(message)
            .setPositiveButton(R.string.privacy_accept) { _, _ ->
                prefs.acceptPrivacy()
                updatePrivacyStatus()
            }
            .setNeutralButton(R.string.privacy_view_policy) { _, _ ->
                openLegal(LegalActivity.MODE_PRIVACY)
            }
            .setNegativeButton(R.string.privacy_decline, null)
            .setCancelable(false)
            .create()
        dialog.show()
    }

    private fun ensurePrivacyConsent(): Boolean {
        if (prefs.hasPrivacyConsent) return true
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.privacy_consent_title)
            .setMessage(R.string.privacy_consent_message)
            .setPositiveButton(R.string.privacy_accept) { _, _ ->
                prefs.acceptPrivacy()
                updatePrivacyStatus()
            }
            .setNeutralButton(R.string.privacy_view_policy) { _, _ ->
                openLegal(LegalActivity.MODE_PRIVACY)
            }
            .setNegativeButton(R.string.privacy_decline, null)
            .show()
        return false
    }

    private fun openLegal(mode: String) {
        startActivity(
            Intent(this, LegalActivity::class.java).putExtra(LegalActivity.EXTRA_MODE, mode)
        )
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        overlaySettingsLauncher.launch(intent)
    }

    private fun openUsageAccessSettings() {
        runCatching {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }.onFailure {
            Toast.makeText(this, R.string.toast_usage_settings_fail, Toast.LENGTH_LONG)
                .show()
        }
    }

    private fun saveForm() {
        prefs.baseUrl = binding.inputBaseUrl.text?.toString().orEmpty()
        prefs.apiKey = binding.inputApiKey.text?.toString().orEmpty()
        prefs.model = binding.inputModel.text?.toString().orEmpty()
        prefs.intervalSec = binding.inputInterval.text?.toString()?.toIntOrNull() ?: 15
        prefs.mockApi = binding.switchMock.isChecked
    }

    private fun startRoastFlow() {
        if (!ensurePrivacyConsent()) return
        if (!Entitlement.isUnlocked(this)) {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.purchase_required_title)
                .setMessage(R.string.purchase_required_message)
                .setPositiveButton(R.string.purchase_buy) { _, _ ->
                    billingManager?.launchPurchase()
                }
                .setNeutralButton(R.string.start_demo, null)
                .setNegativeButton(android.R.string.cancel, null)
                .show()
            return
        }
        if (!Settings.canDrawOverlays(this)) {
            Toast.makeText(this, R.string.toast_need_overlay, Toast.LENGTH_SHORT).show()
            openOverlaySettings()
            return
        }
        saveForm()
        if (!prefs.mockApi && prefs.apiKey.isBlank()) {
            Toast.makeText(
                this,
                R.string.toast_need_api_key,
                Toast.LENGTH_LONG
            ).show()
            return
        }
        if (!prefs.mockApi && !prefs.baseUrl.startsWith("https://") &&
            !prefs.baseUrl.contains("127.0.0.1") &&
            !prefs.baseUrl.contains("localhost") &&
            !prefs.baseUrl.contains("10.0.2.2")
        ) {
            Toast.makeText(
                this,
                R.string.toast_https_only,
                Toast.LENGTH_LONG
            ).show()
            return
        }
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.capture_disclosure_title)
            .setMessage(R.string.capture_disclosure_message)
            .setPositiveButton(R.string.capture_disclosure_continue) { _, _ ->
                val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                captureLauncher.launch(mpm.createScreenCaptureIntent())
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun startDemoFlow() {
        if (!ensurePrivacyConsent()) return
        if (!Settings.canDrawOverlays(this)) {
            Toast.makeText(this, R.string.toast_need_overlay, Toast.LENGTH_SHORT).show()
            openOverlaySettings()
            return
        }
        saveForm()
        prefs.mockApi = true
        binding.switchMock.isChecked = true
        RoastService.startDemo(this)
        Toast.makeText(this, R.string.toast_demo_started, Toast.LENGTH_SHORT).show()
        moveTaskToBack(true)
    }

    companion object {
        const val EXTRA_AUTO_DEMO = "auto_demo"
    }
}
