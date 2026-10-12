import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'glass_reveal.dart';
import 'glass_surface.dart';
import 'ios_kit.dart' show SpringPress, TileTone, tileColor;
import 'sheet_kit.dart' show SheetRise, sheetGroupFill;
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

  /// An in-chat game: live, turn by turn in a DM, or solo against the bot.
  /// Text-shaped for the guardian policy, like the three above.
  static const game = AttachmentMenuChoice._('game');
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
///
/// [anchor] is the "+" button's rect in global coordinates. The menu is a
/// glass panel that grows out of the button and over the composer, the iOS 26
/// Messages menu, on every window size: its corner sits where the button's
/// corner is, so the button (which the host hides meanwhile, see
/// `ChatComposerLiquid.attachHidden`) reads as having become the menu. It used
/// to be a full-width bottom sheet: flat, edge to edge, with nothing to say
/// where it came from. Null anchors it to the bottom-leading corner, where the
/// button would be.
Future<AttachmentMenuChoice?> showAttachmentMenu(
  BuildContext context, {
  Rect? anchor,
  bool allowMedia = true,
  bool allowLocation = true,
  bool allowGames = true,
  bool unifiedGallery = false,
}) {
  final calm = MotionScope.of(context).calm;
  // The root navigator: [anchor] is in window coordinates, and on a desktop
  // the room sits in a nested pane navigator whose overlay is not the window.
  return Navigator.of(context, rootNavigator: true).push(_AttachMenuRoute(
    anchor: anchor,
    calm: calm,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    child: _AttachmentSheet(
      allowMedia: allowMedia,
      allowLocation: allowLocation,
      allowGames: allowGames,
      unifiedGallery: unifiedGallery,
    ),
  ));
}

/// The menu's route: a light dim over the chat and the glass panel placed
/// over the anchor, growing out of the button's corner.
class _AttachMenuRoute extends PopupRoute<AttachmentMenuChoice> {
  _AttachMenuRoute({
    required this.anchor,
    required this.calm,
    required this.barrierLabel,
    required this.child,
  });

  final Rect? anchor;
  final bool calm;
  final Widget child;

  @override
  final String barrierLabel;

  /// Lighter than a sheet's dim: the glass is what lifts the menu, and the
  /// chat behind it is still the place it belongs to.
  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.22);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      calm ? Duration.zero : const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration =>
      calm ? Duration.zero : const Duration(milliseconds: 260);

  /// Widest the panel gets: a column of names, not a page.
  static const double _maxWidth = 264;

  /// The panel's corner, shared with [_AttachmentSheet] so the reveal's clip
  /// lands on exactly the shape the glass draws.
  static double _radius(BuildContext context) =>
      (ThemeScope.of(context).radiusXl * 1.4).clamp(16.0, 30.0);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final a = anchor ??
        Rect.fromLTWH(16, size.height - media.padding.bottom - 56, 40, 40);
    final width = (size.width - 24).clamp(0.0, _maxWidth);
    // Out of the side the button is on: its leading edge in a left-hand
    // composer, its trailing edge if it ever sits on the right.
    final fromLeft = a.center.dx < size.width / 2;
    final left = fromLeft
        ? a.left.clamp(12.0, size.width - width - 12)
        : (a.right - width).clamp(12.0, size.width - width - 12);
    // Over the button and the field beside it, not above them: the panel's
    // corner is the button's corner.
    final bottom = size.height - a.bottom;
    // Less the glass's own 8pt padding top and bottom: this bounds the rows.
    final maxHeight = (a.bottom - media.padding.top - 12 - 16)
        .clamp(120.0, double.infinity);
    return Stack(
      children: [
        Positioned(
          left: left,
          bottom: bottom,
          width: width,
          child: _AttachMenuReveal(
            animation: animation,
            fromLeft: fromLeft,
            button: a.size,
            radius: _radius(context),
            // A route of its own, so nothing above it sets a text style.
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The "+" becoming the menu. The panel is laid out at full size from the
/// first frame and revealed through a clip that starts as a circle exactly
/// over the button and opens into the panel's rounded rectangle, so the
/// button's own shape is what grows. Its rows fade in once there is room for
/// them. Folding back is the same in reverse, into the button's circle.
///
/// A clip, not a scale: scaling the panel down to button size squashed a tall
/// rounded rectangle into a small bar that read as a separate sheet fading in.
/// The glass is never faded either way (see [GlassReveal]); the clip bounds
/// its blur, which is free.
class _AttachMenuReveal extends StatelessWidget {
  const _AttachMenuReveal({
    required this.animation,
    required this.fromLeft,
    required this.button,
    required this.radius,
    required this.child,
  });

  final Animation<double> animation;
  final bool fromLeft;
  final Size button;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The shape opens on a soft spring; the slight swell past full size is a
    // scale, since a clip cannot grow past the panel it reveals.
    // Slow out of the button, fast through the middle, soft landing: an
    // ease-out spent its first frame growing the circle by an eighth of the
    // panel, so the circle was never seen. Folding back mirrors it.
    final open = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.45, 0, 0.15, 1),
      reverseCurve: const Cubic(0.6, 0, 0.7, 1),
    );
    final swell = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.3, 1.5, 0.5, 1),
      reverseCurve: Curves.easeInCubic,
    );
    final corner = fromLeft ? Alignment.bottomLeft : Alignment.bottomRight;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = open.value;
        return Transform.scale(
          scale: 0.94 + 0.06 * swell.value,
          alignment: corner,
          child: ClipRRect(
            clipper: _ButtonToPanel(
              t: t,
              button: button,
              radius: radius,
              fromLeft: fromLeft,
            ),
            // Unclipped once open, so the glass's shadow is not cut off at
            // its own edge.
            clipBehavior: t >= 1 ? Clip.none : Clip.antiAlias,
            child: GlassContentFade(
              opacity: const Interval(0.35, 1).transform(t),
              // The glass's corner follows the clip's: drawn at the panel's
              // full radius, its corner would sit inside the button's circle
              // and flatten it where they overlap.
              child: GlassSurface(
                radius: _ButtonToPanel.cornerAt(t, button, radius),
                padding: const EdgeInsets.all(8),
                child: child!,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// The reveal's shape at [t]: the button's circle at 0, the panel's rounded
/// rectangle at 1, held to the button's corner throughout.
class _ButtonToPanel extends CustomClipper<RRect> {
  const _ButtonToPanel({
    required this.t,
    required this.button,
    required this.radius,
    required this.fromLeft,
  });

  final double t;
  final Size button;
  final double radius;
  final bool fromLeft;

  /// The corner radius at [t]: the button's half-width to the panel's own.
  static double cornerAt(double t, Size button, double radius) =>
      button.shortestSide / 2 + (radius - button.shortestSide / 2) * t;

  @override
  RRect getClip(Size size) {
    final w = button.width + (size.width - button.width) * t;
    final h = button.height + (size.height - button.height) * t;
    final r = cornerAt(t, button, radius);
    final left = fromLeft ? 0.0 : size.width - w;
    return RRect.fromLTRBR(
        left, size.height - h, left + w, size.height, Radius.circular(r));
  }

  @override
  bool shouldReclip(_ButtonToPanel old) =>
      old.t != t || old.button != button || old.radius != radius;
}

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({
    required this.allowMedia,
    required this.allowLocation,
    this.allowGames = true,
    this.unifiedGallery = false,
  });

  final bool allowMedia;
  final bool allowLocation;

  /// Off in Saved Messages, where there is nobody to play.
  final bool allowGames;

  /// One "Gallery" row for photos and videos together, where the host's
  /// picker shows both (the inline picker, on a phone). Elsewhere the system
  /// pickers are one kind each, so Photo and Video stay two rows.
  final bool unifiedGallery;

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
          unifiedGallery
              ? l10n.attachmentMenuGalleryLabel
              : l10n.attachmentMenuPhotoLabel,
          TileTone.pink,
        ),
        if (!unifiedGallery)
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
      if (allowGames)
        (
          AttachmentMenuChoice.game,
          CupertinoIcons.gamecontroller_fill,
          l10n.chatGameMenuItem,
          TileTone.indigo,
        ),
    ];
    // The glass is the reveal's (see [_AttachMenuReveal]): its corner moves.
    return SingleChildScrollView(
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
