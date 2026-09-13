package com.pangchuang.app

import android.content.Context
import android.content.SharedPreferences

class Prefs(context: Context) {
    private val sp: SharedPreferences =
        context.getSharedPreferences("pangchuang", Context.MODE_PRIVATE)

    var baseUrl: String
        get() = sp.getString(KEY_BASE, DEFAULT_BASE)!!.trimEnd('/')
        set(value) = sp.edit().putString(KEY_BASE, value.trimEnd('/')).apply()

    var apiKey: String
        get() = sp.getString(KEY_KEY, "")!!
        set(value) = sp.edit().putString(KEY_KEY, value).apply()

    var model: String
        get() = sp.getString(KEY_MODEL, MODEL_STABLE)!!
        set(value) = sp.edit().putString(KEY_MODEL, value).apply()

    var intervalSec: Int
        get() = sp.getInt(KEY_INTERVAL, DEFAULT_INTERVAL_SEC).coerceIn(5, 120)
        set(value) = sp.edit().putInt(KEY_INTERVAL, value.coerceIn(5, 120)).apply()

    /**
     * Settings switch: canned demo lines instead of vision.
     * Demo overlay uses an in-memory session flag and does not persist this.
     * Full companion refuses to start while this is on.
     */
    var mockApi: Boolean
        get() = sp.getBoolean(KEY_MOCK, false)
        set(value) = sp.edit().putBoolean(KEY_MOCK, value).apply()

    /** Average RGB delta (0–255) that counts as a “screen changed” tick. */
    var changeThreshold: Float
        get() = sp.getFloat(KEY_THRESHOLD, DEFAULT_THRESHOLD)
        set(value) = sp.edit().putFloat(KEY_THRESHOLD, value.coerceIn(1f, 80f)).apply()

    /** Unix ms when user accepted privacy policy; 0 = not accepted. */
    var privacyConsentAt: Long
        get() = sp.getLong(KEY_PRIVACY_CONSENT, 0L)
        set(value) = sp.edit().putLong(KEY_PRIVACY_CONSENT, value).apply()

    val hasPrivacyConsent: Boolean
        get() = privacyConsentAt > 0L

    /** One-time Play purchase unlocks real screen companion; demo stays free. */
    var isPremiumUnlocked: Boolean
        get() = sp.getBoolean(KEY_PREMIUM, false)
        set(value) = sp.edit().putBoolean(KEY_PREMIUM, value).apply()

    fun acceptPrivacy() {
        privacyConsentAt = System.currentTimeMillis()
    }

    fun revokePrivacy() {
        sp.edit()
            .putLong(KEY_PRIVACY_CONSENT, 0L)
            .apply()
    }

    /** Last overlay TOP|START position; -1 means never saved. */
    var overlayX: Int
        get() = sp.getInt(KEY_OVERLAY_X, -1)
        set(value) = sp.edit().putInt(KEY_OVERLAY_X, value).apply()

    var overlayY: Int
        get() = sp.getInt(KEY_OVERLAY_Y, -1)
        set(value) = sp.edit().putInt(KEY_OVERLAY_Y, value).apply()

    val hasOverlayPos: Boolean
        get() = overlayX >= 0 && overlayY >= 0

    /** Last companion/vision error shown on home until the next success. */
    var lastCompanionError: String
        get() = sp.getString(KEY_LAST_ERROR, "").orEmpty()
        set(value) = sp.edit().putString(KEY_LAST_ERROR, value).apply()

    var lastCompanionErrorAt: Long
        get() = sp.getLong(KEY_LAST_ERROR_AT, 0L)
        set(value) = sp.edit().putLong(KEY_LAST_ERROR_AT, value).apply()

    fun clearCompanionError() {
        sp.edit().remove(KEY_LAST_ERROR).remove(KEY_LAST_ERROR_AT).apply()
    }

    fun recordCompanionError(message: String) {
        lastCompanionError = message.take(180)
        lastCompanionErrorAt = System.currentTimeMillis()
    }

    /** User already saw the post-consent notification rationale. */
    var notificationPrompted: Boolean
        get() = sp.getBoolean(KEY_NOTIF_PROMPTED, false)
        set(value) = sp.edit().putBoolean(KEY_NOTIF_PROMPTED, value).apply()

    /** Billing purchase is pending (cash / slow Play). */
    var purchasePending: Boolean
        get() = sp.getBoolean(KEY_PURCHASE_PENDING, false)
        set(value) = sp.edit().putBoolean(KEY_PURCHASE_PENDING, value).apply()

    fun useStableModel() {
        model = MODEL_STABLE
    }

    /** One-time migrations toward Play-ready defaults. */
    fun migrateForPlayReadiness() {
        val schema = sp.getInt(KEY_SCHEMA, 0)
        if (schema < 6) {
            if (VisionClient.isHeavyModel(model)) {
                model = MODEL_STABLE
            }
            // Drop unused custom-style leftover; vision always uses the built-in prompt.
            sp.edit().remove(KEY_STYLE).putInt(KEY_SCHEMA, 6).apply()
        }
    }

    companion object {
        const val DEFAULT_BASE = "https://api.siliconflow.cn/v1"
        const val MODEL_STABLE = "Qwen/Qwen3-VL-8B-Instruct"
        const val DEFAULT_THRESHOLD = 8f

        private const val DEFAULT_INTERVAL_SEC = 15
        private const val KEY_BASE = "base_url"
        private const val KEY_KEY = "api_key"
        private const val KEY_MODEL = "model"
        private const val KEY_INTERVAL = "interval"
        private const val KEY_MOCK = "mock"
        private const val KEY_STYLE = "style"
        private const val KEY_THRESHOLD = "threshold"
        private const val KEY_PRIVACY_CONSENT = "privacy_consent_at"
        private const val KEY_PREMIUM = "premium_unlocked"
        private const val KEY_SCHEMA = "prefs_schema"
        private const val KEY_OVERLAY_X = "overlay_x"
        private const val KEY_OVERLAY_Y = "overlay_y"
        private const val KEY_LAST_ERROR = "last_companion_error"
        private const val KEY_LAST_ERROR_AT = "last_companion_error_at"
        private const val KEY_NOTIF_PROMPTED = "notification_prompted"
        private const val KEY_PURCHASE_PENDING = "purchase_pending"
    }
}
