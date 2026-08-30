package com.pangchuang.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
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
    private lateinit var prefs: Prefs
    private lateinit var vision: VisionClient

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        prefs = Prefs(this)
        vision = VisionClient(prefs)
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfSafe()
                return START_NOT_STICKY
            }
            ACTION_FORCE_ROAST -> {
                scope.launch { roastOnce(force = true) }
            }
            ACTION_START_DEMO -> {
                startAsForeground(demo = true)
                beginDemo()
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
                beginCapture(resultCode, data)
            }
        }
        return START_STICKY
    }

    private fun startAsForeground(demo: Boolean) {
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
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(
                if (demo) "演示悬浮窗中 · 合成画面吐槽"
                else "正在看你的屏幕并吐槽"
            )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(open)
            .addAction(0, getString(R.string.stop_roast), stop)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            val type = if (demo) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            startForeground(NOTIF_ID, notification, type)
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun beginCapture(resultCode: Int, data: Intent) {
        if (loopJob?.isActive == true) return
        demoMode = false
        unchangedStreak = 0

        val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = mpm.getMediaProjection(resultCode, data)
        mediaProjection = projection

        // Android 14+: callback must be registered before createVirtualDisplay.
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
        overlayController.show("已盯上你的屏幕。长按「旁」可立刻吐槽。")

        val screenCaptor = ScreenCaptor(this, projection)
        captor = screenCaptor
        screenCaptor.start()

        loopJob = scope.launch {
            delay(900)
            // First roast ASAP so users feel it working.
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
        val overlayController = OverlayController(this) {
            scope.launch { roastOnce(force = true) }
        }
        overlay = overlayController
        overlayController.show("演示模式：合成画面吐槽。长按「旁」立刻换一句。")

        loopJob = scope.launch {
            delay(400)
            while (isActive) {
                roastOnce(force = true)
                delay((prefs.intervalSec.coerceAtMost(8)) * 1000L)
            }
        }
    }

    private suspend fun roastOnce(force: Boolean) {
        if (!roasting.compareAndSet(false, true)) return
        try {
            val o = overlay ?: return
            val frame = if (demoMode) {
                withContext(Dispatchers.Default) { nextDemoFrame() }
            } else {
                val c = captor ?: return
                o.hideForCapture()
                delay(180)
                val captured = withContext(Dispatchers.Default) { c.captureBitmap(900) }
                o.restoreAfterCapture()
                captured
            }
            if (frame == null) {
                o.showText("还没抓到画面，再等一下…")
                return
            }

            if (!force && !demoMode) {
                val changed = withContext(Dispatchers.Default) {
                    screenChanged(lastFrame, frame, prefs.changeThreshold)
                }
                if (!changed) {
                    unchangedStreak++
                    frame.recycle()
                    // Every few quiet ticks, remind instead of looking dead.
                    if (unchangedStreak % 3 == 0) {
                        o.showText("画面差不多，继续盯着…长按可强制吐槽")
                    }
                    return
                }
            }
            unchangedStreak = 0
            lastFrame?.recycle()
            lastFrame = frame.copy(Bitmap.Config.ARGB_8888, false)

            o.showText("正在看屏吐槽…")
            val scene = if (demoMode) DEMO_SCENES[demoIndex % DEMO_SCENES.size].first else null
            val result = withContext(Dispatchers.IO) { vision.roast(frame, scene) }
            frame.recycle()
            val tag = when (result.source) {
                "api" -> "看屏"
                "mock" -> "演示"
                else -> "异常"
            }
            o.showText("[$tag] ${result.text}")
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
        canvas.drawText("旁窗演示画面 #${demoIndex + 1}", 72f, 440f, body)
        return bmp
    }

    private fun stopSelfSafe() {
        loopJob?.cancel()
        loopJob = null
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
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        loopJob?.cancel()
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
                "旁窗吐槽",
                NotificationManager.IMPORTANCE_LOW
            )
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    companion object {
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
