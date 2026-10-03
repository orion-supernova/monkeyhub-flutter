import 'package:flutter/widgets.dart';
// Narrowed on purpose: the one thing this file needs from Material is the
// determinate progress ring — there is no widgets-level progress indicator.
import 'package:flutter/material.dart' show CircularProgressIndicator;

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import 'liquid_glass.dart';

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
/// make, and a near-copy of a 38pt circle is how two screens that are meant to
/// read as one surface start to drift apart.
/// The circled "1" — arms burn-after-reading for this photo.
///
/// Sized to the 38pt glass buttons beside it so the rail sits on one baseline.
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
            width: 38,
            height: 38,
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
/// Deliberately built as a near-twin of [PhotoViewOnceToggle] — same 38pt circle,
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
            width: 38,
            height: 38,
            child: Center(
              child: Text(
                'HD',
                style: TextStyle(
                  color: fg,
                  // A shade smaller than the view-once "1": two glyphs in the
                  // same 38pt circle need the room.
                  fontSize: 12.5,
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
