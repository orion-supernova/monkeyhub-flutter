/// The speech model voice transcripts run on, and where it lives.
///
/// ── Why Whisper small, and not something newer or smaller ──────────────────
///
/// Researched 2026-10-17 against everything shipping on-device: Parakeet v3
/// and its 178 MB "Redux", Moonshine, SenseVoice, Canary, Kyutai, Voxtral,
/// Cohere Transcribe, Qwen3-ASR, Nemotron. The deciding fact is Turkish. Every
/// one of the small modern models leaves it out (Parakeet's 25 languages are
/// all European, and none of them is Turkish; Moonshine is one model per
/// language), and the few that keep it are 600 MB and up. Whisper covers all
/// twelve of the app's languages with automatic detection, and small is
/// the smallest size that is actually usable in the languages this app is
/// spoken in: FLEURS WER 15.9% Turkish / 20.8% Swedish, against 27.5% / 37.4%
/// for base and 42.5% / 52.7% for tiny — which read as broken.
///
/// q5_1 is the 5-bit ggml quantisation: 190 MB instead of 488 for the full
/// precision weights.
///
/// Pinned like a brain (see `brain_spec.dart` for the reasoning): exact bytes
/// from the CDN, digest from the git-lfs oid, and changing it is a release.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../companions/brain_download.dart';

class TranscriptModel {
  const TranscriptModel._({
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
  });

  /// A few bytes standing in for the real thing.
  @visibleForTesting
  const TranscriptModel.test({
    required this.fileName,
    required this.sizeBytes,
    this.url = 'https://example.invalid/model.bin',
    this.sha256 = '',
  });

  /// `ggerganov/whisper.cpp`, ungated, measured 2026-10-17.
  static const TranscriptModel whisperSmall = TranscriptModel._(
    fileName: 'ggml-small-q5_1.bin',
    url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin',
    sizeBytes: 190085487,
    sha256: 'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb',
  );

  static const TranscriptModel current = whisperSmall;

  final String fileName;
  final String url;
  final int sizeBytes;
  final String sha256;

  /// `181 MB`, in the binary megabytes every OS storage screen uses — the same
  /// convention as [BrainSpec.sizeLabel].
  String get sizeLabel => '${(sizeBytes / (1024 * 1024)).round()} MB';

  DownloadTarget get target => DownloadTarget(
        url: url,
        sizeBytes: sizeBytes,
        sha256: sha256,
        file: () => TranscriptStore.instance.modelFile(this),
      );
}

/// `<support>/transcripts/` — the model, its partial, and the transcript cache.
///
/// Application SUPPORT for the same reason as the brains: large,
/// re-downloadable, never in the Files app or an iCloud backup. Its own
/// directory rather than `companions/brains`, whose sweep deletes every file
/// the brain catalog does not name.
class TranscriptStore {
  TranscriptStore._();
  static final TranscriptStore instance = TranscriptStore._();

  Directory? _dir;

  /// Tests point this at a temp directory.
  Directory? debugDir;

  Future<Directory> dir() async {
    final override = debugDir;
    if (override != null) return override;
    final cached = _dir;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    return _dir = Directory('${support.path}/transcripts');
  }

  Future<File> modelFile(TranscriptModel m) async =>
      File('${(await dir()).path}/${m.fileName}');

  Future<File> cacheFile() async =>
      File('${(await dir()).path}/transcripts.json');

  Future<bool> isInstalled(TranscriptModel m) async {
    try {
      final f = await modelFile(m);
      return await f.exists() && await f.length() == m.sizeBytes;
    } catch (_) {
      return false;
    }
  }

  /// Everything in the directory: model, partial, transcripts.
  Future<int> bytesUsed() async {
    try {
      final d = await dir();
      if (!await d.exists()) return 0;
      var total = 0;
      await for (final e in d.list()) {
        if (e is File) {
          try {
            total += await e.length();
          } catch (_) {}
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Deletes the model and any partial of it. Transcripts already made stay —
  /// they are a few bytes each and the reason the model was downloaded.
  Future<int> deleteModel(TranscriptModel m) async {
    var freed = 0;
    final t = m.target;
    for (final f in [await modelFile(m), await t.partFile(), await t.resumeFile()]) {
      try {
        if (await f.exists()) {
          freed += await f.length();
          await f.delete();
        }
      } catch (_) {}
    }
    return freed;
  }
}
