package com.walhallaa.chattest20241220

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import androidx.annotation.OptIn
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.recyclerview.widget.RecyclerView
import androidx.viewpager2.widget.ViewPager2
import java.net.URL
import java.util.concurrent.Executors

/// The swipeable native gallery, Android's half of `presentGallery` on the
/// `monkeyhub/video` channel (see NativeVideoPlayer on the Dart side).
///
/// The same idea as [VideoPlayerActivity], one level up: videos keep the
/// platform's own PlayerView (scrubbing, the buffered track, double-tap seek,
/// TalkBack labels), and the user can swipe left and right through the rest of
/// the chat's media instead of being stuck on one clip. Photos sit between
/// them as plain fitted images.
///
/// One ExoPlayer for the whole gallery, moved to whichever video page is in
/// view, rather than a player per page: decoders are a scarce resource on
/// Android, and a pager keeps three pages alive at once.
@OptIn(UnstableApi::class)
class VideoGalleryActivity : Activity() {
    companion object {
        const val EXTRA_URLS = "urls"
        const val EXTRA_KINDS = "kinds"
        const val EXTRA_POSTERS = "posters"
        const val EXTRA_INDEX = "index"

        /// Told which page the gallery closed on, so the Flutter screen
        /// underneath can land there. Set by MainActivity before launching,
        /// called once from [finish].
        var onClosed: ((Int) -> Unit)? = null
    }

    private data class Item(val video: Boolean, val url: String, val poster: String?)

    private lateinit var items: List<Item>
    private var index = 0
    private var player: ExoPlayer? = null

    /// The page whose video is loaded in [player], so re-attaching the same
    /// page (a rebind, a second callback) does not restart it.
    private var loadedIndex = -1
    private var pager: ViewPager2? = null

    /// The PlayerView of each bound video page, by position, so the shared
    /// player can be moved onto the one that becomes current.
    private val playerViews = HashMap<Int, PlayerView>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val urls = intent.getStringArrayListExtra(EXTRA_URLS) ?: arrayListOf()
        val kinds = intent.getStringArrayListExtra(EXTRA_KINDS) ?: arrayListOf()
        val posters = intent.getStringArrayListExtra(EXTRA_POSTERS) ?: arrayListOf()
        items = urls.indices.map { i ->
            Item(
                video = kinds.getOrNull(i) == "video",
                url = urls[i],
                poster = posters.getOrNull(i)?.takeIf { it.isNotEmpty() },
            )
        }
        if (items.isEmpty()) {
            finish()
            return
        }
        index = (savedInstanceState?.getInt("index")
            ?: intent.getIntExtra(EXTRA_INDEX, 0)).coerceIn(0, items.size - 1)

        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        val pagerView = ViewPager2(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            adapter = GalleryAdapter()
            offscreenPageLimit = 1
        }
        pager = pagerView
        root.addView(pagerView)

        val close = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.WHITE)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(90, 0, 0, 0))
            }
            contentDescription = getString(android.R.string.cancel)
            setOnClickListener { finish() }
        }
        val size = dp(40)
        root.addView(close, FrameLayout.LayoutParams(size, size).apply {
            gravity = Gravity.TOP or Gravity.START
            topMargin = dp(40)
            leftMargin = dp(16)
        })

        setContentView(root)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, root).apply {
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }

        player = ExoPlayer.Builder(this).build()
        pagerView.setCurrentItem(index, false)
        pagerView.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
            override fun onPageSelected(position: Int) {
                index = position
                playCurrent()
            }
        })
        // The page views are bound a frame after setContentView.
        pagerView.post { playCurrent() }
    }

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    /// Moves the shared player onto the current page if it is a video, and
    /// stops it otherwise, so a photo page is always silent.
    private fun playCurrent() {
        val exo = player ?: return
        playerViews.values.forEach { it.player = null }
        val item = items[index]
        if (!item.video) {
            exo.pause()
            return
        }
        val view = playerViews[index] ?: return
        view.player = exo
        if (loadedIndex != index) {
            loadedIndex = index
            exo.setMediaItem(MediaItem.fromUri(item.url))
            exo.prepare()
        }
        exo.playWhenReady = true
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt("index", index)
    }

    /// Audio keeps playing over the app otherwise: the activity is only
    /// stopped, not destroyed, when the user goes home.
    override fun onStop() {
        super.onStop()
        player?.playWhenReady = false
    }

    override fun finish() {
        onClosed?.invoke(index)
        onClosed = null
        super.finish()
    }

    override fun onDestroy() {
        playerViews.values.forEach { it.player = null }
        playerViews.clear()
        player?.release()
        player = null
        super.onDestroy()
    }

    // ─────────────────────────────── pages ───────────────────────────────

    private class Holder(val frame: FrameLayout) : RecyclerView.ViewHolder(frame)

    private inner class GalleryAdapter : RecyclerView.Adapter<Holder>() {
        override fun getItemCount() = items.size

        override fun getItemViewType(position: Int) = if (items[position].video) 1 else 0

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
            val frame = FrameLayout(parent.context).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
                setBackgroundColor(Color.BLACK)
            }
            return Holder(frame)
        }

        override fun onBindViewHolder(holder: Holder, position: Int) {
            holder.frame.removeAllViews()
            playerViews.entries.removeAll { it.value.parent == holder.frame }
            val item = items[position]
            val image = ImageView(holder.frame.context).apply {
                scaleType = ImageView.ScaleType.FIT_CENTER
                layoutParams = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
            }
            if (item.video) {
                // The poster under the player, visible until the first frame.
                item.poster?.let { GalleryImages.load(it, image) }
                holder.frame.addView(image)
                val view = PlayerView(holder.frame.context).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
                    setShutterBackgroundColor(Color.TRANSPARENT)
                    keepScreenOn = true
                }
                holder.frame.addView(view)
                playerViews[position] = view
                if (position == index) view.post { playCurrent() }
            } else {
                holder.frame.addView(image)
                GalleryImages.load(item.url, image)
            }
        }

        override fun onViewRecycled(holder: Holder) {
            playerViews.entries.removeAll { it.value.parent == holder.frame }
            for (i in 0 until holder.frame.childCount) {
                (holder.frame.getChildAt(i) as? PlayerView)?.player = null
            }
        }
    }
}

/// Loads a picture for a gallery page, from disk or the network, decoded off
/// the main thread at roughly screen size and delivered on it.
private object GalleryImages {
    private val pool = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())
    private val cache = object : LruCache<String, Bitmap>(32 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    fun load(url: String, into: ImageView) {
        into.tag = url
        cache.get(url)?.let {
            into.setImageBitmap(it)
            return
        }
        into.setImageDrawable(null)
        val maxEdge = into.resources.displayMetrics.let {
            maxOf(it.widthPixels, it.heightPixels)
        }
        pool.execute {
            val bitmap = try {
                decode(read(url), maxEdge)
            } catch (_: Throwable) {
                null
            }
            if (bitmap != null) cache.put(url, bitmap)
            main.post {
                // The view may have been recycled onto another page meanwhile.
                if (into.tag == url) into.setImageBitmap(bitmap)
            }
        }
    }

    private fun read(url: String): ByteArray {
        val uri = Uri.parse(url)
        return if (uri.scheme == "file") {
            java.io.File(uri.path ?: "").readBytes()
        } else {
            URL(url).openStream().use { it.readBytes() }
        }
    }

    private fun decode(bytes: ByteArray, maxEdge: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxEdge) {
            sample *= 2
        }
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
    }
}
