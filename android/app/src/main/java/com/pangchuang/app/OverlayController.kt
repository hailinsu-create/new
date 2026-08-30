package com.pangchuang.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class OverlayController(
    private val context: Context,
    private val onForceRoast: (() -> Unit)? = null
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private var root: View? = null
    private var bubblePanel: LinearLayout? = null
    private var bubbleText: TextView? = null
    private var avatar: Live2DAvatarView? = null
    private var params: WindowManager.LayoutParams? = null
    private var hiddenForCapture = false

    private val bobLoop = object : Runnable {
        override fun run() {
            val ball = avatar ?: return
            if (root == null) return
            ball.animate()
                .translationY(-5f)
                .setDuration(900)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .withEndAction {
                    ball.animate()
                        .translationY(0f)
                        .setDuration(900)
                        .setInterpolator(AccelerateDecelerateInterpolator())
                        .withEndAction {
                            if (root != null) handler.postDelayed(this, 70L)
                        }
                        .start()
                }
                .start()
        }
    }

    @SuppressLint("ClickableViewAccessibility", "InflateParams")
    fun show(initialText: String = "小旁来陪你啦，我会悄悄看着屏幕陪你聊聊。") {
        if (root != null) return
        val view = LayoutInflater.from(context).inflate(R.layout.overlay_bubble, null)
        bubblePanel = view.findViewById(R.id.bubblePanel)
        bubbleText = view.findViewById(R.id.bubbleText)
        avatar = view.findViewById(R.id.fab)
        val live2d = avatar!!
        live2d.onError = { err ->
            showText("Live2D 加载中…($err)")
        }
        live2d.onReady = {
            // Keep current bubble; model is now live.
        }
        val touchTarget = live2d.touchTarget()

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = 24
        lp.y = 180

        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var downAt = 0L
        touchTarget.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = lp.x
                    startY = lp.y
                    downAt = SystemClock.uptimeMillis()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    lp.x = startX + (event.rawX - downX).toInt()
                    lp.y = startY + (event.rawY - downY).toInt()
                    windowManager.updateViewLayout(view, lp)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val moved = abs(event.rawX - downX) >= 8 || abs(event.rawY - downY) >= 8
                    val held = SystemClock.uptimeMillis() - downAt >= 450
                    if (!moved) {
                        if (held) {
                            showText("嗯，我看看你现在在干嘛…")
                            onForceRoast?.invoke()
                        } else {
                            live2d.tap()
                            toggleBubble()
                        }
                    }
                    true
                }
                else -> false
            }
        }

        windowManager.addView(view, lp)
        root = view
        params = lp
        handler.post(bobLoop)
        showText(initialText)
    }

    fun showText(text: String) {
        val panel = bubblePanel ?: return
        val label = bubbleText ?: return
        label.text = text
        panel.visibility = View.VISIBLE
        panel.alpha = 0f
        panel.translationY = 12f
        panel.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(280)
            .setInterpolator(DecelerateInterpolator())
            .start()
        val mood = CompanionMoodMatcher.fromText(text)
        avatar?.speak(text, mood)
    }

    fun showThinking(text: String = "让我看看你在干嘛…") {
        showText(text)
    }

    fun hideForCapture() {
        root?.visibility = View.INVISIBLE
        hiddenForCapture = true
    }

    fun restoreAfterCapture() {
        if (hiddenForCapture) {
            root?.visibility = View.VISIBLE
            hiddenForCapture = false
        }
    }

    private fun toggleBubble() {
        val panel = bubblePanel ?: return
        panel.visibility = if (panel.visibility == View.VISIBLE) View.GONE else View.VISIBLE
    }

    fun dismiss() {
        handler.removeCallbacksAndMessages(null)
        avatar?.animate()?.cancel()
        avatar?.destroy()
        root?.let {
            runCatching { windowManager.removeView(it) }
        }
        root = null
        bubblePanel = null
        bubbleText = null
        avatar = null
        params = null
    }
}
