package com.pangchuang.app

import android.os.Handler
import android.os.Looper
import android.widget.ImageView
import kotlin.random.Random

/**
 * Lightweight PNG frame engine for the floating avatar.
 * Covers mood faces, blink, and three-step mouth chatter without Live2D/WebGL.
 */
class FrameAvatarAnimator(
    private val imageView: ImageView,
    private val handler: Handler = Handler(Looper.getMainLooper())
) {
    private var mood: CompanionMood = CompanionMood.IDLE
    private var speaking = false
    private var mouthPhase = 0
    private var destroyed = false
    private var blinkScheduled = false

    private val mouthTick = object : Runnable {
        override fun run() {
            if (destroyed || !speaking) return
            val frames = mouthFramesFor(mood)
            mouthPhase = (mouthPhase + 1) % frames.size
            imageView.setImageResource(frames[mouthPhase])
            handler.postDelayed(this, 110L + Random.nextLong(0, 40))
        }
    }

    private val blinkTick = object : Runnable {
        override fun run() {
            if (destroyed) return
            blinkScheduled = false
            if (!speaking) {
                imageView.setImageResource(R.drawable.companion_avatar_blink)
                handler.postDelayed({
                    if (!destroyed && !speaking) {
                        imageView.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
                    }
                    scheduleBlink()
                }, 120L)
            } else {
                scheduleBlink()
            }
        }
    }

    fun start() {
        if (destroyed) return
        imageView.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
        scheduleBlink()
    }

    fun setMood(next: CompanionMood) {
        mood = next
        if (!speaking) {
            imageView.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
        }
    }

    fun speak(text: String, next: CompanionMood) {
        mood = next
        speaking = true
        mouthPhase = 0
        handler.removeCallbacks(mouthTick)
        imageView.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
        handler.post(mouthTick)
        val duration = (800 + text.length * 60).coerceIn(1000, 7200).toLong()
        handler.postDelayed({ idle() }, duration)
    }

    fun tap() {
        if (speaking) return
        imageView.setImageResource(R.drawable.companion_avatar_blink)
        handler.postDelayed({
            if (!destroyed && !speaking) {
                imageView.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
            }
        }, 140L)
    }

    fun idle() {
        speaking = false
        handler.removeCallbacks(mouthTick)
        imageView.setImageResource(CompanionMoodMatcher.restingDrawable(mood))
    }

    fun destroy() {
        destroyed = true
        speaking = false
        handler.removeCallbacks(mouthTick)
        handler.removeCallbacks(blinkTick)
        blinkScheduled = false
    }

    private fun scheduleBlink() {
        if (destroyed || blinkScheduled) return
        blinkScheduled = true
        handler.postDelayed(blinkTick, 2200L + Random.nextLong(0, 2800))
    }

    private fun mouthFramesFor(mood: CompanionMood): IntArray {
        val closed = CompanionMoodMatcher.restingDrawable(mood)
        return intArrayOf(
            closed,
            R.drawable.companion_avatar_mouth_mid,
            R.drawable.companion_avatar_mouth_open,
            R.drawable.companion_avatar_mouth_mid,
            closed
        )
    }
}
