package com.hiennv.flutter_callkit_incoming

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.content.ContextCompat

class CallkitIncomingBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallkitIncomingReceiver"

        /// Shared with CallFcmService and CallkitConnectionService so one
        /// `adb logcat -s MHCallRing` shows a ring's whole life.
        const val RING_TAG = "MHCallRing"
        var silenceEvents = false

        // MonkeyHub patch: every intent below carries FLAG_RECEIVER_FOREGROUND.
        // Without it a broadcast to this (manifest) receiver goes through the
        // BACKGROUND broadcast queue, which the system drains behind every
        // other app's background broadcasts and which on a busy Samsung can
        // hold one for seconds. That queue sat between a cancel push and the
        // ringtone it stops. This receiver's work is a few milliseconds, well
        // inside the foreground queue's shorter timeout.

        fun getIntent(context: Context, action: String, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                this.action = "${context.packageName}.${action}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentIncoming(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_INCOMING}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentStart(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_START}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentAccept(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_ACCEPT}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentDecline(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_DECLINE}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentEnded(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_ENDED}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentTimeout(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_TIMEOUT}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentCallback(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_CALLBACK}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentHeldByCell(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_HELD}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentUnHeldByCell(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_UNHELD}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }

        fun getIntentConnected(context: Context, data: Bundle?) =
            Intent().apply {
                setClassName(context.packageName, "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver")
                action = "${context.packageName}.${CallkitConstants.ACTION_CALL_CONNECTED}"
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
                `package` = context.packageName
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }
    }

    // Get notification manager dynamically to handle plugin lifecycle properly
    private fun getCallkitNotificationManager(): CallkitNotificationManager? {
        return FlutterCallkitIncomingPlugin.getInstance()?.getCallkitNotificationManager()
    }

    @SuppressLint("MissingPermission")
    private fun registerTelecomIncomingCall(context: Context, data: Bundle) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val parsed = try {
            Data.fromBundle(data)
        } catch (e: Exception) {
            null
        } ?: return
        if (parsed.id.isEmpty()) return
        if (CallkitConnection.find(parsed.id) != null) {
            Log.d(TAG, "Telecom call already registered id=${parsed.id} — skip")
            return
        }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.MANAGE_OWN_CALLS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "MANAGE_OWN_CALLS not granted — Telecom incoming skipped")
            return
        }
        val telecom = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager ?: return
        val manager = InAppCallManager(context.applicationContext)
        val handle = manager.getPhoneAccountHandle()
        val extras = Bundle().apply {
            putBundle(CallkitConnection.EXTRA_CALL_BUNDLE, data)
            putInt(
                TelecomManager.EXTRA_INCOMING_VIDEO_STATE,
                android.telecom.VideoProfile.STATE_AUDIO_ONLY,
            )
        }
        try {
            telecom.addNewIncomingCall(handle, extras)
            Log.d(TAG, "Telecom addNewIncomingCall id=${parsed.id}")
        } catch (e: SecurityException) {
            Log.w(TAG, "Telecom addNewIncomingCall rejected: ${e.message}")
        } catch (e: Exception) {
            Log.w(TAG, "Telecom addNewIncomingCall error: ${e.message}")
        }
    }

    private fun driveTelecomConnection(context: Context, data: Bundle, action: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val parsed = try {
            Data.fromBundle(data)
        } catch (e: Exception) {
            null
        } ?: return
        val conn = CallkitConnection.find(parsed.id) ?: return
        when (action) {
            CallkitConstants.ACTION_CALL_ACCEPT -> conn.markAccepted()
            // Outgoing call answered by the remote side — drive the dialing
            // connection to active so Telecom treats it as an ongoing call.
            CallkitConstants.ACTION_CALL_CONNECTED -> conn.markAccepted()
            CallkitConstants.ACTION_CALL_DECLINE -> conn.markDeclined(context)
            CallkitConstants.ACTION_CALL_ENDED -> conn.markEnded()
            CallkitConstants.ACTION_CALL_TIMEOUT -> conn.markMissed()
        }
    }


    @SuppressLint("MissingPermission")
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val data = intent.extras?.getBundle(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA) ?: return

        Log.d(TAG, action)

        when (action) {
            "${context.packageName}.${CallkitConstants.ACTION_CALL_INCOMING}" -> {
                try {
                    val incomingData = Data.fromBundle(data)
                    // MonkeyHub patch: never ring a call that already ended
                    // here (its dismissal beat its invite; see
                    // markCallEnded), and never ring one card twice. The
                    // push path and the in-app path can both raise the same
                    // call, and a second INCOMING used to restart the
                    // ringtone and register a SECOND Telecom connection
                    // under the same id, orphaning the first one in
                    // RINGING, which nothing ever ended.
                    if (isCallEnded(context, incomingData.id)) {
                        Log.i(RING_TAG, "INCOMING dropped id=${incomingData.id}: already ended")
                        return
                    }
                    if (getDataActiveCalls(context).any { it.id == incomingData.id }) {
                        Log.i(RING_TAG, "INCOMING dropped id=${incomingData.id}: card already up")
                        return
                    }
                    Log.i(RING_TAG, "INCOMING ring id=${incomingData.id}")
                    registerTelecomIncomingCall(context, data)
                    if (incomingData.isFullScreen) {
                        val intent = CallkitIncomingActivity.getIntent(context, data)
                        context.startActivity(intent)
                    } else {
                        getCallkitNotificationManager()?.showIncomingNotification(data)
                        sendEventFlutter(CallkitConstants.ACTION_CALL_INCOMING, data)
                        addCall(context, incomingData)
                    }
                } catch (error: Exception) {
                    Log.e(TAG, null, error)
                }
            }

            "${context.packageName}.${CallkitConstants.ACTION_CALL_START}" -> {
                try {
                    // MonkeyHub: upstream 3.1.6 registers the outgoing call
                    // with Telecom here (`placeCall`). Not ported: it hands the
                    // audio mode of every outgoing call to Telecom alongside
                    // flutter_webrtc's AudioSwitch, untested on our devices.
                    // start service and show ongoing call when call is accepted
                    CallkitNotificationService.startServiceWithAction(
                        context,
                        CallkitConstants.ACTION_CALL_START,
                        data
                    )
                    sendEventFlutter(CallkitConstants.ACTION_CALL_START, data)
                    addCall(context, Data.fromBundle(data), true)
                } catch (error: Exception) {
                    Log.e(TAG, null, error)
                }
            }

            "${context.packageName}.${CallkitConstants.ACTION_CALL_ACCEPT}" -> {
                try {
                    // MonkeyHub patch: an Accept on a card whose call already
                    // ended (tapped in the instant before the end took it
                    // down) starts no ongoing-call service and tells Dart
                    // nothing, so it can never open an empty call.
                    val acceptedId = Data.fromBundle(data).id
                    if (isCallEnded(context, acceptedId)) {
                        Log.i(RING_TAG, "ACCEPT ignored id=$acceptedId: already ended")
                        getCallkitNotificationManager()?.clearIncomingNotification(data, false)
                        return
                    }
                    driveTelecomConnection(context, data, CallkitConstants.ACTION_CALL_ACCEPT)
                    FlutterCallkitIncomingPlugin.notifyEventCallbacks(CallkitEventCallback.CallEvent.ACCEPT, data)
                    // start service and show ongoing call when call is accepted
                    CallkitNotificationService.startServiceWithAction(
                        context,
                        CallkitConstants.ACTION_CALL_ACCEPT,
                        data
                    )
                    sendEventFlutter(CallkitConstants.ACTION_CALL_ACCEPT, data)
                    addCall(context, Data.fromBundle(data), true)
                    FlutterCallkitIncomingPlugin.acceptCallHandleCallback(data)
                } catch (error: Exception) {
                    Log.e(TAG, null, error)
                }
            }

            "${context.packageName}.${CallkitConstants.ACTION_CALL_DECLINE}" -> {
                try {
                    markCallEnded(context, Data.fromBundle(data).id)
                    driveTelecomConnection(context, data, CallkitConstants.ACTION_CALL_DECLINE)
                    FlutterCallkitIncomingPlugin.notifyEventCallbacks(CallkitEventCallback.CallEvent.DECLINE, data)
                    // clear notification
                    getCallkitNotificationManager()?.clearIncomingNotification(data, false)
                    sendEventFlutter(CallkitConstants.ACTION_CALL_DECLINE, data)
                    removeCall(context, Data.fromBundle(data))
                } catch (error: Exception) {
                    Log.e(TAG, null, error)
                }
            }

            "${context.packageName}.${CallkitConstants.ACTION_CALL_ENDED}" -> {
                try {
                    val endedId = Data.fromBundle(data).id
                    markCallEnded(context, endedId)
                    // MonkeyHub patch: an END that names no card here (a
                    // `taken` push for a call this phone never showed, or
                    // already ended) must not touch a DIFFERENT live call.
                    // The steps below are not scoped to the id: the sound
                    // stop silences whatever is ringing and stopService ends
                    // the ongoing-call service of the call in progress. With
                    // no other call up there is nothing for them to hurt, so
                    // then they still run, as the belt they always were.
                    val active = getDataActiveCalls(context)
                    val others = active.filter { it.id != endedId }
                    val named = others.size != active.size ||
                        (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            CallkitConnection.find(endedId) != null)
                    if (!named && others.isNotEmpty()) {
                        Log.i(RING_TAG, "ENDED id=$endedId names no card; ${others.size} other call(s) left alone")
                        return
                    }
                    Log.i(RING_TAG, "ENDED id=$endedId")
                    driveTelecomConnection(context, data, CallkitConstants.ACTION_CALL_ENDED)
                    FlutterCallkitIncomingPlugin.notifyEventCallbacks(CallkitEventCallback.CallEvent.END, data)
                    // clear notification and stop service
                    getCallkitNotificationManager()?.clearIncomingNotification(data, false)
                    CallkitNotificationService.stopService(context)
                    sendEventFlutter(CallkitConstants.ACTION_CALL_ENDED, data)
                    removeCall(context, Data.fromBundle(data))
                } catch (error: Exception) {
                    Log.e(TAG, null, error)
                }
            }

            "${context.packageName}.${CallkitConstants.ACTION_CALL_TIMEOUT}" -> {
                try {
                    markCallEnded(context, Data.fromBundle(data).id)
                    driveTelecomConnection(context, data, CallkitConstants.ACTION_CALL_TIMEOUT)
                    // clear notification and show miss notification
                    val notificationManager = getCallkitNotificationManager()
                    notificationManager?.clearIncomingNotification(data, false)
                    notificationManager?.showMissCallNotification(data)
                    sendEventFlutter(CallkitConstants.ACTION_CALL_TIMEOUT, data)
                    removeCall(context, Data.fromBundle(data))
                } catch (error: Exception) {
                    Log.e(TAG, null, error)
                }
            }

            "${context.packageName}.${CallkitConstants.ACTION_CALL_CONNECTED}" -> {
                try {
                    driveTelecomConnection(context, data, CallkitConstants.ACTION_CALL_CONNECTED)
                    // update notification on going connected
                    getCallkitNotificationManager()?.showOngoingCallNotification(data, true)
                    sendEventFlutter(CallkitConstants.ACTION_CALL_CONNECTED, data)
                } catch (error: Exception) {
                    Log.e(TAG, null, error)
                }
            }

            "${context.packageName}.${CallkitConstants.ACTION_CALL_CALLBACK}" -> {
                try {
                    getCallkitNotificationManager()?.clearMissCallNotification(data)
                    sendEventFlutter(CallkitConstants.ACTION_CALL_CALLBACK, data)
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        val closeNotificationPanel = Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
                        context.sendBroadcast(closeNotificationPanel)
                    }
                } catch (error: Exception) {
                    Log.e(TAG, null, error)
                }
            }
        }
    }

    private fun sendEventFlutter(event: String, data: Bundle) {
        if (silenceEvents) return

        val android = mapOf(
            "isCustomNotification" to data.getBoolean(
                CallkitConstants.EXTRA_CALLKIT_IS_CUSTOM_NOTIFICATION,
                false
            ),
            "isCustomSmallExNotification" to data.getBoolean(
                CallkitConstants.EXTRA_CALLKIT_IS_CUSTOM_SMALL_EX_NOTIFICATION,
                false
            ),
            "ringtonePath" to data.getString(CallkitConstants.EXTRA_CALLKIT_RINGTONE_PATH, ""),
            "backgroundColor" to data.getString(
                CallkitConstants.EXTRA_CALLKIT_BACKGROUND_COLOR,
                ""
            ),
            "backgroundUrl" to data.getString(CallkitConstants.EXTRA_CALLKIT_BACKGROUND_URL, ""),
            "actionColor" to data.getString(CallkitConstants.EXTRA_CALLKIT_ACTION_COLOR, ""),
            "textColor" to data.getString(CallkitConstants.EXTRA_CALLKIT_TEXT_COLOR, ""),
            "incomingCallNotificationChannelName" to data.getString(
                CallkitConstants.EXTRA_CALLKIT_INCOMING_CALL_NOTIFICATION_CHANNEL_NAME,
                ""
            ),
            "missedCallNotificationChannelName" to data.getString(
                CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_NOTIFICATION_CHANNEL_NAME,
                ""
            ),
            "isImportant" to data.getBoolean(CallkitConstants.EXTRA_CALLKIT_IS_IMPORTANT, true),
            "isBot" to data.getBoolean(CallkitConstants.EXTRA_CALLKIT_IS_BOT, false),
        )
        val missedCallNotification = mapOf(
            "id" to data.getInt(CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_ID),
            "showNotification" to data.getBoolean(CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_SHOW),
            "count" to data.getInt(CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_COUNT),
            "subtitle" to data.getString(CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_SUBTITLE),
            "callbackText" to data.getString(CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_CALLBACK_TEXT),
            "isShowCallback" to data.getBoolean(CallkitConstants.EXTRA_CALLKIT_MISSED_CALL_CALLBACK_SHOW),
        )
        val callingNotification = mapOf(
            "id" to data.getString(CallkitConstants.EXTRA_CALLKIT_CALLING_ID),
            "showNotification" to data.getBoolean(CallkitConstants.EXTRA_CALLKIT_CALLING_SHOW),
            "subtitle" to data.getString(CallkitConstants.EXTRA_CALLKIT_CALLING_SUBTITLE),
            "callbackText" to data.getString(CallkitConstants.EXTRA_CALLKIT_CALLING_HANG_UP_TEXT),
            "isShowCallback" to data.getBoolean(CallkitConstants.EXTRA_CALLKIT_CALLING_HANG_UP_SHOW),
        )
        val forwardData = mapOf(
            "id" to data.getString(CallkitConstants.EXTRA_CALLKIT_ID, ""),
            "nameCaller" to data.getString(CallkitConstants.EXTRA_CALLKIT_NAME_CALLER, ""),
            "avatar" to data.getString(CallkitConstants.EXTRA_CALLKIT_AVATAR, ""),
            "number" to data.getString(CallkitConstants.EXTRA_CALLKIT_HANDLE, ""),
            "type" to data.getInt(CallkitConstants.EXTRA_CALLKIT_TYPE, 0),
            "duration" to data.getLong(CallkitConstants.EXTRA_CALLKIT_DURATION, 0L),
            "textAccept" to data.getString(CallkitConstants.EXTRA_CALLKIT_TEXT_ACCEPT, ""),
            "textDecline" to data.getString(CallkitConstants.EXTRA_CALLKIT_TEXT_DECLINE, ""),
            "acceptColor" to data.getString(CallkitConstants.EXTRA_CALLKIT_ACCEPT_COLOR, ""),
            "declineColor" to data.getString(CallkitConstants.EXTRA_CALLKIT_DECLINE_COLOR, ""),
            "extra" to data.getSerializable(CallkitConstants.EXTRA_CALLKIT_EXTRA),
            "missedCallNotification" to missedCallNotification,
            "callingNotification" to callingNotification,
            "android" to android
        )
        FlutterCallkitIncomingPlugin.sendEvent(event, forwardData)
    }
}
