package com.walhallaa.chattest20241220

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
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

        /// Cache key for the one and only Dart isolate this process runs.
        const val ENGINE_ID = "monkeyhub.main"
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
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        // Plugins (camerax, mobile_scanner, webrtc) share this callback — always
        // let them see it first.
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
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
        "mh_monkey_hmm", "mh_monkey_fields", "mh_monkey_hiking", "mh_monkey_astronaut",
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
