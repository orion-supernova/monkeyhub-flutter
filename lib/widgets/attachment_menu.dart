import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;

class AttachmentMenuChoice {
  const AttachmentMenuChoice._(this.id);
  final String id;
  static const gallery = AttachmentMenuChoice._('gallery');
  static const camera = AttachmentMenuChoice._('camera');
  static const voice = AttachmentMenuChoice._('voice');
  static const video = AttachmentMenuChoice._('video');

  /// The circular video note. Here as well as on the composer's drag control
  /// because a mode reachable only by dragging is a mode a screen-reader user
  /// does not have — this sheet is the named, tappable route to it.
  static const videoNote = AttachmentMenuChoice._('videoNote');
  static const file = AttachmentMenuChoice._('file');
  static const location = AttachmentMenuChoice._('location');

  /// The three interactive messages. Here rather than behind a second menu
  /// because this sheet is already the answer to "what am I sending", and a
  /// poll is one of the answers — Telegram, Slack and every group chat that has
  /// them put them exactly here for the same reason.
  ///
  /// Deliberately NOT web-gated, unlike voice and the video note. These are
  /// text and a date: there is no recorder, no camera and no file picker
  /// involved, so every platform can compose one and every platform can answer
  /// one.
  static const poll = AttachmentMenuChoice._('poll');
  static const checklist = AttachmentMenuChoice._('checklist');
  static const event = AttachmentMenuChoice._('event');
}

/// [allowMedia] and [allowLocation] are the guardian policy, mirrored from
/// `FamilyService`. Two flags rather than one because the two backend switches
/// are genuinely independent — see `LOCATION_POLICY_FLAG` in
/// `backend/convex/childGuard.ts` — so a child may legitimately be allowed
/// either without the other.
///
/// A refused capability is REMOVED from the sheet rather than dimmed. The
/// server refuses the send regardless, so a visible-but-dead tile would be a
/// tap whose only possible outcome is a refusal, and children are the one
/// audience for whom that reads as the app being broken.
Future<AttachmentMenuChoice?> showAttachmentMenu(
  BuildContext context, {
  bool allowMedia = true,
  bool allowLocation = true,
}) {
  return showAdaptiveSheet<AttachmentMenuChoice>(
    context,
    builder: (_) => _AttachmentSheet(
      allowMedia: allowMedia,
      allowLocation: allowLocation,
    ),
  );
}

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({
    required this.allowMedia,
    required this.allowLocation,
  });

  final bool allowMedia;
  final bool allowLocation;

  /// Tiles sit four to a row no matter how many are on offer. A fixed grid
  /// reads as considered furniture; a single row that keeps redividing its
  /// width by however many tiles happen to survive the guardian policy and
  /// `kIsWeb` gates is what made the old sheet feel squashed.
  static const _columns = 4;
  static const _tileSpacing = 12.0;
  static const _rowSpacing = 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final tiles = <(AttachmentMenuChoice, IconData, String)>[
      if (allowMedia) ...[
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
        // Absent in a browser. `record_web` writes an opus/webm blob rather
        // than the AAC the send path and the players downstream both assume,
        // and it ignores the temp-file path the recorder screen asks
        // path_provider for — which has no web implementation to ask. Offering
        // a tile that records something nobody can play back would be worse
        // than not offering it.
        if (!kIsWeb)
          (
            AttachmentMenuChoice.voice,
            CupertinoIcons.mic,
            l10n.attachmentMenuVoiceLabel,
          ),
        // Gated for the same reason voice is, and one more: `camera_web`
        // implements none of the video-recording API at all.
        if (!kIsWeb)
          (
            AttachmentMenuChoice.videoNote,
            CupertinoIcons.videocam_circle,
            l10n.attachmentMenuVideoNoteLabel,
          ),
        // Deliberately NOT web-gated, unlike voice above. `file_selector` has a
        // real web implementation backed by `<input type=file>`, and the bytes
        // it hands back are exactly what the upload path already wants.
        (
          AttachmentMenuChoice.file,
          CupertinoIcons.doc,
          l10n.attachmentMenuFileLabel,
        ),
      ],
      // Web-gated, unlike the document tile beside it. A browser's Geolocation
      // API has no distance filter and no background delivery, so a live share
      // started here would be a share the tab silently stops feeding the moment
      // it is not the foreground tab — and the tab is also the only thing that
      // could stop it. Offering half the feature, in the half of the app where
      // its failure is invisible, is worse than not offering it. Locations SENT
      // from a phone still render on web, which is the half that matters.
      if (!kIsWeb && allowLocation)
        (
          AttachmentMenuChoice.location,
          CupertinoIcons.location,
          l10n.attachmentMenuLocationLabel,
        ),
      // Outside the `allowMedia` block on purpose, and outside `allowLocation`
      // too. A poll carries no blob and no coordinates — it is a sentence and
      // some labels, which a child who may type at all may already send — so
      // neither guardian switch has anything to say about it. Mirrored
      // server-side by `TEXT_SHAPED_TYPES` in `messages.ts`, which is the
      // authority; this sheet only decides what to offer.
      (
        AttachmentMenuChoice.poll,
        CupertinoIcons.chart_bar_alt_fill,
        l10n.attachmentMenuPollLabel,
      ),
      (
        AttachmentMenuChoice.checklist,
        CupertinoIcons.checkmark_square,
        l10n.attachmentMenuChecklistLabel,
      ),
      (
        AttachmentMenuChoice.event,
        CupertinoIcons.calendar,
        l10n.attachmentMenuEventLabel,
      ),
    ];
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottomInset),
        child: DefaultTextStyle(
          style: theme.body.copyWith(color: theme.ink),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrabber(),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth -
                          _tileSpacing * (_columns - 1)) /
                      _columns;
                  return Wrap(
                    spacing: _tileSpacing,
                    runSpacing: _rowSpacing,
                    children: [
                      for (final t in tiles)
                        SizedBox(
                          width: tileWidth,
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
                  );
                },
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
    return FocusableTap(
      onTap: widget.onTap,
      radius: theme.radiusMd,
      semanticLabel: widget.label,
      child: GestureDetector(
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
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 23, color: theme.accent),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.monoTiny.copyWith(
                    color: theme.inkSoft,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
