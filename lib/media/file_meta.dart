/// Facts about a document that neither the picker nor the server will tell us.
///
/// The picker hands back a name and bytes, but `XFile.mimeType` is unreliable
/// across platforms — null on most Android content providers, and only as good
/// as the browser's own guess on web. The upload needs a content type at the
/// moment the bytes go up (`UploadService.uploadFile` takes one, and Convex
/// storage records whatever it is given), so it is derived here from the name
/// instead.
library;

/// The largest document this app will send.
///
/// Bounded by three things, and it is the smallest of them that matters:
///
///  * `ChatRepository._maxRetainedUploadBytes` (48 MB) is the budget for *all*
///    unfinished sends at once. Overflowing it produces a failed bubble with no
///    bytes left to retry, which is a dead end rather than an error — so a
///    single pick must never be able to approach it. This is what sets the
///    number: uploads are chained rather than raced, but retained bytes count
///    everything still queued, so TWO picks have to fit. At 25 MB they did not
///    (50 > 48) and the second large document a user chose would have landed in
///    that dead end. `upload_cap_test.dart` holds the ratio.
///  * `UploadService.webTimeout` is a hard five-minute ceiling on the whole
///    request in a browser, because `package:http`'s browser client reports no
///    progress and so cannot be watchdogged on inactivity instead.
///  * Everything here is buffered whole in memory. There is no streamed or
///    resumable upload, so peak cost is the file itself, twice, on web.
///
/// Enforced at pick time — see `_pickAndSendFile` — so the refusal names a
/// reason while the user is still in the file browser they chose it from.
const int kMaxFileUploadBytes = 20 * 1024 * 1024;

/// Extension → content type, for the formats a chat actually carries.
///
/// Deliberately not exhaustive: anything absent falls to
/// `application/octet-stream`, which every platform treats as "download it and
/// let the OS decide". Guessing wrong is worse than not guessing — a `.pages`
/// file mislabelled `application/zip` (which it is, underneath) opens in an
/// archiver instead of Pages.
const Map<String, String> _mimeByExtension = {
  // Documents
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'rtf': 'application/rtf',
  'epub': 'application/epub+zip',
  // Data
  'json': 'application/json',
  'xml': 'application/xml',
  'html': 'text/html',
  'htm': 'text/html',
  // Archives
  'zip': 'application/zip',
  'rar': 'application/vnd.rar',
  '7z': 'application/x-7z-compressed',
  'tar': 'application/x-tar',
  'gz': 'application/gzip',
  // Pictures. Reachable here because the file tile can send one as a document —
  // picking a photo through the file browser keeps it unrecompressed, which is
  // the whole reason someone would.
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'svg': 'image/svg+xml',
  // Audio / video
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
};

/// The lowercased extension of [fileName], or empty when it has none.
///
/// A leading dot is not an extension: `.gitignore` is a name, not a type, and
/// treating it as one produces a "GITIGNORE" glyph on a file the OS considers
/// extensionless. Anything past the last dot that contains a path separator or
/// a space is rejected too — those come from names like `report v2` and
/// `archive.tar.gz backup`.
String fileExtensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return '';
  final ext = fileName.substring(dot + 1).toLowerCase();
  if (ext.contains('/') || ext.contains(r'\') || ext.contains(' ')) return '';
  return ext;
}

/// Content type to upload [fileName] as.
///
/// Never null and never guessed beyond the table: an unknown extension is
/// `application/octet-stream`, which is honest rather than wrong.
String mimeTypeForFileName(String fileName) =>
    _mimeByExtension[fileExtensionOf(fileName)] ?? 'application/octet-stream';

/// Whether a document is plain enough to render in-app rather than only
/// handed to the OS — the one exception to `FileMessage`'s "no in-app viewer"
/// rule, since there is nothing a `.txt` can mis-render.
///
/// Trusts an explicit [mimeType] either way: `text/plain` says yes, and any
/// other declared type (a `.log` mislabelled `application/octet-stream` by
/// some sender, say) says no rather than guessing past it. Only an absent or
/// empty mimeType falls back to the extension, which is what a message with
/// no `mimeType` field at all — every one written before that field existed —
/// leaves to go on.
bool isPlainTextFile({required String? mimeType, required String fileName}) {
  if (mimeType == 'text/plain') return true;
  if (mimeType != null && mimeType.isNotEmpty) return false;
  return fileExtensionOf(fileName) == 'txt';
}

/// Short uppercase badge for a document tile — `PDF`, `DOCX`, or `FILE` when
/// there is no extension to show.
///
/// Capped at four characters because the badge is a fixed-width chip and a
/// `.sketchpalette` would otherwise push the filename off the row.
String fileTypeBadge(String fileName) {
  final ext = fileExtensionOf(fileName);
  if (ext.isEmpty) return 'FILE';
  return ext.length <= 4 ? ext.toUpperCase() : ext.substring(0, 4).toUpperCase();
}

const List<String> _sizeUnits = ['B', 'KB', 'MB', 'GB', 'TB'];

/// Human size for a document row: `842 B`, `1.4 KB`, `12.8 MB`.
///
/// Binary units (1024), matching what every desktop file browser shows, so a
/// file the user sees as "24.6 MB" in Finder does not read as "25.8 MB" here
/// and appear to have grown in transit.
///
/// Bytes are never fractional — `1.0 B` is nonsense — and anything at or above
/// a kilobyte gets exactly one decimal, so the column width is stable.
String formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _sizeUnits.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '${value.round()} B';
  return '${value.toStringAsFixed(1)} ${_sizeUnits[unit]}';
}
