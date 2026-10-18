package com.walhallaa.chattest20241220

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /// Arbitrary but must not collide with a plugin's own request codes.
        private const val CALL_PERMISSION_REQUEST = 0x0CA1

        /// Deliberately a SECOND request code, paired with its own pending
        /// result below. Sharing the call one would let a notification prompt
        /// answer the microphone request — or complete the same MethodChannel
        /// result twice, which throws.
        private const val NOTIF_PERMISSION_REQUEST = 0x0CA2

        /// Cache key for the one and only Dart isolate this process runs.
        const val ENGINE_ID = "monkeyhub.main"

        /// Shortcut work runs here, never on the main thread: publishing
        /// fetches an avatar per chat over the network. Single-threaded so a
        /// burst of `touchTarget` calls (one per sent message) queues instead
        /// of opening eight sockets, and process-global so a second activity
        /// instance — which answering a call can always produce, see
        /// [provideFlutterEngine] — does not strand a second idle thread.
        private val shareWorker: java.util.concurrent.ExecutorService =
            java.util.concurrent.Executors.newSingleThreadExecutor()

        /// The monkeyhub/notifications and monkeyhub/share channels, and whether
        /// Dart has drained each one's backlog — process-scoped, NOT Activity
        /// instance fields, and deliberately so.
        ///
        /// [provideFlutterEngine] above documents why a second `MainActivity`
        /// instance sharing this process's one cached engine is an ordinary,
        /// expected event here (answering a call relaunches through
        /// flutter_callkit_incoming's TransparentActivity; switching the launcher
        /// icon relaunches through a different <activity-alias> ComponentName).
        /// PushManager/ShareIntake on the Dart side call `takePendingEvents` /
        /// `takePendingShare` exactly ONCE per process — `PushManager.initialize`
        /// is guarded on `_initialized`. These four used to be Activity instance
        /// fields, which meant a fresh second instance constructed a fresh
        /// `notifDartReady = false` / `shareDartReady = false` that Dart's
        /// already-drained-once handler would never ask again — so a notification
        /// or share tapped for the rest of that process's life queued into a list
        /// nobody ever collected, and the tap silently did nothing.
        private var notifChannel: MethodChannel? = null
        private val pendingNotifEvents = mutableListOf<Map<String, Any?>>()
        private var notifDartReady = false
        private var shareChannel: MethodChannel? = null
        private var shareDartReady = false
    }

    /// Reuse the process's existing Dart isolate instead of booting a second
    /// one. Returning null (first launch) falls back to the normal path where
    /// the delegate creates the engine; [configureFlutterEngine] then adopts it.
    ///
    /// This is defence in depth for calls. Answering goes through
    /// flutter_callkit_incoming's TransparentActivity, which relaunches us via
    /// `getLaunchIntentForPackage` — and that resolves to whichever
    /// <activity-alias> is currently enabled (see [applyAlternateIcon]), a
    /// different ComponentName than the running instance, which no launchMode
    /// can dedupe. A second MainActivity is therefore always possible; sharing
    /// the engine makes it harmless, because a second CallService in a second
    /// isolate will happily tear down the call the first one is running.
    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(ENGINE_ID)

    /// The isolate outlives any single activity — finishing one must not take
    /// a live call down with it. Also required: attaching a cached engine to a
    /// second activity asserts against hosts that claim engine ownership.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    /// The Dart future waiting on an open runtime-permission dialog, if any.
    /// Held so [onRequestPermissionsResult] can answer it — a MethodChannel
    /// result cannot be completed twice, so this is nulled the moment it is used.
    private var pendingPermissionResult: MethodChannel.Result? = null

    /// Same idea for POST_NOTIFICATIONS, on its own slot — see
    /// NOTIF_PERMISSION_REQUEST.
    private var pendingNotifPermissionResult: MethodChannel.Result? = null

    // notifChannel/pendingNotifEvents/notifDartReady and
    // shareChannel/shareDartReady moved to the companion object above — see the
    // note there for why they must be process-scoped rather than Activity
    // instance fields.

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        val cache = FlutterEngineCache.getInstance()
        if (cache.get(ENGINE_ID) !== flutterEngine) {
            // First activity to see this engine: register the plugins and
            // adopt it for the rest of the process's life.
            super.configureFlutterEngine(flutterEngine)
            cache.put(ENGINE_ID, flutterEngine)
        }

        // The handlers below capture `this`, so they are re-bound on EVERY
        // attach — not just the first. When a second activity takes the engine
        // over, the old activity is evicted and destroyed; handlers still
        // pointing at its window would be talking to a corpse.

        // monkeyhub/screen_share — the mediaProjection foreground service a
        // share needs on Android 14, and its notification's STOP button.
        ScreenShareBridge.register(this, flutterEngine)
        // monkeyhub/draw_mirror — the strokes over a shared screen, painted
        // over other apps while ours is out of sight.
        DrawMirrorBridge.register(this, flutterEngine)
        // monkeyhub/call_window — keep-screen-on and the proximity sensor
        // for the length of a call.
        CallWindowBridge.register(this, flutterEngine)
        // monkeyhub/call_pip — the video call's Picture in Picture window.
        CallPipBridge.register(this, flutterEngine)
        // monkeyhub/call_notification — the ongoing-call notification's mute
        // action and its foreground service's camera type.
        CallNotificationBridge.register(this, flutterEngine)
        // monkeyhub/phone_call — any call ringing or live on the phone; a
        // daily game's clock stops on it.
        PhoneCallBridge.register(this, flutterEngine)
        MapsBridge.register(this, flutterEngine)
        VideoShrink.register(this, flutterEngine)
        // monkeyhub/media_compose — joins and trims the segments of a paused
        // voice or video note.
        MediaCompose.register(this, flutterEngine)

        // monkeyhub/capture — toggles FLAG_SECURE on the window. With
        // FLAG_SECURE set, Android blocks screenshots AND screen-recording at
        // the OS level (the app content shows as black to recorders). No
        // overlay needed on Android.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monkeyhub/capture")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.setFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                    WindowManager.LayoutParams.FLAG_SECURE
                                )
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(null)
                    }
                    "isCaptured" -> {
                        // Android has no equivalent — FLAG_SECURE pre-empts
                        // capture entirely, so we never need to know.
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }

        // monkeyhub/screen — the front camera's "flash" for a video note is
        // the screen itself, white; it only lights a face at full brightness.
        // Overrides this window's brightness, never the system setting, and
        // hands it back when the flash goes off.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monkeyhub/screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setFlashBrightness" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        runOnUiThread {
                            val params = window.attributes
                            params.screenBrightness = if (on) 1f
                                else WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            window.attributes = params
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Stub events channel so the Dart layer's stream listen call is
        // accepted on Android — we just never emit.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "monkeyhub/capture/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    events?.success(false)
                }
                override fun onCancel(arguments: Any?) {}
            })

        // monkeyhub/launcher_icon — swap the home-screen launcher icon by
        // enabling one <activity-alias> in AndroidManifest.xml and disabling
        // the others. Aliases are named `.{themeId}` and target MainActivity.
        // A null iconName re-enables MainActivity (the canonical mark) and
        // disables every alias.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monkeyhub/launcher_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "supportsAlternateIcons" -> result.success(true)
                    "getAlternateIconName" -> result.success(currentAlternateIconName())
                    "setAlternateIconName" -> {
                        val target = call.argument<String>("iconName")  // nil → primary
                        applyAlternateIcon(target)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // monkeyhub/fcm — mirrors the iOS monkeyhub/voip channel (PushKit).
        // Dart calls `getToken` after login; backend uses it to send FCM
        // data-only pushes that wake the app for incoming calls.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monkeyhub/fcm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getToken" -> {
                        FirebaseMessaging.getInstance().token
                            .addOnCompleteListener { task ->
                                if (task.isSuccessful) {
                                    result.success(task.result)
                                } else {
                                    // Null (not an error) keeps Dart's
                                    // refreshTokens() flow silent — same
                                    // contract as a missing iOS PushKit token.
                                    result.success(null)
                                }
                            }
                    }
                    else -> result.notImplemented()
                }
            }

        // monkeyhub/device — exposes a human-readable name for this
        // physical device. Settings.Global.DEVICE_NAME is user-editable
        // on Android 7.1+ (e.g., "Bob's Pixel"); when blank we fall back
        // to Build.MODEL (e.g., "Pixel 7").
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monkeyhub/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDisplayName" -> {
                        val configured = try {
                            Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)
                        } catch (_: Throwable) {
                            null
                        }
                        val name = if (!configured.isNullOrBlank()) configured else Build.MODEL
                        result.success(name)
                    }
                    // Build + display facts for the diagnostics header. Read
                    // once per launch by DeviceReport; never on a hot path.
                    //
                    // The three animation scales, the refresh rate and the
                    // power-save flag are here because they are live suspects
                    // for a strobe that reproduces on exactly one Galaxy: a
                    // variable-refresh panel handing over between modes, a
                    // battery mode that zeroes animation durations, and an OEM
                    // power manager throttling the process all look identical
                    // from Dart, and none of them are visible without this.
                    //
                    // Every lookup is individually guarded — a diagnostics
                    // header with a hole in it beats one that throws.
                    "getBuildInfo" -> {
                        val info = HashMap<String, Any?>()
                        info["sdkInt"] = Build.VERSION.SDK_INT
                        info["release"] = Build.VERSION.RELEASE
                        info["manufacturer"] = Build.MANUFACTURER
                        info["brand"] = Build.BRAND
                        info["model"] = Build.MODEL
                        info["device"] = Build.DEVICE
                        info["hardware"] = Build.HARDWARE
                        info["fingerprint"] = Build.FINGERPRINT

                        info["powerSaveMode"] = try {
                            (getSystemService(POWER_SERVICE) as PowerManager).isPowerSaveMode
                        } catch (_: Throwable) { null }

                        // 0.0 means "animations off", which changes how every
                        // transition in the app behaves.
                        for ((key, setting) in listOf(
                            "animatorScale" to Settings.Global.ANIMATOR_DURATION_SCALE,
                            "transitionScale" to Settings.Global.TRANSITION_ANIMATION_SCALE,
                            "windowScale" to Settings.Global.WINDOW_ANIMATION_SCALE,
                        )) {
                            info[key] = try {
                                Settings.Global.getFloat(contentResolver, setting, 1.0f)
                            } catch (_: Throwable) { null }
                        }

                        info["refreshRate"] = try {
                            display?.refreshRate
                        } catch (_: Throwable) { null }

                        // One UI's version is not on the public SDK. Both known
                        // routes are reflection over vendor internals, so this
                        // is strictly best-effort and must never throw — a null
                        // here just means the header omits one line.
                        info["oneUi"] = try {
                            val f = Build.VERSION::class.java.getDeclaredField("SEM_PLATFORM_INT")
                            val raw = f.getInt(null)
                            // Samsung encodes One UI as 100000 + major*10000 + …
                            if (raw >= 100000) {
                                val v = raw - 90000
                                "${v / 10000}.${(v % 10000) / 100}"
                            } else null
                        } catch (_: Throwable) { null }

                        result.success(info)
                    }
                    // Data and Storage's "uses N% of your free space".
                    "getDiskSpace" -> {
                        val stat = android.os.StatFs(filesDir.path)
                        result.success(
                            hashMapOf(
                                "free" to stat.availableBytes,
                                "total" to stat.totalBytes,
                            )
                        )
                    }
                    // Battery-optimization exemption — OEM power managers
                    // (Xiaomi/Samsung/Oppo…) defer or drop high-priority FCM
                    // for optimized apps, which is fatal for call wakes.
                    // Dart (AndroidCallReliability) checks + prompts once.
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(true)
                        } catch (_: Throwable) {
                            // Some OEM builds hide this screen; fall back to
                            // the generic list so the user can still find us.
                            try {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                                result.success(true)
                            } catch (_: Throwable) {
                                result.success(false)
                            }
                        }
                    }
                    // Mic/camera grants for calling. These are a hard
                    // precondition for showing any native call UI, not a
                    // convenience — see CallPermissions for the crash they
                    // prevent. Dart (CallPermissions in lib/calls/) checks
                    // before starting or ringing a call.
                    "hasCallPermissions" -> {
                        val video = call.argument<Boolean>("video") ?: false
                        result.success(CallPermissions.granted(this, video))
                    }
                    "requestCallPermissions" -> {
                        val video = call.argument<Boolean>("video") ?: false
                        val missing = CallPermissions.missing(this, video)
                        when {
                            missing.isEmpty() -> result.success(true)
                            // One dialog at a time. Stacking requests makes the
                            // framework drop all but the last, which would
                            // strand the earlier Dart futures forever.
                            pendingPermissionResult != null -> result.success(false)
                            else -> {
                                pendingPermissionResult = result
                                ActivityCompat.requestPermissions(
                                    this,
                                    missing.toTypedArray(),
                                    CALL_PERMISSION_REQUEST
                                )
                            }
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(true)
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // monkeyhub/video — play a video in a full-screen ExoPlayer activity
        // with the platform's own transport controls, rather than a Dart
        // re-implementation on top of a bare `video_player` texture. Backs
        // NativeVideoPlayer.
        val videoChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monkeyhub/video")
        videoChannel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // The swipeable gallery. Reports the page it closed on
                    // back over this channel, so Flutter can land there too.
                    "presentGallery" -> {
                        val raw = call.argument<List<Map<String, Any?>>>("items")
                            ?: emptyList()
                        val urls = ArrayList<String>()
                        val kinds = ArrayList<String>()
                        val posters = ArrayList<String>()
                        for (m in raw) {
                            val url = m["url"] as? String ?: continue
                            urls.add(url)
                            kinds.add(m["kind"] as? String ?: "photo")
                            posters.add(m["poster"] as? String ?: "")
                        }
                        if (urls.isEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            VideoGalleryActivity.onClosed = { index ->
                                videoChannel.invokeMethod("galleryClosed", index)
                            }
                            startActivity(
                                Intent(this, VideoGalleryActivity::class.java)
                                    .putStringArrayListExtra(VideoGalleryActivity.EXTRA_URLS, urls)
                                    .putStringArrayListExtra(VideoGalleryActivity.EXTRA_KINDS, kinds)
                                    .putStringArrayListExtra(VideoGalleryActivity.EXTRA_POSTERS, posters)
                                    .putExtra(
                                        VideoGalleryActivity.EXTRA_INDEX,
                                        call.argument<Int>("index") ?: 0
                                    )
                            )
                            result.success(true)
                        } catch (_: Throwable) {
                            VideoGalleryActivity.onClosed = null
                            result.success(false)
                        }
                    }
                    "present" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            startActivity(
                                Intent(this, VideoPlayerActivity::class.java)
                                    .putExtra(VideoPlayerActivity.EXTRA_URL, url)
                                    .putExtra(
                                        VideoPlayerActivity.EXTRA_SECURE,
                                        call.argument<Boolean>("secure") ?: false
                                    )
                            )
                            // Answered on launch, not on the user closing the
                            // player: Dart's only remaining job is to pop the
                            // placeholder route underneath, and this activity
                            // outlives it.
                            result.success(true)
                        } catch (_: Throwable) {
                            // Dart falls back to its own player rather than
                            // showing the user a dead tap.
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // monkeyhub/notifications — mirrors the iOS channel of the same name.
        // Dismissal, the notification permission, and which room is on screen.
        notifChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "monkeyhub/notifications"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "dismiss" -> {
                        val ids = call.argument<List<String>>("ids").orEmpty()
                        val nm = NotificationManagerCompat.from(this)
                        for (id in ids) nm.cancel(id, ChatNotifications.ID)
                        result.success(null)
                    }
                    "dismissRoom" -> {
                        call.argument<String>("roomId")?.let {
                            ChatNotifications.cancelRoom(this, it)
                        }
                        result.success(null)
                    }
                    "setActiveRoom" -> {
                        ChatNotifications.activeRoomId = call.argument<String>("roomId")
                        result.success(null)
                    }
                    "authorizationStatus" -> result.success(notificationAuthorizationStatus())
                    "requestAuthorization" -> requestNotificationPermission(result)
                    "takePendingEvents" -> {
                        notifDartReady = true
                        val events = pendingNotifEvents.toList()
                        pendingNotifEvents.clear()
                        result.success(events)
                    }
                    // The raw `data` maps of chat pushes this device has shown
                    // a notification for, so a room can open already showing
                    // the message instead of asking the network for it. Staged
                    // by ChatNotifications on a process that may since have
                    // died; see its INBOX_DIR doc for why it is files rather
                    // than memory.
                    "takePushInbox" -> result.success(ChatNotifications.takeInbox(this))
                    "clearPushInbox" -> {
                        ChatNotifications.clearInbox(this)
                        result.success(null)
                    }
                    // iOS answers this from its cached APNs token; Android's
                    // equivalent lives on monkeyhub/fcm. Answering null keeps
                    // one Dart code path for both.
                    "getApnsToken" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
        }

        // monkeyhub/share — the system share sheet, both directions.
        //
        // INBOUND: ShareTargetActivity has already copied the shared content
        // into our cache by the time anything reaches here (see ShareIntake),
        // so what crosses this channel is file paths, never bytes.
        //
        // OUTBOUND: the chats the app offers in the sheet's top row. Dart owns
        // WHICH chats and what they are called; this side owns what a shortcut
        // is and what its icon has to look like.
        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "monkeyhub/share"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingShare" -> {
                        // Dart's handler is installed (it just called us), so
                        // everything after this is delivered live.
                        shareDartReady = true
                        result.success(ShareIntake.take())
                    }
                    "publishTargets" -> {
                        val targets = call.argument<List<Map<String, Any?>>>("targets")
                            .orEmpty()
                        val ctx = applicationContext
                        shareWorker.execute { ShareShortcuts.publish(ctx, targets) }
                        result.success(null)
                    }
                    "touchTarget" -> {
                        val raw = call.arguments as? Map<*, *>
                        if (raw != null) {
                            @Suppress("UNCHECKED_CAST")
                            val target = raw as Map<String, Any?>
                            val ctx = applicationContext
                            shareWorker.execute { ShareShortcuts.touch(ctx, target) }
                        }
                        result.success(null)
                    }
                    "clearTargets" -> {
                        val ctx = applicationContext
                        shareWorker.execute { ShareShortcuts.clear(ctx) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // monkeyhub/live_location — the foreground service that keeps a live
        // share publishing off screen, its stoppable notification, and the
        // background-location escalation. Registered through the shared object
        // rather than inline because [LiveLocationService] registers the SAME
        // channel on the headless engine it boots after a reboot, and the STOP
        // button has to reach Dart whichever of the two brought the isolate up.
        LiveLocationBridge.register(flutterEngine, applicationContext)
        // Below Android 11 the background-location prompt is a runtime dialog
        // and needs an activity to show it from. Re-attached on every engine
        // attach, like the handlers above, so a second activity taking the
        // engine over does not leave this pointing at a destroyed window.
        LiveLocationBridge.attachActivity(this)

        // A cold start FROM a notification: the intent is already on the
        // activity by the time the engine is configured.
        handleNotificationIntent(intent)
        handleShareIntent(intent)

        // Anything left in the share staging directory from a previous run.
        // Age-bounded rather than a wipe — see ShareIntake.sweepStaging for
        // why "delete everything now" is not safe here.
        val ctx = applicationContext
        shareWorker.execute { ShareIntake.sweepStaging(ctx) }
    }

    /// Leaving the app with a video call armed for PiP (Android 8-11; 12+
    /// enters on its own). See CallPipBridge.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        CallPipBridge.onUserLeaveHint(this)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        CallPipBridge.onPictureInPictureModeChanged(isInPictureInPictureMode)
    }

    /// A tap while the process is alive. `launchMode="singleTask"` routes it
    /// here rather than through a fresh onCreate.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val extras = intent?.extras ?: return
        val roomId = extras.getString(ChatNotifications.EXTRA_ROOM_ID).orEmpty()
        val kind = extras.getString(ChatNotifications.EXTRA_KIND).orEmpty()
        val momentId = extras.getString(ChatNotifications.EXTRA_MOMENT_ID).orEmpty()
        val focus = extras.getString(ChatNotifications.EXTRA_FOCUS).orEmpty()
        if (roomId.isEmpty() && kind.isEmpty()) return
        // Consume it, or rotating the device replays the same navigation.
        intent.removeExtra(ChatNotifications.EXTRA_ROOM_ID)
        intent.removeExtra(ChatNotifications.EXTRA_KIND)
        intent.removeExtra(ChatNotifications.EXTRA_MOMENT_ID)
        intent.removeExtra(ChatNotifications.EXTRA_FOCUS)

        val event: Map<String, Any?> = when {
            // `focus` rides along rather than branching: "which room" and
            // "what to show once you are in it" are different questions, and
            // making the second a separate method would mean every new
            // destination needs a native release on two platforms. Empty on
            // every ordinary message tap, and Dart treats empty as absent.
            roomId.isNotEmpty() ->
                mapOf("method" to "onOpenRoom", "roomId" to roomId, "focus" to focus)
            kind == "approval" -> mapOf("method" to "onOpenRequests")
            // The daily games nudge: the Feed, with today's games open. It
            // carries no roomId, which is why it falls past the first branch.
            kind == "daily_games" -> mapOf("method" to "onOpenGames")
            // A friend's highlight or point. Opens that card's viewer, so the
            // tap lands on the thing the banner named rather than on the board
            // it happens to be somewhere on. A payload that somehow lost its
            // momentId falls through to the games/else branches rather than
            // invoking with an empty id — Dart would ignore it anyway, and
            // raising the app is the better failure.
            //
            // `focus` rides along here too: "comments" for a comment or reply
            // push, which opens the card with its conversation already up.
            kind == "friend_moment" && momentId.isNotEmpty() ->
                mapOf("method" to "onOpenMoment", "momentId" to momentId, "focus" to focus)
            // A friend's shared game result: the games shelf and its standings.
            kind == "game_result" -> mapOf("method" to "onOpenGames")
            else -> return
        }
        val method = event["method"] as String
        if (notifDartReady) {
            notifChannel?.invokeMethod(method, event)
        } else {
            pendingNotifEvents.add(event)
        }
    }

    /// Hands over a share that [ShareTargetActivity] parked for us.
    ///
    /// Keyed on an extra rather than on "is there anything pending", so a
    /// rotation — which replays the launch intent — cannot resurrect a share
    /// the user has already dealt with. Consumed for the same reason
    /// `handleNotificationIntent` consumes its extras.
    private fun handleShareIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(ShareIntake.EXTRA_HAS_SHARE, false) != true) return
        intent.removeExtra(ShareIntake.EXTRA_HAS_SHARE)
        if (!shareDartReady) return  // waits in ShareIntake for takePendingShare
        val payload = ShareIntake.take() ?: return
        shareChannel?.invokeMethod("onShare", payload)
    }

    private fun notificationAuthorizationStatus(): String {
        // Pre-13 there is no runtime permission; the per-app switch in Settings
        // is the only control, and NotificationManagerCompat reads it.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return if (NotificationManagerCompat.from(this).areNotificationsEnabled()) {
                "granted"
            } else {
                "denied"
            }
        }
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return "granted"
        // Android cannot distinguish "never asked" from "permanently denied"
        // directly. shouldShowRequestPermissionRationale is true only between
        // the two — i.e. asked once and refused — so a false here is either
        // state, and asking is only safe in the first. Dart's own one-ask latch
        // resolves the ambiguity across launches; this keeps us from ever
        // hammering the permanently-denied case.
        return if (ActivityCompat.shouldShowRequestPermissionRationale(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            )
        ) {
            "denied"
        } else {
            "notDetermined"
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
            return
        }
        val perm = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        // Once permanently denied, requestPermissions returns INSTANTLY with no
        // dialog — while still pausing and resuming the activity. That resume
        // is what re-triggers a token refresh, which asks again: the ~30
        // permission flips in 23 seconds seen on a Galaxy S24. Refusing here is
        // what breaks the loop.
        if (ActivityCompat.shouldShowRequestPermissionRationale(this, perm)) {
            result.success(false)
            return
        }
        // One dialog at a time, same contract as the call permissions above.
        if (pendingNotifPermissionResult != null) {
            result.success(false)
            return
        }
        pendingNotifPermissionResult = result
        ActivityCompat.requestPermissions(this, arrayOf(perm), NOTIF_PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        // Plugins (camerax, mobile_scanner, webrtc) share this callback — always
        // let them see it first.
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIF_PERMISSION_REQUEST) {
            val pendingNotif = pendingNotifPermissionResult ?: return
            pendingNotifPermissionResult = null
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            try {
                pendingNotif.success(granted)
            } catch (_: Throwable) {
                // Channel already torn down — nothing left to answer.
            }
            return
        }
        if (requestCode != CALL_PERMISSION_REQUEST) return
        val pending = pendingPermissionResult ?: return
        pendingPermissionResult = null
        // An empty array means the prompt was cancelled, which is a denial. We
        // requested exactly the permissions this call kind needs, so every one
        // of them has to come back granted.
        val allGranted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        try {
            pending.success(allGranted)
        } catch (_: Throwable) {
            // Channel already torn down — nothing left to answer.
        }
    }

    override fun onDestroy() {
        // Never leave a Dart future hanging on a dialog this activity will no
        // longer outlive; a stuck future would wedge the call it gates.
        pendingPermissionResult?.let {
            pendingPermissionResult = null
            try {
                it.success(false)
            } catch (_: Throwable) {
            }
        }
        pendingNotifPermissionResult?.let {
            pendingNotifPermissionResult = null
            try {
                it.success(false)
            } catch (_: Throwable) {
            }
        }
        // Only if it is still us. A second activity may already have taken the
        // engine over and attached itself, and clearing that would leave the
        // live one unable to show the background-location dialog.
        if (LiveLocationBridge.activityIsCurrent(this)) {
            LiveLocationBridge.attachActivity(null)
        }
        super.onDestroy()
    }

    /// Aliases declared in AndroidManifest.xml. Keep in sync with the
    /// <activity-alias> entries and the AppTheme.id values on the Dart side.
    // Keep in sync with the Info.plist CFBundleAlternateIcons keys,
    // the <activity-alias android:name=".$id"> values in AndroidManifest.xml,
    // and `launcherIconNameForThemeId` in lib/services/launcher_icon_names.dart.
    private val aliasIds = listOf(
        "basic", "mh_daylight", "basic_graphite", "basic_rose", "mh_forest",
        "vault_noir", "vault_ivory",
        "risograph_pop", "bio_organic", "cyberpunk",
        "retro_wave", "neon_night", "deep_ocean",
        // Monkey Collection — see lib/widgets/monkey_collection.dart
        "mh_monkey_bubble_head", "mh_monkey_bubble_peek",
        "mh_monkey_bubble_hang", "mh_monkey_neon_hang", "mh_monkey_tail_bubble",
        "mh_monkey_typing", "mh_monkey_ops_tech", "mh_monkey_detective",
        "mh_monkey_safety_spotter", "mh_monkey_control_room",
        "mh_monkey_case_board", "mh_monkey_astronaut", "mh_monkey_hiking",
        "mh_monkey_fields", "mh_monkey_hmm",
    )

    private fun currentAlternateIconName(): String? {
        val pm = packageManager
        for (id in aliasIds) {
            val state = pm.getComponentEnabledSetting(
                ComponentName(packageName, "$packageName.$id")
            )
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return id
        }
        return null
    }

    private fun applyAlternateIcon(requested: String?) {
        val pm = packageManager
        val mainComponent = ComponentName(packageName, "$packageName.MainActivity")

        // An unknown name would otherwise disable MainActivity AND match no
        // alias in the loop below, leaving the package with zero enabled
        // LAUNCHER components — the app vanishes from the home screen and the
        // drawer, with no way back from inside an app the user can no longer
        // start. Treat anything we can't honour as "primary" instead; the
        // canonical icon is always a correct answer.
        val target = if (requested == null || requested in aliasIds) requested else null

        // Enable MainActivity if target is null; otherwise disable it so two
        // launcher entries don't appear.
        //
        // Side effect worth knowing about: while an alias is the enabled
        // launcher entry, `getLaunchIntentForPackage` resolves to THAT
        // component, not `.MainActivity`. flutter_callkit_incoming relaunches
        // us through exactly that call when a call is answered, and its
        // SINGLE_TOP|CLEAR_TOP reuse matches on component name — so a running
        // `.MainActivity` is not found and Android builds a second one. The
        // engine cache in [provideFlutterEngine] is what keeps that survivable;
        // don't remove it.
        pm.setComponentEnabledSetting(
            mainComponent,
            if (target == null) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )

        for (id in aliasIds) {
            val alias = ComponentName(packageName, "$packageName.$id")
            pm.setComponentEnabledSetting(
                alias,
                if (id == target) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }
    }
}
