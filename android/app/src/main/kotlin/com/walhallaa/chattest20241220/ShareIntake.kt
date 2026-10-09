package com.walhallaa.chattest20241220

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import androidx.core.content.pm.ShortcutManagerCompat
import java.io.File

/// Everything between "the OS handed us an ACTION_SEND" and "Dart has file
/// paths it can read".
///
/// Two jobs, and the first is the reason this exists at all:
///
///  1. **Copy the content out.** A `content://` URI in a share intent comes with
///     a temporary read grant scoped to the activity that received it. Dart
///     cannot open one (it has no ContentResolver), and by the time a
///     `RoomScreen` exists to send it the grant may be gone. So the bytes are
///     copied into our own cache directory here, synchronously, while the grant
///     is still live, and everything downstream deals in ordinary file paths.
///  2. **Hold it until Dart asks.** A share is very often the launch, so the
///     payload exists before the Dart isolate has a handler. Same queue-then-
///     drain contract [ChatNotifications] taps use — see `takePendingShare` in
///     MainActivity.
object ShareIntake {

    private const val TAG = "ShareIntake"

    /// Mirrors `kMaxFileUploadBytes` in lib/media/file_meta.dart.
    ///
    /// Duplicated rather than asked for, because the decision has to be made
    /// here: the point of the cap on this path is to NOT spend 200 MB of disk
    /// and several seconds copying a video the composer is going to refuse.
    /// `share_upload_cap_test.dart` pins the two together.
    const val MAX_UPLOAD_BYTES = 20L * 1024 * 1024

    /// Mirrors `kMaxMediaIntakeBytes` in lib/media/file_meta.dart: the cap for
    /// a photo or video, which the app compresses down to [MAX_UPLOAD_BYTES]
    /// on the way out. Past it the copy would cost a minute for a clip too
    /// long to fit at any quality.
    const val MAX_MEDIA_INTAKE_BYTES = 500L * 1024 * 1024

    /// Which cap applies to [mime]. Mirrors `intakeCapFor` in Dart.
    fun intakeCapFor(mime: String): Long =
        if (mime.startsWith("image/") || mime.startsWith("video/")) MAX_MEDIA_INTAKE_BYTES
        else MAX_UPLOAD_BYTES

    /// Set on the launch intent by [ShareTargetActivity] so MainActivity knows
    /// to drain [pending] rather than treating it as an ordinary launch.
    const val EXTRA_HAS_SHARE = "mh.share.pending"

    /// The payload waiting for Dart, as the channel map Dart parses. Null when
    /// there is nothing in flight.
    ///
    /// Process-global rather than passed through the launch Intent: the two
    /// activities are always in the same process, and a Binder transaction is a
    /// 1 MB budget nobody should have to think about for a list of file paths.
    @Volatile
    private var pending: Map<String, Any?>? = null

    @Synchronized
    fun offer(payload: Map<String, Any?>) {
        pending = payload
    }

    @Synchronized
    fun take(): Map<String, Any?>? {
        val out = pending
        pending = null
        return out
    }

    @Synchronized
    fun hasPending(): Boolean = pending != null

    /// Reads a share intent into the channel's map shape, copying every
    /// attachment into [Context.getCacheDir].
    ///
    /// Runs off the main thread — see [ShareTargetActivity], which is the only
    /// caller. Never throws: a share that is half-readable delivers the half it
    /// could read, because the alternative is a chooser that appears to do
    /// nothing.
    fun read(ctx: Context, intent: Intent): Map<String, Any?>? {
        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_SEND ->
                listOfNotNull(intent.getParcelableExtraCompat(Intent.EXTRA_STREAM, Uri::class.java))
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtraCompat(Intent.EXTRA_STREAM, Uri::class.java)
                    ?: emptyList()
            else -> emptyList()
        }

        // EXTRA_TEXT is a CharSequence, not a String: Chrome and several
        // readers share a Spanned. `toString()` is the only safe read.
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim()

        val items = ArrayList<Map<String, Any?>>(uris.size)
        val dir = stagingDir(ctx)
        for ((index, uri) in uris.withIndex()) {
            val item = stage(ctx, uri, dir, index)
            if (item != null) items.add(item)
        }

        // A shortcut tap names the chat. Anything else lands on the picker.
        val targetId = intent.getStringExtra(ShortcutManagerCompat.EXTRA_SHORTCUT_ID)

        // Prefer the body over the subject. A browser share sends the page
        // title as the subject and the URL as the text, and the URL is the part
        // that is worth anything in a chat.
        val body = if (!text.isNullOrEmpty()) text else subject

        if (items.isEmpty() && body.isNullOrEmpty()) return null
        return mapOf(
            "items" to items,
            "text" to body,
            "targetId" to targetId,
        )
    }

    /// Our own scratch space under the cache dir, so [sweepStaging] can tidy it
    /// without touching anything else the app cached.
    private fun stagingDir(ctx: Context): File =
        File(ctx.cacheDir, "shared_inbox").apply { mkdirs() }

    private fun stage(ctx: Context, uri: Uri, dir: File, index: Int): Map<String, Any?>? {
        val resolver = ctx.contentResolver
        val mime = resolveMime(resolver, uri)
        val name = queryName(resolver, uri)
        val declaredSize = querySize(resolver, uri)
        val cap = intakeCapFor(mime)

        // Refused BEFORE the copy, which is the whole reason the size is
        // queried separately: the composer would refuse these anyway, and
        // finding that out after writing 200 MB to the user's phone is the
        // expensive way to learn it. Reported rather than dropped so the app
        // can say why instead of silently sending fewer things than were
        // shared.
        if (declaredSize != null && declaredSize > cap) {
            return mapOf(
                "path" to "",
                "mimeType" to mime,
                "fileName" to name,
                "size" to declaredSize,
                "oversize" to true,
            )
        }

        val target = File(dir, stagedName(index, name, mime))
        var written = 0L
        try {
            resolver.openInputStream(uri).use { input ->
                if (input == null) {
                    Log.w(TAG, "no stream for $uri")
                    return null
                }
                target.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        written += read
                        // A provider that lied about its size (or reported
                        // none) is caught here instead. Stop at the cap rather
                        // than filling the disk, and report what we saw.
                        if (written > cap) {
                            output.close()
                            target.delete()
                            return mapOf(
                                "path" to "",
                                "mimeType" to mime,
                                "fileName" to name,
                                "size" to written,
                                "oversize" to true,
                            )
                        }
                        output.write(buffer, 0, read)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "could not stage $uri: ${e.message}")
            target.delete()
            return null
        }

        if (written == 0L) {
            target.delete()
            return null
        }
        return mapOf(
            "path" to target.absolutePath,
            "mimeType" to mime,
            "fileName" to name,
            "size" to written,
            "oversize" to false,
        )
    }

    /// The MIME type, in the order the answers are trustworthy.
    ///
    /// The resolver's own answer beats the intent's `type`, which for
    /// ACTION_SEND_MULTIPLE is the LEAST COMMON DENOMINATOR of everything being
    /// shared — five photos and one video arrive as `*/*`, and taking that at
    /// face value would send every one of them as a document.
    private fun resolveMime(resolver: ContentResolver, uri: Uri): String {
        resolver.getType(uri)?.let { if (it.isNotBlank() && !it.contains('*')) return it }
        val ext = android.webkit.MimeTypeMap.getFileExtensionFromUrl(uri.toString())
        if (!ext.isNullOrEmpty()) {
            android.webkit.MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(ext.lowercase())
                ?.let { return it }
        }
        return "application/octet-stream"
    }

    private fun queryName(resolver: ContentResolver, uri: Uri): String? = runCatching {
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            val col = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (col >= 0 && c.moveToFirst()) c.getString(col) else null
        }
    }.getOrNull() ?: uri.lastPathSegment

    private fun querySize(resolver: ContentResolver, uri: Uri): Long? = runCatching {
        resolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { c ->
            val col = c.getColumnIndex(OpenableColumns.SIZE)
            if (col >= 0 && c.moveToFirst() && !c.isNull(col)) c.getLong(col) else null
        }
    }.getOrNull()

    /// A name that cannot escape [stagingDir] and cannot collide within one
    /// share. The original name is only ever a *suffix* — a provider is free to
    /// report `../../databases/session` as a display name, and this is the one
    /// place that string would otherwise become a path.
    private fun stagedName(index: Int, name: String?, mime: String): String {
        val safe = name?.substringAfterLast('/')?.substringAfterLast('\\')
            ?.replace(Regex("[^A-Za-z0-9._-]"), "_")
            ?.takeIf { it.isNotBlank() && it != "." && it != ".." }
        if (safe != null) return "${System.nanoTime()}_${index}_$safe"
        val ext = android.webkit.MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(mime) ?: "bin"
        return "${System.nanoTime()}_$index.$ext"
    }

    /// How long a staged copy may sit unclaimed before a later launch sweeps
    /// it. Long enough that no live share can be inside it — a share is placed
    /// within seconds of arriving — and short enough that a directory of
    /// somebody's photos is not still on the phone next week.
    private const val STAGING_TTL_MS = 24L * 60 * 60 * 1000

    /// Deletes staged copies older than [STAGING_TTL_MS].
    ///
    /// Dart deletes each file as it consumes it, so this only ever finds what
    /// Dart never got to: a share abandoned by killing the app mid-flight.
    ///
    /// Age-bounded rather than "empty the directory": a second activity can
    /// attach to a live engine (see MainActivity.provideFlutterEngine) while a
    /// share is being consumed, and a blanket wipe there would delete the photo
    /// out from under the send that is uploading it.
    fun sweepStaging(ctx: Context) {
        runCatching {
            val cutoff = System.currentTimeMillis() - STAGING_TTL_MS
            stagingDir(ctx).listFiles()?.forEach {
                if (it.lastModified() < cutoff) it.delete()
            }
        }.onFailure { Log.w(TAG, "could not sweep staging: ${it.message}") }
    }
}

/// `getParcelableExtra` without the API-33 deprecation warning, and without the
/// unchecked cast the un-typed overload needs below 33.
@Suppress("DEPRECATION")
internal fun <T> Intent.getParcelableExtraCompat(key: String, clazz: Class<T>): T? =
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        getParcelableExtra(key, clazz)
    } else {
        @Suppress("UNCHECKED_CAST")
        getParcelableExtra<android.os.Parcelable>(key) as? T
    }

@Suppress("DEPRECATION")
internal fun <T> Intent.getParcelableArrayListExtraCompat(
    key: String,
    clazz: Class<T>,
): ArrayList<T>? =
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        getParcelableArrayListExtra(key, clazz)
    } else {
        @Suppress("UNCHECKED_CAST")
        getParcelableArrayListExtra<android.os.Parcelable>(key) as? ArrayList<T>
    }
