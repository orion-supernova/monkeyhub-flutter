package com.walhallaa.chattest20241220

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import kotlin.math.roundToInt

/**
 * `monkeyhub/video_shrink` — re-encodes a video that is over the upload cap
 * until it fits.
 *
 * `shrink` takes a file path and the cap in bytes, and answers the path of a
 * new MP4 at or under the cap, or null when the clip is too long to fit at any
 * watchable bitrate or will not transcode at all. The caller owns, and
 * deletes, the file it gets back.
 *
 * One pass at a bitrate worked out from the clip's length, rather than the
 * preset ladder iOS uses: Android has no presets with a known size, but its
 * encoders take a target bitrate. The resolution steps down with the bitrate,
 * so a long clip is smaller rather than blockier. If the encoder overshoots,
 * one more pass at a lower bitrate.
 *
 * Same contract as `ios/Runner/VideoShrink.swift`.
 */
@OptIn(UnstableApi::class)
object VideoShrink {
    private const val AUDIO_BPS = 128_000L
    private const val MIN_VIDEO_BPS = 200_000L
    private const val MAX_VIDEO_BPS = 4_000_000L

    fun register(ctx: Context, engine: FlutterEngine) {
        val app = ctx.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/video_shrink")
            .setMethodCallHandler { call, result ->
                if (call.method != "shrink") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val input = call.argument<String>("input")
                val cap = call.argument<Number>("capBytes")?.toLong()
                if (input == null || cap == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                shrink(app, input, cap) { path -> result.success(path) }
            }
    }

    private data class Shape(val width: Int, val height: Int, val durationMs: Long)

    private fun shapeOf(path: String): Shape? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            fun int(key: Int) = r.extractMetadata(key)?.toIntOrNull() ?: 0
            val w = int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val h = int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val rotation = int(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            val ms = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            if (w <= 0 || h <= 0 || ms <= 0) null
            // Effects see the frame upright, so size it as it is displayed.
            else if (rotation == 90 || rotation == 270) Shape(h, w, ms)
            else Shape(w, h, ms)
        } catch (e: Exception) {
            null
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
    }

    /** Runs on the main looper, which Transformer needs; the encode itself is off it. */
    fun shrink(ctx: Context, input: String, cap: Long, done: (String?) -> Unit) {
        val shape = shapeOf(input)
        if (shape == null) {
            done(null)
            return
        }
        val seconds = shape.durationMs / 1000.0
        // 90% of the cap for the payload: the container and the encoder's
        // overshoot get the rest.
        val budget = (cap * 8 * 0.9 / seconds).toLong() - AUDIO_BPS
        if (budget < MIN_VIDEO_BPS) {
            done(null)
            return
        }
        attempt(ctx, input, cap, shape, minOf(budget, MAX_VIDEO_BPS), retries = 1, done)
    }

    private fun attempt(
        ctx: Context,
        input: String,
        cap: Long,
        shape: Shape,
        bitrate: Long,
        retries: Int,
        done: (String?) -> Unit,
    ) {
        val shortSide = when {
            bitrate >= 2_500_000 -> 720
            bitrate >= 1_200_000 -> 540
            else -> 360
        }
        val portrait = shape.height > shape.width
        val currentShort = minOf(shape.width, shape.height)
        // Never upscale; height in the frame's own displayed orientation.
        val target = minOf(shortSide, currentShort)
        val height = if (portrait) {
            (target.toDouble() * shape.height / shape.width).roundToInt()
        } else {
            target
        }
        val evenHeight = height - height % 2

        val out = File(ctx.cacheDir, "shrink-${UUID.randomUUID()}.mp4")
        val transformer = Transformer.Builder(ctx)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(ctx)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder()
                            .setBitrate(bitrate.toInt())
                            .build()
                    )
                    .setEnableFallback(true)
                    .build()
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    val size = out.length()
                    if (size in 1..cap) {
                        done(out.absolutePath)
                        return
                    }
                    out.delete()
                    if (retries > 0 && bitrate * 3 / 4 >= MIN_VIDEO_BPS) {
                        attempt(ctx, input, cap, shape, bitrate * 3 / 4, retries - 1, done)
                    } else {
                        done(null)
                    }
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    out.delete()
                    done(null)
                }
            })
            .build()
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(listOf(), listOf(Presentation.createForHeight(evenHeight))))
            .build()
        try {
            transformer.start(item, out.absolutePath)
        } catch (e: Exception) {
            out.delete()
            done(null)
        }
    }
}
