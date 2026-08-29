package com.pangchuang.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.pangchuang.app.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private lateinit var prefs: Prefs

    private val overlaySettingsLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
            refreshPermissionLabels()
        }

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* no-op */ }

    private val captureLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode != Activity.RESULT_OK || result.data == null) {
                Toast.makeText(this, "需要屏幕录制权限才能持续看屏", Toast.LENGTH_SHORT).show()
                return@registerForActivityResult
            }
            saveForm()
            RoastService.start(this, result.resultCode, result.data!!)
            Toast.makeText(this, "小窗已启动，去刷手机吧", Toast.LENGTH_SHORT).show()
            moveTaskToBack(true)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        prefs = Prefs(this)

        binding.inputBaseUrl.setText(prefs.baseUrl)
        binding.inputApiKey.setText(prefs.apiKey)
        binding.inputModel.setText(prefs.model)
        binding.inputInterval.setText(prefs.intervalSec.toString())
        binding.switchMock.isChecked = prefs.mockApi

        binding.btnOverlay.setOnClickListener { openOverlaySettings() }
        binding.btnStart.setOnClickListener { startRoastFlow() }
        binding.btnStop.setOnClickListener {
            RoastService.stop(this)
            Toast.makeText(this, "已停止", Toast.LENGTH_SHORT).show()
        }

        maybeAskNotificationPermission()
        refreshPermissionLabels()
    }

    override fun onResume() {
        super.onResume()
        refreshPermissionLabels()
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
            "悬浮窗权限：已开启"
        } else {
            getString(R.string.overlay_hint)
        }
        binding.btnOverlay.isEnabled = !overlayOk
        binding.captureStatus.text = getString(R.string.capture_hint)
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        overlaySettingsLauncher.launch(intent)
    }

    private fun saveForm() {
        prefs.baseUrl = binding.inputBaseUrl.text?.toString().orEmpty()
        prefs.apiKey = binding.inputApiKey.text?.toString().orEmpty()
        prefs.model = binding.inputModel.text?.toString().orEmpty()
        prefs.intervalSec = binding.inputInterval.text?.toString()?.toIntOrNull() ?: 15
        prefs.mockApi = binding.switchMock.isChecked
    }

    private fun startRoastFlow() {
        if (!Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "请先开启悬浮窗权限", Toast.LENGTH_SHORT).show()
            openOverlaySettings()
            return
        }
        saveForm()
        val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        captureLauncher.launch(mpm.createScreenCaptureIntent())
    }
}
