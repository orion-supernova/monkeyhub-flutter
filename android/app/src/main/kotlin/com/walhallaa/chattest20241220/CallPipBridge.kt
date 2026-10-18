package com.walhallaa.chattest20241220

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.util.Rational
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * `monkeyhub/call_pip` on Android: the video call's Picture in Picture
 * window. Dart's `CallPip` arms it while a call has a picture on it and
 * disarms it when the picture or the call goes.
 *
 * Armed, leaving the app shrinks the activity into PiP instead of hiding
 * it: on Android 12+ by `setAutoEnterEnabled` (the system enters PiP on the
 * home gesture itself, with the smooth transition), on 8-11 from
 * [onUserLeaveHint]. While in PiP Dart draws only the call's picture
 * (`SystemPipView`), told so by `pipModeChanged`.
 *
 * Being in PiP keeps the activity visible, so the process keeps its
 * foreground standing for the camera and microphone as well; the call's
 * foreground service covers the case where the user closes the window.
 *
 * Like the other bridges, re-bound to whichever activity registers last;
 * the params live on the activity, so they are re-applied on every bind.
 */
object CallPipBridge {
    private const val TAG = "MHCallPip"

    private var activity: WeakReference<Activity>? = null
    private var channel: MethodChannel? = null
    private var armed = false

    fun register(activity: Activity, engine: FlutterEngine) {
        this.activity = WeakReference(activity)
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, "monkeyhub/call_pip")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "arm", "update" -> {
                    armed = true
                    apply()
                    result.success(null)
                }
                "disarm" -> {
                    val wasArmed = armed
                    armed = false
                    apply()
                    // The call is over (or has no picture left) while the
                    // window is up: close the window rather than leave a
                    // shrunken app on the screen. The task goes behind
                    // whatever the user was doing, as the window did.
                    val a = this.activity?.get()
                    if (wasArmed && a != null && inPip(a)) {
                        try {
                            a.moveTaskToBack(false)
                        } catch (e: Exception) {
                            Log.w(TAG, "moveTaskToBack: $e")
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        apply()
    }

    private fun supported(a: Activity): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            a.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun inPip(a: Activity): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && a.isInPictureInPictureMode

    private fun params(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val b = PictureInPictureParams.Builder().setAspectRatio(Rational(9, 16))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            b.setAutoEnterEnabled(armed)
            // Video: the system crossfades rather than stretching the
            // last frame while it resizes.
            b.setSeamlessResizeEnabled(false)
        }
        return b.build()
    }

    private fun apply() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val a = activity?.get() ?: return
        if (!supported(a)) return
        val p = params() ?: return
        try {
            a.setPictureInPictureParams(p)
        } catch (e: Exception) {
            // IllegalStateException when the activity does not support
            // PiP (a manifest without the flag, a device policy).
            Log.w(TAG, "setPictureInPictureParams: $e")
        }
    }

    /// Android 8-11 have no auto-enter: the activity enters PiP itself
    /// when the user leaves it (home, recents), never on a dialog or a
    /// notification shade.
    fun onUserLeaveHint(a: Activity) {
        if (!armed || Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!supported(a) || inPip(a)) return
        val p = params() ?: return
        try {
            a.enterPictureInPictureMode(p)
        } catch (e: Exception) {
            Log.w(TAG, "enterPictureInPictureMode: $e")
        }
    }

    fun onPictureInPictureModeChanged(inPip: Boolean) {
        try {
            channel?.invokeMethod("pipModeChanged", inPip)
        } catch (e: Exception) {
            Log.w(TAG, "pipModeChanged: $e")
        }
    }
}
