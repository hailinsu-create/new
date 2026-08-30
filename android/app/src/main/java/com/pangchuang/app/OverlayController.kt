package com.pangchuang.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.SystemClock
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

class OverlayController(
    private val context: Context,
    private val onForceRoast: (() -> Unit)? = null
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: View? = null
    private var bubblePanel: LinearLayout? = null
    private var bubbleText: TextView? = null
    private var params: WindowManager.LayoutParams? = null
    private var hiddenForCapture = false

    @SuppressLint("ClickableViewAccessibility", "InflateParams")
    fun show(initialText: String = "旁窗已就位，开始盯着你的屏幕。") {
        if (root != null) return
        val view = LayoutInflater.from(context).inflate(R.layout.overlay_bubble, null)
        bubblePanel = view.findViewById(R.id.bubblePanel)
        bubbleText = view.findViewById(R.id.bubbleText)
        val fab = view.findViewById<FrameLayout>(R.id.fab)

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
        fab.setOnTouchListener { _, event ->
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
                            showText("马上吐槽眼前画面…")
                            onForceRoast?.invoke()
                        } else {
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
        root?.let {
            runCatching { windowManager.removeView(it) }
        }
        root = null
        bubblePanel = null
        bubbleText = null
        params = null
    }
}
