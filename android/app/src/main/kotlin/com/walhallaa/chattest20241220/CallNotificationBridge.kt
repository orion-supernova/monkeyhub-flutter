package com.walhallaa.chattest20241220

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import com.hiennv.flutter_callkit_incoming.CallkitConstants
import com.hiennv.flutter_callkit_incoming.CallkitNotificationManager
import com.hiennv.flutter_callkit_incoming.CallkitNotificationService
import com.hiennv.flutter_callkit_incoming.Data
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import com.hiennv.flutter_callkit_incoming.getDataActiveCalls
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `monkeyhub/call_notification`: what the ongoing-call notification and
 * its foreground service learn from the call itself (Dart's
 * `CallNotificationSync`).
 *
 *  * `setMuted {callId, muted, mute, unmute, connected}`: the notification's
 *    Mute/Unmute action, labelled by the mic's real state, re-posted in
 *    place (vendored callkit plugin, patch I).
 *  * `ensureCamera {callId, connected}`: the camera came on in a call whose
 *    foreground service was started for voice. The service was typed
 *    phoneCall|microphone only, and Android (9+ for an idle app, 11+ under
 *    the while-in-use rules) cuts the camera off as soon as the app leaves
 *    the screen without a camera-typed foreground service. Re-runs
 *    startForeground with the camera type added (plugin patch J). Only
 *    while the app is in front, which is when the camera can come on at
 *    all, and only with the CAMERA grant (Android 14 refuses the type
 *    without it).
 *  * `clear`: the call is over; no mute action on the next one.
 *
 * The call is found in the plugin's own persisted list, by the `callId` in
 * its extra, accepted (or dialled) cards only.
 */
object CallNotificationBridge {
    private const val TAG = "MHCallNotif"

    /// Calls whose service has been widened to the camera, so a later
    /// re-post keeps the video icon.
    private val cameraCalls = HashSet<String>()

    fun register(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/call_notification")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "setMuted" -> {
                            val callId = call.argument<String>("callId")
                            CallkitNotificationManager.ongoingMuteLabel = call.argument<String>("mute")
                            CallkitNotificationManager.ongoingUnmuteLabel = call.argument<String>("unmute")
                            CallkitNotificationManager.ongoingMuted = call.argument<Boolean>("muted")
                            repost(app, callId, call.argument<Boolean>("connected") == true)
                            result.success(null)
                        }
                        "ensureCamera" -> {
                            result.success(
                                ensureCamera(
                                    app,
                                    call.argument<String>("callId"),
                                    call.argument<Boolean>("connected") == true
                                )
                            )
                        }
                        "clear" -> {
                            CallkitNotificationManager.ongoingMuted = null
                            cameraCalls.clear()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "${call.method}: $e")
                    result.success(null)
                }
            }
    }

    private fun findCall(context: Context, callId: String?): Data? {
        if (callId == null) return null
        return getDataActiveCalls(context).lastOrNull {
            it.isAccepted && it.extra["callId"]?.toString() == callId
        }
    }

    private fun bundleFor(data: Data, callId: String): Bundle {
        val b = data.toBundle()
        if (callId in cameraCalls) b.putInt(CallkitConstants.EXTRA_CALLKIT_TYPE, 1)
        return b
    }

    private fun repost(context: Context, callId: String?, connected: Boolean) {
        val data = findCall(context, callId) ?: return
        if (!data.isShowCallingNotification) return
        val manager = FlutterCallkitIncomingPlugin.getInstance()?.getCallkitNotificationManager()
            ?: return
        manager.showOngoingCallNotification(bundleFor(data, callId!!), connected)
    }

    private fun ensureCamera(context: Context, callId: String?, connected: Boolean): Boolean {
        // Camera as a foreground-service type matters from Android 11 (the
        // while-in-use rules); before that the service's existence is enough.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        val data = findCall(context, callId) ?: return false
        // No service was started for this call (its grants were missing at
        // ring time): starting one now is not ours to do.
        if (!data.isShowCallingNotification) return false
        val id = callId!!
        if (data.type > 0 || id in cameraCalls) return true
        cameraCalls.add(id)
        val bundle = bundleFor(data, id)
        bundle.putBoolean(CallkitNotificationService.EXTRA_MONKEYHUB_CONNECTED, connected)
        val intent = Intent(context, CallkitNotificationService::class.java).apply {
            action = CallkitNotificationService.ACTION_REFRESH_FOREGROUND
            putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, bundle)
        }
        return try {
            // Plain startService: the service is already in the foreground,
            // and so is the app (the camera only comes on from the screen).
            context.startService(intent)
            Log.i(TAG, "foreground service widened to the camera for $id")
            true
        } catch (e: Exception) {
            cameraCalls.remove(id)
            Log.w(TAG, "ensureCamera: $e")
            false
        }
    }
}
