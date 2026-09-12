package com.pangchuang.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class OverlayController(
    private val context: Context,
    private val onForceRoast: (() -> Unit)? = null,
    private val onClose: (() -> Unit)? = null
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private var root: View? = null
    private var bubblePanel: LinearLayout? = null
    private var bubbleText: TextView? = null
    private var avatar: Live2DAvatarView? = null
    private var params: WindowManager.LayoutParams? = null

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
    fun show(initialText: String? = null) {
        if (root != null) {
            showText(initialText ?: context.getString(R.string.overlay_hello))
            return
        }
        val view = LayoutInflater.from(context).inflate(R.layout.overlay_bubble, null)
        bubblePanel = view.findViewById(R.id.bubblePanel)
        bubbleText = view.findViewById(R.id.bubbleText)
        avatar = view.findViewById(R.id.fab)
        val close = view.findViewById<ImageButton>(R.id.overlayClose)
        val live2d = avatar!!
        live2d.contentDescription = context.getString(R.string.overlay_avatar_cd)
        live2d.touchTarget().contentDescription = context.getString(R.string.overlay_avatar_cd)
        live2d.touchTarget().importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        close.contentDescription = context.getString(R.string.overlay_close_cd)
        close.setOnClickListener { onClose?.invoke() }
        live2d.onError = { err ->
            val short = err.take(48)
            showText("Live2D：$short")
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

        // No FLAG_LAYOUT_NO_LIMITS: that flag lets the window fly off-screen.
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
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
                    applyClamp(view, lp, snap = false)
                    windowManager.updateViewLayout(view, lp)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val moved = abs(event.rawX - downX) >= 8 || abs(event.rawY - downY) >= 8
                    val held = SystemClock.uptimeMillis() - downAt >= 450
                    applyClamp(view, lp, snap = moved)
                    windowManager.updateViewLayout(view, lp)
                    if (!moved && event.action == MotionEvent.ACTION_UP) {
                        if (held) {
                            showText(context.getString(R.string.overlay_looking))
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
        view.post { applyClamp(view, lp, snap = true); windowManager.updateViewLayout(view, lp) }
        handler.post(bobLoop)
        showText(initialText ?: context.getString(R.string.overlay_hello))
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

    fun showThinking(text: String? = null) {
        showText(text ?: context.getString(R.string.overlay_thinking))
    }

    /**
     * Overlay is a face crop, not the screen content being roasted.
     * Do not blink the whole window out for capture.
     */
    fun hideForCapture() {
        // Intentionally empty.
    }

    fun restoreAfterCapture() {
        // Intentionally empty.
    }

    private fun toggleBubble() {
        val panel = bubblePanel ?: return
        panel.visibility = if (panel.visibility == View.VISIBLE) View.GONE else View.VISIBLE
    }

    private fun applyClamp(view: View, lp: WindowManager.LayoutParams, snap: Boolean) {
        val (sw, sh) = screenSize()
        val vw = view.width.coerceAtLeast(dp(96))
        val vh = view.height.coerceAtLeast(dp(96))
        val pad = dp(8)
        val (nx, ny) = if (snap) {
            OverlayGeometry.snapAndClamp(lp.x, lp.y, vw, vh, sw, sh, pad)
        } else {
            OverlayGeometry.clamp(lp.x, lp.y, vw, vh, sw, sh, pad)
        }
        lp.x = nx
        lp.y = ny
    }

    private fun screenSize(): Pair<Int, Int> {
        if (Build.VERSION.SDK_INT >= 30) {
            val bounds = windowManager.currentWindowMetrics.bounds
            val insets = windowManager.currentWindowMetrics.windowInsets
                .getInsetsIgnoringVisibility(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars()
                )
            val w = bounds.width()
            val h = bounds.height() - insets.bottom
            return w to h.coerceAtLeast(1)
        }
        val d = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(d)
        return d.widthPixels to d.heightPixels
    }

    private fun dp(v: Int): Int =
        (v * context.resources.displayMetrics.density).toInt()

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
