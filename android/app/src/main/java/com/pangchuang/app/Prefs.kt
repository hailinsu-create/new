package com.pangchuang.app

import android.content.Context
import android.content.SharedPreferences

class Prefs(context: Context) {
    private val sp: SharedPreferences =
        context.getSharedPreferences("pangchuang", Context.MODE_PRIVATE)

    var baseUrl: String
        get() = sp.getString(KEY_BASE, "https://api.siliconflow.cn/v1")!!.trimEnd('/')
        set(value) = sp.edit().putString(KEY_BASE, value.trimEnd('/')).apply()

    var apiKey: String
        get() = sp.getString(KEY_KEY, "")!!
        set(value) = sp.edit().putString(KEY_KEY, value).apply()

    var model: String
        get() = sp.getString(KEY_MODEL, "Qwen/Qwen2.5-VL-7B-Instruct")!!
        set(value) = sp.edit().putString(KEY_MODEL, value).apply()

    var intervalSec: Int
        get() = sp.getInt(KEY_INTERVAL, 15).coerceIn(5, 120)
        set(value) = sp.edit().putInt(KEY_INTERVAL, value.coerceIn(5, 120)).apply()

    var mockApi: Boolean
        get() = sp.getBoolean(KEY_MOCK, true)
        set(value) = sp.edit().putBoolean(KEY_MOCK, value).apply()

    companion object {
        private const val KEY_BASE = "base_url"
        private const val KEY_KEY = "api_key"
        private const val KEY_MODEL = "model"
        private const val KEY_INTERVAL = "interval"
        private const val KEY_MOCK = "mock"
    }
}
