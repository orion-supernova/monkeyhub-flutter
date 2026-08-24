package com.walhallaa.chattest20241220

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.util.Log
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

/// The chats the app offers in the share sheet's top row.
///
/// This is Android's Sharing Shortcuts API: a dynamic shortcut whose id is the
/// room id, categorised to match the `<share-target>` in
/// `res/xml/share_targets.xml`. When one is tapped the system delivers the
/// ordinary `ACTION_SEND` to [ShareTargetActivity] with
/// `ShortcutManagerCompat.EXTRA_SHORTCUT_ID` set — which is how a share arrives
/// already knowing which chat it is for.
///
/// The same shortcuts show up under a long-press on the launcher icon, which is
/// free and is why their [Intent] opens the room rather than just the app.
object ShareShortcuts {

    private const val TAG = "ShareShortcuts"

    /// Must match the `<category>` inside `<share-target>`. A shortcut without
    /// it is a launcher shortcut and nothing else — it silently never appears
    /// in a share sheet, with no error anywhere.
    const val CATEGORY = "com.walhallaa.chattest20241220.category.SHARE_TARGET"

    /// Adaptive-icon bitmaps are masked by the launcher, so the drawing is
    /// full-bleed and the safe zone is the middle ~72/108. 216px is two
    /// device-independent icons' worth, which is enough for every density the
    /// share sheet renders at without holding a megabyte per chat.
    private const val ICON_PX = 216

    /// Replaces the published set with [targets], in order.
    ///
    /// `setDynamicShortcuts` rather than repeated pushes: the list IS the
    /// answer, and a chat the user left has to stop being offered rather than
    /// linger until something evicts it.
    fun publish(ctx: Context, targets: List<Map<String, Any?>>) {
        val max = ShortcutManagerCompat.getMaxShortcutCountPerActivity(ctx)
            .coerceAtLeast(1)
        val infos = targets.take(max).mapIndexedNotNull { index, raw ->
            build(ctx, raw, rank = index)
        }
        runCatching {
            ShortcutManagerCompat.setDynamicShortcuts(ctx, infos)
        }.onFailure { Log.w(TAG, "setDynamicShortcuts failed: ${it.message}") }
    }

    /// Bumps one chat, without disturbing the rest of the list.
    ///
    /// `pushDynamicShortcut` is the API that exists precisely for "the user
    /// just used this": it re-ranks, and when the list is full it evicts the
    /// least-recently-used one itself rather than refusing.
    fun touch(ctx: Context, raw: Map<String, Any?>) {
        val info = build(ctx, raw, rank = 0) ?: return
        runCatching {
            ShortcutManagerCompat.pushDynamicShortcut(ctx, info)
        }.onFailure { Log.w(TAG, "pushDynamicShortcut failed: ${it.message}") }
    }

    /// Sign-out. Removes the dynamic shortcuts AND asks the launcher to retire
    /// any the user pinned to their home screen — those name a person and a
    /// chat, and a pinned tile that survives a sign-out is somebody else's
    /// contact list sitting on the home screen.
    fun clear(ctx: Context) {
        runCatching {
            ShortcutManagerCompat.removeAllDynamicShortcuts(ctx)
            val pinned = ShortcutManagerCompat.getShortcuts(
                ctx, ShortcutManagerCompat.FLAG_MATCH_PINNED
            ).map { it.id }
            if (pinned.isNotEmpty()) {
                ShortcutManagerCompat.disableShortcuts(ctx, pinned, null)
            }
        }.onFailure { Log.w(TAG, "clear failed: ${it.message}") }
    }

    private fun build(ctx: Context, raw: Map<String, Any?>, rank: Int): ShortcutInfoCompat? {
        val id = raw["id"] as? String ?: return null
        if (id.isEmpty()) return null
        val title = (raw["title"] as? String)?.takeIf { it.isNotBlank() } ?: id

        // Opens the room when tapped from the launcher's long-press menu. The
        // extras are ChatNotifications', so the room-open path in MainActivity
        // needs no second shape to understand.
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            ?: return null
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        launch.putExtra(ChatNotifications.EXTRA_ROOM_ID, id)

        val person = Person.Builder()
            .setName(title)
            // The key is what lets the system tie a donation, a notification
            // and a shortcut together as one conversation.
            .setKey(id)
            .setBot(false)
            .build()

        return ShortcutInfoCompat.Builder(ctx, id)
            .setShortLabel(title)
            .setLongLabel(title)
            .setIcon(icon(ctx, raw, title))
            .setIntent(launch)
            .setRank(rank)
            // Both are mandatory for direct share, and each fails silently on
            // its own: without the category the system does not consider this a
            // share target, and without long-lived it may not cache it long
            // enough to offer.
            .setCategories(setOf(CATEGORY))
            .setLongLived(true)
            .setPerson(person)
            .build()
    }

    /// The avatar, or the app's own gradient-and-initial fallback.
    ///
    /// Drawn here rather than handed over as pixels because an adaptive icon is
    /// a platform-shaped thing — full-bleed, masked by whatever the launcher
    /// feels like — and the size that is right for it is not a size Dart has
    /// any reason to know.
    private fun icon(ctx: Context, raw: Map<String, Any?>, title: String): IconCompat {
        val url = (raw["avatarUrl"] as? String)?.takeIf { it.isNotBlank() }
        if (url != null) {
            // Reuses the notification avatar fetcher, which is already a
            // short-timeout, failure-tolerant blocking read — and is already
            // called from a worker thread for exactly this kind of decoration.
            val bitmap = runCatching { ChatNotifications.fetchAvatar(url) }
                .onFailure { Log.w(TAG, "avatar fetch failed: ${it.message}") }
                .getOrNull()
            if (bitmap != null) return IconCompat.createWithAdaptiveBitmap(fill(bitmap))
        }
        val start = (raw["gradientStart"] as? Number)?.toInt() ?: Color.DKGRAY
        val end = (raw["gradientEnd"] as? Number)?.toInt() ?: Color.GRAY
        val initial = (raw["initial"] as? String)?.takeIf { it.isNotBlank() }
            ?: title.firstOrNull()?.uppercase()
            ?: "?"
        return IconCompat.createWithAdaptiveBitmap(gradient(start, end, initial))
    }

    /// Centre-crops [src] to a square and scales it to [ICON_PX].
    ///
    /// `createScaledBitmap` alone would squash a portrait avatar; the share
    /// sheet renders these small enough that a stretched face is the kind of
    /// wrong you notice without being able to say why.
    private fun fill(src: Bitmap): Bitmap {
        val side = minOf(src.width, src.height).coerceAtLeast(1)
        val left = (src.width - side) / 2
        val top = (src.height - side) / 2
        val out = Bitmap.createBitmap(ICON_PX, ICON_PX, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(
            src,
            Rect(left, top, left + side, top + side),
            Rect(0, 0, ICON_PX, ICON_PX),
            Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG),
        )
        return out
    }

    private fun gradient(start: Int, end: Int, initial: String): Bitmap {
        val out = Bitmap.createBitmap(ICON_PX, ICON_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val size = ICON_PX.toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(0f, 0f, size, size, start, end, Shader.TileMode.CLAMP)
        }
        canvas.drawRect(RectF(0f, 0f, size, size), paint)

        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            // Sized against the SAFE zone (the middle 72/108), not the bitmap:
            // a letter sized to the full square is clipped by every round mask.
            textSize = size * (72f / 108f) * 0.52f
            typeface = android.graphics.Typeface.create(
                android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD
            )
        }
        val metrics = text.fontMetrics
        canvas.drawText(
            initial,
            size / 2f,
            size / 2f - (metrics.ascent + metrics.descent) / 2f,
            text,
        )
        return out
    }
}
