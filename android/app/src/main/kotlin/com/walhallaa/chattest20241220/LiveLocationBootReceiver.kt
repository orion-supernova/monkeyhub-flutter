package com.walhallaa.chattest20241220

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restarts a live share that a reboot interrupted.
 *
 * ## Why this reads the share off disk rather than asking Dart
 *
 * The answer is almost always "there is nothing to restart" — most reboots
 * happen when nobody is sharing anything — and the cost of finding that out by
 * booting a Flutter engine is seconds of CPU and a notification the user did not
 * need to see, on every single boot, forever. Three `SharedPreferences` reads
 * cost a millisecond.
 *
 * That is why `LiveShareResumeStore` uses `shared_preferences` rather than the
 * Keychain-backed store the session lives in: the legacy `SharedPreferences`
 * API writes a plain XML file that this class can read with no Dart in the
 * picture. The keys below are a cross-language contract with that file — the
 * `flutter.` prefix is what the plugin adds on this platform —
 * and `test/live_share_resume_store_test.dart` pins the Dart half of it.
 *
 * ## What it deliberately does not decide
 *
 * Only whether the share is *obviously* over. Everything else — whether the
 * message still exists, whether it was stopped from another handset, whether
 * the account that started it is still signed in here — is the server's call,
 * and it makes it on the first `messages:updateLiveLocation` the resumed
 * publisher sends. A `false` there stops the publisher and erases the handle.
 * So this is allowed to be optimistic; the cost of a wrong guess is one refused
 * mutation.
 *
 * ## Honest limits
 *
 * `BOOT_COMPLETED` is not delivered at all until the user unlocks the device
 * once after a reboot on modern Android, so a phone that reboots in a pocket
 * resumes when it is next unlocked, not before. And OEM power managers on
 * Xiaomi, Huawei and Samsung builds refuse the broadcast to apps the user has
 * not exempted by hand. Neither is fixable from here, and neither costs
 * correctness: the share ends on time server-side either way, and viewers see it
 * STALE rather than seeing a wrong position.
 */
class LiveLocationBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "LiveLocationBoot"

        /** `shared_preferences`'s Android file name and key prefix. Not ours to
         * choose; changing the Dart side to the newer `SharedPreferencesAsync`
         * API would move the data into DataStore and silently break this. */
        private const val PREFS = "FlutterSharedPreferences"
        private const val PREFIX = "flutter."

        private const val KEY_EXPIRES_AT = PREFIX + "mh.liveShare.expiresAt"
        private const val KEY_MESSAGE_ID = PREFIX + "mh.liveShare.messageId"
        private const val KEY_TITLE = PREFIX + "mh.liveShare.title"
        private const val KEY_BODY = PREFIX + "mh.liveShare.body"
        private const val KEY_STOP_LABEL = PREFIX + "mh.liveShare.stopLabel"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val prefs = runCatching {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        }.getOrNull() ?: return

        // Read first and gated on, mirroring the Dart side: the deadline is
        // written last and read first, so a torn write reads as "nothing to do"
        // rather than as a share with no stopping condition.
        val expiresAt = runCatching { prefs.getLong(KEY_EXPIRES_AT, 0L) }.getOrDefault(0L)
        if (expiresAt <= 0L) return
        val messageId = prefs.getString(KEY_MESSAGE_ID, null).orEmpty()
        if (messageId.isEmpty()) return

        if (expiresAt <= System.currentTimeMillis()) {
            Log.i(TAG, "a share was running, but it expired while the phone was off")
            return
        }

        Log.i(TAG, "restarting a live share that has ${expiresAt - System.currentTimeMillis()}ms left")
        LiveLocationService.start(
            context,
            // The copy the share was started with, so the notification comes
            // back in the language the user chose rather than in whatever the
            // device locale says now.
            title = prefs.getString(KEY_TITLE, null).orEmpty(),
            body = prefs.getString(KEY_BODY, null).orEmpty(),
            stopLabel = prefs.getString(KEY_STOP_LABEL, null) ?: "Stop",
            expiresAtMs = expiresAt,
        )
    }
}
