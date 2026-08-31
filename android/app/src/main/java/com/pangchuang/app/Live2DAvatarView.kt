package com.pangchuang.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.Log
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.webkit.WebViewAssetLoader

/**
 * Avatar host with two engines:
 * - Live2D WebView (default when preferFrames=false)
 * - PNG frame animator (Plan B: preferred, or after Live2D gives up)
 *
 * Uses http://appassets.androidplatform.net (httpAllowed) because some OEM
 * WebViews fail fake-HTTPS DNS before shouldInterceptRequest runs.
 */
class Live2DAvatarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {
    private val handler = Handler(Looper.getMainLooper())
    private val fallback: ImageView
    private val webView: WebView
    private val touchShield: View
    private val frameAnimator: FrameAvatarAnimator
    private var ready = false
    private var destroyed = false
    private var pendingSpeak: Pair<String, CompanionMood>? = null
    private var loadAttempts = 0
    private var lastError: String? = null
    private var lockedToFrames = Prefs(context).preferFrameAvatar

    var onReady: (() -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    init {
        setBackgroundResource(R.drawable.bg_fab)
        clipChildren = true
        clipToPadding = true

        fallback = ImageView(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            scaleType = ImageView.ScaleType.CENTER_CROP
            setImageResource(R.drawable.companion_avatar_idle)
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }
        addView(fallback)
        frameAnimator = FrameAvatarAnimator(fallback, handler)

        webView = WebView(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            setBackgroundColor(Color.TRANSPARENT)
            alpha = 0f
            visibility = GONE
            isHorizontalScrollBarEnabled = false
            isVerticalScrollBarEnabled = false
            overScrollMode = OVER_SCROLL_NEVER
        }
        configureWebView(webView)
        addView(webView)

        touchShield = View(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            isClickable = true
            setBackgroundColor(Color.TRANSPARENT)
        }
        addView(touchShield)

        if (lockedToFrames) {
            startFrameEngine(reason = "pref")
        } else {
            webView.visibility = VISIBLE
            post { reloadLive2D() }
            handler.postDelayed({
                if (!ready && !destroyed && !lockedToFrames) {
                    Log.w(TAG, "timeout; retry lastError=$lastError")
                    reloadLive2D()
                }
            }, 6000L)
        }
    }

    fun touchTarget(): View = touchShield

    /** Force Plan B without waiting for Live2D failures. */
    fun lockToFrames(reason: String = "manual") {
        if (lockedToFrames && ready) return
        lockedToFrames = true
        startFrameEngine(reason)
    }

    private fun startFrameEngine(reason: String) {
        if (destroyed) return
        Log.i(TAG, "frame engine on ($reason)")
        lockedToFrames = true
        ready = true
        webView.alpha = 0f
        webView.visibility = GONE
        runCatching { webView.loadUrl("about:blank") }
        fallback.visibility = VISIBLE
        fallback.alpha = 1f
        frameAnimator.start()
        pendingSpeak?.let { (text, mood) ->
            pendingSpeak = null
            frameAnimator.speak(text, mood)
        }
        onReady?.invoke()
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun configureWebView(wv: WebView) {
        if (BuildConfig.DEBUG) {
            WebView.setWebContentsDebuggingEnabled(true)
        }

        val assetLoader = WebViewAssetLoader.Builder()
            .setDomain(ASSET_DOMAIN)
            .setHttpAllowed(true)
            .addPathHandler("/assets/", Live2DAssetsPathHandler(context))
            .build()

        val settings = wv.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.allowFileAccess = false
        settings.allowContentAccess = false
        settings.mediaPlaybackRequiresUserGesture = false
        settings.cacheMode = WebSettings.LOAD_NO_CACHE
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true

        wv.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage): Boolean {
                Log.d(
                    TAG,
                    "${consoleMessage.messageLevel()} ${consoleMessage.sourceId()}:${consoleMessage.lineNumber()} ${consoleMessage.message()}"
                )
                return true
            }
        }
        wv.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest
            ) = assetLoader.shouldInterceptRequest(request.url).also { resp ->
                if (resp == null) {
                    Log.w(TAG, "not intercepted: ${request.url}")
                }
            }

            @Deprecated("Deprecated in Java")
            override fun shouldInterceptRequest(view: WebView, url: String) =
                assetLoader.shouldInterceptRequest(Uri.parse(url))

            override fun onPageFinished(view: WebView?, url: String?) {
                Log.i(TAG, "page finished: $url")
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: android.webkit.WebResourceError?
            ) {
                val desc = error?.description?.toString().orEmpty()
                Log.e(TAG, "webview error isMain=${request?.isForMainFrame} url=${request?.url} $desc")
                if (request?.isForMainFrame == true) {
                    lastError = desc
                    onError?.invoke(desc)
                    maybeGiveUpOnLive2D()
                }
            }
        }
        wv.addJavascriptInterface(Bridge(), "PangchuangBridge")
    }

    private fun reloadLive2D() {
        if (destroyed || lockedToFrames) return
        loadAttempts++
        ready = false
        webView.visibility = VISIBLE
        webView.alpha = 0f
        fallback.visibility = VISIBLE
        fallback.alpha = 1f
        val url = "http://$ASSET_DOMAIN/assets/live2d/index.html"
        Log.i(TAG, "load attempt=$loadAttempts url=$url size=${width}x${height}")
        webView.loadUrl(url)
        if (loadAttempts >= MAX_LIVE2D_ATTEMPTS) {
            handler.postDelayed({ maybeGiveUpOnLive2D() }, 3500L)
        }
    }

    private fun maybeGiveUpOnLive2D() {
        if (destroyed || lockedToFrames || ready) return
        if (loadAttempts >= MAX_LIVE2D_ATTEMPTS) {
            onError?.invoke("Live2D 未就绪，已切帧动画")
            startFrameEngine(reason = "live2d-exhausted")
        }
    }

    fun speak(text: String, mood: CompanionMood) {
        pendingSpeak = text to mood
        if (lockedToFrames) {
            frameAnimator.speak(text, mood)
            pendingSpeak = null
            return
        }
        if (!ready) {
            // Show a living face while Live2D boots; re-speak when ready.
            frameAnimator.setMood(mood)
            fallback.setImageResource(R.drawable.companion_avatar_mouth_open)
            return
        }
        val duration = (800 + text.length * 60).coerceIn(1000, 7200)
        eval("window.PangchuangLive2D && PangchuangLive2D.speak($duration, '${mood.name}');")
        pendingSpeak = null
    }

    fun setMood(mood: CompanionMood) {
        if (lockedToFrames || !ready) {
            frameAnimator.setMood(mood)
            return
        }
        eval("window.PangchuangLive2D && PangchuangLive2D.setMood('${mood.name}');")
    }

    fun tap() {
        if (lockedToFrames || !ready) {
            frameAnimator.tap()
            return
        }
        eval("window.PangchuangLive2D && PangchuangLive2D.tap();")
    }

    fun idle() {
        if (lockedToFrames || !ready) {
            frameAnimator.idle()
            return
        }
        eval("window.PangchuangLive2D && PangchuangLive2D.idle();")
    }

    private fun eval(js: String) {
        webView.evaluateJavascript(js, null)
    }

    private fun markReady() {
        if (ready || destroyed || lockedToFrames) return
        ready = true
        lastError = null
        Log.i(TAG, "Live2D ready")
        frameAnimator.idle()
        webView.animate().alpha(1f).setDuration(280).start()
        fallback.animate().alpha(0f).setDuration(280).withEndAction {
            if (!lockedToFrames) fallback.visibility = GONE
        }.start()
        pendingSpeak?.let { (text, mood) -> speak(text, mood) }
        onReady?.invoke()
    }

    fun destroy() {
        destroyed = true
        handler.removeCallbacksAndMessages(null)
        frameAnimator.destroy()
        runCatching {
            webView.removeJavascriptInterface("PangchuangBridge")
            webView.loadUrl("about:blank")
            webView.stopLoading()
            (webView.parent as? android.view.ViewGroup)?.removeView(webView)
            webView.destroy()
        }
    }

    private inner class Bridge {
        @JavascriptInterface
        fun onLive2dEvent(msg: String) {
            handler.post {
                when {
                    msg == "ready" -> markReady()
                    msg == "boot" -> Log.i(TAG, "JS boot")
                    msg.startsWith("log:") -> Log.d(TAG, msg.removePrefix("log:"))
                    msg.startsWith("error:") -> {
                        val err = msg.removePrefix("error:")
                        lastError = err
                        Log.e(TAG, "JS error: $err")
                        ready = false
                        webView.alpha = 0f
                        fallback.visibility = VISIBLE
                        fallback.alpha = 1f
                        onError?.invoke(err)
                        if (loadAttempts < MAX_LIVE2D_ATTEMPTS) {
                            handler.postDelayed({ reloadLive2D() }, 1000L)
                        } else {
                            maybeGiveUpOnLive2D()
                        }
                    }
                    msg == "speak_end" -> Log.d(TAG, "speak_end")
                }
            }
        }
    }

    private fun dp(v: Int): Int =
        (v * resources.displayMetrics.density).toInt()

    companion object {
        private const val TAG = "PangchuangLive2D"
        private const val ASSET_DOMAIN = "appassets.androidplatform.net"
        private const val MAX_LIVE2D_ATTEMPTS = 4
    }
}
