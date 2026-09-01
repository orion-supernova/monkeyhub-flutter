package com.walhallaa.chattest20241220

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `monkeyhub/screen_share` — Dart's handle on [ScreenShareService], and the
 * service's way back to Dart when the notification's STOP is pressed.
 *
 * Re-bound on every engine attach like the other channels in
 * [MainActivity.configureFlutterEngine]; the channel is held statically so the
 * service — which has no activity — can reach it.
 */
object ScreenShareBridge {
    private var channel: MethodChannel? = null

    fun register(ctx: Context, engine: FlutterEngine) {
        val app = ctx.applicationContext
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/screen_share")
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ScreenShareService.start(
                        app,
                        call.argument<String>("title").orEmpty(),
                        call.argument<String>("body").orEmpty(),
                        call.argument<String>("stop") ?: "Stop",
                    )
                    result.success(null)
                }
                "stop" -> {
                    ScreenShareService.stop(app)
                    result.success(null)
                }
                "isSupported" -> result.success(true)
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    /** True when a Dart side was there to hear it. */
    fun reportUserStop(): Boolean {
        val ch = channel ?: return false
        Handler(Looper.getMainLooper()).post { ch.invokeMethod("onUserStop", null) }
        return true
    }
}
