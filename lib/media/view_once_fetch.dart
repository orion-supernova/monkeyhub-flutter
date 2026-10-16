import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/enums.dart';

/// Spends the viewer's one look at a view-once message and hands back its
/// bytes, in memory — or null when the look could not be had, in which case
/// whoever made the opener has already told the reader why.
///
/// The one shape every sealed bubble is handed, so the photo tile, the voice
/// pill and the video-note disc all open through [fetchViewOnce] and nothing
/// else; each then decides only how to present what came back.
typedef ViewOnceOpener = Future<Uint8List?> Function();

/// Why a view-once open didn't produce a picture.
enum ViewOnceFailure {
  /// This viewer already had their look. Includes the case where another of
  /// their own devices opened it — the ledger is per account, not per device.
  alreadyViewed,

  /// Burned, deleted, expired, or never armed in the first place.
  gone,

  /// The grant succeeded but the bytes didn't arrive. The look is still spent,
  /// which is why this is reported honestly rather than silently retried
  /// forever — see the note on the retry budget below.
  network,
}

/// What to tell the reader when [failure] stopped them opening a view-once
/// message of [type]. Named per kind, because "this photo" on a voice message
/// is the kind of small wrongness that makes people distrust the rest.
String viewOnceFailureMessage(
  AppLocalizations l10n,
  MessageType type,
  ViewOnceFailure failure,
) =>
    switch (type) {
      MessageType.audio => switch (failure) {
          ViewOnceFailure.alreadyViewed => l10n.roomScreenPlayOnceVoiceAlreadyPlayed,
          ViewOnceFailure.gone => l10n.roomScreenPlayOnceVoiceGone,
          ViewOnceFailure.network => l10n.roomScreenPlayOnceVoiceNetworkError,
        },
      MessageType.videoNote => switch (failure) {
          ViewOnceFailure.alreadyViewed =>
            l10n.roomScreenPlayOnceVideoNoteAlreadyPlayed,
          ViewOnceFailure.gone => l10n.roomScreenPlayOnceVideoNoteGone,
          ViewOnceFailure.network => l10n.roomScreenPlayOnceVideoNoteNetworkError,
        },
      _ => switch (failure) {
          ViewOnceFailure.alreadyViewed => l10n.roomScreenViewOnceAlreadyViewed,
          ViewOnceFailure.gone => l10n.roomScreenViewOnceGone,
          ViewOnceFailure.network => l10n.roomScreenViewOnceNetworkError,
        },
    };

/// Result of trying to open a view-once message: bytes, or a reason.
class ViewOnceResult {
  const ViewOnceResult.ok(this.bytes) : failure = null;
  const ViewOnceResult.failed(this.failure) : bytes = null;

  final Uint8List? bytes;
  final ViewOnceFailure? failure;

  bool get isOk => bytes != null;
}

/// Number of attempts at the byte fetch.
///
/// The nonce stays valid for 120s and the server holds the file for a grace
/// period past the last grant, so retrying inside that window is a genuine
/// second chance at the same look — not a second look. Past it, the honest
/// answer is that the photo is gone.
const _attempts = 3;

/// Spends the viewer's one look and downloads the media into memory.
///
/// The bytes deliberately never reach the persistent caches: no
/// `CachedNetworkImage`, no `FileUrlCache`, no `AudioFileCache`, no
/// `VideoFileCache`. A photo is shown from memory and dropped. A voice message
/// or video note has to be handed to a platform player, which wants a source
/// rather than bytes — see `ViewOnceMedia` for the one short-lived copy that
/// costs, and how it is cleaned up.
Future<ViewOnceResult> fetchViewOnce({
  required ChatRepository repo,
  required String roomId,
  required String messageId,
  http.Client? client,
}) async {
  final grant = await repo.openViewOnce(roomId: roomId, messageId: messageId);
  final nonce = grant.nonce;
  if (nonce == null) {
    return ViewOnceResult.failed(
      grant.alreadyViewed ? ViewOnceFailure.alreadyViewed : ViewOnceFailure.gone,
    );
  }

  final url = repo.viewOnceStreamUrl(messageId: messageId, nonce: nonce);
  final owned = client == null;
  final http.Client c = client ?? http.Client();
  try {
    for (var attempt = 0; attempt < _attempts; attempt++) {
      try {
        final res = await c
            .get(url)
            .timeout(const Duration(seconds: 25));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return ViewOnceResult.ok(res.bodyBytes);
        }
        // 403 is terminal — the nonce is wrong or has expired, and no amount of
        // retrying will mint a new one.
        if (res.statusCode == 403) break;
      } catch (e) {
        debugPrint('view-once fetch attempt ${attempt + 1} failed: $e');
      }
    }
  } finally {
    if (owned) c.close();
  }
  return const ViewOnceResult.failed(ViewOnceFailure.network);
}
