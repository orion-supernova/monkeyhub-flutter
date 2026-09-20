import 'package:flutter/foundation.dart';

import '../media/file_meta.dart';

/// What a dragged thing will BECOME if it is let go here.
///
/// Deliberately not `MessageType`: half of these never reach a message at all
/// (a folder is refused, text lands in the composer), and the two that do map
/// straight across are better spelled in the vocabulary of the drag than in
/// the vocabulary of the transcript. [DropAssessment.messageType] does the
/// translation once, in one place.
enum DropKind {
  /// Renders in the transcript as a picture.
  photo,

  /// Plays in the transcript.
  video,

  /// Gets the scrubber bubble.
  audio,

  /// A row with a type badge, a name and a size. The honest default: anything
  /// this app cannot draw or play is still perfectly sendable as a document,
  /// and saying so before the drop is the whole point of the verdict chip.
  document,

  /// A directory. Refused — see [DropAssessment.refusal].
  folder,

  /// Plain text from another app's selection. Becomes composer contents.
  text,

  /// A URL — a dragged browser tab, a link off a web page. Composer contents
  /// too, so the link preview the composer already builds does the rest.
  link,

  /// A file whose type we cannot know yet. Only ever produced BEFORE a drop,
  /// and only in a browser: `DataTransfer` withholds names during a drag, so a
  /// file with no registered MIME type is genuinely anonymous until it lands.
  unknown,
}

/// Why a dragged item will not be sent.
enum DropRefusal {
  /// Bigger than [kMaxFileUploadBytes]. Known before the drop on macOS, and
  /// only after it in a browser.
  tooLarge,

  /// A directory. There is no archiver in this app and no server-side one
  /// either, so a folder is a thing we can name and decline rather than a
  /// thing we can send.
  folder,

  /// Zero bytes. Every platform will happily hand over an empty file and the
  /// upload succeeds; what arrives is a bubble that can only disappoint.
  empty,

  /// The guardian policy on this room forbids attachments. Mirrors
  /// `FamilyService.canSendMedia`; the server refuses it regardless.
  notPermitted,

  /// It fits, but not alongside everything dragged in with it — see
  /// `kMaxDropItems` and `kMaxDropBatchBytes`. The one refusal that is not a
  /// property of the file at all, and the reason a drag needs a batch pass:
  /// pulling a folder's worth of files over the window is what this door is
  /// for, and twenty of them is not a send this app can hold in memory.
  batchFull,
}

/// One thing the OS is currently dragging, as far as we can tell SO FAR.
///
/// Every field is nullable because the two platforms know different amounts at
/// different moments, and the UI's whole job is to be honest about which:
///
/// | | before the drop | after the drop |
/// |---|---|---|
/// | **macOS** | name, size, UTI — everything | everything |
/// | **web** | MIME type and count, nothing else | everything |
///
/// That asymmetry is not a bug to be smoothed over. A browser withholds file
/// names during a drag on purpose (a page could otherwise read a directory
/// listing off a hover), so the hover card shows "3 images" there and
/// "Q3-deck.key · 4.2 MB" on a Mac, and neither of them is lying.
@immutable
class DropCandidate {
  const DropCandidate({
    this.name,
    this.mimeType,
    this.size,
    this.isDirectory = false,
  });

  /// The filesystem name, when the platform will say. Null throughout a
  /// browser drag.
  final String? name;

  /// The type the platform declared. On macOS this is derived from the file's
  /// UTI, which is content-sniffed and therefore better than the extension; in
  /// a browser it is the browser's own guess and is frequently empty.
  final String? mimeType;

  /// Bytes on disk. Null in a browser before the drop.
  final int? size;

  final bool isDirectory;

  /// A name we would be prepared to show. Null when there genuinely is none,
  /// so callers can fall back to a type summary rather than printing "file".
  String? get displayName {
    final n = name?.trim();
    return (n == null || n.isEmpty) ? null : n;
  }

  /// Lowercase extension, or empty.
  String get extension => fileExtensionOf(name ?? '');

  DropCandidate copyWith({String? name, String? mimeType, int? size}) =>
      DropCandidate(
        name: name ?? this.name,
        mimeType: mimeType ?? this.mimeType,
        size: size ?? this.size,
        isDirectory: isDirectory,
      );

  @override
  bool operator ==(Object other) =>
      other is DropCandidate &&
      other.name == name &&
      other.mimeType == mimeType &&
      other.size == size &&
      other.isDirectory == isDirectory;

  @override
  int get hashCode => Object.hash(name, mimeType, size, isDirectory);

  @override
  String toString() =>
      'DropCandidate(${name ?? '?'}, ${mimeType ?? '?'}, ${size ?? '?'}B'
      '${isDirectory ? ', dir' : ''})';
}

/// Everything known about a drag that is currently OVER the window.
///
/// Rebuilt at most once per drag, not once per mouse move: the pointer travels
/// on its own [ValueNotifier] precisely so moving across a 400-item list does
/// not rebuild a single card. See `DropController`.
@immutable
class DropSnapshot {
  const DropSnapshot({
    this.items = const [],
    this.text,
    this.uri,
    this.namesKnown = false,
    this.sizesKnown = false,
    bool? carriesText,
    bool? carriesLink,
  })  : _carriesText = carriesText,
        _carriesLink = carriesLink;

  final List<DropCandidate> items;

  /// A dragged text selection, if the pasteboard carried one AND the platform
  /// will hand the contents over before the drop. Null throughout a browser
  /// drag even when text is on its way — see [carriesText].
  final String? text;

  /// A dragged link. Kept apart from [text] because a URL is worth a different
  /// sentence in the verdict chip and because the composer treats it
  /// differently once it lands.
  final String? uri;

  final bool? _carriesText;
  final bool? _carriesLink;

  /// Whether text is coming, which is a weaker claim than having it.
  ///
  /// A browser exposes the *format list* during a drag and the *contents* only
  /// on drop, so this is true with [text] still null for the whole of a web
  /// hover. Everything that only needs to know what kind of sentence to draw
  /// reads these two; everything that needs the actual string waits for the
  /// bundle.
  bool get carriesText =>
      _carriesText ?? (text != null && text!.trim().isNotEmpty);

  bool get carriesLink =>
      _carriesLink ?? (uri != null && uri!.trim().isNotEmpty);

  /// Whether [items] carry real filenames. False for the whole of a browser
  /// drag — see [DropCandidate].
  final bool namesKnown;

  /// Whether [items] carry real byte counts, which is what decides whether the
  /// size cap can be enforced BEFORE the drop or only after it.
  final bool sizesKnown;

  bool get isEmpty => items.isEmpty && !carriesText && !carriesLink;

  bool get hasFiles => items.isNotEmpty;

  int get count => items.isNotEmpty ? items.length : 1;

  @override
  bool operator ==(Object other) =>
      other is DropSnapshot &&
      listEquals(other.items, items) &&
      other.text == text &&
      other.uri == uri &&
      other.namesKnown == namesKnown &&
      other.sizesKnown == sizesKnown &&
      other.carriesText == carriesText &&
      other.carriesLink == carriesLink;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), text, uri, namesKnown,
      sizesKnown, carriesText, carriesLink);
}

/// One file that has actually LANDED, with bytes reachable behind it.
///
/// Two ways to reach them, one per platform, and the split is not an accident:
///
///  * **[path]** — macOS. The native half copies the dropped file into our own
///    cache before Dart hears about the drop at all, exactly as `ShareIntake`
///    does for the share sheet, and for the same reason: a sandboxed app's
///    access to a dragged URL is granted for the drag and is not something to
///    still be relying on three seconds later while an editor is open. Reading
///    our own copy asks nobody's permission.
///  * **[bytes]** — web. There is no filesystem to stage into; the browser
///    hands over a `File` and we read it whole.
///
/// [oversize] items carry neither. Nothing was copied and nothing was read,
/// because the file is past [kMaxFileUploadBytes] and moving twenty megabytes
/// around to refuse them at the far end is work with no outcome.
@immutable
class DroppedFile {
  const DroppedFile({
    required this.name,
    required this.mimeType,
    required this.size,
    this.path,
    this.bytes,
    this.oversize = false,
  });

  final String name;
  final String mimeType;
  final int size;

  /// Our own staged copy. Non-null on macOS for everything sendable.
  final String? path;

  /// Read-whole bytes. Non-null on web for everything sendable.
  final Uint8List? bytes;

  final bool oversize;

  bool get hasContent => !oversize && (path != null || bytes != null);

  @override
  String toString() =>
      'DroppedFile($name, $mimeType, $size B${oversize ? ', OVERSIZE' : ''})';
}

/// A completed drop: what was let go, and where the bytes are.
@immutable
class DropBundle {
  const DropBundle({this.files = const [], this.text, this.uri});

  final List<DroppedFile> files;
  final String? text;
  final String? uri;

  List<DroppedFile> get sendable =>
      [for (final f in files) if (f.hasContent) f];

  List<DroppedFile> get oversized => [for (final f in files) if (f.oversize) f];

  bool get isEmpty =>
      files.isEmpty && (text == null || text!.trim().isEmpty) && uri == null;

  /// The snapshot this bundle would have produced, used to re-plan against the
  /// real facts once a browser finally hands the names over.
  DropSnapshot toSnapshot() => DropSnapshot(
        items: [
          for (final f in files)
            DropCandidate(name: f.name, mimeType: f.mimeType, size: f.size),
        ],
        text: text,
        uri: uri,
        namesKnown: true,
        sizesKnown: true,
        carriesText: text != null && text!.trim().isNotEmpty,
        carriesLink: uri != null && uri!.trim().isNotEmpty,
      );

  @override
  String toString() =>
      'DropBundle(${files.length} files, text=${text != null}, uri=$uri)';
}
