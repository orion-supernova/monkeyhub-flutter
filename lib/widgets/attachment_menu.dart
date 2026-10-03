import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart' show SpringPress, TileTone, tileColor;
import 'sheet_kit.dart'
    show SheetFrame, SheetRise, sheetGroupFill;
import '../l10n/text_case.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // iMessage's iOS 26 "+" menu: one column of large rows, each a solid
    // coloured disc and a name, rising in one after another. Camera leads —
    // the thing people reach for most — then the rest of the media, then the
    // things that are not media at all.
    final rows = <(AttachmentMenuChoice, IconData, String, TileTone)>[
      if (allowMedia) ...[
        (
          AttachmentMenuChoice.camera,
          CupertinoIcons.camera_fill,
          l10n.attachmentMenuCameraLabel,
          TileTone.gray,
        ),
        (
          AttachmentMenuChoice.gallery,
          CupertinoIcons.photo_fill_on_rectangle_fill,
          l10n.attachmentMenuPhotoLabel,
          TileTone.pink,
        ),
        (
          AttachmentMenuChoice.video,
          CupertinoIcons.film_fill,
          l10n.attachmentMenuVideoLabel,
          TileTone.purple,
        ),
        // Absent in a browser. `record_web` writes an opus/webm blob rather
        // than the AAC the send path and the players downstream both assume,
        // and it ignores the temp-file path the recorder screen asks
        // path_provider for — which has no web implementation to ask.
        if (!kIsWeb)
          (
            AttachmentMenuChoice.voice,
            CupertinoIcons.mic_fill,
            l10n.attachmentMenuVoiceLabel,
            TileTone.orange,
          ),
        // Gated for the same reason voice is, and one more: `camera_web`
        // implements none of the video-recording API at all.
        if (!kIsWeb)
          (
            AttachmentMenuChoice.videoNote,
            CupertinoIcons.videocam_circle_fill,
            l10n.attachmentMenuVideoNoteLabel,
            TileTone.red,
          ),
        // Not web-gated: `file_selector` has a real web implementation.
        (
          AttachmentMenuChoice.file,
          CupertinoIcons.doc_fill,
          l10n.attachmentMenuFileLabel,
          TileTone.indigo,
        ),
      ],
      // Web-gated: a browser's Geolocation API has no background delivery, so
      // a live share started in a tab silently stops when the tab does.
      if (!kIsWeb && allowLocation)
        (
          AttachmentMenuChoice.location,
          CupertinoIcons.location_fill,
          l10n.attachmentMenuLocationLabel,
          TileTone.green,
        ),
      // Outside both guardian switches on purpose: a poll, a checklist and an
      // event are text, which a child who may type at all may already send.
      // Mirrored server-side by `TEXT_SHAPED_TYPES` in `messages.ts`.
      (
        AttachmentMenuChoice.poll,
        CupertinoIcons.chart_bar_alt_fill,
        l10n.attachmentMenuPollLabel,
        TileTone.teal,
      ),
      (
        AttachmentMenuChoice.checklist,
        CupertinoIcons.checkmark_square_fill,
        l10n.attachmentMenuChecklistLabel,
        TileTone.blue,
      ),
      (
        AttachmentMenuChoice.event,
        CupertinoIcons.calendar,
        l10n.attachmentMenuEventLabel,
        TileTone.red,
      ),
    ];
    return SheetFrame(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++)
              SheetRise(
                index: i,
                child: _AttachRow(
                  icon: rows[i].$2,
                  label: sentenceCaseOf(context, rows[i].$3),
                  tone: rows[i].$4,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop(rows[i].$1);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One row of the menu: a solid coloured disc with a white glyph, then the
/// name in body type. The press is a flat fill that fades out, the iOS menu
/// highlight, plus a slight spring on the whole row.
class _AttachRow extends StatefulWidget {
  const _AttachRow({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final TileTone tone;
  final VoidCallback onTap;

  @override
  State<_AttachRow> createState() => _AttachRowState();
}

class _AttachRowState extends State<_AttachRow> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: SpringPress(
        onTap: widget.onTap,
        haptic: false,
        scale: 0.98,
        semanticLabel: widget.label,
        child: AnimatedContainer(
          duration: _pressed
              ? Duration.zero
              : const Duration(milliseconds: 240),
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _pressed ? sheetGroupFill(theme) : null,
            borderRadius: BorderRadius.circular(
              (theme.radiusXl * 0.7).clamp(6.0, 14.0),
            ),
          ),
          child: Row(
            children: [
              _Disc(icon: widget.icon, color: tileColor(theme, widget.tone)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.body.copyWith(
                    fontSize: 17,
                    color: theme.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Lit from above, like an app icon on the home screen; a flat disc
          // reads as a Material avatar.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.14)!, color],
          ),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      );
}
