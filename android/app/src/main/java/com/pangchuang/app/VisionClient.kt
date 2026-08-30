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
        "微信消息堆着也不必慌。先看完眼前这一条，再决定要不要跳进下一阵热闹。",
        "短视频像流水。刷得开心便刷，觉得空了就停；停也是一种本事。",
        "购物车亮着，说明你还在挑。挑本身没错，结不结账，听心里那一下就好。",
        "备忘录写得密，是把明天拆成可走的路。一条一条过，比一口气背起整座山轻松。",
        "匹配界面干等最磨人。胜负都是过客，手别僵着就行。",
        "浏览器页签开得多，心也容易散。先关掉用不上的那几扇窗。",
        "地图在算路，你也在算今天还剩多少气力。近路远路，到了就好。"
    )

    fun roast(bitmap: Bitmap, scene: String? = null): RoastResult {
        if (prefs.mockApi || prefs.apiKey.isBlank()) {
            val pool = when (scene) {
                "深夜刷短视频" -> listOf(
                    "短视频一条接一条，像夜里不停的潮。潮有涨有落，你也可以随时上岸。",
                    "刷到会心一笑就够了。别跟推荐算法较劲，它不知道你几点该睡。",
                    "灯下指尖还在滑。滑着滑着若觉得空，不是你的错，是内容太浅。"
                )
                "微信置顶群" -> listOf(
                    "置顶群在闪，多半有人等回复。回得慢不丢人，回得清楚比回得快更体面。",
                    "红点不是圣旨。你看完屏幕上的字，再决定要不要把自己扔进那阵吵闹里。",
                    "微信里头热闹，微信外头还有你自己。先安顿好呼吸，再点开那一串消息。"
                )
                "购物车结算" -> listOf(
                    "结算页最容易心软。喜欢就买，犹豫就晾着；别让优惠倒逼你的决定。",
                    "凑单像做加减法。加的是物件，减的不该是清醒。",
                    "购物车满了，不代表今天必须清空。留一点空，也是给明天留余地。"
                )
                "排位赛匹配中" -> listOf(
                    "匹配的光一闪一闪。这一局输赢都会过去，手别跟着心跳一起抖就好。",
                    "段位是数字，手感是此刻。打得明白，比打得焦躁强。",
                    "排队的时候最容易胡思乱想。想无可想，就盯着加载，当作一次小小的静坐。"
                )
                "备忘录" -> listOf(
                    "备忘录写得密，是把乱七八糟的事摊成一条条能走的路。很好。",
                    "提醒设了，不等于压力到账。到点做一件，做完勾掉，日子就往前挪。",
                    "列出待办的人，已经赢过只在心里打转的人。剩下的，交给时间表。"
                )
                else -> mockLines
            }
            return RoastResult(pool[Random.nextInt(pool.size)], "mock")
        }
        return try {
            val jpeg = bitmapToJpegBase64(bitmap)
            val systemPrompt = prefs.roastStyle.ifBlank {
                "你是手机悬浮窗里的桌面伴侣「小旁」。气质像武侠里的扫地僧：话不多，看得准，说得稳，带一点温度，绝不端着教训人。" +
                    "你的任务：先从截图识别用户正在用的 App（或网页/系统界面）以及正在做什么，再据此说一两句相关性很强的中文。" +
                    "要求：\n" +
                    "1) 必须点出眼前具体内容（App 名、页面类型、可见文字/状态），禁止空泛安慰；\n" +
                    "2) 像懂行的旁观者随口点破，可短可长（约 20～80 字），长短结合，偶可带一点诗意，但不要文艺腔堆砌；\n" +
                    "3) 不损人、不说教、不连续提问、不给操作教程；\n" +
                    "4) 不要表情符号、不要引号包裹、不要自我介绍、不要分点、不要输出 App 名以外的分析过程。"
            }
            val body = JSONObject()
                .put("model", prefs.model)
                .put("temperature", 0.75)
                .put("max_tokens", 200)
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
                                                    "这是用户手机当前屏幕截图。" +
                                                        "请先在心里确认：这是什么 App/页面？用户正在干什么？" +
                                                        "然后只输出给用户听的一两句点评或陪伴，要让人一听就知道你看见了眼前这件事。"
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
