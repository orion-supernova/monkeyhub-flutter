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
import java.util.UUID

/// Android mirror of the iOS PushKit path in AppDelegate.swift.
///
/// The backend (backend/convex/voipPush.ts sendFcmData) sends data-only,
/// priority-high FCM messages so this service runs even when the app process
/// is dead. Two message kinds, same contract as the iOS VoIP push:
///   kind=invite → show the flutter_callkit_incoming full-screen call UI
///   kind=taken  → dismiss it (answered/rejected elsewhere, cancelled, timeout)
///
/// OneSignal coexistence: OneSignal registers a high-priority FCMBroadcastReceiver
/// (not a FirebaseMessagingService) and filters out its own payloads, so every
/// non-OneSignal message — i.e. ours — flows here. This is the only
/// FirebaseMessagingService in the merged manifest.
class CallFcmService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "CallFcmService"

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
        fun ensureCallkitPlugin(context: Context) {
            if (FlutterCallkitIncomingPlugin.hasInstance()) return
            headlessEngine = FlutterEngine(context.applicationContext)
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        when (data["kind"]) {
            "invite" -> handleInvite(data)
            "taken" -> handleTaken(data)
            else -> Log.d(TAG, "ignoring message kind=${data["kind"]}")
        }
    }

    private fun handleInvite(data: Map<String, String>) {
        val callId = data["callId"] ?: return
        // Foreground app: the Convex realtime subscription rings in-app
        // (IncomingCallScreen) within ~150ms — showing the system UI on top
        // would double-ring. Mirrors the iOS report-and-end escape hatch
        // (AppDelegate.swift:117-123).
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
                        // Matches the backend ring window (60s FCM ttl +
                        // calls.ts CALL_RING_TIMEOUT) — plugin auto-times-out
                        // and posts a missed-call notification after this.
                        "duration" to 60000L,
                        "extra" to hashMapOf<String, Any?>(
                            "callId" to callId,
                            "callerId" to data["callerId"],
                            "roomId" to data["roomId"],
                            "callType" to (data["callType"] ?: "audio"),
                        ),
                    )
                )
                FlutterCallkitIncomingPlugin.getInstance()?.showIncomingNotification(callData)
                    ?: Log.e(TAG, "callkit plugin unavailable — cannot ring $callId")
            } catch (t: Throwable) {
                Log.e(TAG, "showIncomingNotification failed for $callId", t)
            }
        }
    }

    private fun handleTaken(data: Map<String, String>) {
        val callId = data["callId"] ?: return
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

    private fun isAppForeground(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val myPid = android.os.Process.myPid()
        return am.runningAppProcesses?.any {
            it.pid == myPid &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        } ?: false
    }
}
