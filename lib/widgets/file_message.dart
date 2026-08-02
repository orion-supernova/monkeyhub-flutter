import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../media/document_saver.dart';
import '../media/file_meta.dart';
import '../media/file_url_cache.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'photo_chrome.dart';

/// A received document, as a tappable row: type badge, name, size.
///
/// Unlike every other attachment this app carries, a document has nothing to
/// render *of itself* — no thumbnail, no waveform, no poster. The name is the
/// content, which is why `ChatMessage.fileName` is round-tripped through the
/// disk cache and carried through `copyWith` rather than treated as metadata
/// the way `mediaWidth` is.
///
/// Tapping hands the bytes to the OS via [DocumentSaver]. There is deliberately
/// no in-app viewer: a chat app that renders PDFs is a chat app that renders
/// PDFs badly, and every platform this ships on already has a better one.
class FileMessage extends StatefulWidget {
  const FileMessage({
    super.key,
    required this.api,
    required this.storageId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.isMine,
    this.maxWidth,
  });

  final ChatApi api;

  /// Null while the sender's upload is still in flight, and on a message whose
  /// upload failed outright. The row renders its name and size either way —
  /// they came off the pick, not off the server — but refuses the tap.
  final String? storageId;

  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final bool isMine;
  final double? maxWidth;

  @override
  State<FileMessage> createState() => _FileMessageState();
}

class _FileMessageState extends State<FileMessage> {
  bool _busy = false;
  bool _pressed = false;

  /// Measured off this row rather than the whole screen, because
  /// `sharePositionOrigin` is what an iPad anchors the share popover's arrow
  /// to. Null off-iPad, where it is ignored.
  Rect? _globalRect() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _open() async {
    final id = widget.storageId;
    if (id == null || _busy) return;
    final name = widget.fileName ?? 'document';
    final messenger = ScaffoldMessenger.of(context);
    final origin = _globalRect();

    setState(() => _busy = true);
    try {
      await DocumentSaver.save(
        api: widget.api,
        storageId: id,
        fileName: name,
        mimeType: widget.mimeType ?? mimeTypeForFileName(name),
        originRect: origin,
      );
    } on FileUnavailable {
      // Categorically not retryable — the blob is gone, not unreachable — so
      // this says so instead of inviting another tap.
      messenger.showSnackBar(const SnackBar(content: Text('file is no longer available')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("couldn't open that file")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = widget.isMine ? theme.accentInk : theme.ink;
    final soft = ink.withValues(alpha: 0.62);
    final name = widget.fileName ?? 'document';
    final size = widget.fileSize;
    final enabled = widget.storageId != null && !_busy;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypeBadge(theme: theme, fileName: name, ink: ink, busy: _busy),
        const SizedBox(width: 11),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                // Truncating from the right eats the extension first, which is
                // usually a filename's most useful part. Acceptable only
                // because the badge to the left already says what it is —
                // without that this would need middle truncation.
                overflow: TextOverflow.ellipsis,
                style: theme.bodyEmph.copyWith(color: ink),
              ),
              const SizedBox(height: 2),
              Text(
                size == null || size <= 0 ? 'document' : formatFileSize(size),
                style: theme.caption.copyWith(color: soft),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          _busy ? CupertinoIcons.ellipsis : CupertinoIcons.arrow_down_circle,
          size: 19,
          color: enabled ? soft : soft.withValues(alpha: 0.4),
        ),
      ],
    );

    // `FocusableTap` registers no gesture recognizer of its own, so the bare
    // `GestureDetector` inside is what actually receives the pointer. Both
    // carry the handler; wrapping alone would render a row that does nothing.
    // Never an InkWell — this app draws no ink anywhere.
    return FocusableTap(
      onTap: enabled ? _open : null,
      enabled: enabled,
      semanticLabel: 'Save $name',
      radius: 12,
      child: GestureDetector(
        onTap: enabled ? _open : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth ?? 260),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// The square extension chip. Fixed width so a column of documents lines its
/// names up regardless of whether they are `.pdf` or `.pptx`.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.theme,
    required this.fileName,
    required this.ink,
    required this.busy,
  });

  final AppTheme theme;
  final String fileName;
  final Color ink;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: ink.withValues(alpha: 0.16), width: 0.8),
      ),
      child: busy
          ? PhotoSpinner(size: 18, color: ink)
          : Text(
              fileTypeBadge(fileName),
              maxLines: 1,
              style: theme.monoTiny.copyWith(
                color: ink,
                letterSpacing: 0.2,
                fontSize: 9.5,
              ),
            ),
    );
  }
}

/// The tile a document occupies while its bytes are still going up.
///
/// Same shape as the finished row so nothing moves when the upload lands —
/// the badge becomes the progress ring, and the size line becomes the status.
/// Mirrors `_OutboundAudioRow` in `message_bubble.dart`, which exists for the
/// identical reason: an attachment with no storage id has nothing to resolve
/// and would otherwise sit on a loading state forever.
class OutboundFileRow extends StatelessWidget {
  const OutboundFileRow({
    super.key,
    required this.theme,
    required this.fileName,
    required this.fileSize,
    required this.isMine,
    required this.failed,
    required this.indicator,
    this.maxWidth,
  });

  final AppTheme theme;
  final String fileName;
  final int? fileSize;
  final bool isMine;
  final bool failed;

  /// The shared `_UploadIndicator` from `message_bubble.dart` — a ring while
  /// it climbs, a retry/discard pair once it fails.
  final Widget indicator;

  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final ink = isMine ? theme.accentInk : theme.ink;
    final soft = ink.withValues(alpha: 0.62);
    final size = fileSize;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pinned to the badge's own box while it is a ring, so the finished
          // row slots in without anything moving. Not pinned when it is the
          // retry pair — two touch targets do not fit in 40pt of width, and
          // shrinking them would put a destructive control under the minimum
          // tap size. The bubble is free to widen for those few seconds.
          if (failed)
            indicator
          else
            SizedBox(width: 40, height: 40, child: Center(child: indicator)),
          const SizedBox(width: 11),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(color: ink),
                ),
                const SizedBox(height: 2),
                Text(
                  failed
                      ? 'failed'
                      : size == null || size <= 0
                          ? 'sending…'
                          : '${formatFileSize(size)} · sending…',
                  style: theme.caption.copyWith(color: soft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
