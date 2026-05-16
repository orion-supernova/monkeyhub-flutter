package com.walhallaa.chattest20241220

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
                        // Firebase disabled — no FCM token available.
                        result.success(null)
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
                    else -> result.notImplemented()
                }
            }
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
