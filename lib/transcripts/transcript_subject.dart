/// One message's transcript, as the UI addresses it: which message, what
/// kind, and how to get its file onto the disk.
///
/// ── Why this exists ────────────────────────────────────────────────────────
///
/// A voice note, a video and a round video note all want the same thing from
/// the transcriber: "the words in this file". Everything that differs between
/// them is here, in one place — which cache holds the file, what a missing
/// audio track means, which languages are likely — so the bubbles stop
/// carrying transcript code of their own. A bubble builds a subject and hands
/// it to the shared button and slab (`voice_transcript.dart`).
///
/// Transcripts are keyed by storage id and live only on this device.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../backend/chat_api.dart';
import '../media/audio_file_cache.dart';
import '../media/file_url_cache.dart';
import '../media/video_file_cache.dart';
import 'language_hint.dart';
import 'voice_transcriber.dart';

@immutable
class TranscriptSubject {
  const TranscriptSubject({
    required this.storageId,
    required this.media,
    required this.resolveFile,
    this.roomId,
    this.senderId,
  });

  /// The message's file, which is also the cache key. Identical files share a
  /// transcript; a forwarded copy with the same id is not transcribed twice.
  final String storageId;
  final TranscriptMedia media;

  /// A local path the speech engines can read. Downloads on a miss.
  final Future<String> Function() resolveFile;

  /// For [VoiceLanguageHints]: what language the sender writes in this room.
  final String? roomId;
  final String? senderId;

  /// A subject for a stored message file, resolved through the cache that
  /// already holds that kind of media — so something already listened to or
  /// watched is transcribed without another download.
  factory TranscriptSubject.stored({
    required ChatApi api,
    required String storageId,
    required TranscriptMedia media,
    String? roomId,
    String? senderId,
  }) {
    Future<String?> url() =>
        FileUrlCache.instance.resolve(storageId, () => api.getFileUrl(storageId));
    return TranscriptSubject(
      storageId: storageId,
      media: media,
      roomId: roomId,
      senderId: senderId,
      resolveFile: media == TranscriptMedia.voice
          ? () => AudioFileCache.instance.resolve(storageId, url)
          : () => VideoFileCache.instance.resolve(storageId, url),
    );
  }

  /// Null where the platform cannot transcribe (the browser).
  TranscriptHandle? get handle => VoiceTranscriber.instance.supported
      ? VoiceTranscriber.instance.handleFor(storageId)
      : null;

  /// What the button does: opens or folds, and on the first open starts the
  /// work. See [VoiceTranscriber.toggle].
  void toggle(BuildContext context) {
    final guess = VoiceLanguageHints.guess(roomId: roomId, senderId: senderId);
    unawaited(VoiceTranscriber.instance.toggle(
      storageId,
      resolveFile,
      media: media,
      languages: [?guess, Localizations.localeOf(context).toLanguageTag()],
    ));
  }
}
