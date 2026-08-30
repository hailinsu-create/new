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

class VisionClient(private val prefs: Prefs) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .callTimeout(150, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
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

    fun roast(
        bitmap: Bitmap,
        scene: String? = null,
        appHint: AppHint? = null
    ): RoastResult {
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

        val heavy = isHeavyModel(prefs.model)
        val jpeg = bitmapToJpegBase64(
            bitmap,
            maxSide = if (heavy) 640 else 768,
            quality = if (heavy) 55 else 70
        )
        val systemPrompt = prefs.roastStyle.ifBlank { DEFAULT_SYSTEM_PROMPT }
        val hintLine = if (appHint != null) {
            "系统侧提示：前台应用很可能是「${appHint.label}」（${appHint.packageName}）。" +
                "仅作参考，仍以截图为准；若画面明显是别的 App，以画面为准。"
        } else {
            "系统未能提供前台包名，请完全依据截图判断 App 与正在做的事。"
        }
        val userText =
            "这是用户手机当前屏幕截图。$hintLine" +
                "请先在心里默念：这是什么 App/页面？用户正在干什么？" +
                "然后只输出给用户听的一两句，要让人一听就知道你看见了眼前这件事。"

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
                        RoastResult(mockLines.random(), "mock")
                    } else {
                        RoastResult(text, "api")
                    }
                }
            } catch (e: SocketTimeoutException) {
                lastError = RoastResult("模型响应超时，稍后再点头像试试", "error")
                Log.w(TAG, "timeout attempt ${attempt + 1}", e)
                if (attempt < MAX_ATTEMPTS - 1) {
                    Thread.sleep(500L * (attempt + 1))
                }
            } catch (e: IOException) {
                lastError = RoastResult("网络不稳：${e.javaClass.simpleName}", "error")
                Log.w(TAG, "io attempt ${attempt + 1}", e)
                if (attempt < MAX_ATTEMPTS - 1) {
                    Thread.sleep(500L * (attempt + 1))
                }
            } catch (e: Exception) {
                return RoastResult("小旁走神了：${e.javaClass.simpleName}", "error")
            }
        }
        return lastError ?: RoastResult("接口忙，稍后再试", "error")
    }

    private fun friendlyHttpError(code: Int, raw: String): String {
        val serverMsg = runCatching {
            JSONObject(raw).optString("message")
                .ifBlank { JSONObject(raw).optJSONObject("error")?.optString("message").orEmpty() }
        }.getOrDefault("").trim()
        return when (code) {
            429 -> "接口限流了，过几秒再看"
            500, 502, 503, 504, 529 ->
                if (serverMsg.contains("overload", ignoreCase = true) ||
                    serverMsg.contains("busy", ignoreCase = true) ||
                    serverMsg.contains("负载")
                ) {
                    "模型正忙（$code），稍后再试"
                } else {
                    "服务端 $code，多半是模型繁忙或瞬时故障"
                }
            401, 403 -> "Key 无效或无权用该模型"
            404 -> "模型名不对，检查 Vision Model"
            else -> {
                val short = serverMsg.take(40)
                if (short.isNotBlank()) "接口 $code：$short" else "接口 $code：检查 Key/模型"
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

        /** 扫地僧气质：先认 App 与动作，再点到为止说两句。 */
        const val DEFAULT_SYSTEM_PROMPT =
            "你是手机悬浮窗里的桌面伴侣「小旁」。说话气质像金庸笔下的扫地僧：" +
                "话少、语气稳、看得准，偶有一点浅浅的悟性，绝不端着教训人，也不卖萌过头。" +
                "工作方式：先从截图认出用户正在用的 App（或网页/系统界面）以及正在做什么，" +
                "再据此说一两句相关性很强的中文，像随口点破眼前这一幕。" +
                "硬性要求：\n" +
                "1) 必须扣住眼前具体内容——App/页面类型、可见标题、红点、列表、结算、聊天、视频、地图等任一可见线索；禁止空泛安慰或万能鸡汤；\n" +
                "2) 一句或两句即可，约 18～80 字；可短可稍长，长短随场景，偶可带一点诗意，但不要堆砌辞藻；\n" +
                "3) 不损人、不说教、不连续提问、不给操作步骤、不推销、不自我介绍；\n" +
                "4) 不要表情符号、不要引号包裹整段、不要分点、不要输出「我看到了…」式分析过程；直接说给人听的那两句。"
    }
}
