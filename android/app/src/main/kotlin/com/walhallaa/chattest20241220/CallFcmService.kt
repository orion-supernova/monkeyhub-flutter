package com.walhallaa.chattest20241220

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.hiennv.flutter_callkit_incoming.Data
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import io.flutter.embedding.engine.FlutterEngine
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

/// The single entry point for every push this app receives on Android.
///
/// The backend sends data-only, priority-high FCM messages — never a
/// `notification` block — so this service runs even when the app process is
/// dead, and so WE own the rendering. That ownership is the point: a
/// `notification` payload would be drawn by the system and would skip
/// onMessageReceived entirely while backgrounded, which costs tag collapse,
/// group summaries, per-room dismissal and active-room suppression.
///
/// Six kinds, two families:
///   kind=invite/taken            ringing — flutter_callkit_incoming
///                                (voipPush.ts, mirrors iOS PushKit)
///   kind=message/approval/daily_games/friend_moment/game_result/…
///                                banners — ChatNotifications
///                                (push.ts, mirrors iOS UNNotification)
///
/// The one cost of data-only is that a FORCE-stopped app receives nothing
/// until it is next launched. That was already true of the call path.
class CallFcmService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "CallFcmService"
        private const val RECEIPT_TIMEOUT_MS = 4_000

        // Keeps the plugin singleton (and its notification/sound managers)
        // alive for the accept/decline broadcast receivers that follow a show.
        // The engine never executes Dart — constructing it only runs
        // GeneratedPluginRegistrant, which calls the plugin's
        // onAttachedToEngine → initSharedInstance.
        private var headlessEngine: FlutterEngine? = null

        /// flutter_callkit_incoming requires an RFC-4122 UUID for the call id,
        /// but Convex callIds aren't UUIDs (same constraint handled in
        /// AppDelegate.swift:98-103). Deterministic (v3, name-based) so the
        /// `taken` push — possibly handled in a different process instance —
        /// recomputes the identical id to dismiss the right call.
        fun uuidForCallId(callId: String): String =
            UUID.nameUUIDFromBytes(callId.toByteArray(Charsets.UTF_8)).toString()

        /// The plugin's static singleton is null in a freshly-spawned process
        /// until some engine registers it. MUST be called on the main thread.
        ///
        /// The `hasInstance` guard is also what keeps this from standing up a
        /// third engine alongside MainActivity's cached one: if the UI engine
        /// is alive it has already registered the plugin, so we reuse that
        /// registration rather than building our own.
        fun ensureCallkitPlugin(context: Context) {
            if (FlutterCallkitIncomingPlugin.hasInstance()) return
            headlessEngine = FlutterEngine(context.applicationContext)
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        // Nothing below may take the process with it.
        //
        // This runs with no Activity, no Dart and no user watching, so an
        // escaping exception is not a red screen — it is a silent process
        // death that lands in Play Console as a crash somewhere the user was
        // not, and takes out whatever else the app was doing at the time.
        // Every branch is already best-effort by nature: the worst honest
        // outcome for a push we cannot render is that one notification is
        // missing, which is strictly better than killing the app to say so.
        try {
            dispatch(message)
        } catch (t: Throwable) {
            Log.e(TAG, "push kind=${message.data["kind"]} failed to handle", t)
        }
    }

    private fun dispatch(message: RemoteMessage) {
        val data = message.data
        when (data["kind"]) {
            "invite" -> handleInvite(data)
            "taken" -> handleTaken(data)
            // A group call rings exactly like a 1:1 one. The only difference
            // is which id names the card and where an accept lands, so the
            // two share every line below.
            "group_invite" -> handleInvite(data, groupCallId = data["groupCallId"])
            "group_taken" -> handleTaken(data, groupCallId = data["groupCallId"])
            "message", "approval", "call_invite", "group_call_invite",
            "daily_games", "friend_moment", "game_result" -> {
                ChatNotifications.show(this, data)
                // After the banner, never before it: the second tick is not
                // worth a moment of the message itself.
                if (data["kind"] == "message") reportDelivery(data)
            }
            "dismiss" -> ChatNotifications.dismiss(this, data)
            else -> Log.d(TAG, "ignoring message kind=${data["kind"]}")
        }
    }

    /// Ring for an incoming call.
    ///
    /// [groupCallId] non-null marks a GROUP invite, whose id is the group
    /// call rather than a 1:1 `calls` row. It rides into the card's `extra`
    /// so `NativeCallHandler` knows to answer it with
    /// `GroupCallService.joinCall` instead of `CallService.acceptIncoming` —
    /// the two are not interchangeable and the plugin has no idea which is
    /// which.
    private fun handleInvite(data: Map<String, String>, groupCallId: String? = null) {
        val callId = groupCallId ?: data["callId"] ?: return
        // Foreground app: the Convex realtime subscription rings in-app
        // (IncomingCallScreen / IncomingGroupCallScreen) within ~150ms —
        // showing the system UI on top would double-ring. Mirrors the iOS
        // report-and-end escape hatch (AppDelegate.swift:117-123).
        if (isAppForeground()) {
            Log.d(TAG, "invite $callId while foreground — in-app path handles it")
            return
        }
        val callerName = data["callerName"] ?: "Unknown"
        val isVideo = data["callType"] == "video"
        Handler(Looper.getMainLooper()).post {
            try {
                ensureCallkitPlugin(this)
                val callData = Data(
                    mapOf(
                        "id" to uuidForCallId(callId),
                        "nameCaller" to callerName,
                        "appName" to "MonkeyHub",
                        "avatar" to (data["callerAvatarUrl"] ?: ""),
                        "handle" to (data["callerHandle"] ?: callerName),
                        "type" to if (isVideo) 1 else 0,
                        // The card's own end, should every dismissal miss
                        // it: the backend's ring window plus the `taken`
                        // grace and some slack (calls.ts rings a 1:1 call
                        // for 30s, groupCalls.ts a group invite for 60s).
                        // It used to be 60s for both, so a 1:1 ring whose
                        // dismissal was lost rang twice as long as the call
                        // existed. Mirrors NativeCallHandler.showIncoming.
                        "duration" to if (groupCallId != null) 65000L else 40000L,
                        // Whether the plugin may run its ongoing-call foreground
                        // service once this call is answered. It types that
                        // service microphone (+camera for video), which on
                        // Android 14 throws SecurityException out of
                        // Service.onStartCommand — killing the process — if the
                        // grant is missing. The Accept tap starts that service
                        // directly from the plugin's broadcast receiver, so this
                        // flag, persisted with the call now, is the ONLY point
                        // of control on the killed-app path: no Dart exists here
                        // to check anything later. Mirrors
                        // NativeCallHandler.showIncoming on the foreground path.
                        "callingNotification" to mapOf(
                            "showNotification" to
                                CallPermissions.granted(applicationContext, isVideo),
                        ),
                        "extra" to hashMapOf<String, Any?>(
                            "callId" to callId,
                            "callerId" to data["callerId"],
                            "roomId" to data["roomId"],
                            "callType" to (data["callType"] ?: "audio"),
                        ).apply {
                            // PUT, not a null entry: absence is the
                            // discriminant Dart reads, and this way a 1:1
                            // card cannot carry the key in any form at all.
                            if (groupCallId != null) put("groupCallId", groupCallId)
                        },
                    )
                )
                val plugin = FlutterCallkitIncomingPlugin.getInstance()
                if (plugin == null) {
                    Log.e(TAG, "callkit plugin unavailable — cannot ring $callId")
                } else {
                    plugin.showIncomingNotification(callData)
                    // A group ring carries no proof; reportRinging is a
                    // no-op for it. Off the main thread: it blocks on I/O.
                    Thread { reportRinging(data) }.start()
                }
            } catch (t: Throwable) {
                Log.e(TAG, "showIncomingNotification failed for $callId", t)
            }
        }
    }

    /// End a ringing card. [groupCallId] non-null names a GROUP call, whose
    /// card was raised under the id derived from it rather than from a
    /// `calls` row — see [uuidForCallId], which both sides compute.
    private fun handleTaken(data: Map<String, String>, groupCallId: String? = null) {
        val callId = groupCallId ?: data["callId"] ?: return
        Handler(Looper.getMainLooper()).post {
            try {
                ensureCallkitPlugin(this)
                // End unconditionally: the deterministic UUID scopes this to
                // exactly the pushed call, and ending an id that was never
                // shown is a no-op. Checking getDataActiveCalls first would
                // race a `taken` that lands before the invite broadcast has
                // persisted the call — leaving a stuck ringer.
                FlutterCallkitIncomingPlugin.getInstance()
                    ?.endCall(Data(mapOf("id" to uuidForCallId(callId))))
            } catch (t: Throwable) {
                Log.e(TAG, "endCall failed for $callId", t)
            }
        }
    }

    // Token rotation while the app is killed: nothing to do here — the Dart
    // side re-fetches and re-uploads via PushManager.refreshTokens() on every
    // login and app-resume, which is the same self-heal used for iOS PushKit.
    override fun onNewToken(token: String) {
        Log.d(TAG, "FCM token rotated; will re-upload on next app resume/login")
    }

    /// Tells the sender's server this message is on this phone — the second
    /// tick, with no Activity and no Dart running.
    ///
    /// The push carries a proof signed for this recipient and this message
    /// (`rcptUrl`/`rcptUser`/`rcptSig`, see backend/convex/receiptToken.ts);
    /// this echoes it back. The signature is the whole of the authentication,
    /// so there is no session to hold here. A push without the fields — an
    /// older backend, or the feature switched off — sends nothing. The iOS
    /// twin is `reportDelivery` in NotificationService.swift.
    ///
    /// Blocking is fine: `onMessageReceived` runs on a worker thread with a
    /// budget of several seconds, and returning is what lets the process go.
    /// Every failure is swallowed; the app reports delivery again when it
    /// next opens.
    private fun reportDelivery(data: Map<String, String>) {
        val url = data["rcptUrl"] ?: return
        val body = JSONObject()
            .put("roomId", data["roomId"] ?: return)
            .put("userId", data["rcptUser"] ?: return)
            .put("createdAt", data["createdAt"] ?: return)
            .put("sig", data["rcptSig"] ?: return)
            .toString()
            .toByteArray(Charsets.UTF_8)
        try {
            val conn = URL(url).openConnection() as HttpURLConnection
            try {
                conn.requestMethod = "POST"
                conn.connectTimeout = RECEIPT_TIMEOUT_MS
                conn.readTimeout = RECEIPT_TIMEOUT_MS
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setFixedLengthStreamingMode(body.size)
                conn.outputStream.use { it.write(body) }
                conn.responseCode
            } finally {
                conn.disconnect()
            }
        } catch (t: Throwable) {
            Log.d(TAG, "delivery receipt not sent: ${t.message}")
        }
    }

    /// Tells the caller's server this phone is ringing: the ring proof the
    /// invite push carries (`ringUrl`/`ringUser`/`ringSig`, signed in
    /// backend/convex/receiptToken.ts), posted once the card is up. The
    /// caller's screen goes from "calling" to "ringing" and the ringback
    /// starts. A foregrounded app never gets here: it rings from Dart, which
    /// reports through `calls:markRinging` instead. The iOS twin is
    /// `reportRinging` in AppDelegate.swift. Failures are swallowed: a lost
    /// report costs the caller the ringback, never the call.
    private fun reportRinging(data: Map<String, String>) {
        val url = data["ringUrl"] ?: return
        val body = JSONObject()
            .put("callId", data["callId"] ?: return)
            .put("userId", data["ringUser"] ?: return)
            .put("sig", data["ringSig"] ?: return)
            .toString()
            .toByteArray(Charsets.UTF_8)
        try {
            val conn = URL(url).openConnection() as HttpURLConnection
            try {
                conn.requestMethod = "POST"
                conn.connectTimeout = RECEIPT_TIMEOUT_MS
                conn.readTimeout = RECEIPT_TIMEOUT_MS
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setFixedLengthStreamingMode(body.size)
                conn.outputStream.use { it.write(body) }
                conn.responseCode
            } finally {
                conn.disconnect()
            }
        } catch (t: Throwable) {
            Log.d(TAG, "ring report not sent: ${t.message}")
        }
    }

    private fun isAppForeground(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val myPid = android.os.Process.myPid()
        return am.runningAppProcesses?.any {
            it.pid == myPid &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        } ?: false
    }
}
