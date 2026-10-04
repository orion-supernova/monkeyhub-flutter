import 'package:flutter/cupertino.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/document_preview.dart';
import '../media/document_saver.dart';
import '../media/file_meta.dart';
import '../media/file_url_cache.dart';
import '../models/chat_message.dart';
import '../screens/fullscreen_image_viewer.dart';
import '../screens/text_file_viewer_screen.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'app_toast.dart';
import 'photo_chrome.dart';
import 'remote_image.dart';
import 'teardown_safe.dart';

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
///
/// Plain text is the one exception — see [isPlainTextFile]. There is nothing
/// for a `.txt` to mis-render, and the receiving end of a bug report is
/// exactly the case where "download it, then open it" is friction for no
/// reason. The row's own tap opens [TextFileViewerScreen] instead; a second,
/// separately tappable disc next to the type badge — the one carrying an
/// arrow, not an eye — still downloads. That split is deliberate: this is the
/// one attachment shape with two genuinely different things a tap could mean,
/// so it is the one shape with two tap targets instead of an overloaded one.
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
    this.message,
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

  /// The message this row draws, when there is one. Only the picture preview
  /// reads it, to give its viewer a Share button.
  final ChatMessage? message;

  @override
  State<FileMessage> createState() => _FileMessageState();
}

class _FileMessageState extends State<FileMessage>
    with TeardownSafe<FileMessage> {
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

  /// What a tap on the row does — see [DocumentPreview], which owns the
  /// decision so the row and the trailing chip cannot disagree about it.
  DocumentPreviewKind get _previewKind => DocumentPreview.kindFor(
        mimeType: widget.mimeType,
        fileName: widget.fileName ?? '',
      );

  /// Whether the row opens something instead of going straight to
  /// [DocumentSaver]. Drives the eye/arrow split in the trailing chips.
  bool get _viewable => _previewKind != DocumentPreviewKind.none;

  /// The row's own tap. Opens the document for a viewable attachment,
  /// downloads for everything else — for a viewable one, downloading is
  /// [_download]'s job alone, reached through its own button rather than the
  /// row.
  Future<void> _open() async {
    final id = widget.storageId;
    if (id == null || _busy) return;

    final l10n = AppLocalizations.of(context);
    final name = widget.fileName ?? l10n.fileMessageDefaultName;

    switch (_previewKind) {
      case DocumentPreviewKind.text:
        await TextFileViewerScreen.open(
          context,
          api: widget.api,
          storageId: id,
          fileName: name,
        );
        return;
      case DocumentPreviewKind.image:
        // A picture sent as a document is still a picture. It used to render
        // as a grey plate with a `PNG` chip on it, and the only way to see it
        // was to download it.
        await FullscreenImageViewer.open(
          context,
          storageId: id,
          api: widget.api,
          // Share only: it is a document, so Save to Photos is not offered —
          // the share sheet's own "Save Image" covers it.
          message: widget.message,
        );
        return;
      case DocumentPreviewKind.native:
        // The fetch is the slow part and the spinner belongs to it, exactly as
        // it does for a download.
        setState(() => _busy = true);
        try {
          final shown = await DocumentPreview.openNative(
            api: widget.api,
            storageId: id,
            fileName: name,
          );
          if (shown) return;
        } on FileUnavailable {
          if (!mounted) return;
          AppToast.of(context).show(l10n.fileMessageUnavailable,
              tone: ToastTone.danger);
          return;
        } catch (_) {
          // Falls through to the hand-off below rather than reporting: a
          // preview that could not open is not a failure the user has to hear
          // about when the thing they asked for can still happen.
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        if (!mounted) return;
        await _download();
        return;
      case DocumentPreviewKind.none:
        await _download();
        return;
    }
  }

  Future<void> _download() async {
    final id = widget.storageId;
    if (id == null || _busy) return;
    final l10n = AppLocalizations.of(context);
    final name = widget.fileName ?? l10n.fileMessageDefaultName;
    final toast = AppToast.of(context);
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
      toast.show(
        l10n.fileMessageUnavailable,
        tone: ToastTone.danger,
      );
    } catch (_) {
      toast.show(
        l10n.fileMessageOpenFailed,
        tone: ToastTone.danger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ink = widget.isMine ? theme.accentInk : theme.ink;
    final soft = ink.withValues(alpha: 0.62);
    final name = widget.fileName ?? l10n.fileMessageDefaultName;
    final size = widget.fileSize;
    final enabled = widget.storageId != null && !_busy;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypeBadge(
          theme: theme,
          fileName: name,
          ink: ink,
          // A real thumbnail when the document IS a picture — the badge is a
          // stand-in for a preview nobody could see, and where the preview is
          // free there is no reason to draw the stand-in instead.
          api: widget.api,
          thumbnailStorageId:
              _previewKind == DocumentPreviewKind.image ? widget.storageId : null,
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                // One line, deliberately. A document sits in a run of other
                // messages and has to keep a message's rhythm — letting the
                // name wrap made a six-line bubble out of a filename and threw
                // the transcript's spacing out. The full name is reachable
                // instead; see [FileMessage].
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyEmph.copyWith(color: ink),
              ),
              const SizedBox(height: 2),
              Text(
                size == null || size <= 0
                    ? l10n.fileMessageDefaultName
                    : formatFileSize(size),
                style: theme.caption.copyWith(color: soft),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (_viewable) ...[
          // Decorative — part of the row's own tap target below, not its own
          // button. It says what the row does, nothing more.
          _SaveChip(theme: theme, ink: ink, enabled: enabled, busy: false, viewable: true),
          const SizedBox(width: 8),
          // The one thing that actually downloads. Its own `FocusableTap`
          // nested inside the row's wins the tap for a press landing on it —
          // Flutter resolves a tap in favour of the innermost recognizer when
          // more than one shares the same pointer — so this and the row below
          // can disagree about what a tap on THIS 28pt circle does.
          _SaveChip(
            theme: theme,
            ink: ink,
            enabled: enabled,
            busy: _busy,
            onTap: _download,
            semanticLabel: l10n.fileMessageSaveSemanticLabel(name),
          ),
        ] else
          _SaveChip(theme: theme, ink: ink, enabled: enabled, busy: _busy),
      ],
    );

    // `FocusableTap` registers no gesture recognizer of its own, so the bare
    // `GestureDetector` inside is what actually receives the pointer. Both
    // carry the handler; wrapping alone would render a row that does nothing.
    // Never an InkWell — this app draws no ink anywhere.
    return FocusableTap(
      onTap: enabled ? _open : null,
      enabled: enabled,
      semanticLabel: _viewable
          ? l10n.fileMessageViewSemanticLabel(name)
          : l10n.fileMessageSaveSemanticLabel(name),
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
///
/// It says what the file IS, and goes on saying it while the row is busy — the
/// progress indication belongs to [_SaveChip], which is where the tap landed.
/// Swapping this for a spinner as well signalled the same thing twice and threw
/// away the one label that answers "what am I about to open".
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.theme,
    required this.fileName,
    required this.ink,
    this.api,
    this.thumbnailStorageId,
  });

  final AppTheme theme;
  final String fileName;
  final Color ink;

  final ChatApi? api;

  /// Non-null draws the picture itself in place of the extension chip. Only
  /// ever set for a document this app can decode — see
  /// [DocumentPreview.kindFor] — so there is no format here that could fail to
  /// render and leave a hole where the badge used to be.
  final String? thumbnailStorageId;

  @override
  Widget build(BuildContext context) {
    final id = thumbnailStorageId;
    final api = this.api;
    if (id != null && api != null) {
      return SizedBox(
        width: 40,
        height: 40,
        child: RemoteImage(
          storageId: id,
          api: api,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          // 40pt at 3x. Decoding the full picture to paint a chip is what
          // makes a transcript of documents stutter.
          decodeWidth: 120,
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: ink.withValues(alpha: 0.16), width: 0.8),
      ),
      child: Text(
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

/// The trailing save (or, on a viewable attachment, view) affordance.
///
/// A bare 19pt glyph floating beside a 40pt badge read as decoration rather
/// than a control, and swapped to an ellipsis of a different width while
/// saving, which moved the name column under the user's thumb. A fixed 28pt
/// circle fixes both: the footprint never changes, and the disc reads as
/// something you can press.
///
/// [onTap] null (the default) leaves it decorative — it carries no gesture of
/// its own, because the whole row is the tap target, as it has always been.
/// Non-null makes the disc its OWN tap target instead: the download button
/// that sits beside the eye indicator on a viewable attachment, where the
/// row's tap opens the viewer and only this button downloads.
class _SaveChip extends StatelessWidget {
  const _SaveChip({
    required this.theme,
    required this.ink,
    required this.enabled,
    required this.busy,
    this.viewable = false,
    this.onTap,
    this.semanticLabel,
  });

  final AppTheme theme;
  final Color ink;

  /// False while the bytes are still going up, or on a message whose upload
  /// failed — there is nothing to save, and the disc says so by fading.
  final bool enabled;
  final bool busy;

  /// Whether the glyph reads as "view" rather than "save" — a decorative-only
  /// distinction; [onTap] is what actually decides whether this downloads.
  final bool viewable;

  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    final strength = enabled || busy ? 1.0 : 0.4;
    final disc = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ink.withValues(alpha: 0.10 * strength),
        border: Border.all(
          color: ink.withValues(alpha: 0.16 * strength),
          width: 0.8,
        ),
      ),
      child: busy
          ? PhotoSpinner(size: 15, color: ink)
          : Icon(
              viewable ? CupertinoIcons.eye : CupertinoIcons.arrow_down,
              size: 15,
              color: ink.withValues(alpha: 0.72 * strength),
            ),
    );

    final tap = onTap;
    if (tap == null) return disc;

    return FocusableTap(
      onTap: enabled ? tap : null,
      enabled: enabled,
      semanticLabel: semanticLabel,
      shape: FocusRingShape.circle,
      radius: _size / 2,
      child: GestureDetector(
        onTap: enabled ? tap : null,
        behavior: HitTestBehavior.opaque,
        child: disc,
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
    final l10n = AppLocalizations.of(context);
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
                      ? l10n.fileMessageUploadFailedLabel
                      : size == null || size <= 0
                      ? l10n.fileMessageSendingLabel
                      : l10n.fileMessageSizeSendingLabel(formatFileSize(size)),
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
