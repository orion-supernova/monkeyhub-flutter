package com.walhallaa.chattest20241220

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

/// Renders the notifications that used to come from a push SDK.
///
/// The backend sends data-only FCM messages (see backend/convex/push.ts) and
/// everything visible is built here, which is what makes collapse, grouping,
/// per-room dismissal and foreground suppression possible at all.
///
/// The payload keys are a cross-language contract shared with push.ts,
/// AppDelegate.swift and web/mh-push-sw.js. Renaming one here breaks a
/// platform you are not looking at; test/push_payload_contract_test.dart pins
/// them.
object ChatNotifications {

    private const val TAG = "ChatNotifications"

    /// Channel ids. A channel's importance and sound are IMMUTABLE once
    /// created — the OS ignores any later change — so these are new ids rather
    /// than reused ones, and a user who had specifically muted the old push
    /// SDK's channel will hear these until they mute them too. There is no API
    /// to inherit that setting.
    const val CH_MESSAGES = "mh_messages"
    const val CH_REQUESTS = "mh_requests"
    const val CH_CALLS = "mh_call_banner"
    const val CH_GAMES = "mh_games"

    /// Every notification shares one id and is distinguished by TAG instead.
    /// (tag, id) is the identity NotificationManager uses, so a tag of
    /// messageId gives exactly APNs collapse-id semantics: re-posting replaces,
    /// and cancel(tag, id) targets one notification precisely.
    ///
    /// Internal rather than private because MainActivity cancels by (tag, id)
    /// too, and a second hardcoded 1 over there would be a silent no-op the day
    /// this changes.
    const val ID = 1

    /// The room currently on screen, pushed down from Dart via the
    /// monkeyhub/notifications channel. Suppresses a banner for a conversation
    /// the user is already reading — the Android half of iOS's willPresent.
    @Volatile
    @JvmStatic
    var activeRoomId: String? = null

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return

        // Leftovers from the previous push SDK. Deleting them stops dead
        // toggles appearing in the system Settings list, where flipping them
        // would do nothing.
        for (dead in listOf("fcm_fallback_notification_channel", "OS_default", "OS_miscellaneous")) {
            runCatching { nm.deleteNotificationChannel(dead) }
        }

        nm.createNotificationChannel(
            NotificationChannel(
                CH_MESSAGES,
                "Messages",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "New messages in your rooms" }
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CH_REQUESTS,
                "Requests & approvals",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "Friend requests and things waiting on your OK" }
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CH_GAMES,
                "Daily games",
                // DEFAULT, not HIGH. This is the one notification nobody's
                // action produced, and it arrives every day — it belongs in the
                // shade, not over whatever the person was doing. The separate
                // channel matters more than the importance does: it is what
                // lets somebody silence the daily reminder from the system
                // settings without silencing their messages, which is the same
                // promise the in-app switch makes.
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "A reminder to play today's puzzle and boards" }
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CH_CALLS,
                "Call alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Incoming call banners"
                // The ringing UI itself belongs to flutter_callkit_incoming and
                // has its own channels; this is only the tap-to-join banner.
            }
        )
    }

    /// Longest this will block a background thread fetching the sender's
    /// avatar before giving up and posting without one. `onMessageReceived`
    /// itself is never blocked (see below) — this only bounds how late a
    /// banner can land relative to a text-only one.
    private const val AVATAR_FETCH_TIMEOUT_MS = 2_500

    fun show(ctx: Context, data: Map<String, String>) {
        ensureChannels(ctx)
        val kind = data["kind"] ?: return
        val roomId = data["roomId"].orEmpty()

        // Already reading this room in the foreground — the live subscription
        // has the message on screen before this push arrived.
        if (roomId.isNotEmpty() && roomId == activeRoomId && isAppForeground(ctx)) {
            Log.d(TAG, "suppressing $kind for active room $roomId")
            return
        }

        val avatarUrl = data["senderAvatarUrl"].orEmpty()
        if (avatarUrl.isEmpty()) {
            post(ctx, kind, roomId, data, avatar = null)
            return
        }
        // `onMessageReceived` calls this on the main thread, so a blocking
        // fetch has to happen off it — a real network call there risks an
        // ANR, not just a slow banner. Bounded and best-effort: the message
        // itself must never wait on a face that fails to load in time, the
        // way the banner text would if this were synchronous up top.
        Thread {
            val avatar = runCatching { fetchAvatar(avatarUrl) }
                .onFailure { Log.w(TAG, "avatar fetch failed: ${it.message}") }
                .getOrNull()
            post(ctx, kind, roomId, data, avatar)
        }.start()
    }

    private fun fetchAvatar(url: String): Bitmap? {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = AVATAR_FETCH_TIMEOUT_MS
        conn.readTimeout = AVATAR_FETCH_TIMEOUT_MS
        conn.doInput = true
        return try {
            conn.connect()
            if (conn.responseCode != 200) return null
            conn.inputStream.use { BitmapFactory.decodeStream(it) }
        } finally {
            conn.disconnect()
        }
    }

    private fun post(
        ctx: Context,
        kind: String,
        roomId: String,
        data: Map<String, String>,
        avatar: Bitmap?,
    ) {
        val channel = when (kind) {
            "approval" -> CH_REQUESTS
            "call_invite", "group_call_invite" -> CH_CALLS
            "daily_games" -> CH_GAMES
            else -> CH_MESSAGES
        }
        val tag = data["collapseId"]?.takeIf { it.isNotEmpty() }
            ?: roomId.takeIf { it.isNotEmpty() }
            ?: kind

        val pi = contentIntent(ctx, kind, roomId) ?: return
        val body = data["body"].orEmpty()

        val builder = NotificationCompat.Builder(ctx, channel)
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(data["title"].orEmpty())
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setPriority(
                if (channel == CH_GAMES) NotificationCompat.PRIORITY_DEFAULT
                else NotificationCompat.PRIORITY_HIGH
            )
            .setCategory(
                when (channel) {
                    CH_CALLS -> NotificationCompat.CATEGORY_CALL
                    // Not CATEGORY_MESSAGE: nobody sent this, and miscategorising
                    // it puts a daily broadcast in the same bucket Do Not Disturb
                    // rules and conversation surfaces treat as people talking.
                    CH_GAMES -> NotificationCompat.CATEGORY_REMINDER
                    else -> NotificationCompat.CATEGORY_MESSAGE
                }
            )
        if (roomId.isNotEmpty()) builder.setGroup(roomId)
        // Sender's face, WhatsApp/Telegram-style. Most launchers/OEM skins
        // mask a large icon into a circle the same way they do a contact
        // photo; that's system chrome, not something drawn here.
        if (avatar != null) builder.setLargeIcon(avatar)
        // The room name under the sender's name for a GROUP message — never
        // set for a DM, whose `roomName` push.ts deliberately omits. `setSubText`
        // is the closest thing NotificationCompat has to iOS's `aps.alert.subtitle`:
        // a second line rendered above the message body.
        if (data["isGroup"] == "true") {
            data["roomName"]?.takeIf { it.isNotEmpty() }?.let { builder.setSubText(it) }
        }

        val nm = NotificationManagerCompat.from(ctx)
        try {
            nm.notify(tag, ID, builder.build())
            // Android auto-bundles at four; an explicit summary bundles at two,
            // so a room's notifications collapse into one row much sooner.
            if (roomId.isNotEmpty()) postSummary(ctx, roomId, channel)
        } catch (se: SecurityException) {
            // POST_NOTIFICATIONS revoked between the send and now. Nothing to
            // do — the next login re-asks.
            Log.w(TAG, "notify denied: ${se.message}")
        }
    }

    private fun postSummary(ctx: Context, roomId: String, channel: String) {
        val summary = NotificationCompat.Builder(ctx, channel)
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setGroup(roomId)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .setContentIntent(contentIntent(ctx, "message", roomId))
            .setStyle(NotificationCompat.InboxStyle())
            .build()
        runCatching {
            NotificationManagerCompat.from(ctx).notify(summaryTag(roomId), ID, summary)
        }
    }

    fun dismiss(ctx: Context, data: Map<String, String>) {
        val nm = NotificationManagerCompat.from(ctx)
        val roomId = data["roomId"].orEmpty()
        val ids = parseIds(data["dismissIds"])
        if (ids.isNotEmpty()) {
            for (id in ids) nm.cancel(id, ID)
        } else if (roomId.isNotEmpty()) {
            cancelRoom(ctx, roomId)
        }
        if (roomId.isNotEmpty()) reconcileSummary(ctx, roomId)
    }

    /// Clear every notification for one room. Backs
    /// PushManager.dismissRoomNotifications, and is what the whole-room
    /// dismiss push does when it carries no explicit id list.
    fun cancelRoom(ctx: Context, roomId: String) {
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        for (sb in nm.activeNotifications.orEmpty()) {
            if (sb.notification.group == roomId) nm.cancel(sb.tag, sb.id)
        }
    }

    /// Drop a group summary once nothing is left under it, or it lingers as a
    /// row that expands into nothing.
    private fun reconcileSummary(ctx: Context, roomId: String) {
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        val tag = summaryTag(roomId)
        val remaining = nm.activeNotifications.orEmpty().count {
            it.notification.group == roomId && it.tag != tag
        }
        if (remaining == 0) nm.cancel(tag, ID)
    }

    private fun summaryTag(roomId: String) = "summary:$roomId"

    private fun parseIds(raw: String?): List<String> {
        // A JSON string rather than an array, because FCM v1 data values are
        // all strings. iOS parses the identical encoding.
        if (raw.isNullOrEmpty()) return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }
        }.getOrElse {
            Log.w(TAG, "bad dismissIds: $raw")
            emptyList()
        }
    }

    private fun contentIntent(ctx: Context, kind: String, roomId: String): PendingIntent? {
        // MUST resolve the launcher intent rather than naming MainActivity
        // explicitly: applyAlternateIcon disables .MainActivity whenever an
        // <activity-alias> is the active launcher entry, and an explicit intent
        // to a disabled component throws. Same reason flutter_callkit_incoming
        // does it this way.
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        if (launch == null) {
            Log.e(TAG, "no launch intent for ${ctx.packageName}")
            return null
        }
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        launch.putExtra(EXTRA_KIND, kind)
        launch.putExtra(EXTRA_ROOM_ID, roomId)
        return PendingIntent.getActivity(
            ctx,
            // Per-room request code. With one shared code, FLAG_UPDATE_CURRENT
            // makes every room's tap open whichever room was notified last.
            if (roomId.isEmpty()) kind.hashCode() else roomId.hashCode(),
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun isAppForeground(ctx: Context): Boolean {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return false
        val myPid = android.os.Process.myPid()
        return am.runningAppProcesses?.any {
            it.pid == myPid &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        } ?: false
    }

    const val EXTRA_KIND = "mh.notif.kind"
    const val EXTRA_ROOM_ID = "mh.notif.roomId"
}
