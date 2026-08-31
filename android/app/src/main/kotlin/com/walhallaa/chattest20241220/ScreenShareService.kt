package com.walhallaa.chattest20241220

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * The foreground service a screen share on Android 14 cannot start without.
 *
 * `MediaProjection.createVirtualDisplay` — the call flutter_webrtc's
 * `getDisplayMedia` makes under the hood — throws unless a foreground service
 * typed `mediaProjection` is already running in the process. The call
 * foreground service belongs to the vendored callkit plugin and is typed
 * `phoneCall|microphone|camera`; the type list of a third-party service is not
 * ours to extend, and adding `mediaProjection` to it would also make every
 * ordinary call carry a permission it does not use. So a share gets a service of
 * its own, started from Dart AFTER the consent dialog has been answered (Android
 * refuses to start a `mediaProjection` service before consent) and BEFORE the
 * capture begins.
 *
 * Modelled on [LiveLocationService], minus the parts that do not apply: a share
 * never outlives the app (`stopWithTask="true"` in the manifest), never
 * restarts on boot, and never has to boot an engine — the call it belongs to is
 * on screen. What it keeps is the notification with a STOP action: a share the
 * user can only end by finding their way back to the call is not one to trust.
 */
class ScreenShareService : Service() {

    companion object {
        private const val TAG = "ScreenShareService"

        /** Its own channel, importance LOW: a status display, not an alert. */
        const val CHANNEL_ID = "mh_screen_share"

        private const val NOTIFICATION_ID = 0x55E

        const val ACTION_START = "com.walhallaa.chattest20241220.SCREEN_SHARE_START"
        const val ACTION_STOP = "com.walhallaa.chattest20241220.SCREEN_SHARE_STOP"

        /** The STOP button — reaches Dart first, which ends the share and then
         * sends [ACTION_STOP]. See [LiveLocationService] for why the two are
         * distinct actions. */
        const val ACTION_USER_STOP = "com.walhallaa.chattest20241220.SCREEN_SHARE_USER_STOP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_STOP_LABEL = "stopLabel"

        fun start(ctx: Context, title: String, body: String, stopLabel: String) {
            val intent = Intent(ctx, ScreenShareService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_STOP_LABEL, stopLabel)
            }
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
            }.onFailure { Log.w(TAG, "could not start: $it") }
        }

        fun stop(ctx: Context) {
            runCatching {
                ctx.startService(
                    Intent(ctx, ScreenShareService::class.java).apply { action = ACTION_STOP }
                )
            }
        }

        fun ensureChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Screen sharing",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Shown while you are sharing your screen on a call"
                    setShowBadge(false)
                }
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_USER_STOP -> {
                // Dart ends the share (the peers must be told, the capture
                // stopped) and comes back with ACTION_STOP. If nobody is
                // listening the share is already gone with the engine; stop.
                if (!ScreenShareBridge.reportUserStop()) stopSelf()
                return START_NOT_STICKY
            }
        }
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty()
        val body = intent?.getStringExtra(EXTRA_BODY).orEmpty()
        val stopLabel = intent?.getStringExtra(EXTRA_STOP_LABEL) ?: "Stop"
        startInForeground(title, body, stopLabel)
        // NOT sticky: a share recreated by the OS with no intent and no capture
        // would be a notification for nothing.
        return START_NOT_STICKY
    }

    private fun startInForeground(title: String, body: String, stopLabel: String) {
        ensureChannel(this)
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val contentIntent = launch?.let {
            PendingIntent.getActivity(
                this,
                NOTIFICATION_ID,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        val stopIntent = PendingIntent.getService(
            this,
            NOTIFICATION_ID + 1,
            Intent(this, ScreenShareService::class.java).apply { action = ACTION_USER_STOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(title.ifEmpty { "Sharing your screen" })
            .setContentText(body)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(0, stopLabel, stopIntent)
            .build()
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // The typed overload; the type must match the manifest's or
                // Android 14 throws rather than degrading.
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        }.onFailure {
            Log.w(TAG, "startForeground refused: $it")
            stopSelf()
        }
    }
}
