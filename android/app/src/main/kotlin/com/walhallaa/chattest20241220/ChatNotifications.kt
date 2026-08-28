package com.walhallaa.chattest20241220

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import androidx.exifinterface.media.ExifInterface
import org.json.JSONArray
import java.io.ByteArrayInputStream
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

    /// Where a push's own `data` map is parked for Dart to pick up, under
    /// `filesDir` — one file per message, named by its id.
    ///
    /// One file per message rather than one appended log, because several of
    /// these can be written at once for a burst and a read-modify-write would
    /// race itself. Naming them by message id also makes a repeat delivery
    /// idempotent for free.
    ///
    /// Deliberately NOT written through Dart's `CacheStore`: that debounces a
    /// whole-file rewrite of the room's transcript, so a native appender would
    /// race it and truncate real history — and its directory is a path_provider
    /// implementation detail that has no business being hard-coded here. This
    /// side stores the RAW push map and nothing else; Dart owns what a message
    /// is (see `ChatRepository.takePushedMessages`).
    private const val INBOX_DIR = "push_inbox"

    /// Ceiling on staged files, oldest dropped first. A device that never opens
    /// the app again must not accumulate these forever.
    private const val INBOX_MAX = 100

    /// Park one push for Dart. Best-effort in the strongest sense: this runs
    /// on the way to showing a notification, and nothing about it may prevent
    /// or delay that.
    private fun stageForSeeding(ctx: Context, data: Map<String, String>) {
        if (data["kind"] != "message") return
        val messageId = data["messageId"].orEmpty()
        if (messageId.isEmpty()) return
        try {
            val dir = java.io.File(ctx.filesDir, INBOX_DIR)
            if (!dir.exists() && !dir.mkdirs()) return
            val existing = dir.listFiles()
            if (existing != null && existing.size >= INBOX_MAX) {
                existing.sortedBy { it.lastModified() }
                    .take(existing.size - INBOX_MAX + 1)
                    .forEach { it.delete() }
            }
            val json = org.json.JSONObject()
            for ((k, v) in data) json.put(k, v)
            java.io.File(dir, "$messageId.json").writeText(json.toString())
        } catch (t: Throwable) {
            Log.w(TAG, "could not stage push for seeding: ${t.message}")
        }
    }

    /// Hand Dart everything staged since it last asked, and empty the inbox.
    ///
    /// Destructive: a stub stands in for a round trip that is about to happen,
    /// not for the transcript itself. If the process dies before the live data
    /// lands, these should die with it rather than come back on the next launch
    /// as something indistinguishable from server truth.
    fun takeInbox(ctx: Context): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        try {
            val dir = java.io.File(ctx.filesDir, INBOX_DIR)
            val files = dir.listFiles() ?: return out
            for (f in files.sortedBy { it.lastModified() }) {
                try {
                    val obj = org.json.JSONObject(f.readText())
                    val row = mutableMapOf<String, String>()
                    for (k in obj.keys()) row[k] = obj.optString(k)
                    out.add(row)
                } catch (t: Throwable) {
                    Log.w(TAG, "dropping unreadable staged push: ${t.message}")
                }
                f.delete()
            }
        } catch (t: Throwable) {
            Log.w(TAG, "could not read staged pushes: ${t.message}")
        }
        return out
    }

    /// Clear everything staged, without handing it to anyone.
    ///
    /// For a sign-out: the inbox can only ever hold pushes addressed to the
    /// session that was live when they arrived, and that is the whole of the
    /// account-safety story here — no recipient id needs to travel in the
    /// payload, because ending the session empties the box.
    fun clearInbox(ctx: Context) {
        runCatching { java.io.File(ctx.filesDir, INBOX_DIR).deleteRecursively() }
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

        // Below the suppression check on purpose: a room already on screen has
        // the message from its own subscription, so seeding it would be a
        // stub racing the truth for no gain. Everywhere else this is what lets
        // the room open already showing the message instead of asking the
        // network for something the phone was just told.
        stageForSeeding(ctx, data)

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

    /// Fetches an avatar, bounded and best-effort. Blocking, so it is only
    /// ever called from a worker thread.
    ///
    /// Shared with [ShareShortcuts], which needs the same picture at the same
    /// two-and-a-half-second patience for the same reason: a face that is slow
    /// to load must never hold up the thing it decorates.
    fun fetchAvatar(url: String): Bitmap? {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = AVATAR_FETCH_TIMEOUT_MS
        conn.readTimeout = AVATAR_FETCH_TIMEOUT_MS
        conn.doInput = true
        // Read to bytes rather than decoding the stream directly: the EXIF
        // orientation has to be read from the SAME file the pixels came from,
        // and a socket can only be walked once.
        val bytes = try {
            conn.connect()
            if (conn.responseCode != 200) return null
            conn.inputStream.use { it.readBytes() }
        } finally {
            conn.disconnect()
        }
        return uprightBitmap(bytes)
    }

    /// Longest edge a face is decoded at. A large icon is drawn at ~48dp and
    /// the whole notification has to survive a 1 MB Binder transaction; a
    /// 12-megapixel selfie is neither needed nor affordable here.
    private const val AVATAR_MAX_EDGE = 512

    /// [bytes] decoded and turned the right way up.
    ///
    /// `BitmapFactory` returns the frame exactly as the sensor stored it and
    /// never looks at the EXIF `Orientation` tag — so a portrait photograph
    /// decodes on its side, a quarter turn out, while the same file looks
    /// correct everywhere in the app (Flutter's decoder does read the tag).
    /// That is the whole of the "some people's avatars are rotated" report:
    /// not some people, but every avatar whose bytes still carry an
    /// orientation other than NORMAL.
    ///
    /// The iOS twin of this is `uprightAvatar` in NotificationService.swift,
    /// which has the identical bug for the identical reason on the identical
    /// pictures — the two should stay legible as siblings.
    ///
    /// Internal rather than private: [ShareShortcuts] draws the same faces
    /// from the same URLs into the share sheet's top row.
    fun uprightBitmap(bytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        val longest = maxOf(bounds.outWidth, bounds.outHeight)
        if (longest <= 0) return null
        val opts = BitmapFactory.Options().apply {
            // Powers of two, which is the only thing inSampleSize honours
            // exactly; anything else is rounded down to one anyway.
            var s = 1
            while (longest / (s * 2) >= AVATAR_MAX_EDGE) s *= 2
            inSampleSize = s
        }
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts) ?: return null

        // A file with no EXIF block at all (a PNG, or a JPEG the crop screen
        // re-encoded) reads as NORMAL and costs one parse of the header.
        val orientation = runCatching {
            ByteArrayInputStream(bytes).use {
                ExifInterface(it).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            }
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)

        val m = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                m.postRotate(90f)
                m.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                m.postRotate(270f)
                m.postScale(-1f, 1f)
            }
            // NORMAL, UNDEFINED, and anything a future tag invents.
            else -> return decoded
        }
        return runCatching {
            Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, m, true)
                .also { if (it != decoded) decoded.recycle() }
        }.getOrElse {
            // Out of memory rotating it. Sideways beats faceless.
            Log.w(TAG, "could not rotate avatar: ${it.message}")
            decoded
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
            // The message's own server-minted timestamp, so a burst of pushes
            // that FCM delivered out of order still sorts by when the messages
            // were sent. Same field the push seeds a bubble from.
            .setWhen(data["createdAt"]?.toLongOrNull() ?: System.currentTimeMillis())
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
        //
        // Set for every kind; a chat message replaces it below with the same
        // picture hung off the Person instead, which is where MessagingStyle
        // looks for it.
        if (avatar != null) builder.setLargeIcon(avatar)

        val isGroup = data["isGroup"] == "true"
        val roomName = data["roomName"].orEmpty()

        if (kind == "message") {
            // MessagingStyle, not BigTextStyle + setSubText.
            //
            // The room name USED to ride on `setSubText`, described here as
            // "the closest thing NotificationCompat has to iOS's
            // aps.alert.subtitle: a second line rendered above the message
            // body". That was true on Android 6 and has not been true since
            // Android 7 (API 24) moved subtext into the collapsed HEADER, where
            // it renders as small grey type beside the app name — routinely
            // truncated away entirely by OEM skins. So the answer to "which
            // group is this?" was technically on screen and practically
            // invisible, which is exactly how it was reported.
            //
            // MessagingStyle is the shape every mainstream messenger uses and
            // the one Android is built around: the conversation title becomes
            // the notification's TITLE, and the line under it is attributed to
            // a Person by name rather than being bare text. It also carries
            // the face properly — a Person's icon reaches the conversation
            // surfaces a large icon does not.
            //
            // What it does NOT change is that this is still one notification
            // per message: the tag is the messageId, because that is what
            // makes `dismissIds` able to pull back exactly the banner whose
            // message was deleted. A room's messages therefore stack under
            // the group summary as they always did — each carrying one line,
            // not a transcript.
            val sender = Person.Builder()
                .setName(data["senderName"].orEmpty().ifEmpty { data["title"].orEmpty() })
                // The same key ShareShortcuts hangs its Person off, so the
                // system can tie a donation, a shortcut and this notification
                // together as one conversation.
                .setKey(data["senderId"].orEmpty().ifEmpty { roomId })
                .apply { if (avatar != null) setIcon(IconCompat.createWithBitmap(avatar)) }
                .build()
            // Names the local user for messages WE add to the transcript. We
            // never add any — this notification only ever reports what somebody
            // else said — so it is never rendered; MessagingStyle simply
            // requires a "me" to exist.
            val style = NotificationCompat.MessagingStyle(
                Person.Builder().setName("").build()
            ).addMessage(
                body,
                data["createdAt"]?.toLongOrNull() ?: System.currentTimeMillis(),
                sender,
            )
            // Never set for a DM, whose `roomName` push.ts deliberately omits:
            // in a two-person conversation the sender's name IS the title, and
            // a conversation title as well would say the same thing twice.
            if (isGroup && roomName.isNotEmpty()) {
                style.conversationTitle = roomName
                // Tells the system this is a room rather than a pair, which is
                // what makes it attribute each line to its sender.
                style.isGroupConversation = true
            }
            builder.setStyle(style)
        } else if (isGroup && roomName.isNotEmpty()) {
            // Approvals and call banners keep the plain layout — nobody is
            // "talking" in either, and MessagingStyle would attribute a
            // system announcement to a person. The room still gets named.
            builder.setSubText(roomName)
        }

        val nm = NotificationManagerCompat.from(ctx)
        try {
            nm.notify(tag, ID, builder.build())
            // Android auto-bundles at four; an explicit summary bundles at two,
            // so a room's notifications collapse into one row much sooner.
            if (roomId.isNotEmpty()) {
                // What the COLLAPSED row says. A summary with no title at all
                // renders as a bare app name with nothing under it, which is
                // what a second message in any room used to collapse into.
                val summaryTitle = if (isGroup && roomName.isNotEmpty()) {
                    roomName
                } else {
                    data["senderName"].orEmpty().ifEmpty { data["title"].orEmpty() }
                }
                postSummary(ctx, roomId, channel, summaryTitle)
            }
        } catch (se: SecurityException) {
            // POST_NOTIFICATIONS revoked between the send and now. Nothing to
            // do — the next login re-asks.
            Log.w(TAG, "notify denied: ${se.message}")
        }
    }

    private fun postSummary(
        ctx: Context,
        roomId: String,
        channel: String,
        title: String = "",
    ) {
        val summary = NotificationCompat.Builder(ctx, channel)
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setGroup(roomId)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .setContentIntent(contentIntent(ctx, "message", roomId))
            .setContentTitle(title)
            .setStyle(NotificationCompat.InboxStyle().setBigContentTitle(title))
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
