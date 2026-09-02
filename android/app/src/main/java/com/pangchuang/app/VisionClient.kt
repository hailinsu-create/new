package com.pangchuang.app

import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.SocketTimeoutException
import java.util.concurrent.TimeUnit
import kotlin.random.Random

data class RoastResult(val text: String, val source: String)

class VisionClient(
    private val context: android.content.Context,
    private val prefs: Prefs
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .callTimeout(150, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    fun roast(
        bitmap: Bitmap,
        scene: String? = null,
        appHint: AppHint? = null
    ): RoastResult {
        if (prefs.mockApi || prefs.apiKey.isBlank()) {
            return RoastResult(mockLine(scene), "mock")
        }

        val heavy = isHeavyModel(prefs.model)
        val jpeg = bitmapToJpegBase64(
            bitmap,
            maxSide = if (heavy) 640 else 768,
            quality = if (heavy) 55 else 70
        )
        val systemPrompt = prefs.roastStyle.ifBlank {
            context.getString(
                R.string.vision_system_prompt,
                context.getString(R.string.vision_reply_language)
            )
        }
        val hintLine = if (appHint != null) {
            context.getString(R.string.vision_hint_with_app, appHint.label, appHint.packageName)
        } else {
            context.getString(R.string.vision_hint_no_app)
        }
        val userText = context.getString(R.string.vision_user_text, hintLine)

        val bodyJson = JSONObject()
            .put("model", prefs.model)
            .put("temperature", 0.65)
            .put("max_tokens", if (heavy) 96 else 160)
            .put(
                "messages",
                JSONArray()
                    .put(
                        JSONObject()
                            .put("role", "system")
                            .put("content", systemPrompt)
                    )
                    .put(
                        JSONObject()
                            .put("role", "user")
                            .put(
                                "content",
                                JSONArray()
                                    .put(
                                        JSONObject()
                                            .put("type", "text")
                                            .put("text", userText)
                                    )
                                    .put(
                                        JSONObject()
                                            .put("type", "image_url")
                                            .put(
                                                "image_url",
                                                JSONObject()
                                                    .put(
                                                        "url",
                                                        "data:image/jpeg;base64,$jpeg"
                                                    )
                                                    // Lower vision tokens when supported (OpenAI-compatible).
                                                    .put("detail", if (heavy) "low" else "auto")
                                            )
                                    )
                            )
                    )
            )
            .toString()

        var lastError: RoastResult? = null
        repeat(MAX_ATTEMPTS) { attempt ->
            try {
                val request = Request.Builder()
                    .url("${prefs.baseUrl}/chat/completions")
                    .addHeader("Authorization", "Bearer ${prefs.apiKey}")
                    .addHeader("Content-Type", "application/json")
                    .post(bodyJson.toRequestBody("application/json".toMediaType()))
                    .build()

                client.newCall(request).execute().use { resp ->
                    val raw = resp.body?.string().orEmpty()
                    if (!resp.isSuccessful) {
                        val retryable = resp.code in RETRYABLE_CODES
                        val friendly = friendlyHttpError(resp.code, raw)
                        lastError = RoastResult(friendly, "error")
                        if (retryable && attempt < MAX_ATTEMPTS - 1) {
                            Log.w(TAG, "API ${resp.code}, retry ${attempt + 1}: ${raw.take(200)}")
                            Thread.sleep(700L * (attempt + 1))
                            return@repeat
                        }
                        return lastError!!
                    }
                    val json = JSONObject(raw)
                    var text = json
                        .getJSONArray("choices")
                        .getJSONObject(0)
                        .getJSONObject("message")
                        .optString("content")
                        .trim()
                        .replace('\n', ' ')
                        .replace(Regex("\\s+"), " ")
                        .trim('"', '“', '”', '「', '」')
                    // Strip common thinking/analysis preambles some larger models leak.
                    text = text
                        .replace(Regex("(?i)^(分析|思考|观察)[:：].{0,40}?。"), "")
                        .trim()
                    if (text.length > 96) text = text.take(95) + "…"
                    return if (text.isBlank()) {
                        RoastResult(mockLine(null), "mock")
                    } else {
                        RoastResult(text, "api")
                    }
                }
            } catch (e: SocketTimeoutException) {
                lastError = RoastResult(context.getString(R.string.vision_timeout), "error")
                Log.w(TAG, "timeout attempt ${attempt + 1}", e)
                if (attempt < MAX_ATTEMPTS - 1) {
                    Thread.sleep(500L * (attempt + 1))
                }
            } catch (e: IOException) {
                lastError = RoastResult(
                    context.getString(R.string.vision_network, e.javaClass.simpleName),
                    "error"
                )
                Log.w(TAG, "io attempt ${attempt + 1}", e)
                if (attempt < MAX_ATTEMPTS - 1) {
                    Thread.sleep(500L * (attempt + 1))
                }
            } catch (e: Exception) {
                return RoastResult(
                    context.getString(R.string.vision_distracted, e.javaClass.simpleName),
                    "error"
                )
            }
        }
        return lastError ?: RoastResult(context.getString(R.string.vision_busy), "error")
    }

    private fun mockLine(scene: String?): String {
        val poolId = when (scene) {
            SCENE_SHORTS -> R.array.mock_shorts
            SCENE_CHAT -> R.array.mock_chat
            SCENE_CART -> R.array.mock_cart
            SCENE_RANKED -> R.array.mock_ranked
            SCENE_NOTES -> R.array.mock_notes
            else -> R.array.mock_generic
        }
        val pool = context.resources.getStringArray(poolId)
        return pool[Random.nextInt(pool.size)]
    }

    private fun friendlyHttpError(code: Int, raw: String): String {
        val serverMsg = runCatching {
            JSONObject(raw).optString("message")
                .ifBlank { JSONObject(raw).optJSONObject("error")?.optString("message").orEmpty() }
        }.getOrDefault("").trim()
        return when (code) {
            429 -> context.getString(R.string.vision_rate_limited)
            500, 502, 503, 504, 529 ->
                if (serverMsg.contains("overload", ignoreCase = true) ||
                    serverMsg.contains("busy", ignoreCase = true) ||
                    serverMsg.contains("负载")
                ) {
                    context.getString(R.string.vision_model_busy, code)
                } else {
                    context.getString(R.string.vision_server, code)
                }
            401, 403 -> context.getString(R.string.vision_bad_key)
            404 -> context.getString(R.string.vision_bad_model)
            else -> {
                val short = serverMsg.take(40)
                if (short.isNotBlank()) {
                    context.getString(R.string.vision_http, code, short)
                } else {
                    context.getString(R.string.vision_http_generic, code)
                }
            }
        }
    }

    private fun bitmapToJpegBase64(bitmap: Bitmap, maxSide: Int, quality: Int): String {
        val scaled = scaleDown(bitmap, maxSide)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(40, 90), out)
        if (scaled !== bitmap) scaled.recycle()
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    private fun scaleDown(src: Bitmap, maxSide: Int): Bitmap {
        val w = src.width
        val h = src.height
        val longest = maxOf(w, h)
        if (longest <= maxSide) return src
        val scale = maxSide.toFloat() / longest
        return Bitmap.createScaledBitmap(src, (w * scale).toInt(), (h * scale).toInt(), true)
    }

    companion object {
        private const val TAG = "PangchuangVision"
        private const val MAX_ATTEMPTS = 3
        private val RETRYABLE_CODES = setOf(408, 429, 500, 502, 503, 504, 529)

        fun isHeavyModel(model: String): Boolean {
            val m = model.lowercase()
            return listOf("32b", "30b", "72b", "235b", "a22b").any { m.contains(it) }
        }

        const val SCENE_SHORTS = "shorts"
        const val SCENE_CHAT = "chat"
        const val SCENE_CART = "cart"
        const val SCENE_RANKED = "ranked"
        const val SCENE_NOTES = "notes"
    }
}
