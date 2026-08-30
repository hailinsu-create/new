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
        "刷这么久啦，眼睛要不要歇一小会儿？",
        "这个页面你好像很喜欢，我陪你一起看。",
        "夜里还醒着呀，我在这里陪着你。",
        "慢慢来就好，我在旁边等你回消息。",
        "购物车亮晶晶的，开心最重要啦。",
        "匹配中吗？深呼吸，我给你加油。",
        "备忘录写得真整齐，明天的你会谢谢现在的你。"
    )

    fun roast(bitmap: Bitmap, scene: String? = null): RoastResult {
        if (prefs.mockApi || prefs.apiKey.isBlank()) {
            val pool = when (scene) {
                "深夜刷短视频" -> listOf(
                    "刷得开心吗？我坐在旁边陪你看到想停为止。",
                    "夜里的光软软的，记得眨眨眼哦。"
                )
                "微信置顶群" -> listOf(
                    "消息在闪啦，不急，想回的时候再回。",
                    "置顶群好热闹，我帮你盯着，你慢慢想。"
                )
                "购物车结算" -> listOf(
                    "购物车在发光呢，选喜欢的就好。",
                    "凑单也好可爱，开心最要紧。"
                )
                "排位赛匹配中" -> listOf(
                    "匹配中呀，我在旁边给你捏个小拳头。",
                    "输赢都没关系，我一直给你加油。"
                )
                "备忘录" -> listOf(
                    "备忘录排得好整齐，明天我们一起完成。",
                    "提醒设好啦，到点我会先替你紧张一下。"
                )
                else -> mockLines
            }
            return RoastResult(pool[Random.nextInt(pool.size)], "mock")
        }
        return try {
            val jpeg = bitmapToJpegBase64(bitmap)
            val systemPrompt = prefs.roastStyle.ifBlank {
                "你是手机悬浮窗里的二次元桌面伴侣「小旁」，温柔、可爱、会陪伴。" +
                    "根据截图里真实内容（App、文字、画面）说一句中文短陪伴语，不超过28字。" +
                    "要具体到眼前画面，像贴在身边轻声说话；俏皮一点但不要损人、不要说教。" +
                    "不要提问、不要表情符号、不要引号包裹、不要自我介绍。"
            }
            val body = JSONObject()
                .put("model", prefs.model)
                .put("temperature", 0.8)
                .put("max_tokens", 96)
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
                                                .put(
                                                    "text",
                                                    "这是用户手机当前屏幕截图。先判断在用什么、在看什么，再以小旁的口吻说一句陪伴。"
                                                )
                                        )
                                        .put(
                                            JSONObject()
                                                .put("type", "image_url")
                                                .put(
                                                    "image_url",
                                                    JSONObject().put(
                                                        "url",
                                                        "data:image/jpeg;base64,$jpeg"
                                                    )
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
                val raw = resp.body?.string().orEmpty()
                if (!resp.isSuccessful) {
                    return RoastResult("接口 ${resp.code}：检查 Key/模型哦", "error")
                }
                val json = JSONObject(raw)
                var text = json
                    .getJSONArray("choices")
                    .getJSONObject(0)
                    .getJSONObject("message")
                    .optString("content")
                    .trim()
                    .replace('\n', ' ')
                    .trim('"', '“', '”', '「', '」')
                if (text.length > 40) text = text.take(39) + "…"
                if (text.isBlank()) RoastResult(mockLines.random(), "mock")
                else RoastResult(text, "api")
            }
        } catch (e: Exception) {
            RoastResult("小旁走神了：${e.javaClass.simpleName}", "error")
        }
    }

    private fun bitmapToJpegBase64(bitmap: Bitmap): String {
        val scaled = scaleDown(bitmap, 768)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 70, out)
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
