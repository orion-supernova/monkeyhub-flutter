package com.walhallaa.chattest20241220

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.BinaryCodec
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * `monkeyhub/draw_mirror` — Dart's `DrawMirror` on Android: the strokes the
 * others draw over this device's shared screen, painted by [DrawOverlay] over
 * whatever app is on the display while ours is out of sight.
 *
 * Two channels. The method channel arms and disarms (a share starting and
 * ending) and owns the "display over other apps" access. The binary one
 * carries the drawing itself, as the bytes came off the call's data channel;
 * see `draw_mirror.dart` for the four message kinds.
 *
 * The overlay is held by this object, not by an activity: the share it
 * belongs to outlives any one activity attach, and nothing here touches an
 * activity window — the overlay is a window of its own.
 */
object DrawMirrorBridge {
    private const val TAG = "DrawMirror"

    private const val MSG_RESET = 0x01
    private const val MSG_OPS = 0x02
    private const val MSG_STROKE = 0x03
    private const val MSG_VISIBLE = 0x04

    private var overlay: DrawOverlay? = null

    fun register(ctx: Context, engine: FlutterEngine) {
        val app = ctx.applicationContext
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "monkeyhub/draw_mirror").setMethodCallHandler { call, result ->
            when (call.method) {
                "arm" -> {
                    if (overlay == null) overlay = DrawOverlay(app)
                    result.success(canDrawOverlays(app))
                }
                "disarm" -> {
                    overlay?.dispose()
                    overlay = null
                    result.success(null)
                }
                "overlayPermission" -> result.success(canDrawOverlays(app))
                "requestOverlayPermission" -> {
                    openOverlaySettings(app)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        BasicMessageChannel(messenger, "monkeyhub/draw_mirror/ops", BinaryCodec.INSTANCE)
            .setMessageHandler { message, reply ->
                // The buffer is only valid inside this call; everything is
                // read out of it before the handler returns.
                if (message != null) {
                    runCatching { handle(message) }
                        .onFailure { Log.w(TAG, "bad message: $it") }
                }
                reply.reply(null)
            }
    }

    private fun handle(raw: ByteBuffer) {
        val o = overlay ?: return
        val buf = raw.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        buf.position(0)
        if (!buf.hasRemaining()) return
        when (buf.get().toInt() and 0xFF) {
            MSG_RESET -> o.reset()
            MSG_VISIBLE -> o.setVisible(buf.hasRemaining() && buf.get().toInt() != 0)
            MSG_OPS -> {
                val author = readAuthor(buf) ?: return
                o.applyOps(author, DrawWire.decode(buf))
            }
            MSG_STROKE -> {
                val author = readAuthor(buf) ?: return
                if (buf.remaining() < 4) return
                val endedAgoMs = buf.getInt()
                o.applyStroke(author, endedAgoMs, DrawWire.decode(buf))
            }
        }
    }

    private fun readAuthor(buf: ByteBuffer): String? {
        if (!buf.hasRemaining()) return null
        val n = buf.get().toInt() and 0xFF
        if (buf.remaining() < n) return null
        val bytes = ByteArray(n)
        buf.get(bytes)
        return String(bytes, Charsets.UTF_8)
    }

    fun canDrawOverlays(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(ctx)

    private fun openOverlaySettings(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val direct = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${ctx.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { ctx.startActivity(direct) }.onFailure {
            // Some OEM builds drop the per-app page; the list still works.
            runCatching {
                ctx.startActivity(
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }.onFailure { e -> Log.w(TAG, "no overlay settings page: $e") }
        }
    }
}

/**
 * The decoder half of `draw_wire.dart`, version 1. Same contract: never
 * throws, and whatever parsed before the first truncated or unknown op is
 * what comes back.
 */
object DrawWire {
    private const val VERSION = 1
    private const val OP_BEGIN = 0x01
    private const val OP_APPEND = 0x02
    private const val OP_END = 0x03
    private const val OP_CLEAR = 0x04

    sealed class Op {
        class Begin(val id: Long, val argb: Int, val width: Float, val points: FloatArray) : Op()
        class Append(val id: Long, val points: FloatArray) : Op()
        class End(val id: Long) : Op()
        object Clear : Op()
    }

    /** Reads from [buf]'s position to its limit. [buf] must be little-endian. */
    fun decode(buf: ByteBuffer): List<Op> {
        val out = ArrayList<Op>()
        while (buf.remaining() >= 2) {
            if ((buf.get().toInt() and 0xFF) != VERSION) return out
            val count = buf.get().toInt() and 0xFF
            repeat(count) {
                if (!buf.hasRemaining()) return out
                when (buf.get().toInt() and 0xFF) {
                    OP_BEGIN -> {
                        if (buf.remaining() < 14) return out
                        val id = buf.getInt().toLong() and 0xFFFFFFFFL
                        val argb = buf.getInt()
                        val width = buf.getFloat()
                        val pts = points(buf) ?: return out
                        out.add(Op.Begin(id, argb, width, pts))
                    }
                    OP_APPEND -> {
                        if (buf.remaining() < 6) return out
                        val id = buf.getInt().toLong() and 0xFFFFFFFFL
                        val pts = points(buf) ?: return out
                        out.add(Op.Append(id, pts))
                    }
                    OP_END -> {
                        if (buf.remaining() < 4) return out
                        out.add(Op.End(buf.getInt().toLong() and 0xFFFFFFFFL))
                    }
                    OP_CLEAR -> out.add(Op.Clear)
                    else -> return out
                }
            }
        }
        return out
    }

    private fun points(buf: ByteBuffer): FloatArray? {
        val n = buf.getShort().toInt() and 0xFFFF
        if (buf.remaining() < n * 8) return null
        val pts = FloatArray(n * 2)
        for (k in 0 until n * 2) pts[k] = buf.getFloat()
        return pts
    }
}
