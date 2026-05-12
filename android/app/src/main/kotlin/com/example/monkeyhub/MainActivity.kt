package com.example.monkeyhub

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
    }
}
