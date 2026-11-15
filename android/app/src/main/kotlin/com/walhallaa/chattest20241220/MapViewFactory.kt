package com.walhallaa.chattest20241220

import android.animation.ValueAnimator
import android.content.Context
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
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions
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
    private var disposed = false

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
                        result.success(null)
                    }
                    "recenter" -> {
                        map?.animateCamera(
                            CameraUpdateFactory.newLatLngZoom(LatLng(lat, lng), initialZoom)
                        )
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
        // Default red pin, tinted teal (hue 174).
        marker = googleMap.addMarker(
            MarkerOptions()
                .position(LatLng(lat, lng))
                .icon(BitmapDescriptorFactory.defaultMarker(174f))
        )
        syncCircle(LatLng(lat, lng))
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
        map = null
    }
}
