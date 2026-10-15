package com.walhallaa.chattest20241220

import android.app.Activity
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import com.hiennv.flutter_callkit_incoming.CallkitEventCallback
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * `monkeyhub/call_window` — what a phone call does to the screen.
 *
 * Two things every calling app does and this one did not:
 *   - the screen stays on for the whole call (FLAG_KEEP_SCREEN_ON), so a
 *     video call does not dim and lock under the person watching it;
 *   - a voice call at the ear turns the screen off and back on with the
 *     proximity sensor (PROXIMITY_SCREEN_OFF_WAKE_LOCK), so a cheek cannot
 *     mute, hang up or flip the camera.
 *
 * Dart drives it from the call's audio route (`applyAndroidCallRoute` in
 * call_media.dart): `set(keepScreenOn, proximity)` on every route change,
 * `set(false, false)` when the call is torn down. Idempotent, main thread
 * only (method calls already are).
 *
 * The window flag belongs to an activity, and the engine outlives
 * activities (MainActivity caches it), so the flag is re-applied to whichever
 * activity registers next. The wake lock is process-wide and needs none.
 *
 * Neither may outlive the call, and Dart's teardown is not the only guard:
 * a teardown that never runs (a Dart exception, an engine that died with the
 * call) would otherwise blank the screen at every face and keep it lit for
 * good. So the wake lock is held on a [PROXIMITY_TIMEOUT_MS] lease, and a
 * native watchdog renews it every [WATCHDOG_MS] only while the phone is
 * still in a call by its own account: the audio mode, which flutter_webrtc's
 * AudioSwitch (and Telecom) hold at IN_COMMUNICATION for exactly the life of
 * the call's audio. Out of a call for two ticks running, the watchdog drops
 * both and tells Dart (`reset`), so its de-dup does not swallow the next
 * call's state. A native call end (the callkit plugin's END) checks early.
 */
object CallWindowBridge {
    private const val TAG = "MHCallAudio"

    /// The wake lock's lease: long enough that renewing it is rare, short
    /// enough that a lost teardown cannot blank the screen for long.
    private const val PROXIMITY_TIMEOUT_MS = 10 * 60_000L
    private const val WATCHDOG_MS = 30_000L
    /// How soon after a native call end the watchdog takes an early look:
    /// time for Dart's own teardown, and for WebRTC to let the audio go.
    private const val END_CHECK_DELAY_MS = 4_000L

    private var activity: WeakReference<Activity>? = null
    private var appContext: Context? = null
    private var channel: MethodChannel? = null
    private var keepScreenOn = false
    private var proximityWanted = false
    private var proximityLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private var idleTicks = 0
    private var callbackRegistered = false

    private val watchdog = object : Runnable {
        override fun run() = tick()
    }

    private val endCheck = Runnable { tick() }

    /// Held strongly here: the plugin keeps only a weak reference.
    private val callEndCallback = object : CallkitEventCallback {
        override fun onCallEvent(event: CallkitEventCallback.CallEvent, callData: Bundle) {
            if (event != CallkitEventCallback.CallEvent.END) return
            if (!keepScreenOn && !proximityWanted) return
            handler.removeCallbacks(endCheck)
            handler.postDelayed(endCheck, END_CHECK_DELAY_MS)
        }
    }

    fun register(activity: Activity, engine: FlutterEngine) {
        this.activity = WeakReference(activity)
        // The application context, captured here and not in the handler: the
        // channel's handler lives as long as the cached engine, and would
        // otherwise pin the first activity that registered it.
        val context = activity.applicationContext
        appContext = context
        applyKeepScreenOn(activity)
        if (!callbackRegistered) {
            FlutterCallkitIncomingPlugin.registerEventCallback(callEndCallback)
            callbackRegistered = true
        }
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/call_window")
            .also {
                it.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "set" -> {
                            keepScreenOn = call.argument<Boolean>("keepScreenOn") ?: false
                            proximityWanted = call.argument<Boolean>("proximity") ?: false
                            this.activity?.get()?.let { a -> applyKeepScreenOn(a) }
                            setProximity(context, proximityWanted)
                            armWatchdog()
                            Log.i(TAG, "call window keepScreenOn=$keepScreenOn proximity=$proximityWanted")
                            result.success(null)
                        }
                        // The output the call's audio is on right now, for the
                        // in-call speaker button's glyph and the route sheet's
                        // check (lib/calls/call_audio_devices.dart). Read-only:
                        // routing stays flutter_webrtc's AudioSwitch's.
                        "audioOutput" -> result.success(currentOutput(context))
                        else -> result.notImplemented()
                    }
                }
            }
    }

    private fun armWatchdog() {
        handler.removeCallbacks(watchdog)
        idleTicks = 0
        if (keepScreenOn || proximityWanted) handler.postDelayed(watchdog, WATCHDOG_MS)
    }

    /// One watchdog look: renew the lease while the phone is in a call, and
    /// drop everything once it has been out of one for two looks running
    /// (one alone can be a route change that briefly resets the mode).
    private fun tick() {
        handler.removeCallbacks(watchdog)
        val context = appContext ?: return
        if (!keepScreenOn && !proximityWanted) return
        if (inCall(context)) {
            idleTicks = 0
            if (proximityWanted) setProximity(context, true)
        } else if (++idleTicks >= 2) {
            Log.i(TAG, "call window reset: no call audio for ${idleTicks} checks, teardown missed")
            keepScreenOn = false
            proximityWanted = false
            activity?.get()?.let { applyKeepScreenOn(it) }
            setProximity(context, false)
            try {
                channel?.invokeMethod("reset", null)
            } catch (t: Throwable) {
                Log.w(TAG, "call window reset not sent: ${t.message}")
            }
            return
        }
        handler.postDelayed(watchdog, WATCHDOG_MS)
    }

    /// `kind` in AudioSwitch's type names (`earpiece`, `speaker`,
    /// `bluetooth`, `wired-headset`, or `other`) and the device's name.
    /// Android 12+ names the communication device outright; before that the
    /// legacy flags AudioSwitch itself sets are the answer.
    private fun currentOutput(context: Context): Map<String, Any?> {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            ?: return emptyMap()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val device = am.communicationDevice
            if (device != null) {
                val kind = when (device.type) {
                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER_SAFE -> "speaker"
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLE_HEADSET,
                    AudioDeviceInfo.TYPE_BLE_SPEAKER,
                    AudioDeviceInfo.TYPE_HEARING_AID -> "bluetooth"
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_USB_HEADSET -> "wired-headset"
                    else -> "other"
                }
                return mapOf("kind" to kind, "name" to device.productName?.toString())
            }
        }
        @Suppress("DEPRECATION")
        val kind = when {
            am.isSpeakerphoneOn -> "speaker"
            am.isBluetoothScoOn -> "bluetooth"
            am.isWiredHeadsetOn -> "wired-headset"
            else -> "earpiece"
        }
        return mapOf("kind" to kind)
    }

    private fun inCall(context: Context): Boolean {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return true
        val mode = am.mode
        return mode == AudioManager.MODE_IN_COMMUNICATION || mode == AudioManager.MODE_IN_CALL
    }

    private fun applyKeepScreenOn(activity: Activity) {
        if (keepScreenOn) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    /// [on] while held RENEWS the lease: a non-counted lock re-acquired
    /// with a timeout drops its old release and schedules the new one.
    private fun setProximity(context: Context, on: Boolean) {
        val held = proximityLock?.isHeld == true
        if (!on && !held) return
        try {
            if (on) {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) {
                    Log.i(TAG, "no proximity sensor; screen stays as it is")
                    return
                }
                val lock = proximityLock ?: pm.newWakeLock(
                    PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                    "MonkeyHub:CallProximity",
                ).also {
                    it.setReferenceCounted(false)
                    proximityLock = it
                }
                // A lease, not a hold: the watchdog renews it for as long as
                // the call lasts, so a lost teardown costs ten minutes at
                // most. Teardown is `set(false, false)` from Dart.
                lock.acquire(PROXIMITY_TIMEOUT_MS)
            } else {
                // Wait for the phone to leave the ear before lighting the
                // screen, or it lights against a cheek.
                proximityLock?.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "proximity wake lock failed: ${t.message}")
        }
    }
}
