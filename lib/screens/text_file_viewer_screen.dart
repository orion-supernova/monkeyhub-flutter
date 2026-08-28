import 'dart:convert';

import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/document_saver.dart';
import '../media/file_url_cache.dart' show FileUnavailable;
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/app_toast.dart';
import '../widgets/photo_chrome.dart';

/// In-app preview for a plain-text attachment — the one exception to
/// `FileMessage`'s "no in-app viewer" rule (see the doc comment there). A
/// `.txt` log is read, not opened in another app, so making that cost a
/// download first is friction with no payoff. Reached only for attachments
/// `isPlainTextFile` accepts; every other document keeps tapping straight to
/// [DocumentSaver].
///
/// Downloading stays one tap away via the trailing action — this replaces the
/// *default* tap for a text file, it doesn't remove the ability to save one.
class TextFileViewerScreen extends StatefulWidget {
  const TextFileViewerScreen({
    super.key,
    required this.api,
    required this.storageId,
    required this.fileName,
  });

  final ChatApi api;
  final String storageId;
  final String fileName;

  static Future<void> open(
    BuildContext context, {
    required ChatApi api,
    required String storageId,
    required String fileName,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => TextFileViewerScreen(
          api: api,
          storageId: storageId,
          fileName: fileName,
        ),
      ),
    );
  }

  @override
  State<TextFileViewerScreen> createState() => _TextFileViewerScreenState();
}

class _TextFileViewerScreenState extends State<TextFileViewerScreen> {
  /// Past this many bytes the view shows a prefix rather than the whole file.
  /// A multi-megabyte log laid out as one `SelectableText` locks the frame up
  /// shaping every glyph at once, and nobody reads a log that way regardless —
  /// the full file is still one download away.
  static const _previewCapBytes = 2 * 1024 * 1024;

  late final Future<({String text, bool truncated})> _load = _fetch();
  bool _saving = false;

  Future<({String text, bool truncated})> _fetch() async {
    final bytes = await DocumentSaver.fetchBytes(
      api: widget.api,
      storageId: widget.storageId,
    );
    final truncated = bytes.length > _previewCapBytes;
    final slice = truncated ? bytes.sublist(0, _previewCapBytes) : bytes;
    // Malformed rather than strict: a byte offset that lands mid-codepoint —
    // guaranteed whenever the truncation above cuts through a multi-byte
    // character — must not turn "long log" into "nothing rendered".
    return (text: utf8.decode(slice, allowMalformed: true), truncated: truncated);
  }

  Future<void> _download() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    setState(() => _saving = true);
    try {
      await DocumentSaver.save(
        api: widget.api,
        storageId: widget.storageId,
        fileName: widget.fileName,
        mimeType: 'text/plain',
      );
    } on FileUnavailable {
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.arrow_back,
                            color: theme.inkSoft,
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodyEmph,
                          ),
                        ),
                        IconButton(
                          onPressed: _saving ? null : _download,
                          tooltip: l10n.textFileViewerDownloadTooltip,
                          icon: _saving
                              ? PhotoSpinner(size: 16, color: theme.inkSoft)
                              : Icon(
                                  Icons.file_download_outlined,
                                  color: theme.inkSoft,
                                  size: 18,
                                ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: FutureBuilder<({String text, bool truncated})>(
                        future: _load,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return Center(
                              child: PhotoSpinner(
                                size: 24,
                                color: theme.accent,
                              ),
                            );
                          }
                          if (snap.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  snap.error is FileUnavailable
                                      ? l10n.fileMessageUnavailable
                                      : l10n.fileMessageOpenFailed,
                                  style: theme.bodySoft,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          final data = snap.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data.truncated)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.surfaceSunken,
                                    borderRadius: BorderRadius.circular(
                                      theme.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    l10n.textFileViewerTruncatedNotice,
                                    style: theme.caption.copyWith(
                                      color: theme.inkMuted,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.only(
                                    bottom: edgeToEdgeBottom(context, 24),
                                  ),
                                  child: SelectableText(
                                    data.text,
                                    style: theme.mono,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
