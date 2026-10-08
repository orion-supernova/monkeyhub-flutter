
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import 'document_saver.dart';
import 'file_meta.dart';

/// How a received document can be looked at without leaving the app.
enum DocumentPreviewKind {
  /// Decoded and laid out by [TextFileViewerScreen]. The oldest of these and
  /// the only one that predates the rest.
  text,

  /// Opened in the app's own fullscreen photo viewer — pinch, pan, save.
  ///
  /// Reachable because a picture CAN be sent as a document: picking a photo
  /// through the file browser keeps it unrecompressed, which is the whole
  /// reason somebody would. Before this it arrived as a grey plate with a
  /// `PNG` badge on it and no way to see the picture short of downloading it.
  image,

  /// Handed to the platform's own document previewer — QuickLook on iOS and
  /// macOS. Covers PDF, EPUB, Pages/Numbers/Keynote, Office, RTF and every
  /// other format Apple renders, which is a longer list than anything this
  /// app could carry a renderer for.
  native,

  /// Nothing in the app can render it. The OS hand-off is the whole story.
  none,
}

/// Decides what a tap on a document does, and does it.
///
/// ### Why this is not "add a PDF renderer"
///
/// [FileMessage] used to state flatly that there is no in-app viewer, because
/// "a chat app that renders PDFs is a chat app that renders PDFs badly". That
/// reasoning is still right about *carrying a renderer* — a PDF engine is
/// megabytes of dependency and a permanent stream of layout bugs in somebody
/// else's format. It is not right about refusing to preview at all, which is
/// what it had become: receiving a book meant downloading it to find out what
/// it was.
///
/// So nothing here renders anything. Two of the three kinds are viewers this
/// app already had and was not reaching for, and the third is the previewer
/// Apple already ships in the OS, reached over a channel. There is no new
/// dependency and no new format support to maintain — [kindFor] is a routing
/// decision, not a parser.
class DocumentPreview {
  const DocumentPreview._();

  static const MethodChannel _channel = MethodChannel('monkeyhub/preview');

  /// Whether the platform has a document previewer of its own.
  ///
  /// iOS and macOS, via QuickLook. Android's equivalent is an `ACTION_VIEW`
  /// intent, which is the OS hand-off this already does — an in-app preview
  /// there would mean shipping a renderer, which is the thing this class
  /// exists to avoid. A browser can only offer the download it already offers.
  ///
  /// Read through `defaultTargetPlatform` rather than `dart:io`'s `Platform`
  /// so the getter is safe to evaluate on web, where `dart:io` is a stub that
  /// throws.
  static bool get nativeAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// What a tap on this document should do.
  static DocumentPreviewKind kindFor({
    required String? mimeType,
    required String fileName,
  }) {
    if (isPlainTextFile(mimeType: mimeType, fileName: fileName)) {
      return DocumentPreviewKind.text;
    }
    if (_isViewableImage(mimeType: mimeType, fileName: fileName)) {
      return DocumentPreviewKind.image;
    }
    if (nativeAvailable &&
        _quickLookable(mimeType: mimeType, fileName: fileName)) {
      return DocumentPreviewKind.native;
    }
    return DocumentPreviewKind.none;
  }

  /// Fetches [storageId] and shows it in the platform previewer.
  ///
  /// Returns false when the platform declined — an older build with no native
  /// half, a format QuickLook turned out not to handle, a previewer that could
  /// not be presented — and the caller falls back to the OS hand-off. Never
  /// throws for those; a failed preview must degrade into the behaviour that
  /// was there before it, not into an error.
  ///
  /// Throws [FileUnavailable] and transport errors from the fetch, which the
  /// caller already reports on the tile.
  static Future<bool> openNative({
    required ChatApi api,
    required String storageId,
    required String fileName,
  }) async {
    if (!nativeAvailable) return false;
    final Uint8List bytes =
        await DocumentSaver.fetchBytes(
            api: api, storageId: storageId, fileName: fileName);
    try {
      final shown = await _channel.invokeMethod<bool>('show', {
        'bytes': bytes,
        // QuickLook identifies the file by its EXTENSION and by nothing else —
        // it never sniffs — so a name without one previews as plain bytes and
        // renders a hex dump of a book. `_named` guarantees there is one.
        'fileName': _named(fileName, mimeType: null),
      });
      return shown ?? false;
    } on MissingPluginException {
      // A build that predates the native half.
      return false;
    } on PlatformException catch (e) {
      debugPrint('preview: platform declined $fileName: ${e.message}');
      return false;
    }
  }

  /// A filename QuickLook can work with.
  ///
  /// The App Store's link-preview blob is the case this exists for: five
  /// characters, no dot, 273 KB of PNG. Apple's previewer reads the extension
  /// and only the extension, so an extensionless name is a guaranteed failure
  /// no matter what the bytes are.
  static String _named(String fileName, {required String? mimeType}) {
    if (fileExtensionOf(fileName).isNotEmpty) return fileName;
    final guessed = _extensionForMime(mimeType);
    final base = fileName.trim().isEmpty ? 'document' : fileName.trim();
    return guessed == null ? base : '$base.$guessed';
  }

  static String? _extensionForMime(String? mimeType) {
    switch (mimeType) {
      case 'application/pdf':
        return 'pdf';
      case 'application/epub+zip':
        return 'epub';
      case 'image/png':
        return 'png';
      case 'image/jpeg':
        return 'jpg';
      default:
        return null;
    }
  }

  /// Formats this app already draws, sent as documents rather than as photos.
  ///
  /// Deliberately the same set `drop_classifier.dart` calls renderable, minus
  /// the fragile tier: a `.heic` document opens in the OS previewer on an
  /// Apple platform (which can decode it) rather than in a Flutter viewer that
  /// may not.
  static bool _isViewableImage({
    required String? mimeType,
    required String fileName,
  }) {
    const drawable = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
    final ext = fileExtensionOf(fileName);
    if (ext.isNotEmpty) return drawable.contains(ext);
    // No extension to read — which is exactly the shape the App Store's blob
    // arrives in — so the declared type is all there is.
    switch (mimeType) {
      case 'image/png':
      case 'image/jpeg':
      case 'image/gif':
      case 'image/webp':
      case 'image/bmp':
        return true;
      default:
        return false;
    }
  }

  /// Whether QuickLook is worth asking about.
  ///
  /// A allow-list rather than "everything that is not text or an image",
  /// because the failure is ugly: QuickLook renders an unknown file as a page
  /// of nothing, which reads as a broken document rather than as a format
  /// nobody can open. Anything not listed keeps the OS hand-off, which is
  /// honest.
  static bool _quickLookable({
    required String? mimeType,
    required String fileName,
  }) {
    const byExtension = {
      'pdf', 'epub', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'rtf',
      'pages', 'numbers', 'key', 'csv', 'md', 'heic', 'heif', 'tiff', 'tif',
      'svg', 'ics', 'vcf', 'log', 'json', 'xml', 'html', 'htm',
    };
    final ext = fileExtensionOf(fileName);
    if (ext.isNotEmpty) return byExtension.contains(ext);
    const byMime = {
      'application/pdf',
      'application/epub+zip',
      'application/rtf',
      'image/heic',
      'image/tiff',
      'image/svg+xml',
    };
    return mimeType != null && byMime.contains(mimeType);
  }
}
