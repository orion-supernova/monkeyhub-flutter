package com.walhallaa.chattest20241220

import android.app.Activity
import android.os.Bundle
import android.view.ViewGroup
import android.view.WindowManager
import androidx.annotation.OptIn
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

/// Full-screen system video player, launched from MainActivity's
/// `monkeyhub/video` channel (see NativeVideoPlayer on the Dart side).
///
/// ExoPlayer's PlayerView rather than a Dart transport bar over a
/// `video_player` texture: scrubbing, the buffered-range track, double-tap
/// seek, the volume HUD, Cast, and TalkBack labels are all things this gets
/// for free and in the user's language, and all things a hand-rolled control
/// strip gets subtly wrong.
///
/// A separate activity, not a platform view inside Flutter, because a video
/// that has taken over the screen should also take over the back button, the
/// system bars, and the task's recents entry — which a widget in the Flutter
/// tree cannot do.
///
/// Plain `Activity` (not FlutterActivity, not AppCompatActivity): this holds no
/// Dart state and never talks back to the engine, so attaching one would only
/// buy a second engine attach to get wrong.
@OptIn(UnstableApi::class)
class VideoPlayerActivity : Activity() {
    companion object {
        const val EXTRA_URL = "url"

        /// Mirrors the FLAG_SECURE the Flutter window carries while capture
        /// protection is on. Set per-window on Android, so a new activity
        /// starts unprotected unless it asks — the exact gap an ephemeral
        /// room's video would otherwise fall through.
        const val EXTRA_SECURE = "secure"
    }

    private var player: ExoPlayer? = null
    private var playerView: PlayerView? = null

    /// Playback position across a configuration change we didn't ask for.
    /// The manifest declares configChanges for the usual suspects, but a
    /// locale change or a resource swap still rebuilds us, and restarting the
    /// video from zero is the most annoying possible response to a rotation.
    private var resumePosition = 0L
    private var resumePlaying = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent.getBooleanExtra(EXTRA_SECURE, false)) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
        }

        val url = intent.getStringExtra(EXTRA_URL)
        if (url.isNullOrBlank()) {
            finish()
            return
        }

        savedInstanceState?.let {
            resumePosition = it.getLong("position", 0L)
            resumePlaying = it.getBoolean("playing", true)
        }

        val view = PlayerView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            keepScreenOn = true
        }
        playerView = view
        setContentView(view)

        // targetSdk 35+ enforces edge-to-edge and ignores the window-fullscreen
        // theme attribute, so hiding the bars has to happen here. Transient-by-
        // swipe rather than a hard hide: the user still needs a way back to the
        // status bar without leaving the video.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, view).apply {
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }

        val exo = ExoPlayer.Builder(this).build()
        player = exo
        view.player = exo
        exo.setMediaItem(MediaItem.fromUri(url))
        exo.seekTo(resumePosition)
        exo.playWhenReady = resumePlaying
        exo.prepare()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        player?.let {
            outState.putLong("position", it.currentPosition)
            outState.putBoolean("playing", it.playWhenReady)
        }
    }

    /// Audio keeps playing over the transcript if we don't stop here — the
    /// activity is only *stopped*, not destroyed, when the user swipes home or
    /// gets a call, and ExoPlayer has no opinion about being off screen.
    override fun onStop() {
        super.onStop()
        player?.playWhenReady = false
    }

    override fun onDestroy() {
        playerView?.player = null
        player?.release()
        player = null
        playerView = null
        super.onDestroy()
    }
}
