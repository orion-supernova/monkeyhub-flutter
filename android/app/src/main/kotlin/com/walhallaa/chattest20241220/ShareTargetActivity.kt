package com.walhallaa.chattest20241220

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import java.util.concurrent.Executors

/// The app's door in the system share sheet.
///
/// ### Why this is not MainActivity
///
/// [MainActivity.applyAlternateIcon] DISABLES `.MainActivity` whenever one of
/// the seventeen `<activity-alias>` launcher icons is the active one. A
/// disabled component resolves to nothing — so an `ACTION_SEND` filter declared
/// on MainActivity would make the app vanish from the share sheet for every
/// user who picked a themed icon, which is exactly the population most likely
/// to notice. This activity is never enabled or disabled by anything, so the
/// share entry is stable no matter which mark is on the home screen.
///
/// It is also what `res/xml/share_targets.xml` names as the `targetClass` for
/// direct share, for the same reason: a `<share-target>` pointing at a
/// component that may be disabled is a suggestion row that intermittently
/// disappears.
///
/// ### What it does
///
/// Nothing visible. It copies the shared content out of the sender's provider
/// while the read grant is still live (see [ShareIntake]), parks the result,
/// launches the app the same way a notification tap does, and finishes. The
/// theme is translucent and there is no layout, so the only thing the user sees
/// is the share sheet dismissing and MonkeyHub opening.
class ShareTargetActivity : Activity() {

    companion object {
        private const val TAG = "ShareTarget"

        /// One thread, not a pool. Two shares cannot be in flight at once (the
        /// sheet is modal), and a single-threaded executor means a second one
        /// queues behind the first rather than racing it for the same staging
        /// directory.
        private val worker = Executors.newSingleThreadExecutor()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val incoming = intent
        if (incoming == null) {
            finish()
            return
        }
        // Off the main thread: this reads and re-writes the whole attachment,
        // which for a video is tens of megabytes. The activity stays alive (and
        // invisible) until it lands, which is what keeps the content:// read
        // grant valid for the duration — it is scoped to THIS activity, and
        // finishing first would revoke it mid-copy.
        worker.execute {
            val payload = runCatching { ShareIntake.read(applicationContext, incoming) }
                .onFailure { Log.w(TAG, "share read failed: ${it.message}") }
                .getOrNull()
            runOnUiThread { handOff(payload) }
        }
    }

    private fun handOff(payload: Map<String, Any?>?) {
        if (isFinishing || isDestroyed) return
        if (payload == null) {
            // Nothing readable came through. Raising the app to show an empty
            // chat picker would be worse than doing nothing.
            finish()
            return
        }
        ShareIntake.offer(payload)

        // MUST resolve the launcher intent rather than naming MainActivity:
        // `applyAlternateIcon` disables that component whenever an alias is the
        // active launcher entry, and an explicit intent to a disabled component
        // throws. Same call, and same reason, as `ChatNotifications.contentIntent`.
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        if (launch == null) {
            Log.e(TAG, "no launch intent for $packageName")
            finish()
            return
        }
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        launch.putExtra(ShareIntake.EXTRA_HAS_SHARE, true)
        startActivity(launch)
        // No transition of our own: this activity was never visible, so the
        // default one would animate a blank frame in between the share sheet
        // dismissing and the app appearing. Version-guarded because
        // `overridePendingTransition` was deprecated in favour of
        // `overrideActivityTransition` at API 34, and the deprecated call still
        // has to be there for everything below it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
        finish()
    }
}
