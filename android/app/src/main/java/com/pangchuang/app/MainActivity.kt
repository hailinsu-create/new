package com.pangchuang.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.pangchuang.app.databinding.ActivityMainBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity(), BillingManager.Listener {
    private lateinit var binding: ActivityMainBinding
    private lateinit var prefs: Prefs
    private var billingManager: BillingManager? = null
    private var displayedPrice: String? = null
    private var advancedOpen = false
    private var homeEngineUnloaded = false
    private var consentDialogShowing = false

    private val overlaySettingsLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            refreshHome()
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

        loadForm()
        setupLanguagePicker()
        setupModelPreset()
        setupIntervalPreset()

        binding.btnOverlay.setOnClickListener { openOverlaySettings() }
        binding.btnUsage.setOnClickListener { openUsageAccessSettings() }
        binding.btnPrivacy.setOnClickListener { openLegal(LegalActivity.MODE_PRIVACY) }
        binding.btnLicenses.setOnClickListener { openLegal(LegalActivity.MODE_LICENSES) }
        binding.btnTerms.setOnClickListener { openLegal(LegalActivity.MODE_TERMS) }
        binding.btnResetModel.setOnClickListener {
            prefs.useStableModel()
            binding.inputModel.setText(Prefs.MODEL_STABLE)
            binding.inputModelPreset.setText(getString(R.string.model_preset_8b), false)
            binding.inputModelLayout.visibility = View.GONE
            Toast.makeText(this, R.string.toast_reset_model, Toast.LENGTH_SHORT).show()
        }
        binding.btnPurchase.setOnClickListener { billingManager?.launchPurchase() }
        binding.btnRestorePurchase.setOnClickListener { billingManager?.restorePurchases() }
        binding.btnStart.setOnClickListener { startRoastFlow() }
        binding.btnDemo.setOnClickListener { startDemoFlow() }
        binding.btnStop.setOnClickListener {
            RoastService.stop(this)
            Toast.makeText(this, R.string.toast_stopped, Toast.LENGTH_SHORT).show()
            binding.root.postDelayed({ refreshHome() }, 250)
        }
        binding.btnToggleSettings.setOnClickListener { toggleAdvanced() }
        binding.btnPing.setOnClickListener { pingVision() }
        binding.btnRevokePrivacy.setOnClickListener { revokePrivacyConsent() }

        refreshHome()
        billingManager = BillingManager(this, prefs, this).also { it.start() }

        if (intent?.getBooleanExtra(EXTRA_AUTO_DEMO, false) == true) {
            binding.root.post { startDemoFlow() }
        } else {
            maybeShowPrivacyConsent()
        }
    }

    private fun loadForm() {
        binding.inputBaseUrl.setText(prefs.baseUrl)
        binding.inputApiKey.setText(prefs.apiKey)
        binding.inputModel.setText(prefs.model)
        binding.inputInterval.setText(prefs.intervalSec.toString())
        binding.inputThreshold.setText(prefs.changeThreshold.toInt().toString())
        binding.switchMock.isChecked = prefs.mockApi
        binding.switchMock.setOnCheckedChangeListener { _, checked ->
            prefs.mockApi = checked
        }
    }

    private fun setupModelPreset() {
        val labels = listOf(
            getString(R.string.model_preset_8b),
            getString(R.string.model_preset_custom)
        )
        binding.inputModelPreset.setAdapter(
            ArrayAdapter(this, android.R.layout.simple_list_item_1, labels)
        )
        val isStable = prefs.model == Prefs.MODEL_STABLE
        binding.inputModelPreset.setText(if (isStable) labels[0] else labels[1], false)
        binding.inputModelLayout.visibility = if (isStable) View.GONE else View.VISIBLE
        binding.inputModelPreset.setOnClickListener { binding.inputModelPreset.showDropDown() }
        binding.inputModelPreset.setOnItemClickListener { _, _, pos, _ ->
            if (pos == 0) {
                prefs.useStableModel()
                binding.inputModel.setText(Prefs.MODEL_STABLE)
                binding.inputModelLayout.visibility = View.GONE
            } else {
                binding.inputModelLayout.visibility = View.VISIBLE
            }
        }
    }

    private fun setupIntervalPreset() {
        val labels = IntervalPolicy.PRESETS_SEC.map { "${it}s" } +
            getString(R.string.interval_preset_custom)
        binding.inputIntervalPreset.setAdapter(
            ArrayAdapter(this, android.R.layout.simple_list_item_1, labels)
        )
        val sec = prefs.intervalSec
        val presetIndex = IntervalPolicy.PRESETS_SEC.indexOf(sec)
        if (presetIndex >= 0) {
            binding.inputIntervalPreset.setText(labels[presetIndex], false)
            binding.inputIntervalLayout.visibility = View.GONE
        } else {
            binding.inputIntervalPreset.setText(labels.last(), false)
            binding.inputIntervalLayout.visibility = View.VISIBLE
        }
        binding.inputIntervalPreset.setOnClickListener { binding.inputIntervalPreset.showDropDown() }
        binding.inputIntervalPreset.setOnItemClickListener { _, _, pos, _ ->
            if (pos < IntervalPolicy.PRESETS_SEC.size) {
                val chosen = IntervalPolicy.PRESETS_SEC[pos]
                binding.inputInterval.setText(chosen.toString())
                prefs.intervalSec = chosen
                binding.inputIntervalLayout.visibility = View.GONE
            } else {
                binding.inputIntervalLayout.visibility = View.VISIBLE
            }
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
            saveForm()
            AppLanguages.apply(chosen.tag)
        }
    }

    override fun onPause() {
        saveForm()
        if (!RoastService.running && !homeEngineUnloaded && ::binding.isInitialized) {
            binding.homeLive2d.pauseRendering()
        }
        super.onPause()
    }

    override fun onDestroy() {
        billingManager?.stop()
        billingManager = null
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        refreshHome()
        billingManager?.start()
        if (!prefs.hasPrivacyConsent) {
            maybeShowPrivacyConsent()
        } else {
            maybeAskNotificationPermission()
        }
        if (!RoastService.running && !homeEngineUnloaded && ::binding.isInitialized) {
            binding.homeLive2d.resumeRendering()
        }
    }

    override fun onBillingReady(priceLabel: String?) {
        displayedPrice = priceLabel
        runOnUiThread { updatePurchaseUi() }
    }

    override fun onPurchaseStateChanged(unlocked: Boolean) {
        runOnUiThread { updatePurchaseUi(); refreshStatus() }
    }

    override fun onPurchaseMessage(message: String) {
        runOnUiThread {
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            updatePurchaseUi()
        }
    }

    private fun toggleAdvanced() {
        advancedOpen = !advancedOpen
        binding.advancedPanel.visibility = if (advancedOpen) View.VISIBLE else View.GONE
        binding.btnToggleSettings.text = getString(
            if (advancedOpen) R.string.settings_collapse else R.string.settings_expand
        )
        binding.btnToggleSettings.contentDescription = getString(R.string.cd_settings_toggle)
    }

    private fun refreshHome() {
        refreshPermissionLabels()
        updatePrivacyStatus()
        updatePurchaseUi()
        refreshStatus()
        refreshPreview()
        binding.homeVersion.text = getString(
            R.string.home_version,
            BuildConfig.VERSION_NAME,
            BuildConfig.VERSION_CODE
        )
        binding.homeDebugChip.visibility = if (BuildConfig.DEBUG) View.VISIBLE else View.GONE
    }

    private fun refreshPreview() {
        val overlayUp = RoastService.running
        if (overlayUp) {
            if (!homeEngineUnloaded) {
                binding.homeLive2d.unloadEngine()
                homeEngineUnloaded = true
            }
            binding.homeLive2d.visibility = View.GONE
            binding.homeStatic.visibility = View.VISIBLE
        } else {
            binding.homeStatic.visibility = View.GONE
            binding.homeLive2d.visibility = View.VISIBLE
            if (homeEngineUnloaded) {
                binding.homeLive2d.reloadEngine()
                homeEngineUnloaded = false
            }
        }
    }

    private fun refreshStatus() {
        val unlocked = Entitlement.isUnlocked(this)
        val overlayOk = Settings.canDrawOverlays(this)
        val parts = mutableListOf<String>()
        parts += when {
            RoastService.running && RoastService.pausedLock && RoastService.runningDemo ->
                getString(R.string.home_status_locked_pause_demo)
            RoastService.running && RoastService.pausedLock ->
                getString(R.string.home_status_locked_pause)
            RoastService.running && RoastService.pausedSensitive ->
                getString(R.string.home_status_sensitive_pause)
            RoastService.running && RoastService.runningDemo ->
                getString(R.string.home_status_demo)
            RoastService.running ->
                getString(R.string.home_status_full)
            else ->
                getString(R.string.home_status_idle)
        }
        parts += if (overlayOk) {
            getString(R.string.overlay_on)
        } else {
            getString(R.string.overlay_hint)
        }
        parts += if (unlocked) {
            getString(R.string.home_status_unlocked)
        } else {
            getString(R.string.home_status_locked)
        }
        if (prefs.purchasePending && !unlocked) {
            parts += getString(R.string.home_status_purchase_pending)
        }
        val err = prefs.lastCompanionError
        if (err.isNotBlank() && !RoastService.running) {
            parts += getString(R.string.home_status_error, err)
        }
        binding.homeStatus.text = parts.joinToString("\n")
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
            binding.purchaseDebugNote.visibility = View.VISIBLE
        } else {
            binding.purchaseDebugNote.visibility = View.GONE
        }
    }

    private fun maybeAskNotificationPermission() {
        if (!prefs.hasPrivacyConsent) return
        if (Build.VERSION.SDK_INT < 33) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (granted) return
        if (prefs.notificationPrompted) return
        prefs.notificationPrompted = true
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.notification_rationale_title)
            .setMessage(R.string.notification_rationale_message)
            .setPositiveButton(R.string.notification_rationale_allow) { _, _ ->
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            .setNegativeButton(R.string.notification_rationale_skip, null)
            .show()
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
        binding.btnRevokePrivacy.isEnabled = prefs.hasPrivacyConsent
    }

    private fun maybeShowPrivacyConsent() {
        if (prefs.hasPrivacyConsent) return
        if (consentDialogShowing) return
        consentDialogShowing = true
        val message = getString(R.string.privacy_consent_message)
        val dialog = MaterialAlertDialogBuilder(this)
            .setTitle(R.string.privacy_consent_title)
            .setMessage(message)
            .setPositiveButton(R.string.privacy_accept) { _, _ ->
                prefs.acceptPrivacy()
                updatePrivacyStatus()
                maybeAskNotificationPermission()
            }
            .setNeutralButton(R.string.privacy_view_policy) { _, _ ->
                openLegal(LegalActivity.MODE_PRIVACY)
            }
            .setNegativeButton(R.string.privacy_decline, null)
            .setCancelable(false)
            .create()
        dialog.setOnDismissListener { consentDialogShowing = false }
        dialog.show()
    }

    private fun revokePrivacyConsent() {
        prefs.revokePrivacy()
        RoastService.stop(this)
        updatePrivacyStatus()
        refreshHome()
        Toast.makeText(this, R.string.privacy_revoked, Toast.LENGTH_LONG).show()
        binding.root.postDelayed({ maybeShowPrivacyConsent() }, 300)
    }

    private fun ensurePrivacyConsent(): Boolean {
        if (prefs.hasPrivacyConsent) return true
        maybeShowPrivacyConsent()
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
        if (!::binding.isInitialized || !::prefs.isInitialized) return
        prefs.baseUrl = binding.inputBaseUrl.text?.toString().orEmpty()
        prefs.apiKey = binding.inputApiKey.text?.toString().orEmpty()
        prefs.model = binding.inputModel.text?.toString().orEmpty()
        val parsedInterval = IntervalPolicy.parse(binding.inputInterval.text?.toString())
        if (parsedInterval != null) {
            prefs.intervalSec = parsedInterval
        }
        prefs.changeThreshold =
            binding.inputThreshold.text?.toString()?.toFloatOrNull() ?: Prefs.DEFAULT_THRESHOLD
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
                .setNeutralButton(R.string.start_demo) { _, _ -> startDemoFlow() }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
            return
        }
        if (!Settings.canDrawOverlays(this)) {
            Toast.makeText(this, R.string.toast_need_overlay, Toast.LENGTH_SHORT).show()
            openOverlaySettings()
            return
        }
        if (!saveFormOrExplain()) return
        if (CapturePolicy.fullCompanionBlockedByDemoLines(prefs.mockApi)) {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.mock_blocks_full_title)
                .setMessage(R.string.mock_blocks_full_message)
                .setPositiveButton(R.string.mock_blocks_full_turn_off) { _, _ ->
                    binding.switchMock.isChecked = false
                    prefs.mockApi = false
                    startRoastFlow()
                }
                .setNeutralButton(R.string.start_demo) { _, _ -> startDemoFlow() }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
            return
        }
        if (prefs.apiKey.isBlank()) {
            MaterialAlertDialogBuilder(this)
                .setTitle(R.string.toast_need_api_key)
                .setMessage(R.string.empty_key_explain)
                .setPositiveButton(R.string.settings_expand) { _, _ ->
                    if (!advancedOpen) toggleAdvanced()
                    binding.advancedPanel.post {
                        binding.inputApiKey.requestFocus()
                    }
                }
                .setNeutralButton(R.string.start_demo) { _, _ -> startDemoFlow() }
                .setNegativeButton(android.R.string.cancel, null)
                .show()
            return
        }
        if (!prefs.baseUrl.startsWith("https://") &&
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
        if (!saveFormOrExplain()) return
        // Demo uses an in-memory session flag in RoastService. Never persist mockApi=true.
        RoastService.startDemo(this)
        Toast.makeText(this, R.string.toast_demo_started, Toast.LENGTH_SHORT).show()
        moveTaskToBack(true)
    }

    private fun saveFormOrExplain(): Boolean {
        val raw = binding.inputInterval.text?.toString()
        if (IntervalPolicy.parse(raw) == null &&
            binding.inputIntervalLayout.visibility == View.VISIBLE
        ) {
            Toast.makeText(this, R.string.toast_interval_invalid, Toast.LENGTH_LONG).show()
            return false
        }
        saveForm()
        return true
    }

    private fun pingVision() {
        if (!saveFormOrExplain()) return
        binding.pingStatus.text = getString(R.string.ping_testing)
        lifecycleScope.launch {
            val result = withContext(Dispatchers.IO) {
                VisionClient(this@MainActivity, prefs).ping()
            }
            binding.pingStatus.text = result.text
            if (result.source == "error") {
                prefs.recordCompanionError(result.text)
            } else {
                prefs.clearCompanionError()
            }
            refreshStatus()
        }
    }

    companion object {
        const val EXTRA_AUTO_DEMO = "auto_demo"
    }
}
