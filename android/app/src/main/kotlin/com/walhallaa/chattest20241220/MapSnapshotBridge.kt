package com.walhallaa.chattest20241220

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.GoogleMapOptions
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.MapsInitializer
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.MapStyleOptions
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.lang.ref.WeakReference
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.roundToInt

/**
 * A street-map picture for a location bubble, from Google Maps.
 *
 * The Android twin of `ios/Runner/MapSnapshot.swift`: same channel, same
 * arguments, same answer. `snapshot` takes the centre, the width of the view in
 * metres, the size in logical points, the display scale and light/dark, and
 * returns a PNG of the map with NO marker: the Dart side draws the marker and
 * the accuracy ring on top (`lib/widgets/location_map_preview.dart`). `null` on
 * any failure (no key, no Play services, offline, 8 s timeout); the caller keeps
 * its drawn fallback.
 *
 * The Maps SDK has no off-screen snapshotter. A lite-mode [MapView] is the
 * cheap way to get one: it renders a static bitmap, but it still has to be
 * attached to a window and laid out before it loads tiles. So each request
 * parks a MapView far off the left edge of the activity's decor view (drawn,
 * never visible; alpha 0 or INVISIBLE could skip the draw), waits for
 * `OnMapLoaded`, takes `GoogleMap.snapshot`, and tears it down. Requests run
 * one at a time so a transcript scrolling past a dozen bubbles never holds a
 * dozen MapViews.
 *
 * `available` is the other half of the contract: Dart asks it first, and a
 * `false` (no Play services, or the manifest key is empty because the build had
 * no MAPS_API_KEY) keeps the app from trying at all.
 */
object MapSnapshotBridge {

    private const val TAG = "MapSnapshotBridge"
    private const val CHANNEL = "monkeyhub/map_snapshot"
    private const val TIMEOUT_MS = 8000L
    private const val OFFSCREEN_X = -10000f

    private val main = Handler(Looper.getMainLooper())

    /** PNG compression is slow enough to be felt on the main thread. */
    private val compressor: ExecutorService = Executors.newSingleThreadExecutor()

    private var activityRef: WeakReference<Activity>? = null
    private var appContext: Context? = null

    private class Request(
        val lat: Double,
        val lng: Double,
        val spanMeters: Double,
        val widthDp: Double,
        val heightDp: Double,
        val scale: Double,
        val dark: Boolean,
        val result: MethodChannel.Result,
    )

    // Main thread only.
    private val queue = ArrayDeque<Request>()
    private var busy = false

    fun register(activity: Activity, engine: FlutterEngine) {
        // Re-bound on every attach, like the other bridges: a second activity
        // taking the engine over must not leave this pointing at a dead window.
        activityRef = WeakReference(activity)
        appContext = activity.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(isAvailable())
                    "snapshot" -> enqueue(call.arguments as? Map<*, *>, result)
                    else -> result.notImplemented()
                }
            }
    }

    /** Play services present AND a non-empty key in the merged manifest. */
    private fun isAvailable(): Boolean = try {
        val ctx = activityRef?.get() ?: appContext
        if (ctx == null) {
            false
        } else {
            GoogleApiAvailability.getInstance()
                .isGooglePlayServicesAvailable(ctx) == ConnectionResult.SUCCESS &&
                !manifestApiKey(ctx).isNullOrBlank()
        }
    } catch (_: Throwable) {
        false
    }

    private fun manifestApiKey(ctx: Context): String? = try {
        @Suppress("DEPRECATION")
        ctx.packageManager
            .getApplicationInfo(ctx.packageName, PackageManager.GET_META_DATA)
            .metaData
            ?.getString("com.google.android.geo.API_KEY")
    } catch (_: Throwable) {
        null
    }

    private fun enqueue(args: Map<*, *>?, result: MethodChannel.Result) {
        fun num(key: String): Double? = (args?.get(key) as? Number)?.toDouble()
        val lat = num("latitude")
        val lng = num("longitude")
        val span = num("spanMeters")
        val width = num("width")
        val height = num("height")
        if (lat == null || lng == null || span == null || width == null || height == null ||
            width <= 0 || height <= 0 || span <= 0 ||
            lat < -90 || lat > 90 || lng < -180 || lng > 180
        ) {
            result.success(null)
            return
        }
        val scale = (num("scale") ?: 1.0).coerceIn(0.5, 4.0)
        val dark = args?.get("dark") as? Boolean ?: false
        queue.addLast(Request(lat, lng, span, width, height, scale, dark, result))
        pump()
    }

    private fun pump() {
        if (busy) return
        val next = queue.removeFirstOrNull() ?: return
        busy = true
        try {
            run(next)
        } catch (t: Throwable) {
            Log.w(TAG, "snapshot failed to start", t)
            // `run` finished nothing yet; answer and move on.
            next.result.success(null)
            busy = false
            pump()
        }
    }

    private fun run(req: Request) {
        val activity = activityRef?.get()
        val decor = activity?.window?.decorView as? ViewGroup
        if (activity == null || activity.isFinishing || decor == null) {
            req.result.success(null)
            busy = false
            main.post { pump() }
            return
        }

        val widthPx = (req.widthDp * req.scale).roundToInt().coerceAtLeast(1)
        val heightPx = (req.heightDp * req.scale).roundToInt().coerceAtLeast(1)

        // `MapsInitializer` is idempotent; the legacy renderer prompt is gone.
        try { MapsInitializer.initialize(activity.applicationContext) } catch (_: Throwable) {}

        val options = GoogleMapOptions().liteMode(true).mapToolbarEnabled(false)
        val mapView = MapView(activity, options)
        val holder = FrameLayout(activity)
        var created = false
        var finished = false
        var timeout: Runnable? = null

        fun finish(png: ByteArray?) {
            if (finished) return
            finished = true
            timeout?.let { main.removeCallbacks(it) }
            try { decor.removeView(holder) } catch (_: Throwable) {}
            if (created) {
                try {
                    mapView.onPause()
                    mapView.onStop()
                    mapView.onDestroy()
                } catch (_: Throwable) {}
            }
            try { req.result.success(png) } catch (_: Throwable) {}
            busy = false
            pump()
        }

        val timeoutTask = Runnable {
            Log.w(TAG, "snapshot timed out")
            finish(null)
        }
        timeout = timeoutTask
        main.postDelayed(timeoutTask, TIMEOUT_MS)

        try {
            holder.translationX = OFFSCREEN_X
            holder.addView(
                mapView,
                FrameLayout.LayoutParams(widthPx, heightPx),
            )
            decor.addView(holder, FrameLayout.LayoutParams(widthPx, heightPx))
            // Exact size, laid out now: the tiles load for what the view is,
            // and waiting for the next frame would only lose time to the timeout.
            val exactW = View.MeasureSpec.makeMeasureSpec(widthPx, View.MeasureSpec.EXACTLY)
            val exactH = View.MeasureSpec.makeMeasureSpec(heightPx, View.MeasureSpec.EXACTLY)
            holder.measure(exactW, exactH)
            holder.layout(0, 0, widthPx, heightPx)

            mapView.onCreate(null)
            created = true
            mapView.onStart()
            mapView.onResume()

            mapView.getMapAsync { map: GoogleMap ->
                if (finished) return@getMapAsync
                try {
                    map.uiSettings.setAllGesturesEnabled(false)
                    if (req.dark) {
                        map.setMapStyle(MapStyleOptions(MapStyles.DARK_JSON))
                    }
                    // Callback first, so a map that is ready at once cannot
                    // finish loading before anyone is listening.
                    map.setOnMapLoadedCallback {
                        if (finished) return@setOnMapLoadedCallback
                        map.snapshot { bitmap: Bitmap? ->
                            if (finished) return@snapshot
                            // Lite mode may decline `snapshot`; the view itself
                            // is already drawn, so paint that instead.
                            val bmp = bitmap ?: drawView(mapView, widthPx, heightPx)
                            if (bmp == null) {
                                finish(null)
                            } else {
                                compressor.execute {
                                    val png = try {
                                        val out = ByteArrayOutputStream(bmp.byteCount / 4)
                                        if (bmp.compress(Bitmap.CompressFormat.PNG, 100, out)) {
                                            out.toByteArray()
                                        } else null
                                    } catch (_: Throwable) {
                                        null
                                    }
                                    main.post { finish(png) }
                                }
                            }
                        }
                    }
                    map.moveCamera(
                        CameraUpdateFactory.newLatLngZoom(
                            LatLng(req.lat, req.lng),
                            MapStyles.zoomFor(req.lat, req.spanMeters, req.widthDp),
                        )
                    )
                } catch (t: Throwable) {
                    Log.w(TAG, "map setup failed", t)
                    finish(null)
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "snapshot setup failed", t)
            finish(null)
        }
    }

    private fun drawView(view: View, w: Int, h: Int): Bitmap? = try {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bmp))
        bmp
    } catch (_: Throwable) {
        null
    }
}

/** Shared by the snapshot and the interactive map. */
internal object MapStyles {

    /**
     * Zoom at which `spanMeters` spans `widthDp`. Google's tiles are 256 dp at
     * zoom 0, so one dp is 156543.03392 * cos(lat) / 2^zoom metres.
     */
    fun zoomFor(latitude: Double, spanMeters: Double, widthDp: Double): Float {
        val c = cos(Math.toRadians(latitude)).coerceAtLeast(0.01)
        val z = ln(156543.03392 * c * widthDp / spanMeters.coerceAtLeast(1.0)) / ln(2.0)
        return z.coerceIn(2.0, 21.0).toFloat()
    }

    /** A neutral dark map: dark grey land, slightly lighter roads, deep water. */
    const val DARK_JSON = """
[
  {"elementType":"geometry","stylers":[{"color":"#1d2126"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8a9199"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d2126"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#2e343b"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#22272d"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f2a26"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c3238"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1d2126"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#343b42"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3d454d"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#252a30"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#10151a"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4a525a"}]}
]
"""
}
