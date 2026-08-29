package com.pangchuang.app

import android.graphics.Bitmap
import android.util.Base64
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit
import kotlin.random.Random

data class RoastResult(val text: String, val source: String)

class VisionClient(private val prefs: Prefs) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val mockLines = listOf(
        "又开始无脑下拉了，手指比大脑勤快。",
        "这个页面你今天已经见第三次了。",
        "深夜还在刷，明天的你会来讨债。",
        "回都懒得回，手指倒是很忙。",
        "购物车又涨了，存款还在装死。",
        "匹配界面看穿了，还不快投降。",
        "备忘录写得很勤，执行力在隔壁。"
    )

    fun roast(bitmap: Bitmap): RoastResult {
        if (prefs.mockApi || prefs.apiKey.isBlank()) {
            return RoastResult(mockLines[Random.nextInt(mockLines.size)], "mock")
        }
        return try {
            val jpeg = bitmapToJpegBase64(bitmap)
            val body = JSONObject()
                .put("model", prefs.model)
                .put("temperature", 0.8)
                .put("max_tokens", 80)
                .put(
                    "messages",
                    JSONArray().put(
                        JSONObject()
                            .put("role", "system")
                            .put(
                                "content",
                                "你是贴在安卓小窗边上看热闹的损友。用一句中文短吐槽（不超过28字），俏皮具体，不伤人，不要建议和提问。"
                            )
                    ).put(
                        JSONObject()
                            .put("role", "user")
                            .put(
                                "content",
                                JSONArray()
                                    .put(JSONObject().put("type", "text").put("text", "看这张手机截图，来一句短吐槽。"))
                                    .put(
                                        JSONObject()
                                            .put("type", "image_url")
                                            .put(
                                                "image_url",
                                                JSONObject().put("url", "data:image/jpeg;base64,$jpeg")
                                            )
                                    )
                            )
                    )
                )

            val request = Request.Builder()
                .url("${prefs.baseUrl}/chat/completions")
                .addHeader("Authorization", "Bearer ${prefs.apiKey}")
                .addHeader("Content-Type", "application/json")
                .post(body.toString().toRequestBody("application/json".toMediaType()))
                .build()

            client.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) {
                    return RoastResult("视觉接口 ${resp.code}，先开演示段子也行", "error")
                }
                val json = JSONObject(resp.body?.string().orEmpty())
                var text = json
                    .getJSONArray("choices")
                    .getJSONObject(0)
                    .getJSONObject("message")
                    .optString("content")
                    .trim()
                    .replace('\n', ' ')
                if (text.length > 40) text = text.take(39) + "…"
                if (text.isBlank()) RoastResult(mockLines.random(), "mock")
                else RoastResult(text, "api")
            }
        } catch (e: Exception) {
            RoastResult("吐槽开小差：${e.javaClass.simpleName}", "error")
        }
    }

    private fun bitmapToJpegBase64(bitmap: Bitmap): String {
        val scaled = scaleDown(bitmap, 768)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 72, out)
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
}
