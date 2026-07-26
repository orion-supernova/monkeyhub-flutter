package com.walhallaa.chattest20241220

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

/// The runtime permissions that must already be held before ANY native call UI
/// is allowed to appear.
///
/// Why this is load-bearing rather than a nicety: flutter_callkit_incoming 3.x
/// starts a foreground service typed `phoneCall|microphone[|camera]` for both
/// ACTION_CALL_START (outgoing) and ACTION_CALL_ACCEPT (answer). From Android 14
/// — and this app is targetSdk 34, so the rules apply — an FGS typed
/// `microphone` requires RECORD_AUDIO to be granted at `startForeground` time,
/// and `camera` requires CAMERA. The plugin's call
/// (CallkitNotificationService.startForeground) is annotated
/// @SuppressLint("MissingPermission") and is NOT wrapped in try/catch, so a
/// missing grant throws SecurityException straight out of
/// Service.onStartCommand and takes the whole process down.
///
/// Nothing on the Dart side can catch that: it happens in a different Android
/// component, asynchronously, after `startCall`/the Accept broadcast has already
/// returned. The only defence is to never let the service start without the
/// grants — which is what this object is consulted for, from both
/// MainActivity (the Dart-facing channel) and CallFcmService (the killed-app
/// ring path, where no Dart is running at all).
object CallPermissions {

    /// True when a call of this kind may safely bring up the native UI.
    fun granted(context: Context, video: Boolean): Boolean =
        missing(context, video).isEmpty()

    /// Exactly the permissions still needed for this call kind, in request
    /// order. Audio calls never ask for CAMERA — requesting a permission the
    /// call does not need trains users to say no.
    fun missing(context: Context, video: Boolean): List<String> {
        val out = mutableListOf<String>()
        if (!has(context, Manifest.permission.RECORD_AUDIO)) {
            out += Manifest.permission.RECORD_AUDIO
        }
        if (video && !has(context, Manifest.permission.CAMERA)) {
            out += Manifest.permission.CAMERA
        }
        return out
    }

    private fun has(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED
}
