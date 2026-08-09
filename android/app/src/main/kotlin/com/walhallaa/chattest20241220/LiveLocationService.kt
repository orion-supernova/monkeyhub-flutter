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
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Keeps a live location share publishing when MonkeyHub is not on screen.
 *
 * ## What this service is actually for
 *
 * Not for taking positions — `geolocator` does that, from the Dart isolate, and
 * it is perfectly capable of it. This service exists to keep that isolate ALIVE
 * and unthrottled. An ordinary backgrounded Android app gets its location
 * updates throttled to a few an hour within minutes and is killed outright soon
 * after; a process hosting a `foregroundServiceType="location"` service does
 * not. That is the whole mechanism.
 *
 * `geolocator` can start a foreground service of its own (see
 * `ForegroundNotificationConfig`) and this app does not use that path, for one
 * reason: its notification has a title, a body and an icon, and no way to add an
 * action button. A background tracker that can only be stopped by finding the
 * app, opening it, finding the room and finding the bubble is the thing people
 * are right to distrust. So the notification is ours, and it has a STOP button.
 *
 * ## Started from the foreground, and why that matters legally
 *
 * [start] is called from Dart at the moment the user taps a live-share
 * duration — while the app is demonstrably on screen. Android allows a
 * foreground service started from the foreground to keep receiving location
 * with only `ACCESS_FINE_LOCATION`; `ACCESS_BACKGROUND_LOCATION` is required
 * only for the boot-restart path, which is why that permission is requested
 * separately, later, and only from people who asked for it.
 *
 * ## The engine
 *
 * On a boot restart there is no activity and no Dart isolate, so [ensureEngine]
 * starts one — the app's ordinary `main` entrypoint, headless, cached under the
 * id `MainActivity` also uses. That is deliberately the SAME engine the UI
 * later adopts rather than a second background isolate: the app's normal
 * bootstrap restores the session from the Keychain and attaches the repository,
 * which is exactly the work a resumed share needs, and none of it has to be
 * duplicated in a special background entrypoint that would then drift.
 *
 * It mirrors what iOS has always done here — `AppDelegate` runs
 * `FlutterEngine(name:).run()` in `didFinishLaunchingWithOptions`, before any
 * scene exists, for the same reason on the VoIP path.
 *
 * ## What this cannot promise
 *
 * Stock Android restarts the share after a reboot and keeps it alive across a
 * swipe-away. Xiaomi, Huawei and Samsung's aggressive power managers kill
 * foreground services anyway, and there is no API that stops them — the user has
 * to exempt the app by hand. The share still ends on time regardless, because
 * the deadline is enforced server-side, and viewers see it go STALE rather than
 * seeing a wrong position.
 */
class LiveLocationService : Service() {

    companion object {
        private const val TAG = "LiveLocationService"

        /** Its own channel so the user can silence the ongoing notification
         * without silencing messages. Importance LOW: no sound, no heads-up —
         * it is a status display, not an alert. */
        const val CHANNEL_ID = "mh_live_location"

        /** Fixed id: there is only ever one share, so a second notification
         * would be a second share this app refuses to have. */
        private const val NOTIFICATION_ID = 0x11E

        const val ACTION_START = "com.walhallaa.chattest20241220.LIVE_LOCATION_START"
        const val ACTION_STOP = "com.walhallaa.chattest20241220.LIVE_LOCATION_STOP"

        /** The STOP button. A separate action from [ACTION_STOP] because this
         * one has to reach Dart — the server must be told the share is over —
         * whereas ACTION_STOP is Dart telling US it already is. Collapsing them
         * would either loop or leave the share running server-side. */
        const val ACTION_USER_STOP = "com.walhallaa.chattest20241220.LIVE_LOCATION_USER_STOP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_STOP_LABEL = "stopLabel"
        const val EXTRA_EXPIRES_AT = "expiresAtMs"

        fun start(ctx: Context, title: String, body: String, stopLabel: String, expiresAtMs: Long) {
            val intent = Intent(ctx, LiveLocationService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_STOP_LABEL, stopLabel)
                putExtra(EXTRA_EXPIRES_AT, expiresAtMs)
            }
            // startForegroundService, not startService: from Android O the
            // latter is illegal from the background and throws, and this is
            // called from a boot receiver as well as from a foregrounded app.
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
            }.onFailure {
                // ForegroundServiceStartNotAllowedException on an OEM build that
                // decided otherwise, most likely. Logged and swallowed: the
                // share still publishes for as long as the app is on screen, and
                // crashing the send path over a notification would be worse.
                Log.w(TAG, "could not start: $it")
            }
        }

        fun stop(ctx: Context) {
            runCatching {
                ctx.startService(
                    Intent(ctx, LiveLocationService::class.java).apply { action = ACTION_STOP }
                )
            }
        }

        fun ensureChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Live location",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Shown while you are sharing your live location"
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
                // Tell Dart FIRST, and only tear down once it has heard. The
                // server has to be told: a share that merely stopped being fed
                // sits live and stale for its full duration, which for somebody
                // who pressed STOP is the worst outcome this feature has.
                //
                // A false answer means no isolate exists yet — a STOP pressed
                // seconds into a boot restart — so the press is buffered and
                // this service stays up, notification and all, until the engine
                // comes up and drains it. Dart then calls `stopSharing`, which
                // arrives back here as [ACTION_STOP].
                if (LiveLocationBridge.reportUserStop()) {
                    stopSelf()
                } else {
                    ensureEngine()
                }
                return START_NOT_STICKY
            }
        }

        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty()
        val body = intent?.getStringExtra(EXTRA_BODY).orEmpty()
        val stopLabel = intent?.getStringExtra(EXTRA_STOP_LABEL) ?: "Stop"
        val expiresAt = intent?.getLongExtra(EXTRA_EXPIRES_AT, 0L) ?: 0L

        // The service's own deadline check, independent of Dart's. A foreground
        // service that outlived its share would be a permanent notification for
        // something that ended — and this is the one code path that can be
        // entered by the OS (a boot restart) with no Dart running to object.
        if (expiresAt in 1..System.currentTimeMillis()) {
            Log.i(TAG, "share already expired; not starting")
            stopSelf()
            return START_NOT_STICKY
        }

        startInForeground(title, stopLabel, body)
        ensureEngine()
        // START_STICKY: if Android kills the process under memory pressure, the
        // service is recreated with a null intent — which lands above with an
        // empty title and a zero deadline, so it re-posts a bare notification
        // and re-boots the engine, and Dart's own resume decides whether there
        // is anything left to publish. That is the right division: this class
        // knows how to stay alive, the persisted handle knows whether it should.
        return START_STICKY
    }

    private fun startInForeground(title: String, stopLabel: String, body: String) {
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
            Intent(this, LiveLocationService::class.java).apply { action = ACTION_USER_STOP },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(title.ifEmpty { "Sharing your live location" })
            .setContentText(body)
            .setContentIntent(contentIntent)
            // Ongoing: the user cannot swipe this away and lose their only
            // handle on a tracker that is running. The STOP action is the way
            // out, and it is right there.
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(0, stopLabel, stopIntent)
            .build()

        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // The typed overload is mandatory from Android 14 (targetSdk 34+)
                // and the type must match the <service> declaration in the
                // manifest, or the OS throws rather than degrading.
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        }.onFailure {
            // SecurityException when location permission was revoked while we
            // were away — Android checks it at startForeground time for a
            // location-typed service. Nothing to recover: stop cleanly rather
            // than crash, and let the share go stale, which is the truth.
            Log.w(TAG, "startForeground refused: $it")
            stopSelf()
        }
    }

    /**
     * Makes sure a Dart isolate exists, starting the app headlessly if not.
     *
     * On the ordinary path (the user tapped share) this finds the engine
     * MainActivity already cached and does nothing. On a boot restart it starts
     * the app's normal `main` entrypoint with no activity attached — the engine
     * renders nowhere and costs nothing visible, but `main()` runs, the session
     * is restored from the Keychain, `ChatRepository.attach` runs, and its
     * resume finds the persisted handle.
     *
     * Cached under [MainActivity.ENGINE_ID] so that when the user does open the
     * app, `provideFlutterEngine` adopts this same isolate instead of booting a
     * second one — which would mean two publishers feeding one share.
     */
    private fun ensureEngine() {
        val cache = FlutterEngineCache.getInstance()
        if (cache.get(MainActivity.ENGINE_ID) != null) return
        runCatching {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val engine = FlutterEngine(applicationContext)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "main")
            )
            // Registers the app's own channels on an engine that has no
            // activity, so `monkeyhub/live_location` works before (and without)
            // any UI. MainActivity re-binds its activity-scoped handlers when it
            // later adopts the same engine.
            LiveLocationBridge.register(engine, applicationContext)
            cache.put(MainActivity.ENGINE_ID, engine)
            Log.i(TAG, "booted a headless Dart isolate for a resumed share")
        }.onFailure {
            Log.e(TAG, "could not boot Dart: $it")
        }
    }

    override fun onDestroy() {
        // Deliberately does NOT stop the engine. A share may have ended while
        // the user has the app open, and tearing down the isolate under a live
        // UI would be spectacular. The engine is owned by the cache and by
        // MainActivity's `shouldDestroyEngineWithHost() == false`, which is the
        // same arrangement calls already rely on.
        super.onDestroy()
    }
}
