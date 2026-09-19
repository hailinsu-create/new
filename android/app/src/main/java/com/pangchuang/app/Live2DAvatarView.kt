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
import android.view.ViewOutlineProvider
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
 * Live2D host. Uses http://appassets.androidplatform.net (httpAllowed) because some OEM
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
    private var ready = false
    private var destroyed = false
    private var pendingSpeak: Pair<String, CompanionMood>? = null
    private var loadAttempts = 0
    private var lastError: String? = null

    var onReady: (() -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    init {
        setBackgroundResource(R.drawable.bg_fab)
        clipChildren = true
        clipToPadding = true
        outlineProvider = ViewOutlineProvider.BACKGROUND
        clipToOutline = true

        fallback = ImageView(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            scaleType = ImageView.ScaleType.CENTER_CROP
            setImageResource(R.drawable.companion_avatar_idle)
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }
        addView(fallback)

        webView = WebView(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            setBackgroundColor(Color.TRANSPARENT)
            alpha = 0f
            visibility = VISIBLE
            isHorizontalScrollBarEnabled = false
            isVerticalScrollBarEnabled = false
            overScrollMode = OVER_SCROLL_NEVER
        }
        configureWebView(webView)
        addView(webView)

        touchShield = View(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            isClickable = true
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
            contentDescription = context.getString(R.string.cd_preview)
            setBackgroundColor(Color.TRANSPARENT)
        }
        addView(touchShield)

        liveEngineCount += 1
        post { reloadLive2D() }
        handler.postDelayed({
            if (!ready && !destroyed) {
                Log.w(TAG, "timeout; retry lastError=$lastError")
                reloadLive2D()
            }
        }, 6000L)
    }

    fun touchTarget(): View = touchShield

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun configureWebView(wv: WebView) {
        if (BuildConfig.DEBUG) {
            WebView.setWebContentsDebuggingEnabled(true)
        }

        // httpAllowed: many China OEM WebViews resolve HTTPS DNS for appassets.* and fail
        // before interception. HTTP virtual host is intercepted reliably.
        val assetLoader = WebViewAssetLoader.Builder()
            .setDomain(ASSET_DOMAIN)
            .setHttpAllowed(true)
            .addPathHandler("/assets/", Live2DAssetsPathHandler(context))
            .build()

        val settings = wv.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = false
        settings.allowFileAccess = false
        settings.allowContentAccess = false
        settings.mediaPlaybackRequiresUserGesture = true
        settings.cacheMode = WebSettings.LOAD_NO_CACHE
        // Assets are intercepted; never load mixed third-party HTTP.
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true
        settings.setSupportZoom(false)
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        settings.javaScriptCanOpenWindowsAutomatically = false
        settings.setSupportMultipleWindows(false)
        settings.setGeolocationEnabled(false)
        @Suppress("DEPRECATION")
        settings.allowFileAccessFromFileURLs = false
        @Suppress("DEPRECATION")
        settings.allowUniversalAccessFromFileURLs = false

        wv.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage): Boolean {
                if (BuildConfig.DEBUG) {
                    Log.d(
                        TAG,
                        "${consoleMessage.messageLevel()} ${consoleMessage.sourceId()}:${consoleMessage.lineNumber()} ${consoleMessage.message()}"
                    )
                }
                return true
            }
        }
        try {
            wv.setLayerType(LAYER_TYPE_HARDWARE, null)
        } catch (_: Throwable) {
            wv.setLayerType(LAYER_TYPE_SOFTWARE, null)
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
                    onError?.invoke(humanizeError(desc))
                }
            }
        }
        wv.addJavascriptInterface(Bridge(), "PangchuangBridge")
    }

    private fun reloadLive2D() {
        if (destroyed) return
        loadAttempts++
        ready = false
        webView.alpha = 0f
        fallback.visibility = VISIBLE
        fallback.alpha = 1f
        // Prefer HTTP virtual host for OEM WebView compatibility.
        val url = "http://$ASSET_DOMAIN/assets/live2d/index.html"
        Log.i(TAG, "load attempt=$loadAttempts url=$url size=${width}x${height}")
        webView.loadUrl(url)
    }

    fun speak(text: String, mood: CompanionMood) {
        pendingSpeak = text to mood
        if (!ready) {
            fallback.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
            return
        }
        val duration = (800 + text.length * 60).coerceIn(1000, 7200)
        eval("window.PangchuangLive2D && PangchuangLive2D.speak($duration, '${mood.name}');")
        pendingSpeak = null
    }

    fun setMood(mood: CompanionMood) {
        if (!ready) {
            fallback.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
            return
        }
        eval("window.PangchuangLive2D && PangchuangLive2D.setMood('${mood.name}');")
    }

    fun tap() {
        if (ready) eval("window.PangchuangLive2D && PangchuangLive2D.tap();")
    }

    fun idle() {
        if (ready) eval("window.PangchuangLive2D && PangchuangLive2D.idle();")
        else fallback.setImageResource(R.drawable.companion_avatar_idle)
    }

    private fun eval(js: String) {
        webView.evaluateJavascript(js, null)
    }

    private fun markReady() {
        if (ready || destroyed) return
        ready = true
        lastError = null
        Log.i(TAG, "Live2D ready")
        webView.animate().alpha(1f).setDuration(280).start()
        fallback.animate().alpha(0f).setDuration(280).withEndAction {
            fallback.visibility = GONE
        }.start()
        pendingSpeak?.let { (text, mood) -> speak(text, mood) }
        onReady?.invoke()
    }

    /**
     * Pause WebGL without [WebView.pauseTimers] (that is process-wide).
     * Used on SCREEN_OFF and when the home preview yields to the overlay.
     */
    fun pauseRendering() {
        if (destroyed) return
        runCatching { webView.onPause() }
        eval("window.PangchuangLive2D && PangchuangLive2D.setPaused(true);")
    }

    fun resumeRendering() {
        if (destroyed) return
        runCatching { webView.onResume() }
        eval("window.PangchuangLive2D && PangchuangLive2D.setPaused(false);")
    }

    /** Drop Cubism so only one Live2D WebView stays alive in this process. */
    fun unloadEngine() {
        if (destroyed) return
        ready = false
        runCatching { webView.onPause() }
        webView.loadUrl("about:blank")
        webView.alpha = 0f
        fallback.visibility = VISIBLE
        fallback.alpha = 1f
        if (liveEngineCount > 0) liveEngineCount -= 1
    }

    fun reloadEngine() {
        if (destroyed) return
        liveEngineCount += 1
        runCatching { webView.onResume() }
        reloadLive2D()
    }

    fun humanizeError(raw: String): String {
        val r = raw.lowercase()
        return when {
            "webgl" in r || "gl_" in r || "context lost" in r ->
                context.getString(R.string.overlay_live2d_fail)
            "cubism" in r || "live2d" in r || "moc3" in r ->
                context.getString(R.string.overlay_live2d_fail)
            "net::" in r || "err_" in r || "failed to load" in r ->
                context.getString(R.string.overlay_live2d_fail)
            raw.length > 80 || raw.contains('\n') || raw.contains("at ") ->
                context.getString(R.string.overlay_live2d_fail)
            else -> context.getString(R.string.overlay_live2d_fail)
        }
    }

    fun destroy() {
        destroyed = true
        if (liveEngineCount > 0) liveEngineCount -= 1
        handler.removeCallbacksAndMessages(null)
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
                        if (loadAttempts < 4) {
                            handler.postDelayed({ reloadLive2D() }, 1000L)
                        } else {
                            runCatching { webView.setLayerType(LAYER_TYPE_SOFTWARE, null) }
                            onError?.invoke(humanizeError(err))
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

        @Volatile
        var liveEngineCount: Int = 0
            private set
    }
}
