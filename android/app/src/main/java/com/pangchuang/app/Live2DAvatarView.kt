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
            setBackgroundColor(Color.TRANSPARENT)
        }
        addView(touchShield)

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

    fun destroy() {
        destroyed = true
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
                        onError?.invoke(err)
                        if (loadAttempts < 4) {
                            handler.postDelayed({ reloadLive2D() }, 1000L)
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
    }
}
