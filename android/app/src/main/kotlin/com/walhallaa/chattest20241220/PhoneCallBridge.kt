package com.walhallaa.chattest20241220

import android.content.Context
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `monkeyhub/phone_call` — whether any call is up on this phone: ringing,
 * connected, ours or the carrier's.
 *
 * Read from the audio mode, which needs no permission (READ_PHONE_STATE would,
 * and would only see carrier calls): Telecom holds it at RINGTONE while a call
 * rings and IN_CALL / IN_COMMUNICATION for the life of a call's audio, VoIP
 * apps included. Anything but NORMAL counts.
 *
 * A heads-up incoming call, answered from the notification, never takes the
 * activity out of the foreground, so Flutter's lifecycle cannot see it. Dart
 * asks `active` once and then hears `changed(Boolean)` on every edge, which
 * the mode listener reports on Android 12+. Older versions answer `active`
 * only.
 */
object PhoneCallBridge {
    private var channel: MethodChannel? = null
    private var last: Boolean? = null
    private var listener: Any? = null

    fun register(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        val am = app.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/phone_call")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "active" -> {
                    val now = am?.let { inCall(it) } ?: false
                    last = now
                    result.success(now)
                }
                else -> result.notImplemented()
            }
        }
        // Process-wide, and the engine outlives activities: added once.
        if (am != null && listener == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val l = AudioManager.OnModeChangedListener { _ ->
                val now = inCall(am)
                if (now != last) {
                    last = now
                    try {
                        channel?.invokeMethod("changed", now)
                    } catch (_: Throwable) {
                        // Engine gone; the next attach re-asks `active`.
                    }
                }
            }
            am.addOnModeChangedListener(app.mainExecutor, l)
            listener = l
        }
    }

    private fun inCall(am: AudioManager): Boolean = am.mode > AudioManager.MODE_NORMAL
}
