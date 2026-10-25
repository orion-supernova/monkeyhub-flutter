import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
// Narrowed on purpose: the one thing this file needs from Material is the
// determinate progress ring — there is no widgets-level progress indicator.
import 'package:flutter/material.dart' show CircularProgressIndicator;

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/density.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';
import 'spring_press.dart';

// Photo-specific controls that sit on media glass. The glass itself, the
// icon/pill buttons and the media palette are shared (liquid_glass.dart,
// glass_buttons.dart); only what exists solely for photos lives here.

/// The one spinner the photo screens use.
///
/// Was copy-pasted verbatim in three places — the camera preview, the post-
/// capture editor and the avatar cropper — each spelling out the same
/// `SizedBox(22, 22)` wrapping a `strokeWidth: 2` indicator. Three copies of a
/// number is three chances for one of them to drift, and a spinner that is 22pt
/// on one screen and 24 on the next is exactly the kind of difference nobody
/// notices and everybody feels.
///
/// [value] is null for indeterminate — the usual case, where there is nothing to
/// count. Pass 0..1 where the work reports itself honestly: an upload that knows
/// how many bytes have gone out. Never pass a made-up number; a bar that moves
/// on a timer is worse than one that admits it doesn't know.
class PhotoSpinner extends StatelessWidget {
  const PhotoSpinner({super.key, this.size = 22, this.color, this.value});

  final double size;

  /// Defaults to [MediaGlass.inkDim] — legible over any photograph, quiet
  /// enough not to compete with it. Pass `theme.accent` on the surfaces that
  /// aren't over a photo.
  final Color? color;

  /// 0..1, or null for indeterminate.
  final double? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: 2,
        color: color ?? MediaGlass.inkDim,
      ),
    );
  }
}

/// The two send-time toggles. They live here rather than in the chat editor
/// that first grew them because the photo tray puts the same two controls on
/// the same glass rail — a bulk send has exactly the same two decisions to
/// make, and a near-copy of a 40pt circle is how two screens that are meant to
/// read as one surface start to drift apart.
/// The circled "1" — arms burn-after-reading for this photo.
///
/// Sized to the glass buttons beside it (Density.iconButton) so the rail sits on one baseline.
/// Kept hand-drawn rather than swapped for an icon: nothing in any icon set
/// says "they get one look at this", and the numeral does.
class PhotoViewOnceToggle extends StatelessWidget {
  const PhotoViewOnceToggle({
    super.key,
    required this.active,
    required this.accent,
    required this.accentInk,
    required this.onTap,
  });

  final bool active;
  final Color accent;
  final Color accentInk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = active
        ? accentInk
        : (enabled ? MediaGlass.ink : MediaGlass.inkDisabled);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: active
          ? l10n.cameraEditorScreenViewOnceOnSemanticLabel
          : l10n.cameraEditorScreenViewOnceOffSemanticLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: LiquidGlass(
          tone: GlassTone.media,
          tint: active ? accent : null,
          child: SizedBox(
            width: Density.regular.iconButton,
            height: Density.regular.iconButton,
            child: Center(
              child: Text(
                '1',
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The HD switch: send at source resolution instead of the capped default.
///
/// Deliberately built as a near-twin of [PhotoViewOnceToggle] — same 40pt circle,
/// same glass surface, same accent fill when armed — because the two sit side
/// by side and are the same KIND of control: a per-photo property of the send,
/// not a tool that changes the picture.
class PhotoHdToggle extends StatelessWidget {
  const PhotoHdToggle({
    super.key,
    required this.active,
    required this.accent,
    required this.accentInk,
    required this.onTap,
  });

  final bool active;
  final Color accent;
  final Color accentInk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = active
        ? accentInk
        : (enabled ? MediaGlass.ink : MediaGlass.inkDisabled);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: active
          ? l10n.cameraEditorScreenHdOnSemanticLabel
          : l10n.cameraEditorScreenHdOffSemanticLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: LiquidGlass(
          tone: GlassTone.media,
          tint: active ? accent : null,
          child: SizedBox(
            width: Density.regular.iconButton,
            height: Density.regular.iconButton,
            child: Center(
              child: Text(
                'HD',
                style: TextStyle(
                  color: fg,
                  // The meta size, a step under the view-once "1": two glyphs
                  // in the same circle need the room.
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Over-media primitives ──────────────────────────────────────────────
// Small marks that sit ON a photo or video rather than on app chrome: a
// flat dark wash, white Cupertino glyphs, 13pt meta on the theme's body face.
// Deliberately NOT glass — dozens of these can be on screen in a grid or a
// transcript, and a backdrop blur per tile is a frame budget spent on a
// control nobody looks at for long. (A [LiquidGlass] note capsule is the
// exception: there is one at a time, over a static editor.)

/// The wash behind every over-media mark: dark enough to carry white on a
/// bright photo, light enough not to punch a hole in a dark one.
const Color kMediaScrim = Color(0x8C000000);

/// A small round control floating over a picture — re-crop, remove, rotate:
/// a dark translucent disc with a white glyph, the Photos edit control.
/// Replaces the composers' `_PhotoChip` / `_SlotChip` twins.
class MediaOverlayChip extends StatelessWidget {
  const MediaOverlayChip({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.size = 30,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SpringPress(
      onTap: onTap,
      scale: PressSpec.scaleSmall,
      semanticLabel: semanticLabel,
      focusShape: FocusRingShape.circle,
      focusRadius: size / 2,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: kMediaScrim,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: size * 0.5,
          color: enabled ? MediaGlass.ink : MediaGlass.inkDisabled,
        ),
      ),
    );
  }
}

/// THE play mark over a video: a dark disc with a white play glyph, nudged
/// right so the triangle looks centred. One recipe at any [size] — the app
/// had five (64/36, 52/28, 46/26…) and a Material glyph. Not tappable on its
/// own: the tile under it owns the tap.
class MediaPlayDisc extends StatelessWidget {
  const MediaPlayDisc({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: kMediaScrim,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.only(left: size * 0.06),
            child: Icon(
              CupertinoIcons.play_fill,
              size: size * 0.46,
              color: MediaGlass.ink,
            ),
          ),
        ),
      );
}

/// A one-line note on a media glass capsule above an editor's rail — "Sends
/// in full resolution", "Opens once": an optional glyph and 13pt text.
/// Replaces the editor's identical `_hdNote` / `_viewOnceNote` pair.
class MediaNoteCapsule extends StatelessWidget {
  const MediaNoteCapsule({
    super.key,
    required this.text,
    this.icon,
    this.iconColor,
    this.glyph,
  });

  final String text;
  final IconData? icon;

  /// A drawn glyph in place of [icon], sized and inked by the caller (the
  /// armed switch's own glyph, so the note and the switch read as one).
  final Widget? glyph;

  /// Defaults to white; pass the accent to tie the note to an armed toggle.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return LiquidGlass(
      tone: GlassTone.media,
      shape: LiquidGlassShape.capsule,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              glyph!,
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: 13, color: iconColor ?? MediaGlass.ink),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: theme.bodySoft.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  color: MediaGlass.ink,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The length of a video, in a tile's corner: a small dark capsule with white
/// 13/w600 tabular digits ("0:42", "1:03:07") and an optional leading glyph.
class MediaDurationBadge extends StatelessWidget {
  const MediaDurationBadge({
    super.key,
    this.duration,
    this.text,
    this.icon,
  }) : assert(duration != null || text != null);

  final Duration? duration;

  /// Pre-formatted text instead of [duration] ("Live", "GIF").
  final String? text;

  /// A leading glyph — `CupertinoIcons.video_camera_solid` on a grid tile.
  final IconData? icon;

  static String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: kMediaScrim,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: MediaGlass.ink),
              const SizedBox(width: 4),
            ],
            Text(
              text ?? format(duration!),
              style: theme.bodySoft.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: MediaGlass.ink,
                decoration: TextDecoration.none,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
