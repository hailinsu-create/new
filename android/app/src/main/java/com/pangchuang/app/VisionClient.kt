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
        "夜里还醒着呀。窗外大概也醒着，我在这里陪着你。",
        "慢慢来就好，回不回消息都没关系，我在旁边等。",
        "购物车亮晶晶的，开心比凑单更重要啦。",
        "匹配中吗？深呼吸，我给你加油。",
        "备忘录写得真整齐。明天的风会记得你今晚列下的每一行。",
        "哇，消息又在闪。不急，想好再回也不迟。",
        "你这样认真的样子也好可爱。",
        "夜色像墨，屏幕像灯。你往下刷，我就坐在灯边陪着。",
        "今日事今日毕也好，留到明天也行。我只负责在你身边轻轻说一句：别太苛待自己。"
    )

    fun roast(bitmap: Bitmap, scene: String? = null): RoastResult {
        if (prefs.mockApi || prefs.apiKey.isBlank()) {
            val pool = when (scene) {
                "深夜刷短视频" -> listOf(
                    "刷得开心吗？我坐在旁边陪你看到想停为止。",
                    "夜里的光软软的。短视频流水一样往下淌，记得偶尔眨眨眼哦。",
                    "灯下人未睡，指尖还在滑。我不催你停，只轻轻守着。"
                )
                "微信置顶群" -> listOf(
                    "消息在闪啦，不急，想回的时候再回。",
                    "置顶群好热闹。你慢慢想，我帮你盯着那一串小红点。",
                    "有人在喊你的名字。你可以先深呼吸，再决定要不要走进那阵热闹里。"
                )
                "购物车结算" -> listOf(
                    "购物车在发光呢，选喜欢的就好。",
                    "凑单也好可爱。喜欢就留下，犹豫就放一放，开心最要紧。",
                    "好物满车如星子。买或不买都温柔，别让犹豫抢走今晚的好心情。"
                )
                "排位赛匹配中" -> listOf(
                    "匹配中呀，我在旁边给你捏个小拳头。",
                    "输赢都没关系，我一直给你加油。",
                    "匹配的光一闪一闪。无论这一局潮起潮落，我都在岸边给你加油。"
                )
                "备忘录" -> listOf(
                    "备忘录排得好整齐，明天我们一起完成。",
                    "提醒设好啦，到点我会先替你紧张一下。",
                    "一行一行写下来的，都是明天的自己会遇见的小小约定。我替你记着。"
                )
                else -> mockLines
            }
            return RoastResult(pool[Random.nextInt(pool.size)], "mock")
        }
        return try {
            val jpeg = bitmapToJpegBase64(bitmap)
            val systemPrompt = prefs.roastStyle.ifBlank {
                "你是手机悬浮窗里的二次元桌面伴侣「小旁」，温柔、可爱、会陪伴。" +
                    "根据截图里真实内容（App、文字、画面）说一句中文陪伴语。" +
                    "长短结合：多数时候 18～48 字；偶尔可以稍长到 72 字左右，可带一点诗意或轻柔意象，但不要堆砌辞藻。" +
                    "要具体到眼前画面，像贴在身边说话；俏皮一点但不要损人、不要说教、不要连续提问。" +
                    "不要表情符号、不要引号包裹、不要自我介绍、不要分点列表。"
            }
            val body = JSONObject()
                .put("model", prefs.model)
                .put("temperature", 0.85)
                .put("max_tokens", 180)
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
                                                    "这是用户手机当前屏幕截图。先判断在用什么、在看什么，再以小旁的口吻说一句陪伴。" +
                                                        "可短可长，偶尔也可像一句小诗，但必须贴合眼前画面。"
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
                    .replace(Regex("\\s+"), " ")
                    .trim('"', '“', '”', '「', '」')
                if (text.length > 96) text = text.take(95) + "…"
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
