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
import android.graphics.BitmapFactory
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
    /** True while screen is off or keyguard is showing — capture pipeline is released. */
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
        vision = VisionClient(this, prefs)
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
                    overlay?.showText(getString(R.string.overlay_locked_idle))
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
        return START_NOT_STICKY
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
        if (!pausedForLock.compareAndSet(false, true)) {
            // Already paused; still drop any leftover frame.
            dropHeldFrames()
            return
        }
        dropHeldFrames()
        if (CapturePolicy.shouldReleaseMirroringOnLock(demoMode)) {
            captor?.pauseMirroring()
        }
        pausedLock = true
        updateNotification(statusText())
        overlay?.showText(getString(R.string.overlay_locked))
        android.util.Log.i(TAG, "stopped capture for lock ($reason)")
    }

    private fun onScreenUnlocked(reason: String) {
        if (isDeviceLockedOrOff()) return
        if (!pausedForLock.compareAndSet(true, false)) return
        pausedLock = false
        if (CapturePolicy.shouldResumeMirroring(running, demoMode, locked = false)) {
            captor?.resumeMirroring()
        }
        updateNotification(statusText())
        overlay?.showText(getString(R.string.overlay_welcome_back))
        android.util.Log.i(TAG, "resumed after unlock ($reason)")
        // Do not force-roast: lock-screen / PIN frames must never be sent.
    }

    private fun dropHeldFrames() {
        lastFrame?.recycle()
        lastFrame = null
    }

    private fun statusText(demo: Boolean = demoMode): String = when {
        pausedForLock.get() && demo -> getString(R.string.notification_paused_demo)
        pausedForLock.get() -> getString(R.string.notification_paused_capture)
        demo -> getString(R.string.notification_demo)
        else -> getString(R.string.notification_title)
    }

    private fun startAsForeground(demo: Boolean) {
        val text = statusText(demo)
        if (Build.VERSION.SDK_INT >= 34) {
            val type = if (demo) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
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

    /** Stop the current loop / capture without dismissing the overlay or FGS. */
    private fun teardownSession(keepOverlay: Boolean) {
        loopJob?.cancel()
        loopJob = null
        captor?.release()
        captor = null
        projectionCallback?.let { cb ->
            runCatching { mediaProjection?.unregisterCallback(cb) }
        }
        projectionCallback = null
        runCatching { mediaProjection?.stop() }
        mediaProjection = null
        dropHeldFrames()
        unchangedStreak = 0
        if (!keepOverlay) {
            overlay?.dismiss()
            overlay = null
        }
    }

    private fun ensureOverlay(hello: String): OverlayController {
        val existing = overlay
        if (existing != null) {
            existing.showText(hello)
            return existing
        }
        val created = OverlayController(
            this,
            onForceRoast = { scope.launch { roastOnce(force = true) } },
            onClose = { stopSelfSafe() }
        )
        overlay = created
        created.show(hello)
        return created
    }

    private fun beginCapture(resultCode: Int, data: Intent) {
        teardownSession(keepOverlay = true)
        demoMode = false
        runningDemo = false
        running = true
        unchangedStreak = 0
        refreshLockState("beginCapture")

        val mpm = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val projection = mpm.getMediaProjection(resultCode, data)
        if (projection == null) {
            ensureOverlay(getString(R.string.overlay_no_projection))
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

        ensureOverlay(getString(R.string.overlay_capture_hello))

        val screenCaptor = ScreenCaptor(this, projection)
        captor = screenCaptor
        if (!pausedForLock.get()) {
            screenCaptor.start()
        }

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
        teardownSession(keepOverlay = true)
        demoMode = true
        runningDemo = true
        running = true
        refreshLockState("beginDemo")
        ensureOverlay(getString(R.string.overlay_demo_hello))

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
            val appHint = if (demoMode) {
                null
            } else {
                withContext(Dispatchers.IO) { ForegroundAppResolver.resolve(this@RoastService) }
            }
            val sensitive = !demoMode && SensitiveApps.shouldSkip(appHint?.packageName)
            if (CapturePolicy.shouldSkipTick(pausedForLock.get(), demoMode, sensitive)) {
                if (sensitive) o.showText(getString(R.string.overlay_sensitive_skip))
                return
            }
            val frame = if (demoMode) {
                withContext(Dispatchers.Default) { nextDemoFrame() }
            } else {
                val c = captor ?: return
                if (!c.isMirroring()) {
                    o.showText(getString(R.string.overlay_frame_wait))
                    return
                }
                withContext(Dispatchers.Default) { c.captureBitmap(900) }
            }
            if (frame == null) {
                o.showText(getString(R.string.overlay_frame_wait))
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
                        o.showText(getString(R.string.overlay_unchanged))
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
                getString(
                    if (VisionClient.isHeavyModel(prefs.model)) {
                        R.string.overlay_thinking_heavy
                    } else {
                        R.string.overlay_thinking
                    }
                )
            )
            val scene = if (demoMode) demoScenes[demoIndex % demoScenes.size].key else null
            val result = if (demoMode) {
                vision.mockRoast(scene)
            } else {
                withContext(Dispatchers.IO) { vision.roast(frame, scene, appHint) }
            }
            frame.recycle()
            if (pausedForLock.get()) return
            o.showText(result.text)
            if (demoMode) demoIndex++
        } finally {
            roasting.set(false)
        }
    }

    private fun nextDemoFrame(): Bitmap {
        val scene = demoScenes[demoIndex % demoScenes.size]
        val fromAsset = runCatching {
            assets.open(scene.asset).use { BitmapFactory.decodeStream(it) }
        }.getOrNull()
        if (fromAsset != null) return fromAsset

        val bmp = Bitmap.createBitmap(720, 1280, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(scene.bg)
        val title = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 54f
            isFakeBoldText = true
        }
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#E2E8F0")
            textSize = 40f
        }
        canvas.drawRoundRect(48f, 96f, 672f, 240f, 36f, 36f, Paint().apply { color = scene.accent })
        canvas.drawText(getString(scene.titleRes), 72f, 180f, title.apply { color = Color.parseColor("#0B1220") })
        canvas.drawText(getString(scene.bodyRes), 72f, 360f, body)
        canvas.drawText(getString(R.string.demo_frame_label, demoIndex + 1), 72f, 440f, body)
        return bmp
    }

    private fun stopSelfSafe() {
        running = false
        runningDemo = false
        pausedLock = false
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
        running = false
        runningDemo = false
        pausedLock = false
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
                getString(R.string.notification_channel),
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

        @Volatile
        var running: Boolean = false

        @Volatile
        var runningDemo: Boolean = false

        @Volatile
        var pausedLock: Boolean = false

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

    private val demoScenes = listOf(
        DemoScene(
            VisionClient.SCENE_SHORTS,
            R.string.demo_scene_shorts_title,
            R.string.demo_scene_shorts_body,
            Color.parseColor("#0F172A"),
            Color.parseColor("#38BDF8"),
            "mock/feed.png"
        ),
        DemoScene(
            VisionClient.SCENE_CHAT,
            R.string.demo_scene_chat_title,
            R.string.demo_scene_chat_body,
            Color.parseColor("#111827"),
            Color.parseColor("#34D399"),
            "mock/chat.png"
        ),
        DemoScene(
            VisionClient.SCENE_CART,
            R.string.demo_scene_cart_title,
            R.string.demo_scene_cart_body,
            Color.parseColor("#1C1917"),
            Color.parseColor("#FB923C"),
            "mock/shop.png"
        ),
        DemoScene(
            VisionClient.SCENE_RANKED,
            R.string.demo_scene_ranked_title,
            R.string.demo_scene_ranked_body,
            Color.parseColor("#0C1222"),
            Color.parseColor("#A78BFA"),
            "mock/game.png"
        ),
        DemoScene(
            VisionClient.SCENE_NOTES,
            R.string.demo_scene_notes_title,
            R.string.demo_scene_notes_body,
            Color.parseColor("#14221B"),
            Color.parseColor("#86EFAC"),
            "mock/note.png"
        )
    )
}

private data class DemoScene(
    val key: String,
    val titleRes: Int,
    val bodyRes: Int,
    val bg: Int,
    val accent: Int,
    val asset: String
)
