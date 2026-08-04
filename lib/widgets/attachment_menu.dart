import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';

class AttachmentMenuChoice {
  const AttachmentMenuChoice._(this.id);
  final String id;
  static const gallery = AttachmentMenuChoice._('gallery');
  static const camera = AttachmentMenuChoice._('camera');
  static const voice = AttachmentMenuChoice._('voice');
  static const video = AttachmentMenuChoice._('video');
  static const file = AttachmentMenuChoice._('file');
}

Future<AttachmentMenuChoice?> showAttachmentMenu(BuildContext context) {
  return showAdaptiveSheet<AttachmentMenuChoice>(
    context,
    builder: (_) => const _AttachmentSheet(),
  );
}

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final tiles = <(AttachmentMenuChoice, IconData, String)>[
      (
        AttachmentMenuChoice.gallery,
        CupertinoIcons.photo,
        l10n.attachmentMenuPhotoLabel,
      ),
      (
        AttachmentMenuChoice.video,
        CupertinoIcons.film,
        l10n.attachmentMenuVideoLabel,
      ),
      (
        AttachmentMenuChoice.camera,
        CupertinoIcons.camera,
        l10n.attachmentMenuCameraLabel,
      ),
      // Absent in a browser. `record_web` writes an opus/webm blob rather than
      // the AAC the send path and the players downstream both assume, and it
      // ignores the temp-file path the recorder screen asks path_provider for —
      // which has no web implementation to ask. Offering a tile that records
      // something nobody can play back would be worse than not offering it.
      if (!kIsWeb)
        (
          AttachmentMenuChoice.voice,
          CupertinoIcons.mic,
          l10n.attachmentMenuVoiceLabel,
        ),
      // Deliberately NOT web-gated, unlike voice above. `file_selector` has a
      // real web implementation backed by `<input type=file>`, and the bytes
      // it hands back are exactly what the upload path already wants.
      (
        AttachmentMenuChoice.file,
        CupertinoIcons.doc,
        l10n.attachmentMenuFileLabel,
      ),
    ];
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + bottomInset),
        child: DefaultTextStyle(
          style: theme.body.copyWith(color: theme.ink),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Meaningless once dismiss-by-drag isn't a thing — the desktop
              // popover closes via barrier tap / Esc, not a drag gesture.
              if (context.isCompact) ...[
                Container(
                  width: 36,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: theme.inkMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final t in tiles)
                    Expanded(
                      child: _AttachTile(
                        icon: t.$2,
                        label: t.$3,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(t.$1);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachTile extends StatefulWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_AttachTile> createState() => _AttachTileState();
}

class _AttachTileState extends State<_AttachTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.surfaceRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.divider, width: 0.8),
                ),
                child: Icon(widget.icon, size: 20, color: theme.accent),
              ),
              const SizedBox(height: 7),
              Text(
                widget.label,
                style: theme.monoTiny.copyWith(
                  color: theme.inkSoft,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
