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
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
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
                startAsForeground()
                begin(resultCode, data)
            }
        }
        return START_STICKY
    }

    private fun startAsForeground() {
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
            .setContentText(getString(R.string.notification_text))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(open)
            .addAction(0, getString(R.string.stop_roast), stop)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun begin(resultCode: Int, data: Intent) {
        if (loopJob?.isActive == true) return
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
            // Wait a beat for first frames to arrive.
            delay(800)
            while (isActive) {
                roastOnce()
                delay(prefs.intervalSec * 1000L)
            }
        }
    }

    private suspend fun roastOnce() {
        val o = overlay ?: return
        val c = captor ?: return
        o.hideForCapture()
        delay(120)
        val frame = withContext(Dispatchers.Default) { c.captureBitmap() }
        o.restoreAfterCapture()
        if (frame == null) {
            o.showText("还没抓到画面，稍后再试。")
            return
        }
        val changed = withContext(Dispatchers.Default) { screenChanged(lastFrame, frame) }
        if (!changed && lastFrame != null) {
            frame.recycle()
            return
        }
        lastFrame?.recycle()
        lastFrame = frame.copy(Bitmap.Config.ARGB_8888, false)

        o.showText("正在吐槽…")
        val result = withContext(Dispatchers.IO) { vision.roast(frame) }
        frame.recycle()
        val tag = when (result.source) {
            "api" -> "视觉"
            "mock" -> "演示"
            else -> "异常"
        }
        o.showText("[$tag] ${result.text}")
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
        const val ACTION_STOP = "com.pangchuang.app.STOP"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        private const val CHANNEL_ID = "pangchuang_roast"
        private const val NOTIF_ID = 42

        fun start(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, RoastService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_RESULT_DATA, data)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.startService(Intent(context, RoastService::class.java).setAction(ACTION_STOP))
        }
    }
}
