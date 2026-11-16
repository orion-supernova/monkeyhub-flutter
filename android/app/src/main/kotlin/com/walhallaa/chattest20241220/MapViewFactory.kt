package com.walhallaa.chattest20241220

import android.animation.ValueAnimator
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.view.animation.DecelerateInterpolator
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.GoogleMapOptions
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.MapsInitializer
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.Circle
import com.google.android.gms.maps.model.CircleOptions
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.Polyline
import com.google.android.gms.maps.model.PolylineOptions
import com.google.android.gms.maps.model.RoundCap
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * The interactive map behind the fullscreen location screen, as a platform view
 * of type `monkeyhub/map_view`.
 *
 * Creation params: `latitude`, `longitude`, `accuracyM` (nullable),
 * `spanMeters` (the visible width at first), `dark`. Each view also owns a
 * `monkeyhub/map_view_<viewId>` channel for the live updates Dart sends:
 * `update` (a moved point, optionally followed by the camera), `recenter` and
 * `setDark`. The stills in chat bubbles are [MapSnapshotBridge]'s job, not this.
 */
class MapViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        MapPlatformView(context, messenger, viewId, args as? Map<*, *>)

    companion object {
        const val VIEW_TYPE = "monkeyhub/map_view"

        fun register(engine: FlutterEngine) {
            // Returns false (not throws) when this engine already has it, which
            // is the second activity re-attaching to the cached engine.
            engine.platformViewsController.registry.registerViewFactory(
                VIEW_TYPE,
                MapViewFactory(engine.dartExecutor.binaryMessenger),
            )
        }
    }
}

private class MapPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    params: Map<*, *>?,
) : PlatformView {

    private companion object {
        const val TAG = "MapPlatformView"
        const val MOVE_MS = 350L
        /** Width assumed when the real one is unknown at creation. */
        const val FALLBACK_WIDTH_DP = 360.0
        const val ACCURACY_FILL = 0x1F40CFBA
        const val ACCURACY_STROKE = 0x5940CFBA
        const val TRAIL_COLOR = 0x8C40CFBA
        const val READY_FALLBACK_MS = 2000L
        const val GESTURE_THROTTLE_MS = 500L
        const val PAD_TOP_DP = 110
        const val PAD_BOTTOM_DP = 220
        const val BOTH_PAD_DP = 80
    }

    private val ctx: Context = context
    private val density: Float = context.resources.displayMetrics.density
    private fun dp(v: Int): Int = (v * density).toInt()
    private val main = Handler(Looper.getMainLooper())

    private fun decodePin(bytes: Any?): Bitmap? = try {
        (bytes as? ByteArray)?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
    } catch (t: Throwable) {
        Log.w(TAG, "pin decode failed", t)
        null
    }

    private fun parseTrail(raw: Any?): List<LatLng>? {
        val list = raw as? List<*> ?: return null
        val out = ArrayList<LatLng>(list.size)
        for (e in list) {
            val pair = e as? List<*> ?: continue
            val a = (pair.getOrNull(0) as? Number)?.toDouble() ?: continue
            val b = (pair.getOrNull(1) as? Number)?.toDouble() ?: continue
            out.add(LatLng(a, b))
        }
        return out
    }

    private fun num(m: Map<*, *>?, key: String): Double? = (m?.get(key) as? Number)?.toDouble()

    private var lat = num(params, "latitude") ?: 0.0
    private var lng = num(params, "longitude") ?: 0.0
    private var accuracyM: Double? = num(params, "accuracyM")
    private var dark = params?.get("dark") as? Boolean ?: false
    private val initialZoom: Float = MapStyles.zoomFor(
        lat,
        num(params, "spanMeters") ?: 500.0,
        FALLBACK_WIDTH_DP,
    )

    private var map: GoogleMap? = null
    private var marker: Marker? = null
    private var circle: Circle? = null
    private var mover: ValueAnimator? = null
    private var polyline: Polyline? = null
    private var disposed = false

    // Dart-supplied look, kept so values that arrive before the map is ready apply on ready.
    private var pinBitmap: Bitmap? = decodePin(params?.get("pinImage"))
    private var pinAnchorY: Float = (num(params, "pinAnchorY") ?: 0.5).toFloat()
    private var trailPoints: List<LatLng>? = parseTrail(params?.get("trail"))
    private var mapTypeName: String = params?.get("mapType") as? String ?: "standard"
    private var traffic: Boolean = params?.get("traffic") as? Boolean ?: false
    private var showsUser: Boolean = params?.get("showsUser") as? Boolean ?: false

    private var readySent = false
    private var lastGestureAt = 0L
    private val readyFallback = Runnable { sendReady() }

    private val mapView: MapView
    private val channel = MethodChannel(messenger, "monkeyhub/map_view_$viewId")

    init {
        try { MapsInitializer.initialize(context.applicationContext) } catch (_: Throwable) {}
        val options = GoogleMapOptions()
            .mapToolbarEnabled(false)
            .compassEnabled(true)
            .zoomControlsEnabled(false)
            .zoomGesturesEnabled(true)
            .scrollGesturesEnabled(true)
            .rotateGesturesEnabled(true)
            .camera(
                com.google.android.gms.maps.model.CameraPosition.fromLatLngZoom(
                    LatLng(lat, lng), initialZoom,
                )
            )
        mapView = MapView(context, options)
        mapView.onCreate(null)
        mapView.onStart()
        mapView.onResume()
        mapView.getMapAsync { onMapReady(it) }

        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "update" -> {
                        val args = call.arguments as? Map<*, *>
                        val nLat = num(args, "latitude")
                        val nLng = num(args, "longitude")
                        if (nLat != null && nLng != null) {
                            update(nLat, nLng, num(args, "accuracyM"), args?.get("follow") as? Boolean ?: false)
                        }
                        if (args?.get("pinImage") != null) {
                            decodePin(args["pinImage"])?.let { pinBitmap = it }
                            num(args, "pinAnchorY")?.let { pinAnchorY = it.toFloat() }
                            applyPin()
                        }
                        if (args != null && args.containsKey("trail") && args["trail"] != null) {
                            trailPoints = parseTrail(args["trail"])
                            applyTrail()
                        }
                        result.success(null)
                    }
                    "recenter" -> {
                        map?.animateCamera(
                            CameraUpdateFactory.newLatLngZoom(LatLng(lat, lng), initialZoom)
                        )
                        result.success(null)
                    }
                    "setMapType" -> {
                        mapTypeName = (call.arguments as? Map<*, *>)?.get("type") as? String ?: "standard"
                        applyMapType()
                        result.success(null)
                    }
                    "setTraffic" -> {
                        traffic = (call.arguments as? Map<*, *>)?.get("on") as? Boolean ?: false
                        map?.isTrafficEnabled = traffic
                        result.success(null)
                    }
                    "setShowsUser" -> {
                        showsUser = (call.arguments as? Map<*, *>)?.get("on") as? Boolean ?: false
                        applyShowsUser()
                        result.success(null)
                    }
                    "showBoth" -> {
                        showBoth()
                        result.success(null)
                    }
                    "setDark" -> {
                        dark = (call.arguments as? Map<*, *>)?.get("dark") as? Boolean ?: false
                        applyStyle()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                Log.w(TAG, "${call.method} failed", t)
                result.success(null)
            }
        }
    }

    private fun onMapReady(googleMap: GoogleMap) {
        if (disposed) return
        map = googleMap
        googleMap.uiSettings.apply {
            isZoomControlsEnabled = false
            isMapToolbarEnabled = false
            isCompassEnabled = true
            isZoomGesturesEnabled = true
            isScrollGesturesEnabled = true
            isRotateGesturesEnabled = true
            isMyLocationButtonEnabled = false
        }
        applyStyle()
        // `lat`/`lng` may already have moved on if an update beat the map.
        googleMap.moveCamera(CameraUpdateFactory.newLatLngZoom(LatLng(lat, lng), initialZoom))
        googleMap.setPadding(0, dp(PAD_TOP_DP), 0, dp(PAD_BOTTOM_DP))
        applyMapType()
        googleMap.isTrafficEnabled = traffic
        applyShowsUser()
        val pin = pinBitmap
        val opts = MarkerOptions().position(LatLng(lat, lng)).zIndex(2f)
        if (pin != null) {
            opts.icon(BitmapDescriptorFactory.fromBitmap(pin))
                .anchor(0.5f, pinAnchorY)
                .flat(false)
            // A custom pin has no info window and swallows taps.
            googleMap.setOnMarkerClickListener { true }
        } else {
            // Default red pin, tinted teal (hue 174).
            opts.icon(BitmapDescriptorFactory.defaultMarker(174f))
        }
        marker = googleMap.addMarker(opts)
        syncCircle(LatLng(lat, lng))
        applyTrail()

        googleMap.setOnCameraMoveStartedListener { reason ->
            if (reason == GoogleMap.OnCameraMoveStartedListener.REASON_GESTURE) {
                val now = SystemClock.elapsedRealtime()
                if (now - lastGestureAt >= GESTURE_THROTTLE_MS) {
                    lastGestureAt = now
                    if (!disposed) channel.invokeMethod("gesture", null)
                }
            }
        }
        googleMap.setOnMapLoadedCallback { sendReady() }
        main.postDelayed(readyFallback, READY_FALLBACK_MS)
    }

    private fun sendReady() {
        if (disposed || readySent) return
        readySent = true
        main.removeCallbacks(readyFallback)
        channel.invokeMethod("ready", null)
    }

    private fun applyPin() {
        val m = marker ?: return
        val pin = pinBitmap ?: return
        m.setIcon(BitmapDescriptorFactory.fromBitmap(pin))
        m.setAnchor(0.5f, pinAnchorY)
        map?.setOnMarkerClickListener { true }
    }

    private fun applyTrail() {
        val g = map ?: return
        val pts = trailPoints
        if (pts == null || pts.size < 2) {
            polyline?.remove()
            polyline = null
            return
        }
        val pl = polyline
        if (pl == null) {
            polyline = g.addPolyline(
                PolylineOptions()
                    .addAll(pts)
                    .color(TRAIL_COLOR.toInt())
                    .width(3f * density)
                    .startCap(RoundCap())
                    .endCap(RoundCap())
                    .jointType(com.google.android.gms.maps.model.JointType.ROUND)
                    .zIndex(0f)
            )
        } else {
            pl.points = pts
        }
    }

    private fun applyMapType() {
        map?.mapType = when (mapTypeName) {
            "hybrid" -> GoogleMap.MAP_TYPE_HYBRID
            "satellite" -> GoogleMap.MAP_TYPE_SATELLITE
            else -> GoogleMap.MAP_TYPE_NORMAL
        }
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun applyShowsUser() {
        val g = map ?: return
        try {
            g.isMyLocationEnabled = showsUser && hasLocationPermission()
            g.uiSettings.isMyLocationButtonEnabled = false
        } catch (e: SecurityException) {
            Log.w(TAG, "my location denied", e)
        }
    }

    /** Frames the shared point and the user together; falls back to a recenter. */
    @Suppress("DEPRECATION")
    private fun showBoth() {
        val g = map ?: return
        val user = try {
            if (g.isMyLocationEnabled) g.myLocation else null
        } catch (_: Throwable) {
            null
        }
        if (user == null) {
            g.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(lat, lng), initialZoom))
            return
        }
        val bounds = LatLngBounds.Builder()
            .include(LatLng(lat, lng))
            .include(LatLng(user.latitude, user.longitude))
            .build()
        g.animateCamera(CameraUpdateFactory.newLatLngBounds(bounds, dp(BOTH_PAD_DP)))
    }

    private fun applyStyle() {
        try {
            map?.setMapStyle(if (dark) MapStyleOptions(MapStyles.DARK_JSON) else null)
        } catch (t: Throwable) {
            Log.w(TAG, "style failed", t)
        }
    }

    /** Adds, moves or removes the accuracy circle to match [accuracyM]. */
    private fun syncCircle(center: LatLng) {
        val g = map ?: return
        val radius = accuracyM
        if (radius == null || radius <= 0) {
            circle?.remove()
            circle = null
            return
        }
        val c = circle
        if (c == null) {
            circle = g.addCircle(
                CircleOptions()
                    .center(center)
                    .radius(radius)
                    .fillColor(ACCURACY_FILL)
                    .strokeColor(ACCURACY_STROKE)
                    .strokeWidth(2f)
                    .zIndex(1f)
            )
        } else {
            c.center = center
            c.radius = radius
        }
    }

    private fun update(newLat: Double, newLng: Double, accuracy: Double?, follow: Boolean) {
        accuracyM = accuracy
        lat = newLat
        lng = newLng
        val target = LatLng(newLat, newLng)
        val g = map
        val m = marker
        mover?.cancel()
        mover = null
        if (g == null || m == null) return  // onMapReady will draw the latest
        syncCircle(m.position)
        val from = m.position
        val animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = MOVE_MS
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                if (disposed) return@addUpdateListener
                val t = it.animatedValue as Float
                val p = LatLng(
                    from.latitude + (target.latitude - from.latitude) * t,
                    from.longitude + (target.longitude - from.longitude) * t,
                )
                m.position = p
                circle?.center = p
            }
        }
        mover = animator
        animator.start()
        // newLatLng keeps the zoom the user has chosen.
        if (follow) g.animateCamera(CameraUpdateFactory.newLatLng(target))
    }

    override fun getView(): View = mapView

    override fun dispose() {
        if (disposed) return
        disposed = true
        main.removeCallbacks(readyFallback)
        channel.setMethodCallHandler(null)
        mover?.cancel()
        mover = null
        try {
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        } catch (t: Throwable) {
            Log.w(TAG, "dispose failed", t)
        }
        marker = null
        circle = null
        polyline = null
        map = null
    }
}
