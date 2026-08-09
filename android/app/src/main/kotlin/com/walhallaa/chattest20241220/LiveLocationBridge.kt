package com.walhallaa.chattest20241220

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of `monkeyhub/live_location`.
 *
 * An object rather than a class because it has two hosts and one identity.
 * MainActivity registers it when the app is opened normally; [LiveLocationService]
 * registers it on the headless engine it boots after a reboot. Both must reach
 * the same channel, because the STOP button on the notification has to get to
 * Dart whichever of the two brought the isolate up.
 *
 * What lives here is only what `geolocator` cannot do — see
 * `lib/services/live_location_platform.dart` for the same list from the Dart
 * side. Continuous background updates are the plugin's job and need nothing
 * from this file; the foreground service, the stoppable notification and the
 * background-permission escalation are ours.
 */
object LiveLocationBridge {

    private const val TAG = "LiveLocationBridge"
    private const val CHANNEL = "monkeyhub/live_location"

    /** Arbitrary, and must not collide with MainActivity's own two. */
    const val BACKGROUND_PERMISSION_REQUEST = 0x0CA3

    @Volatile
    private var channel: MethodChannel? = null

    /**
     * A STOP press that arrived before Dart was listening.
     *
     * The same "native buffers, Dart drains" pattern the notification and VoIP
     * channels in this app already use, and needed for the same reason: pressing
     * STOP on a share whose process was killed launches the service, which boots
     * an engine, which takes a second or two to install a handler. Without this
     * the press would land on nothing and the share would keep running
     * server-side — for someone who just pressed stop.
     */
    @Volatile
    private var pendingUserStop = false

    /**
     * The activity, when there is one. Only [requestBackgroundPermission] needs
     * it, and only below Android 11; everything else works from an application
     * context so it keeps working with no UI at all.
     */
    @Volatile
    private var activity: Activity? = null

    fun attachActivity(a: Activity?) {
        activity = a
    }

    /// Whether [a] is the activity currently held. Asked by `onDestroy` so a
    /// dying activity does not clear a live one's registration — two
    /// MainActivities in one process is routine in this app (see
    /// `provideFlutterEngine`), and their destroy/create order is not.
    fun activityIsCurrent(a: Activity): Boolean = activity === a

    fun register(engine: FlutterEngine, context: Context) {
        val appContext = context.applicationContext
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "authorizationTier" -> result.success(tier(appContext))

                "requestAlwaysAuthorization" ->
                    requestBackgroundPermission(appContext, result)

                "startSharing" -> {
                    LiveLocationService.start(
                        appContext,
                        title = call.argument<String>("title").orEmpty(),
                        body = call.argument<String>("body").orEmpty(),
                        stopLabel = call.argument<String>("stopLabel") ?: "Stop",
                        expiresAtMs = call.argument<Number>("expiresAtMs")?.toLong() ?: 0L,
                    )
                    result.success(null)
                }

                "stopSharing" -> {
                    LiveLocationService.stop(appContext)
                    result.success(null)
                }

                // iOS-only concept — Android is never launched *by* location,
                // it is launched by a boot broadcast that this app handles
                // explicitly. Answered rather than notImplemented so the Dart
                // side needs no platform check.
                "wasLaunchedForLocation" -> result.success(false)

                else -> result.notImplemented()
            }
        }
        channel = ch
        // Drained on every registration, not just the first: the buffered press
        // may have arrived while the previous engine was being torn down.
        if (pendingUserStop) {
            pendingUserStop = false
            Handler(Looper.getMainLooper()).post {
                ch.invokeMethod("stopRequested", null)
            }
        }
    }

    /**
     * The notification's STOP button, on its way to Dart.
     *
     * Returns whether Dart actually heard it. False means there is no isolate
     * yet — a STOP pressed within a second or two of a boot restart — and the
     * press has been buffered instead; the caller must then keep the service
     * alive long enough for the engine to come up and drain it. Stopping the
     * service at that moment would take the notification away and leave the
     * share running server-side for its full duration, for somebody who has just
     * pressed stop. That is the worst outcome this feature has, and it is worth
     * the two lines of protocol.
     */
    fun reportUserStop(): Boolean {
        val ch = channel ?: run {
            pendingUserStop = true
            return false
        }
        Handler(Looper.getMainLooper()).post { ch.invokeMethod("stopRequested", null) }
        return true
    }

    /**
     * How much location this app holds, in the three-way vocabulary the Dart
     * side uses.
     *
     * "always" means `ACCESS_BACKGROUND_LOCATION` as well as a foreground one —
     * the Android equivalent of iOS's Always, and the only tier that can survive
     * a reboot. Coarse-only counts as `whenInUse`: a share still runs, the
     * bubble just draws a wider accuracy ring, which is exactly what the user
     * chose when they picked "Approximate".
     */
    fun tier(context: Context): String {
        val fine = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) return "none"

        // Below Android 10 there is no separate background permission: a granted
        // foreground permission IS background access. Reporting "always" there
        // is not a lie, it is the platform.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return "always"

        val background = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_BACKGROUND_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return if (background) "always" else "whenInUse"
    }

    /**
     * Asks for `ACCESS_BACKGROUND_LOCATION`, by whichever route the OS version
     * allows.
     *
     * Two genuinely different flows, and the split is Android's, not ours:
     *
     *  * **Android 10.** A normal runtime dialog with an "Allow all the time"
     *    option. Requested alone, never bundled with the foreground permissions —
     *    Android rejects a request that mixes the two outright.
     *  * **Android 11 and up.** The runtime dialog no longer OFFERS "Allow all
     *    the time". `requestPermissions` here shows nothing and denies. The only
     *    documented route is the app's own settings page, where the user picks
     *    it by hand.
     *
     * Which means this returns the CURRENT tier, not the tier after the user
     * decides — on 11+ there is nothing to wait for, the answer arrives whenever
     * they come back. The Dart side is written for that: a `whenInUse` reply
     * means "carry on with Tier 1", never "failed", and is never re-asked.
     */
    private fun requestBackgroundPermission(context: Context, result: MethodChannel.Result) {
        val current = tier(context)
        if (current == "always" || current == "none") {
            // "none" first: asking for background location before the foreground
            // one is granted is a request Android refuses, and the room screen
            // has already sent that user down the ordinary permission path.
            result.success(current)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            openAppSettings(context)
            result.success(current)
            return
        }

        val act = activity
        if (act == null) {
            result.success(current)
            return
        }
        runCatching {
            // ActivityCompat rather than Activity.requestPermissions, which is
            // API 23+ and would need a version guard inside a branch that is
            // already guarded on something else. MainActivity's two permission
            // paths use the same helper.
            ActivityCompat.requestPermissions(
                act,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                BACKGROUND_PERMISSION_REQUEST,
            )
        }.onFailure { Log.w(TAG, "background permission request failed: $it") }
        // Answered immediately with the pre-request tier rather than held open
        // for the dialog. The Dart caller uses it only to decide whether to ask
        // the platform for boot-restart behaviour, and it re-reads the tier on
        // every later share; holding a MethodChannel result across a permission
        // dialog is how the other two request paths in this app grew their
        // "cannot complete twice" bugs.
        result.success(current)
    }

    private fun openAppSettings(context: Context) {
        runCatching {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", context.packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        }.onFailure { Log.w(TAG, "could not open app settings: $it") }
    }
}
