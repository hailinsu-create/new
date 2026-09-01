package com.pangchuang.app

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean

class RoastService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var loopJob: Job? = null
    private var mediaProjection: MediaProjection? = null
    private var projectionCallback: MediaProjection.Callback? = null
    private var captor: ScreenCaptor? = null
    private var overlay: OverlayController? = null
    private var lastFrame: Bitmap? = null
    private var demoMode = false
    private var demoIndex = 0
    private var unchangedStreak = 0
    private val roasting = AtomicBoolean(false)
    /** True while screen is off or keyguard is showing — skip capture/API to save tokens. */
    private val pausedForLock = AtomicBoolean(false)
    private var screenReceiverRegistered = false
    private lateinit var prefs: Prefs
    private lateinit var vision: VisionClient

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> onScreenLocked("screen_off")
                Intent.ACTION_SCREEN_ON -> refreshLockState("screen_on")
                Intent.ACTION_USER_PRESENT -> onScreenUnlocked("user_present")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        prefs = Prefs(this)
        vision = VisionClient(prefs)
        createChannel()
        registerScreenReceiver()
        refreshLockState("onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfSafe()
                return START_NOT_STICKY
            }
            ACTION_FORCE_ROAST -> {
                if (overlay == null) {
                    startAsForeground(demo = demoMode)
                }
                if (pausedForLock.get()) {
                    overlay?.showText("锁屏中，醒了我再陪你看屏～")
                } else {
                    scope.launch { roastOnce(force = true) }
                }
            }
            ACTION_START_DEMO -> {
                startAsForeground(demo = true)
                mainHandler.post { beginDemo() }
            }
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
                val data = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(EXTRA_RESULT_DATA)
                }
                if (data == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                startAsForeground(demo = false)
                mainHandler.post { beginCapture(resultCode, data) }
            }
        }
        return START_STICKY
    }

    private fun registerScreenReceiver() {
        if (screenReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(screenReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
        screenReceiverRegistered = true
    }

    private fun unregisterScreenReceiver() {
        if (!screenReceiverRegistered) return
        runCatching { unregisterReceiver(screenReceiver) }
        screenReceiverRegistered = false
    }

    private fun isDeviceLockedOrOff(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return true
        val km = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        return km.isKeyguardLocked
    }

    private fun refreshLockState(reason: String) {
        if (isDeviceLockedOrOff()) {
            onScreenLocked(reason)
        } else {
            onScreenUnlocked(reason)
        }
    }

    private fun onScreenLocked(reason: String) {
        if (!pausedForLock.compareAndSet(false, true)) return
        updateNotification(
            if (demoMode) "演示已暂停 · 锁屏中"
            else "锁屏中 · 已暂停看屏（省 token）"
        )
        overlay?.showText("锁屏啦，我先歇着，不乱花 token～")
        android.util.Log.i(TAG, "paused for lock ($reason)")
    }

    private fun onScreenUnlocked(reason: String) {
        if (isDeviceLockedOrOff()) return
        if (!pausedForLock.compareAndSet(true, false)) return
        updateNotification(
            if (demoMode) "演示模式 · 小旁用合成画面陪聊"
            else "小旁陪你看屏幕中"
        )
        overlay?.showText("欢迎回来，我继续陪着你。")
        android.util.Log.i(TAG, "resumed after unlock ($reason)")
        if (loopJob?.isActive == true && !demoMode) {
            scope.launch {
                delay(600)
                if (!pausedForLock.get()) roastOnce(force = true)
            }
        }
    }

    private fun startAsForeground(demo: Boolean) {
        val text = when {
            pausedForLock.get() && demo -> "演示已暂停 · 锁屏中"
            pausedForLock.get() -> "锁屏中 · 已暂停看屏（省 token）"
            demo -> "演示模式 · 小旁用合成画面陪聊"
            else -> "小旁陪你看屏幕中"
        }
        if (Build.VERSION.SDK_INT >= 34) {
            val type = if (demo) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            startForeground(NOTIF_ID, buildNotification(text), type)
        } else {
            startForeground(NOTIF_ID, buildNotification(text))
        }
    }

    private fun buildNotification(contentText: String): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, RoastService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(open)
            .addAction(0, getString(R.string.stop_roast), stop)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val nm = getSystemService(NotificationManager::class.java) ?: return
        nm.notify(NOTIF_ID, buildNotification(contentText))
    }

    private fun beginCapture(resultCode: Int, data: Intent) {
        if (loopJob?.isActive == true) return
        demoMode = false
        unchangedStreak = 0
        refreshLockState("beginCapture")

        val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = mpm.getMediaProjection(resultCode, data)
        if (projection == null) {
            overlay?.show("系统未给出录屏权限，先休息一下。")
            stopSelfSafe()
            return
        }
        mediaProjection = projection

        val callback = object : MediaProjection.Callback() {
            override fun onStop() {
                mainHandler.post { stopSelfSafe() }
            }
        }
        projectionCallback = callback
        projection.registerCallback(callback, mainHandler)

        val overlayController = OverlayController(this) {
            scope.launch { roastOnce(force = true) }
        }
        overlay = overlayController
        overlayController.show("我在这儿陪着你。锁屏会自动停看屏。")

        val screenCaptor = ScreenCaptor(this, projection)
        captor = screenCaptor
        screenCaptor.start()

        loopJob = scope.launch {
            delay(900)
            roastOnce(force = true)
            while (isActive) {
                delay(prefs.intervalSec * 1000L)
                roastOnce(force = false)
            }
        }
    }

    private fun beginDemo() {
        if (loopJob?.isActive == true) return
        demoMode = true
        refreshLockState("beginDemo")
        val overlayController = OverlayController(this) {
            scope.launch { roastOnce(force = true) }
        }
        overlay = overlayController
        overlayController.show("演示模式：我会用合成画面陪你练对话。长按头像换一句。")

        loopJob = scope.launch {
            delay(400)
            while (isActive) {
                roastOnce(force = true)
                delay((prefs.intervalSec.coerceAtMost(8)) * 1000L)
            }
        }
    }

    private suspend fun roastOnce(force: Boolean) {
        if (pausedForLock.get()) return
        if (!roasting.compareAndSet(false, true)) return
        try {
            if (pausedForLock.get()) return
            val o = overlay ?: return
            val frame = if (demoMode) {
                withContext(Dispatchers.Default) { nextDemoFrame() }
            } else {
                val c = captor ?: return
                o.hideForCapture()
                delay(180)
                if (pausedForLock.get()) {
                    o.restoreAfterCapture()
                    return
                }
                val captured = withContext(Dispatchers.Default) { c.captureBitmap(900) }
                o.restoreAfterCapture()
                captured
            }
            if (frame == null) {
                o.showText("画面还没准备好，再等我一小下…")
                return
            }

            if (!force && !demoMode) {
                val changed = withContext(Dispatchers.Default) {
                    screenChanged(lastFrame, frame, prefs.changeThreshold)
                }
                if (!changed) {
                    unchangedStreak++
                    frame.recycle()
                    if (unchangedStreak % 3 == 0) {
                        o.showText("画面没怎么变，我还在陪着你。长按头像可以说一句。")
                    }
                    return
                }
            }
            unchangedStreak = 0
            lastFrame?.recycle()
            lastFrame = frame.copy(Bitmap.Config.ARGB_8888, false)

            if (pausedForLock.get()) {
                frame.recycle()
                return
            }

            o.showThinking(
                if (VisionClient.isHeavyModel(prefs.model)) "大模型在看这一屏…" else "且看这一屏…"
            )
            val scene = if (demoMode) DEMO_SCENES[demoIndex % DEMO_SCENES.size].first else null
            val appHint = if (demoMode) null else withContext(Dispatchers.IO) {
                ForegroundAppResolver.resolve(this@RoastService)
            }
            val result = withContext(Dispatchers.IO) { vision.roast(frame, scene, appHint) }
            frame.recycle()
            if (pausedForLock.get()) return
            o.showText(result.text)
            if (demoMode) demoIndex++
        } finally {
            roasting.set(false)
        }
    }

    private fun nextDemoFrame(): Bitmap {
        val scene = DEMO_SCENES[demoIndex % DEMO_SCENES.size]
        val bmp = Bitmap.createBitmap(720, 1280, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(scene.second)
        val title = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 54f
            isFakeBoldText = true
        }
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#E2E8F0")
            textSize = 40f
        }
        canvas.drawRoundRect(48f, 96f, 672f, 240f, 36f, 36f, Paint().apply { color = scene.third })
        canvas.drawText(scene.first, 72f, 180f, title.apply { color = Color.parseColor("#0B1220") })
        canvas.drawText(scene.fourth, 72f, 360f, body)
        canvas.drawText("小旁演示画面 #${demoIndex + 1}", 72f, 440f, body)
        return bmp
    }

    private fun stopSelfSafe() {
        loopJob?.cancel()
        loopJob = null
        unregisterScreenReceiver()
        captor?.release()
        captor = null
        projectionCallback?.let { cb ->
            runCatching { mediaProjection?.unregisterCallback(cb) }
        }
        projectionCallback = null
        mediaProjection?.stop()
        mediaProjection = null
        overlay?.dismiss()
        overlay = null
        lastFrame?.recycle()
        lastFrame = null
        demoMode = false
        pausedForLock.set(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        loopJob?.cancel()
        unregisterScreenReceiver()
        scope.cancel()
        captor?.release()
        overlay?.dismiss()
        mediaProjection?.stop()
        lastFrame?.recycle()
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "旁窗伴侣",
                NotificationManager.IMPORTANCE_LOW
            )
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    companion object {
        private const val TAG = "PangchuangRoast"
        const val ACTION_START = "com.pangchuang.app.START"
        const val ACTION_START_DEMO = "com.pangchuang.app.START_DEMO"
        const val ACTION_FORCE_ROAST = "com.pangchuang.app.FORCE_ROAST"
        const val ACTION_STOP = "com.pangchuang.app.STOP"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        private const val CHANNEL_ID = "pangchuang_roast"
        private const val NOTIF_ID = 42

        private val DEMO_SCENES = listOf(
            Triple("深夜刷短视频", Color.parseColor("#0F172A"), Color.parseColor("#38BDF8")) to "又一条同款舞蹈",
            Triple("微信置顶群", Color.parseColor("#111827"), Color.parseColor("#34D399")) to "老板：在吗？急！",
            Triple("购物车结算", Color.parseColor("#1C1917"), Color.parseColor("#FB923C")) to "凑单还差 ¥12.8",
            Triple("排位赛匹配中", Color.parseColor("#0C1222"), Color.parseColor("#A78BFA")) to "你已经连跪三把",
            Triple("备忘录", Color.parseColor("#14221B"), Color.parseColor("#86EFAC")) to "明天早上 7:30 开会"
        ).map { (triple, body) ->
            Quadruple(triple.first, triple.second, triple.third, body)
        }

        fun start(context: Context, resultCode: Int, data: Intent) {
            if (!Entitlement.isUnlocked(context)) return
            val intent = Intent(context, RoastService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, data)
            }
            context.startForegroundService(intent)
        }

        fun startDemo(context: Context) {
            context.startForegroundService(
                Intent(context, RoastService::class.java).setAction(ACTION_START_DEMO)
            )
        }

        fun stop(context: Context) {
            context.startService(Intent(context, RoastService::class.java).setAction(ACTION_STOP))
        }
    }
}

private data class Quadruple<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
