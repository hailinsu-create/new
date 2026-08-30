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
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.max
import kotlin.random.Random

class OverlayController(
    private val context: Context,
    private val onForceRoast: (() -> Unit)? = null
) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val handler = Handler(Looper.getMainLooper())
    private var root: View? = null
    private var bubblePanel: LinearLayout? = null
    private var bubbleText: TextView? = null
    private var avatar: ImageView? = null
    private var fab: FrameLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var hiddenForCapture = false
    private var animating = false
    private var currentMood: CompanionMood = CompanionMood.IDLE
    private var speakToken = 0

    private val mouthClosed: Int
        get() = when (currentMood) {
            CompanionMood.HAPPY -> R.drawable.companion_avatar_happy
            CompanionMood.CARE -> R.drawable.companion_avatar_care
            CompanionMood.THINK -> R.drawable.companion_avatar_think
            CompanionMood.SURPRISE -> R.drawable.companion_avatar_surprise
            CompanionMood.SHY -> R.drawable.companion_avatar_shy
            CompanionMood.TALK -> R.drawable.companion_avatar_talk
            CompanionMood.IDLE -> R.drawable.companion_avatar_idle
        }

    private val speakFrames: IntArray
        get() = intArrayOf(
            mouthClosed,
            R.drawable.companion_avatar_mouth_mid,
            R.drawable.companion_avatar_mouth_open,
            R.drawable.companion_avatar_mouth_mid,
            mouthClosed,
            R.drawable.companion_avatar_talk,
            R.drawable.companion_avatar_mouth_open,
            R.drawable.companion_avatar_mouth_mid
        )

    private val idleBlink = object : Runnable {
        override fun run() {
            val img = avatar ?: return
            if (animating || root == null) return
            img.setImageResource(R.drawable.companion_avatar_blink)
            handler.postDelayed({
                if (!animating && root != null) {
                    img.setImageResource(CompanionMoodMatcher.restingDrawable(CompanionMood.IDLE))
                }
                handler.postDelayed(this, 2200L + (SystemClock.uptimeMillis() % 1100))
            }, 130L)
        }
    }

    private val cuteIdleTwitch = object : Runnable {
        override fun run() {
            val img = avatar ?: return
            if (animating || root == null) return
            // Occasional cute micro-expression while idle.
            val flash = listOf(
                R.drawable.companion_avatar_shy,
                R.drawable.companion_avatar_happy,
                R.drawable.companion_avatar_care
            )[Random.nextInt(3)]
            img.setImageResource(flash)
            img.animate()
                .scaleX(1.05f)
                .scaleY(1.05f)
                .setDuration(180)
                .withEndAction {
                    img.animate().scaleX(1f).scaleY(1f).setDuration(200).start()
                    handler.postDelayed({
                        if (!animating && root != null) {
                            img.setImageResource(R.drawable.companion_avatar_idle)
                        }
                    }, 520L)
                }
                .start()
            handler.postDelayed(this, 6500L + Random.nextLong(0, 3500))
        }
    }

    private val bobLoop = object : Runnable {
        override fun run() {
            val ball = fab ?: return
            if (root == null) return
            val amp = if (animating) -6f else -3.5f
            ball.animate()
                .translationY(amp)
                .setDuration(if (animating) 520 else 920)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .withEndAction {
                    ball.animate()
                        .translationY(0f)
                        .setDuration(if (animating) 520 else 920)
                        .setInterpolator(AccelerateDecelerateInterpolator())
                        .withEndAction {
                            if (root != null) handler.postDelayed(this, 60L)
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
        avatar = view.findViewById(R.id.avatar)
        fab = view.findViewById(R.id.fab)
        val touchTarget = fab!!

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
        handler.postDelayed(idleBlink, 1600L)
        handler.postDelayed(cuteIdleTwitch, 4200L)
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
        speak(text)
    }

    fun showThinking(text: String = "让我看看你在干嘛…") {
        showText(text)
    }

    private fun speak(text: String) {
        val img = avatar ?: return
        currentMood = CompanionMoodMatcher.fromText(text)
        animating = true
        val token = ++speakToken
        handler.removeCallbacks(finishSpeak)

        // Kick with matched expression, then lip-sync.
        img.setImageResource(CompanionMoodMatcher.restingDrawable(currentMood))
        img.animate().cancel()
        img.scaleX = 1f
        img.scaleY = 1f
        img.animate()
            .scaleX(1.08f)
            .scaleY(1.08f)
            .setDuration(160)
            .setInterpolator(OvershootInterpolator(1.4f))
            .withEndAction {
                img.animate().scaleX(1f).scaleY(1f).setDuration(160).start()
            }
            .start()

        val cycles = max(4, (text.length / 3).coerceIn(4, 10))
        val frameMs = 95L
        var step = 0
        val frames = speakFrames
        val lipSync = object : Runnable {
            override fun run() {
                if (token != speakToken || root == null) return
                img.setImageResource(frames[step % frames.size])
                step++
                if (step < cycles * frames.size / 2) {
                    // Slightly irregular cadence feels more like speech.
                    val jitter = Random.nextLong(0, 35)
                    handler.postDelayed(this, frameMs + jitter)
                } else {
                    img.setImageResource(CompanionMoodMatcher.restingDrawable(currentMood))
                    // Hold the matched cute face a beat after talking.
                    val hold = when (currentMood) {
                        CompanionMood.HAPPY, CompanionMood.SHY -> 1600L
                        CompanionMood.CARE -> 1400L
                        CompanionMood.SURPRISE -> 1100L
                        CompanionMood.THINK -> 900L
                        else -> 1000L
                    }
                    handler.postDelayed(finishSpeak, hold)
                }
            }
        }
        handler.postDelayed(lipSync, 120L)
    }

    private val finishSpeak = Runnable {
        animating = false
        currentMood = CompanionMood.IDLE
        avatar?.setImageResource(R.drawable.companion_avatar_idle)
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
        speakToken++
        handler.removeCallbacksAndMessages(null)
        fab?.animate()?.cancel()
        avatar?.animate()?.cancel()
        root?.let {
            runCatching { windowManager.removeView(it) }
        }
        root = null
        bubblePanel = null
        bubbleText = null
        avatar = null
        fab = null
        params = null
        animating = false
        currentMood = CompanionMood.IDLE
    }
}
