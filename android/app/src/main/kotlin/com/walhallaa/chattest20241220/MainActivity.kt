package com.walhallaa.chattest20241220

import android.content.ComponentName
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
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /// Arbitrary but must not collide with a plugin's own request codes.
        private const val CALL_PERMISSION_REQUEST = 0x0CA1
    }

    /// The Dart future waiting on an open runtime-permission dialog, if any.
    /// Held so [onRequestPermissionsResult] can answer it — a MethodChannel
    /// result cannot be completed twice, so this is nulled the moment it is used.
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

    private fun applyAlternateIcon(target: String?) {
        val pm = packageManager
        val mainComponent = ComponentName(packageName, "$packageName.MainActivity")

        // Enable MainActivity if target is null; otherwise disable it so two
        // launcher entries don't appear.
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
