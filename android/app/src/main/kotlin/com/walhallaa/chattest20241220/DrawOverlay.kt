package com.walhallaa.chattest20241220

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.Configuration
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.input.InputManager
import android.os.Build
import android.os.SystemClock
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import kotlin.math.max

/**
 * The strokes over a shared screen, painted over every other app.
 *
 * A system overlay window (`TYPE_APPLICATION_OVERLAY`) the size of the
 * display, so a stroke's 0..1 fractions of the captured frame land on the
 * same pixels the capture took them from — the same mapping the in-app
 * `ScreenShareOverlay` makes onto the app's window.
 *
 * It must never get in the way of the app being shared:
 *
 *  * **No touches.** `FLAG_NOT_TOUCHABLE` sends every touch through. On
 *    Android 12+ a touch through another app's window is dropped unless that
 *    window is at most `maximumObscuringOpacityForTouch` opaque (0.8 by
 *    default), so the window's alpha is set to exactly that — the strokes
 *    read a touch lighter, and every tap under them still lands.
 *  * **Only while there is something to show.** The window is added when a
 *    stroke arrives and removed once the last one has faded. An overlay that
 *    sat there empty would still count as one: banking and password apps
 *    refuse touches while any window obscures them, and Android lists the
 *    app as "displaying over other apps" for as long as it is up.
 *  * **Only while the app is out of sight** ([setVisible]); in front, the
 *    Flutter layer draws and this one would be a second copy.
 *
 * Each stroke lives [LIFETIME_MS] after its finger lifts and then fades over
 * [DISSOLVE_MS], on the same clock the Dart model keeps. Repaints are driven
 * by deadlines, not a loop: one frame per incoming batch, then nothing until
 * a stroke starts to fade, then a frame per vsync for the fade alone.
 */
class DrawOverlay(appCtx: Context) {

    companion object {
        private const val TAG = "DrawOverlay"
        const val LIFETIME_MS = 2500L
        const val DISSOLVE_MS = 650L

        /** A run of strokes this long is a stuck finger or a flood; the
         * oldest go first. */
        private const val MAX_STROKES = 256
    }

    class Stroke(val color: Int, val width: Float) {
        var pts = FloatArray(64)
        var n = 0

        /** [SystemClock.uptimeMillis] the finger lifted at; -1 while down. */
        var endedAt = -1L

        val path = Path()
        var pathN = -1
        var pathW = 0
        var pathH = 0

        fun add(xy: FloatArray) {
            val add = xy.size / 2
            if (add == 0) return
            val need = (n + add) * 2
            if (need > pts.size) {
                var cap = pts.size
                while (cap < need) cap *= 2
                pts = pts.copyOf(cap)
            }
            System.arraycopy(xy, 0, pts, n * 2, add * 2)
            n += add
        }
    }

    /** A window context for the overlay type on 11+, where a window added
     * through the application context is a StrictMode violation and gets
     * the wrong configuration on rotation. */
    private val ctx: Context = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        runCatching {
            val display = appCtx.getSystemService(DisplayManager::class.java)
                .getDisplay(Display.DEFAULT_DISPLAY) ?: return@runCatching appCtx
            appCtx.createDisplayContext(display)
                .createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
        }.getOrDefault(appCtx)
    } else {
        appCtx
    }

    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    /** Insertion-ordered: oldest first, which is also the paint order. */
    private val strokes = LinkedHashMap<String, Stroke>()
    private val view = OverlayView(ctx)
    private var attached = false
    private var visible = false
    private var disposed = false

    fun setVisible(v: Boolean) {
        if (disposed) return
        visible = v
        if (!v) {
            strokes.clear()
            detach()
        } else {
            refresh()
        }
    }

    fun reset() {
        strokes.clear()
        refresh()
    }

    fun applyOps(author: String, ops: List<DrawWire.Op>) {
        if (disposed || ops.isEmpty()) return
        val now = SystemClock.uptimeMillis()
        for (op in ops) {
            when (op) {
                is DrawWire.Op.Begin -> {
                    val s = Stroke(op.argb, op.width)
                    s.add(op.points)
                    strokes["$author/${op.id}"] = s
                }
                is DrawWire.Op.Append -> strokes["$author/${op.id}"]?.add(op.points)
                is DrawWire.Op.End -> strokes["$author/${op.id}"]?.let {
                    if (it.endedAt < 0) it.endedAt = now
                }
                DrawWire.Op.Clear -> strokes.clear()
            }
        }
        while (strokes.size > MAX_STROKES) {
            strokes.remove(strokes.keys.first())
        }
        refresh()
    }

    /** A stroke handed over mid-life: [endedAgoMs] is -1 while still drawn. */
    fun applyStroke(author: String, endedAgoMs: Int, ops: List<DrawWire.Op>) {
        val begin = ops.firstOrNull() as? DrawWire.Op.Begin ?: return
        if (endedAgoMs >= LIFETIME_MS + DISSOLVE_MS) return
        val s = Stroke(begin.argb, begin.width)
        s.add(begin.points)
        if (endedAgoMs >= 0) s.endedAt = SystemClock.uptimeMillis() - endedAgoMs
        strokes["$author/${begin.id}"] = s
        refresh()
    }

    fun dispose() {
        disposed = true
        strokes.clear()
        detach()
    }

    // ------------------------------------------------------------- window

    private fun refresh() {
        if (!visible || strokes.isEmpty()) {
            if (strokes.isEmpty()) detach()
            return
        }
        attach()
        view.kick()
    }

    private fun attach() {
        if (attached || disposed) return
        if (!DrawMirrorBridge.canDrawOverlays(ctx)) return
        runCatching {
            wm.addView(view, overlayParams())
            attached = true
        }.onFailure { Log.w(TAG, "addView refused: $it") }
    }

    private fun detach() {
        view.halt()
        if (!attached) return
        attached = false
        runCatching { wm.removeViewImmediate(view) }
            .onFailure { Log.w(TAG, "removeView: $it") }
    }

    /** The whole display, rotation included, under the bars and the cutout. */
    private fun displayBounds(): Rect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return wm.maximumWindowMetrics.bounds
        }
        val dm = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(dm)
        return Rect(0, 0, dm.widthPixels, dm.heightPixels)
    }

    private fun overlayParams(): WindowManager.LayoutParams {
        val b = displayBounds()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(
            b.width(),
            b.height(),
            type,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT,
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = 0
        lp.y = 0
        lp.title = "MonkeyHub drawings"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lp.layoutInDisplayCutoutMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else {
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            lp.fitInsetsTypes = 0
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val im = ctx.getSystemService(InputManager::class.java)
            lp.alpha = im?.maximumObscuringOpacityForTouch ?: 0.8f
        }
        return lp
    }

    // --------------------------------------------------------------- view

    @SuppressLint("ViewConstructor")
    private inner class OverlayView(ctx: Context) : View(ctx) {
        private val halo = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        private val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        private val tick = Runnable { invalidate() }

        init {
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        }

        /** New data: one frame now, the clock takes it from there. */
        fun kick() {
            removeCallbacks(tick)
            invalidate()
        }

        fun halt() {
            removeCallbacks(tick)
        }

        override fun onConfigurationChanged(newConfig: Configuration) {
            super.onConfigurationChanged(newConfig)
            // Rotated: the frame rotated with the display, so the window
            // follows it to keep the fractions on the same pixels.
            if (attached) {
                runCatching { wm.updateViewLayout(this, overlayParams()) }
            }
        }

        override fun onDraw(canvas: Canvas) {
            val now = SystemClock.uptimeMillis()
            val w = width
            val h = height
            var fading = false
            var next = Long.MAX_VALUE
            val it = strokes.values.iterator()
            while (it.hasNext()) {
                val s = it.next()
                var opacity = 1f
                if (s.endedAt >= 0) {
                    val start = s.endedAt + LIFETIME_MS
                    if (now >= start + DISSOLVE_MS) {
                        it.remove()
                        continue
                    }
                    if (now >= start) {
                        val t = (now - start).toFloat() / DISSOLVE_MS
                        opacity = 1f - t * t
                        fading = true
                    } else {
                        next = minOf(next, start)
                    }
                }
                if (s.n == 0 || opacity <= 0.01f) continue
                val path = pathFor(s, w, h)
                val sw = max(1f, s.width * w)
                val a = (s.color ushr 24) and 0xFF
                halo.color = s.color
                halo.alpha = (a * 0.28f * opacity).toInt()
                halo.strokeWidth = sw * 2.2f
                canvas.drawPath(path, halo)
                ink.color = s.color
                ink.alpha = (a * opacity).toInt()
                ink.strokeWidth = sw
                canvas.drawPath(path, ink)
            }
            when {
                strokes.isEmpty() -> post { if (strokes.isEmpty()) detach() }
                fading -> postInvalidateOnAnimation()
                next != Long.MAX_VALUE -> postDelayed(tick, max(0L, next - now))
            }
        }

        /** Midpoint quadratics, as the Flutter painter draws them, rebuilt
         * only when a point arrived or the window changed shape. */
        private fun pathFor(s: Stroke, w: Int, h: Int): Path {
            if (s.pathN == s.n && s.pathW == w && s.pathH == h) return s.path
            val p = s.path
            p.rewind()
            val pts = s.pts
            val n = s.n
            p.moveTo(pts[0] * w, pts[1] * h)
            when (n) {
                1 -> p.lineTo(pts[0] * w + 0.01f, pts[1] * h)
                2 -> p.lineTo(pts[2] * w, pts[3] * h)
                else -> {
                    for (i in 1 until n - 1) {
                        val cx = pts[2 * i] * w
                        val cy = pts[2 * i + 1] * h
                        val mx = (cx + pts[2 * i + 2] * w) / 2
                        val my = (cy + pts[2 * i + 3] * h) / 2
                        p.quadTo(cx, cy, mx, my)
                    }
                    p.lineTo(pts[2 * (n - 1)] * w, pts[2 * (n - 1) + 1] * h)
                }
            }
            s.pathN = n
            s.pathW = w
            s.pathH = h
            return p
        }
    }
}
