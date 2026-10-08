import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import 'file_url_cache.dart';
import 'native_video_player.dart';
import 'storage/media_image_cache.dart';
import 'video_file_cache.dart';

/// The media around a video, for the native player to swipe through.
///
/// Handed to `FullscreenVideoViewer` by every surface that shows a run of
/// media: the room's shared media grid, the media pager, a chat's photos and
/// videos. Without it the OS player gets one URL and nothing to swipe to.
class VideoGallery {
  const VideoGallery({required this.items, this.onLanded, this.onPresented});

  /// Photos and videos in display order, the tapped video among them.
  final List<ChatMessage> items;

  /// The item the user closed the gallery on, so the screen underneath can
  /// land there too.
  final ValueChanged<ChatMessage>? onLanded;

  /// The native gallery is on screen. A Flutter gallery that opened it (the
  /// media pager) closes itself here, unseen beneath the OS player, so that
  /// closing the player is one close back to where the user started.
  final VoidCallback? onPresented;
}

/// Finds a photo's copy in the image cache. Swapped out under `flutter
/// test`, where the cache's database plugin does not exist.
@visibleForTesting
Future<({String path, int bytes})?> Function(String url) nativeGalleryImageStat =
    MediaImageCache.stat;

/// How many items either side of the tapped one the native gallery carries.
/// Resolving a URL each is a cache hit almost always, but a window keeps a
/// first open of a years-long gallery from waiting on hundreds of lookups.
const int kNativeGalleryRadius = 30;

/// The native pages for [gallery] around [current], and the messages they
/// stand for, index for index. [currentUrl] is what the viewer already
/// resolved for the tapped video (usually its fresh local copy).
///
/// Items that cannot be shown (view-once, gone from storage) are left out
/// rather than failing the whole gallery.
Future<({List<NativeMediaItem> pages, List<ChatMessage> messages, int index})>
    buildNativeGallery({
  required VideoGallery gallery,
  required String currentStorageId,
  required String currentUrl,
  required ChatApi api,
}) async {
  final all = gallery.items;
  var at = all.indexWhere((m) => m.mediaStorageId == currentStorageId);
  if (at < 0) at = 0;
  final from = (at - kNativeGalleryRadius).clamp(0, all.length);
  final to = (at + kNativeGalleryRadius + 1).clamp(0, all.length);
  final window = all.sublist(from, to);

  final built = await Future.wait([
    for (final m in window)
      m.mediaStorageId == currentStorageId
          ? _video(m, api, known: currentUrl)
          : _page(m, api),
  ]);

  final pages = <NativeMediaItem>[];
  final messages = <ChatMessage>[];
  var index = 0;
  for (var i = 0; i < window.length; i++) {
    final page = built[i];
    if (page == null) continue;
    if (window[i].mediaStorageId == currentStorageId) index = pages.length;
    pages.add(page);
    messages.add(window[i]);
  }
  return (pages: pages, messages: messages, index: index);
}

Future<NativeMediaItem?> _page(ChatMessage m, ChatApi api) {
  if (m.viewOnce || m.mediaStorageId == null) return Future.value();
  return switch (m.type) {
    MessageType.video || MessageType.videoNote => _video(m, api),
    MessageType.image => _photo(m.mediaStorageId!, api),
    _ => Future.value(),
  };
}

Future<NativeMediaItem?> _video(ChatMessage m, ChatApi api,
    {String? known}) async {
  final id = m.mediaStorageId;
  if (id == null) return null;
  try {
    final local = await VideoFileCache.instance.lookup(id);
    final url = known ??
        (local != null ? Uri.file(local).toString() : await _remote(id, api));
    if (url == null) return null;
    final poster = m.posterStorageId;
    return NativeMediaItem.video(
      url: url,
      posterUrl: poster == null ? null : await _imageUrl(poster, api),
    );
  } catch (e) {
    debugPrint('native gallery: video $id skipped: $e');
    return null;
  }
}

Future<NativeMediaItem?> _photo(String id, ChatApi api) async {
  try {
    final url = await _imageUrl(id, api);
    return url == null ? null : NativeMediaItem.photo(url: url);
  } catch (e) {
    debugPrint('native gallery: photo $id skipped: $e');
    return null;
  }
}

/// The copy in the image cache when there is one, so a swipe through photos
/// already seen costs no data; the remote URL otherwise.
Future<String?> _imageUrl(String id, ChatApi api) async {
  final remote = await _remote(id, api);
  if (remote == null) return null;
  // Bounded: a cache lookup is a database read, and a gallery must never
  // wait on one. Past the limit the photo just loads from the network.
  final hit = await nativeGalleryImageStat(remote)
      .timeout(const Duration(milliseconds: 800), onTimeout: () => null);
  return hit == null ? remote : Uri.file(hit.path).toString();
}

Future<String?> _remote(String id, ChatApi api) => FileUrlCache.instance
    .resolve(id, () => api.getFileUrl(id))
    .timeout(const Duration(seconds: 8), onTimeout: () => null);
