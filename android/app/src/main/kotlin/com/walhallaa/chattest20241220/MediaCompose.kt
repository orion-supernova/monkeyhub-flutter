package com.walhallaa.chattest20241220

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

/**
 * `monkeyhub/media_compose` — joins the segments of a paused-and-resumed voice
 * or video note and trims the result.
 *
 * `compose` takes `paths` (in order), `outPath`, optional `startMs`/`endMs` on
 * the joined timeline and `video`, and answers `{durationMs}` — measured from
 * the file it wrote — or a `compose_failed` error. The caller owns, and
 * deletes, every file involved. See `lib/composer/capture_compose.dart`.
 *
 * The normal path re-encodes nothing: MediaExtractor reads each segment's
 * samples and one MediaMuxer writes them back to back, each segment's
 * timestamps offset by the length of everything before it. A trim drops the
 * samples outside the range. Audio cuts land on an AAC frame (~23 ms). Video
 * cannot start on anything but a keyframe without re-encoding, so the cut
 * moves back to the sync frame at or before `startMs` — CameraX's encoder
 * puts one about every second, so a video trim can start up to ~1 s early.
 * The audio is cut at that same point, so sync holds. The end is exact.
 *
 * Passthrough needs every segment to share one codec config, size and
 * rotation, because an MP4 track has one of each. A flip while paused breaks
 * that — the front and back sensors are mounted opposite ways, so CameraX
 * writes a different rotation hint for each. Those go through Media3
 * Transformer instead, which decodes each segment upright and re-encodes all
 * of them at the first segment's displayed size (crop-to-fill). Slower, and
 * only when it has to be. A muxer failure on video also falls back to it.
 *
 * Same contract as `ios/Runner/MediaCompose.swift`.
 */
@OptIn(UnstableApi::class)
object MediaCompose {
    private const val VIDEO_BPS = 900_000

    fun register(ctx: Context, engine: FlutterEngine) {
        val app = ctx.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/media_compose")
            .setMethodCallHandler { call, result ->
                if (call.method != "compose") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val paths = call.argument<List<String>>("paths")
                val out = call.argument<String>("outPath")
                val startMs = call.argument<Number>("startMs")?.toLong()
                val endMs = call.argument<Number>("endMs")?.toLong()
                val video = call.argument<Boolean>("video") ?: false
                if (paths.isNullOrEmpty() || out == null) {
                    result.error("compose_failed", "paths and outPath are required", null)
                    return@setMethodCallHandler
                }
                val main = Handler(Looper.getMainLooper())
                val reply: (Long?, String?) -> Unit = { ms, message ->
                    main.post {
                        if (ms != null) {
                            result.success(mapOf("durationMs" to ms))
                        } else {
                            result.error("compose_failed", message, null)
                        }
                    }
                }
                // Transformer must be built and started on a looper thread,
                // which this handler is on; the muxer path is plain blocking
                // I/O and goes to a worker.
                Thread {
                    val mixed = video && !uniform(paths)
                    if (mixed) {
                        main.post { transcode(app, paths, out, startMs, endMs, reply) }
                        return@Thread
                    }
                    try {
                        reply(mux(paths, out, startMs, endMs, video), null)
                    } catch (e: Exception) {
                        File(out).delete()
                        if (video) {
                            main.post { transcode(app, paths, out, startMs, endMs, reply) }
                        } else {
                            reply(null, "mux failed: ${e.message}")
                        }
                    }
                }.start()
            }
    }

    // ---- shape checks ------------------------------------------------------

    private fun rotationOf(path: String): Int {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
        } catch (e: Exception) {
            0
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
    }

    private fun durationMsOf(path: String): Long {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
        } catch (e: Exception) {
            0L
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
    }

    /** The first track whose MIME starts with [prefix], or -1. */
    private fun trackOf(ex: MediaExtractor, prefix: String): Int {
        for (i in 0 until ex.trackCount) {
            val mime = ex.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith(prefix)) return i
        }
        return -1
    }

    private fun bytesOf(format: MediaFormat, key: String): ByteBuffer? =
        if (format.containsKey(key)) format.getByteBuffer(key) else null

    /** Every segment's video can share one MP4 track: same codec config, size, rotation. */
    private fun uniform(paths: List<String>): Boolean {
        var first: MediaFormat? = null
        var firstRotation = 0
        for (path in paths) {
            val ex = MediaExtractor()
            try {
                ex.setDataSource(path)
                val track = trackOf(ex, "video/")
                if (track < 0) return false
                val f = ex.getTrackFormat(track)
                val rotation = rotationOf(path)
                val base = first
                if (base == null) {
                    first = f
                    firstRotation = rotation
                    continue
                }
                if (rotation != firstRotation ||
                    f.getString(MediaFormat.KEY_MIME) != base.getString(MediaFormat.KEY_MIME) ||
                    f.getInteger(MediaFormat.KEY_WIDTH) != base.getInteger(MediaFormat.KEY_WIDTH) ||
                    f.getInteger(MediaFormat.KEY_HEIGHT) != base.getInteger(MediaFormat.KEY_HEIGHT) ||
                    bytesOf(f, "csd-0") != bytesOf(base, "csd-0") ||
                    bytesOf(f, "csd-1") != bytesOf(base, "csd-1")
                ) {
                    return false
                }
            } catch (e: Exception) {
                return false
            } finally {
                ex.release()
            }
        }
        return true
    }

    // ---- passthrough -------------------------------------------------------

    /** Blocking. Answers the written file's duration in ms; throws on any failure. */
    private fun mux(paths: List<String>, out: String, startMs: Long?, endMs: Long?, video: Boolean): Long {
        // Pass 1: each segment's span, and the formats the output takes from
        // the first segment that has them.
        val spans = LongArray(paths.size)
        var audioFormat: MediaFormat? = null
        var videoFormat: MediaFormat? = null
        var maxInput = 1 shl 20
        for ((i, path) in paths.withIndex()) {
            val ex = MediaExtractor()
            try {
                ex.setDataSource(path)
                var span = 0L
                for (prefix in if (video) listOf("audio/", "video/") else listOf("audio/")) {
                    val t = trackOf(ex, prefix)
                    if (t < 0) continue
                    val f = ex.getTrackFormat(t)
                    if (prefix == "audio/" && audioFormat == null) audioFormat = f
                    if (prefix == "video/" && videoFormat == null) videoFormat = f
                    if (f.containsKey(MediaFormat.KEY_DURATION)) {
                        // A video segment is as long as its picture; trailing
                        // audio past it is dropped below rather than allowed
                        // to overlap the next segment.
                        val d = f.getLong(MediaFormat.KEY_DURATION)
                        span = if (prefix == "video/") d else maxOf(span, d)
                    }
                    if (f.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                        maxInput = maxOf(maxInput, f.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE))
                    }
                }
                spans[i] = if (span > 0) span else durationMsOf(path) * 1000
            } finally {
                ex.release()
            }
        }
        val total = spans.sum()
        if (total <= 0 || (audioFormat == null && videoFormat == null)) {
            throw IllegalStateException("no media in segments")
        }

        val endUs = endMs?.let { minOf(it * 1000, total) } ?: total
        var cutUs = maxOf(0L, minOf((startMs ?: 0L) * 1000, total))
        if (videoFormat != null && cutUs > 0) cutUs = syncAtOrBefore(paths, spans, cutUs)
        if (endUs <= cutUs) throw IllegalStateException("empty trim range")

        val muxer = MediaMuxer(out, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var started = false
        try {
            if (videoFormat != null) muxer.setOrientationHint(rotationOf(paths[0]))
            val outAudio = audioFormat?.let { muxer.addTrack(it) } ?: -1
            val outVideo = videoFormat?.let { muxer.addTrack(it) } ?: -1
            muxer.start()
            started = true

            val buffer = ByteBuffer.allocate(maxInput)
            val info = MediaCodec.BufferInfo()
            // Highest pts written per output track, across segments.
            val written = mutableMapOf<Int, Long>()
            var offset = 0L
            for ((i, path) in paths.withIndex()) {
                val segStart = offset
                val segEnd = offset + spans[i]
                offset = segEnd
                if (segEnd <= cutUs || segStart >= endUs) continue

                val ex = MediaExtractor()
                try {
                    ex.setDataSource(path)
                    val map = mutableMapOf<Int, Int>()
                    val inAudio = trackOf(ex, "audio/")
                    if (inAudio >= 0 && outAudio >= 0) map[inAudio] = outAudio
                    val inVideo = if (video) trackOf(ex, "video/") else -1
                    if (inVideo >= 0 && outVideo >= 0) map[inVideo] = outVideo
                    for (t in map.keys) ex.selectTrack(t)
                    // A segment whose first sample would land at or before the
                    // previous segment's last (rounding in the per-track
                    // durations) is nudged later as a whole. Never per sample:
                    // video pts are not monotonic when the encoder reorders.
                    val shift = mutableMapOf<Int, Long>()
                    if (cutUs > segStart) {
                        ex.seekTo(cutUs - segStart, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
                    }
                    while (true) {
                        val inTrack = ex.sampleTrackIndex
                        if (inTrack < 0) break
                        val size = ex.readSampleData(buffer, 0)
                        if (size < 0) break
                        val local = ex.sampleTime
                        val at = segStart + local
                        val outTrack = map[inTrack]
                        // Inside the segment's own span and the trim, nothing
                        // else. Video before the cut cannot exist (the cut is
                        // a sync time); audio before it is dropped here.
                        if (outTrack != null && local < spans[i] && at >= cutUs && at < endUs) {
                            val raw = at - cutUs
                            val nudge = shift.getOrPut(outTrack) {
                                val prev = written[outTrack]
                                if (prev != null && raw <= prev) prev + 1 - raw else 0L
                            }
                            val pts = raw + nudge
                            written[outTrack] = maxOf(written[outTrack] ?: pts, pts)
                            val flags = if ((ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0) {
                                MediaCodec.BUFFER_FLAG_KEY_FRAME
                            } else {
                                0
                            }
                            info.set(0, size, pts, flags)
                            muxer.writeSampleData(outTrack, buffer, info)
                        }
                        if (!ex.advance()) break
                    }
                } finally {
                    ex.release()
                }
            }
        } finally {
            try {
                if (started) muxer.stop()
            } finally {
                muxer.release()
            }
        }
        val ms = durationMsOf(out)
        if (ms <= 0) throw IllegalStateException("mux produced no media")
        return ms
    }

    /** The joined-timeline time of the video sync frame at or before [atUs]. */
    private fun syncAtOrBefore(paths: List<String>, spans: LongArray, atUs: Long): Long {
        var offset = 0L
        for ((i, path) in paths.withIndex()) {
            if (atUs < offset + spans[i] || i == paths.size - 1) {
                val ex = MediaExtractor()
                try {
                    ex.setDataSource(path)
                    val t = trackOf(ex, "video/")
                    if (t < 0) return atUs
                    ex.selectTrack(t)
                    ex.seekTo(atUs - offset, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
                    val local = ex.sampleTime
                    return if (local < 0) offset else offset + local
                } finally {
                    ex.release()
                }
            }
            offset += spans[i]
        }
        return atUs
    }

    // ---- re-encode (mixed lenses) -----------------------------------------

    /** Runs on the main looper, which Transformer needs; the encode itself is off it. */
    private fun transcode(
        ctx: Context,
        paths: List<String>,
        out: String,
        startMs: Long?,
        endMs: Long?,
        done: (Long?, String?) -> Unit,
    ) {
        // Displayed size of the first segment: every other one is fitted to it.
        val r = MediaMetadataRetriever()
        var width = 0
        var height = 0
        try {
            r.setDataSource(paths[0])
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rotation = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            if (rotation == 90 || rotation == 270) {
                width = h
                height = w
            } else {
                width = w
                height = h
            }
        } catch (_: Exception) {
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
        width -= width % 2
        height -= height % 2
        if (width <= 0 || height <= 0) {
            done(null, "unreadable first segment")
            return
        }

        val cut = maxOf(0L, startMs ?: 0L)
        val end = endMs ?: Long.MAX_VALUE
        val items = mutableListOf<EditedMediaItem>()
        var offset = 0L
        for (path in paths) {
            val length = durationMsOf(path)
            val segStart = offset
            offset += length
            val from = maxOf(cut, segStart) - segStart
            val to = minOf(end, offset) - segStart
            // A sliver under a frame is not worth a decoder.
            if (length <= 0 || to - from < 40) continue
            val media = MediaItem.Builder().setUri(Uri.fromFile(File(path)))
            if (from > 0 || to < length) {
                media.setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(from)
                        .setEndPositionMs(to)
                        .build()
                )
            }
            items.add(
                EditedMediaItem.Builder(media.build())
                    .setEffects(
                        Effects(
                            listOf(),
                            listOf(
                                Presentation.createForWidthAndHeight(
                                    width, height, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP
                                )
                            )
                        )
                    )
                    .build()
            )
        }
        if (items.isEmpty()) {
            done(null, "empty trim range")
            return
        }

        File(out).delete()
        val transformer = Transformer.Builder(ctx)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(ctx)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder().setBitrate(VIDEO_BPS).build()
                    )
                    .setEnableFallback(true)
                    .build()
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    val ms = durationMsOf(out)
                    if (ms > 0) {
                        done(ms, null)
                    } else {
                        File(out).delete()
                        done(null, "transcode produced no media")
                    }
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    File(out).delete()
                    done(null, "transcode failed: ${exportException.message}")
                }
            })
            .build()
        val composition = Composition.Builder(
            EditedMediaItemSequence.withAudioAndVideoFrom(items)
        ).build()
        try {
            transformer.start(composition, out)
        } catch (e: Exception) {
            File(out).delete()
            done(null, "transcode failed: ${e.message}")
        }
    }
}
