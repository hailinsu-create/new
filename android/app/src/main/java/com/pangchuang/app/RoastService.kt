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
import android.os.IBinder
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

class RoastService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var loopJob: Job? = null
    private var mediaProjection: MediaProjection? = null
    private var captor: ScreenCaptor? = null
    private var overlay: OverlayController? = null
    private var lastFrame: Bitmap? = null
    private var demoMode = false
    private var demoIndex = 0
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
                else getString(R.string.notification_text)
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
        val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = mpm.getMediaProjection(resultCode, data)
        mediaProjection = projection
        projection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                stopSelfSafe()
            }
        }, null)

        val overlayController = OverlayController(this)
        overlay = overlayController
        overlayController.show()

        val screenCaptor = ScreenCaptor(this, projection)
        captor = screenCaptor
        screenCaptor.start()

        loopJob = scope.launch {
            delay(800)
            while (isActive) {
                roastOnce()
                delay(prefs.intervalSec * 1000L)
            }
        }
    }

    private fun beginDemo() {
        if (loopJob?.isActive == true) return
        demoMode = true
        val overlayController = OverlayController(this)
        overlay = overlayController
        overlayController.show()
        overlayController.showText("演示模式：合成手机画面，持续吐槽中。")

        loopJob = scope.launch {
            delay(400)
            while (isActive) {
                roastOnce()
                delay((prefs.intervalSec.coerceAtMost(8)) * 1000L)
            }
        }
    }

    private suspend fun roastOnce() {
        val o = overlay ?: return
        val frame = if (demoMode) {
            withContext(Dispatchers.Default) { nextDemoFrame() }
        } else {
            val c = captor ?: return
            o.hideForCapture()
            delay(120)
            val captured = withContext(Dispatchers.Default) { c.captureBitmap() }
            o.restoreAfterCapture()
            captured
        }
        if (frame == null) {
            o.showText("还没抓到画面，稍后再试。")
            return
        }
        val changed = withContext(Dispatchers.Default) { screenChanged(lastFrame, frame) }
        if (!changed && lastFrame != null && !demoMode) {
            frame.recycle()
            return
        }
        lastFrame?.recycle()
        lastFrame = frame.copy(Bitmap.Config.ARGB_8888, false)

        o.showText("正在吐槽…")
        val scene = if (demoMode) DEMO_SCENES[demoIndex % DEMO_SCENES.size].first else null
        val result = withContext(Dispatchers.IO) { vision.roast(frame, scene) }
        if (!demoMode) frame.recycle()
        else frame.recycle()
        val tag = when (result.source) {
            "api" -> "视觉"
            "mock" -> "演示"
            else -> "异常"
        }
        o.showText("[$tag] ${result.text}")
        if (demoMode) demoIndex++
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
        const val ACTION_STOP = "com.pangchuang.app.STOP"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        private const val CHANNEL_ID = "pangchuang_roast"
        private const val NOTIF_ID = 42

        // name, bg, accent, body
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
