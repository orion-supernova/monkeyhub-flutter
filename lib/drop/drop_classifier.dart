import 'package:flutter/foundation.dart';

import '../media/file_meta.dart';
import '../models/enums.dart';
import 'drop_item.dart';

/// What the verdict chip is allowed to say, in increasing order of alarm.
///
/// Three, not two, and the middle one is the whole feature. "This will send"
/// and "this will not send" are easy; the interesting answer is "this will
/// send, as something other than what it looks like" — a `.mkv` that becomes a
/// download rather than a player, a `.psd` that becomes a document rather than
/// a picture. That answer is worth giving BEFORE the file is let go, which is
/// why the plan is computed on hover and not on drop.
enum DropTone { accept, caution, refuse }

/// What a given surface is willing to receive.
///
/// Mirrors the two guardian switches the attachment sheet already reads
/// (`FamilyService.canSendMedia`), plus a plain "this room takes no
/// attachments at all" for surfaces that are read-only. The server refuses
/// regardless — this only decides what the hover says, so a supervised account
/// is told no while the file is still in the air rather than after it lands.
@immutable
class DropPolicy {
  const DropPolicy({this.allowFiles = true, this.allowText = true});

  /// Everything refuses nothing. The default for an ordinary room.
  static const permissive = DropPolicy();

  final bool allowFiles;
  final bool allowText;

  bool get allowsNothing => !allowFiles && !allowText;
}

// ─────────────────────────── the format tables ───────────────────────────
//
// Split four ways rather than two, because "supported" is not a boolean here.
// A format can be:
//
//   * carried AND rendered by every client            → the plain sets
//   * carried and rendered by MOST clients            → the `fragile` sets
//   * carried but rendered by none of them            → the `fallback` sets
//   * not worth special-casing at all                 → a document, silently
//
// Only the middle two produce a caution, and they are the reason the tables
// are hand-written rather than derived from `_mimeByExtension` in file_meta:
// that table answers "what content type do I upload this as", which is a
// different question with a different right answer for exactly these formats.

/// Decoded by Skia on every platform this app ships on, web included.
const Set<String> _photoExt = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

/// Sent as a picture, but not every client will draw it.
///
/// HEIC is the one that matters: it is what a Mac hands over when a photo is
/// dragged out of Photos, Skia decodes it on Apple platforms and Android P+,
/// and no browser decodes it at all. Downgrading it to a document would be the
/// wrong trade — the overwhelmingly common case is Mac to phone, where it
/// renders — so it goes as a picture and the chip says so.
const Set<String> _fragilePhotoExt = {'heic', 'heif', 'avif', 'tiff', 'tif'};

/// Image-shaped things nothing in this app can draw. They still send, as
/// documents, and the chip is what stops that being a surprise.
const Set<String> _photoFallbackExt = {
  'svg', 'psd', 'ai', 'eps', 'raw', 'cr2', 'cr3', 'nef', 'arw', 'dng', 'orf',
  'rw2', 'ico', 'icns', 'xcf', 'sketch', 'fig', 'afphoto', 'afdesign',
};

/// Plays in the transcript's own player everywhere.
const Set<String> _videoExt = {'mp4', 'mov', 'm4v', 'webm'};

/// Container formats `video_player` does not open on at least one platform.
/// Sent as documents — a player that shows a black rectangle is worse than a
/// row that says "download me".
const Set<String> _videoFallbackExt = {
  'mkv', 'avi', 'wmv', 'flv', 'mpg', 'mpeg', 'mts', 'm2ts', 'ts', 'ogv',
  '3gp', '3g2', 'rm', 'vob', 'asf',
};

/// Opens in `just_audio` on every platform.
const Set<String> _audioExt = {'mp3', 'm4a', 'aac', 'wav'};

/// Plays in most browsers and both phones, but not in Safari — which on this
/// app's web build is a real share of the audience.
const Set<String> _fragileAudioExt = {'ogg', 'oga', 'opus', 'flac'};

/// Audio-shaped and unplayable. Documents.
const Set<String> _audioFallbackExt = {
  'wma', 'aiff', 'aif', 'aifc', 'amr', 'mid', 'midi', 'ra', 'au', 'ape',
  'dsf', 'wv',
};

/// Most attachments one drop will send.
///
/// A drag is the one door in this app that can deliver a hundred files in a
/// single gesture — selecting a folder's worth in Finder and pulling it over
/// is not an edge case, it is what drag-and-drop is FOR. Every other door has
/// a natural bound: the photo picker enforces [kMaxPhotoSelection], the file
/// picker takes one, the share sheet is whatever another app chose to send.
///
/// Twenty is well past any deliberate drop and well short of a mis-selected
/// directory. Everything past it is refused by NAME, before it lands, rather
/// than becoming twenty more bubbles nobody asked for.
const int kMaxDropItems = 20;

/// Most bytes one drop will send.
///
/// The number that keeps a drop out of `ChatRepository._maxRetainedUploadBytes`
/// (48 MB), whose overflow path is the dead end `file_meta.dart` describes: a
/// failed bubble with no bytes left to retry. Two full-size attachments is the
/// ratio that file already reasons about, and this is that ratio spelled as a
/// batch — so a drop either fits entirely or says which part of it did not,
/// while the pointer is still holding it.
///
/// Only enforceable where the platform reports sizes during the drag, which is
/// macOS. In a browser it is applied at the drop instead, which is the same
/// moment everything else about a web drag becomes knowable.
const int kMaxDropBatchBytes = 2 * kMaxFileUploadBytes;

/// How big a dropped photo or video may be.
///
/// Where a drop is staged to disk (macOS) it is [kMaxMediaIntakeBytes]: a
/// photo or video is compressed down to [kMaxFileUploadBytes] before it goes,
/// the same as a shared one. A browser hands the file over by reading it whole
/// into memory and has no video encoder, so there it stays at the upload cap.
int get dropMediaIntakeCap =>
    kIsWeb ? kMaxFileUploadBytes : kMaxMediaIntakeBytes;

/// The size cap for a dropped item of [kind]: [dropMediaIntakeCap] for what
/// gets compressed, [kMaxFileUploadBytes] for what goes as it is.
int dropIntakeCapFor(DropKind kind) =>
    kind == DropKind.photo || kind == DropKind.video
        ? dropMediaIntakeCap
        : kMaxFileUploadBytes;

/// One dragged item, resolved against the tables and the policy.
@immutable
class DropAssessment {
  const DropAssessment({
    required this.candidate,
    required this.kind,
    this.refusal,
    this.downgraded = false,
    this.fragile = false,
  });

  final DropCandidate candidate;

  /// What it becomes. Already accounts for [downgraded]: a `.mkv` assesses as
  /// [DropKind.document], not as a video that happens to be marked.
  final DropKind kind;

  /// Non-null when it will not be sent at all.
  final DropRefusal? refusal;

  /// It looked like media and it is going as a document. The sentence the user
  /// asked for — "it's going to be sent as a regular file" — hangs off this.
  final bool downgraded;

  /// It is going as media, and some clients will not render it.
  final bool fragile;

  bool get accepted => refusal == null;

  /// Null for anything that never reaches the transcript.
  MessageType? get messageType {
    if (!accepted) return null;
    switch (kind) {
      case DropKind.photo:
        return MessageType.image;
      case DropKind.video:
        return MessageType.video;
      case DropKind.audio:
        return MessageType.audio;
      case DropKind.document:
      case DropKind.unknown:
        return MessageType.file;
      case DropKind.folder:
      case DropKind.text:
      case DropKind.link:
        return null;
    }
  }

  /// Content type to upload under.
  ///
  /// Name first, exactly as `_pickAndSendFile` does and for the same reason —
  /// a platform-declared type is null on most Android providers and a guess on
  /// web. The platform's answer is the FALLBACK here rather than being ignored
  /// outright, because macOS derives its type from the file's UTI (content
  /// sniffed, not extension guessed), and that is strictly better than
  /// `application/octet-stream` for a file with no extension at all.
  String get uploadContentType {
    final name = candidate.name;
    if (name != null && fileExtensionOf(name).isNotEmpty) {
      final byName = mimeTypeForFileName(name);
      if (byName != 'application/octet-stream') return byName;
    }
    final declared = candidate.mimeType?.trim();
    if (declared != null && declared.isNotEmpty) return declared;
    return 'application/octet-stream';
  }

  @override
  bool operator ==(Object other) =>
      other is DropAssessment &&
      other.candidate == candidate &&
      other.kind == kind &&
      other.refusal == refusal &&
      other.downgraded == downgraded &&
      other.fragile == fragile;

  @override
  int get hashCode =>
      Object.hash(candidate, kind, refusal, downgraded, fragile);

  @override
  String toString() => 'DropAssessment($kind'
      '${refusal != null ? ', refused: $refusal' : ''}'
      '${downgraded ? ', downgraded' : ''}${fragile ? ', fragile' : ''})';
}

/// The whole answer to "what happens if I let go right here".
@immutable
class DropPlan {
  const DropPlan({
    required this.items,
    required this.namesKnown,
    required this.sizesKnown,
    this.carriesText = false,
    this.carriesLink = false,
    this.text,
    this.uri,
  });

  static const empty =
      DropPlan(items: [], namesKnown: false, sizesKnown: false);

  final List<DropAssessment> items;

  /// Carried through from the snapshot so the chip can choose between naming a
  /// file and counting a type. See [DropSnapshot.namesKnown].
  final bool namesKnown;
  final bool sizesKnown;

  /// Text is coming, whether or not [text] is populated yet. See
  /// [DropSnapshot.carriesText] — a browser withholds the contents until the
  /// drop, and the chip still has to say something on the way there.
  final bool carriesText;
  final bool carriesLink;

  final String? text;
  final String? uri;

  List<DropAssessment> get accepted => [for (final i in items) if (i.accepted) i];
  List<DropAssessment> get refused => [for (final i in items) if (!i.accepted) i];

  int countOf(DropKind kind) =>
      accepted.where((i) => i.kind == kind).length;

  int get photoCount => countOf(DropKind.photo);
  int get videoCount => countOf(DropKind.video);
  int get audioCount => countOf(DropKind.audio);
  int get documentCount =>
      countOf(DropKind.document) + countOf(DropKind.unknown);

  /// Items that look like media and are going as documents.
  int get downgradedCount => accepted.where((i) => i.downgraded).length;

  /// Items going as media that some clients will not render.
  int get fragileCount => accepted.where((i) => i.fragile).length;

  bool get hasText => carriesText || carriesLink;

  /// Whether letting go would put ANYTHING anywhere — a message, or a draft in
  /// the composer.
  bool get sendsAnything => accepted.isNotEmpty || hasText;

  /// True when every accepted item is a picture, which is what routes the drop
  /// into the editor (one) or the photo tray (several) rather than straight
  /// into the transcript.
  bool get isPhotoOnly =>
      accepted.isNotEmpty && accepted.every((i) => i.kind == DropKind.photo);

  /// The single refusal worth naming, when there is exactly one kind of them.
  /// Null when refusals are mixed — the chip falls back to a count there.
  DropRefusal? get soleRefusal {
    final kinds = refused.map((i) => i.refusal).toSet();
    return kinds.length == 1 ? kinds.first : null;
  }

  DropTone get tone {
    if (!sendsAnything) return DropTone.refuse;
    if (refused.isNotEmpty || downgradedCount > 0 || fragileCount > 0) {
      return DropTone.caution;
    }
    return DropTone.accept;
  }

  /// How many cards the ghost stack should draw. Text counts as one card.
  int get cardCount => items.isNotEmpty ? items.length : (hasText ? 1 : 0);

  /// Value equality, which is what lets `DropController` decide whether a
  /// target change actually changed the ANSWER — crossing between two rooms
  /// with the same policy and the same files does not need a repaint.
  @override
  bool operator ==(Object other) =>
      other is DropPlan &&
      listEquals(other.items, items) &&
      other.namesKnown == namesKnown &&
      other.sizesKnown == sizesKnown &&
      other.carriesText == carriesText &&
      other.carriesLink == carriesLink &&
      other.text == text &&
      other.uri == uri;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), namesKnown,
      sizesKnown, carriesText, carriesLink, text, uri);

  @override
  String toString() => 'DropPlan(${items.length} items, tone: $tone)';
}

/// Resolves one dragged item against the format tables and [policy].
DropAssessment assess(DropCandidate candidate, {DropPolicy policy = DropPolicy.permissive}) {
  if (candidate.isDirectory) {
    return DropAssessment(
      candidate: candidate,
      kind: DropKind.folder,
      refusal: DropRefusal.folder,
    );
  }

  final kind = _kindOf(candidate);
  final downgraded = _isDowngrade(candidate);
  final fragile = _isFragile(candidate);

  if (!policy.allowFiles) {
    return DropAssessment(
      candidate: candidate,
      kind: kind,
      refusal: DropRefusal.notPermitted,
      downgraded: downgraded,
      fragile: fragile,
    );
  }

  // Size is checked only when the platform told us one. A browser withholds it
  // until the drop, and inventing a refusal for a file we have not measured
  // would be worse than measuring it a moment later — see `DropCandidate`.
  final size = candidate.size;
  if (size != null) {
    if (size <= 0) {
      return DropAssessment(
        candidate: candidate,
        kind: kind,
        refusal: DropRefusal.empty,
        downgraded: downgraded,
        fragile: fragile,
      );
    }
    if (size > dropIntakeCapFor(kind)) {
      return DropAssessment(
        candidate: candidate,
        kind: kind,
        refusal: DropRefusal.tooLarge,
        downgraded: downgraded,
        fragile: fragile,
      );
    }
  }

  return DropAssessment(
    candidate: candidate,
    kind: kind,
    downgraded: downgraded,
    fragile: fragile,
  );
}

/// Resolves a whole hover.
///
/// Two passes, because one of the answers is not a property of any single
/// item: [assess] decides what each thing IS, and [_applyBatchBudget] then
/// decides how many of them fit in one send. Splitting them keeps the tables
/// testable against one file at a time, which is how they are written.
DropPlan planFor(DropSnapshot snapshot, {DropPolicy policy = DropPolicy.permissive}) {
  final allowText = policy.allowText;
  return DropPlan(
    items: _applyBatchBudget(
      [for (final c in snapshot.items) assess(c, policy: policy)],
    ),
    namesKnown: snapshot.namesKnown,
    sizesKnown: snapshot.sizesKnown,
    carriesText: allowText && snapshot.carriesText,
    carriesLink: allowText && snapshot.carriesLink,
    text: allowText ? snapshot.text : null,
    uri: allowText ? snapshot.uri : null,
  );
}

/// Refuses whatever runs past [kMaxDropItems] or [kMaxDropBatchBytes].
///
/// In drag order, and that is the point: the user arranged the selection and
/// the first things in it are the ones they were thinking about. Refusing from
/// the end is predictable; refusing the largest, or refusing everything, is
/// not.
///
/// Items already refused for their own reasons do not spend budget — a folder
/// and a 30 MB video are not going anywhere, so counting them would shrink the
/// send for no reason. An item whose size is unknown spends none of the byte
/// budget either (a browser withholds it until the drop), and the count cap is
/// what still applies there.
List<DropAssessment> _applyBatchBudget(List<DropAssessment> items) {
  var count = 0;
  var bytes = 0;
  var full = false;
  final out = <DropAssessment>[];
  for (final item in items) {
    if (!item.accepted) {
      out.add(item);
      continue;
    }
    // What it will cost once sent, which for a big photo or video is the
    // compressed file, never more than the upload cap.
    final raw = item.candidate.size ?? 0;
    final size = raw > kMaxFileUploadBytes ? kMaxFileUploadBytes : raw;
    if (!full) {
      if (count + 1 > kMaxDropItems || bytes + size > kMaxDropBatchBytes) {
        // Latched rather than re-evaluated per item: once the budget is gone,
        // a small file later in the drag must not sneak in past the big one
        // that filled it. The order the user arranged is the order that ships.
        full = true;
      } else {
        count++;
        bytes += size;
        out.add(item);
        continue;
      }
    }
    out.add(DropAssessment(
      candidate: item.candidate,
      kind: item.kind,
      refusal: DropRefusal.batchFull,
      downgraded: item.downgraded,
      fragile: item.fragile,
    ));
  }
  return out;
}

// ──────────────────────────────── internals ────────────────────────────────

/// Extension first, declared type second, and the order is load-bearing.
///
/// A browser reports `application/octet-stream` for plenty of files it has no
/// registration for, and macOS reports `public.data` for the same. Neither
/// beats a `.mkv` on the end of the name. The declared type is consulted only
/// where there is no extension to read — which on web before the drop is every
/// single item, because there is no name at all.
DropKind _kindOf(DropCandidate c) {
  final ext = c.extension;
  if (ext.isNotEmpty) {
    if (_photoExt.contains(ext) || _fragilePhotoExt.contains(ext)) {
      return DropKind.photo;
    }
    if (_videoExt.contains(ext)) return DropKind.video;
    if (_audioExt.contains(ext) || _fragileAudioExt.contains(ext)) {
      return DropKind.audio;
    }
    // Everything else with an extension is a document, the fallback tables
    // included — being in one of those is what `downgraded` reports, not a
    // different kind.
    return DropKind.document;
  }

  final mime = c.mimeType?.toLowerCase().trim() ?? '';
  if (mime.isEmpty) {
    // No name and no type. In a browser this is the ordinary pre-drop state
    // for a file with no registered type; everywhere else it is a file with no
    // extension. Both are honestly "we do not know yet".
    return c.name == null ? DropKind.unknown : DropKind.document;
  }
  if (mime == 'text/uri-list') return DropKind.link;
  if (mime.startsWith('text/')) return DropKind.text;
  if (mime.startsWith('image/')) {
    return _mimeSubtypeIsFallbackImage(mime) ? DropKind.document : DropKind.photo;
  }
  if (mime.startsWith('video/')) {
    return _mimeSubtypeIsPlayableVideo(mime) ? DropKind.video : DropKind.document;
  }
  if (mime.startsWith('audio/')) {
    return _mimeSubtypeIsPlayableAudio(mime) ? DropKind.audio : DropKind.document;
  }
  return DropKind.document;
}

bool _mimeSubtypeIsFallbackImage(String mime) =>
    mime == 'image/svg+xml' ||
    mime == 'image/vnd.adobe.photoshop' ||
    mime == 'image/x-icon' ||
    mime == 'image/vnd.microsoft.icon';

bool _mimeSubtypeIsPlayableVideo(String mime) =>
    mime == 'video/mp4' ||
    mime == 'video/quicktime' ||
    mime == 'video/webm' ||
    mime == 'video/x-m4v';

bool _mimeSubtypeIsPlayableAudio(String mime) =>
    mime == 'audio/mpeg' ||
    mime == 'audio/mp4' ||
    mime == 'audio/aac' ||
    mime == 'audio/wav' ||
    mime == 'audio/x-wav' ||
    mime == 'audio/ogg' ||
    mime == 'audio/opus' ||
    mime == 'audio/flac';

/// "It looks like media and it is going as a document."
///
/// Only ever true for something we can NAME — a browser hovering an unnamed
/// `application/octet-stream` has not told us enough to claim a downgrade, and
/// claiming one anyway would put a caution on half of every web drag.
bool _isDowngrade(DropCandidate c) {
  final ext = c.extension;
  if (ext.isNotEmpty) {
    return _photoFallbackExt.contains(ext) ||
        _videoFallbackExt.contains(ext) ||
        _audioFallbackExt.contains(ext);
  }
  final mime = c.mimeType?.toLowerCase().trim() ?? '';
  if (mime.isEmpty) return false;
  if (mime.startsWith('image/')) return _mimeSubtypeIsFallbackImage(mime);
  if (mime.startsWith('video/')) return !_mimeSubtypeIsPlayableVideo(mime);
  if (mime.startsWith('audio/')) return !_mimeSubtypeIsPlayableAudio(mime);
  return false;
}

/// "It is going as media, and it will not render for everybody."
bool _isFragile(DropCandidate c) {
  final ext = c.extension;
  if (ext.isEmpty) return false;
  return _fragilePhotoExt.contains(ext) || _fragileAudioExt.contains(ext);
}
