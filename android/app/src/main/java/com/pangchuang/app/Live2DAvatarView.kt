package com.pangchuang.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ImageView

/**
 * Circular Live2D host for the floating companion.
 * Falls back to the PNG avatar while the WebView model boots.
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
    private var pendingSpeak: Pair<String, CompanionMood>? = null

    var onReady: (() -> Unit)? = null

    init {
        setBackgroundResource(R.drawable.bg_fab)
        clipToOutline = true
        outlineProvider = android.view.ViewOutlineProvider.BACKGROUND

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
            setLayerType(LAYER_TYPE_HARDWARE, null)
            isHorizontalScrollBarEnabled = false
            isVerticalScrollBarEnabled = false
            overScrollMode = OVER_SCROLL_NEVER
            visibility = INVISIBLE
        }
        configureWebView(webView)
        addView(webView)

        // Capture taps/drags so WebView never steals overlay gestures.
        touchShield = View(context).apply {
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
            isClickable = true
            setBackgroundColor(Color.TRANSPARENT)
        }
        addView(touchShield)

        loadLive2D()
    }

    fun touchTarget(): View = touchShield

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun configureWebView(wv: WebView) {
        val settings = wv.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.allowFileAccess = true
        settings.mediaPlaybackRequiresUserGesture = false
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        @Suppress("DEPRECATION")
        settings.allowFileAccessFromFileURLs = true
        @Suppress("DEPRECATION")
        settings.allowUniversalAccessFromFileURLs = true
        wv.webChromeClient = WebChromeClient()
        wv.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                // ready event comes from JS bridge
            }
        }
        wv.addJavascriptInterface(Bridge(), "PangchuangBridge")
    }

    private fun loadLive2D() {
        webView.loadUrl("file:///android_asset/live2d/index.html")
    }

    fun speak(text: String, mood: CompanionMood) {
        pendingSpeak = text to mood
        if (!ready) {
            // Animate PNG fallback until Live2D is up.
            fallback.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
            return
        }
        val duration = (700 + text.length * 55).coerceIn(900, 4200)
        val moodName = mood.name
        eval("PangchuangLive2D.speak($duration, '$moodName');")
        pendingSpeak = null
    }

    fun setMood(mood: CompanionMood) {
        if (!ready) {
            fallback.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
            return
        }
        eval("PangchuangLive2D.setMood('${mood.name}');")
    }

    fun tap() {
        if (ready) eval("PangchuangLive2D.tap();")
    }

    fun idle() {
        if (ready) eval("PangchuangLive2D.idle();")
        else fallback.setImageResource(R.drawable.companion_avatar_idle)
    }

    private fun eval(js: String) {
        webView.evaluateJavascript(js, null)
    }

    fun destroy() {
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
                    msg == "ready" -> {
                        ready = true
                        webView.visibility = VISIBLE
                        fallback.animate().alpha(0f).setDuration(280).withEndAction {
                            fallback.visibility = GONE
                        }.start()
                        pendingSpeak?.let { (text, mood) -> speak(text, mood) }
                        onReady?.invoke()
                    }
                    msg.startsWith("error:") -> {
                        // Keep PNG fallback visible.
                        ready = false
                        webView.visibility = INVISIBLE
                        fallback.visibility = VISIBLE
                        fallback.alpha = 1f
                    }
                }
            }
        }
    }

    private fun dp(v: Int): Int =
        (v * resources.displayMetrics.density).toInt()
}
