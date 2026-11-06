import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../theme/vanish_palette.dart';
import '../swipe_capsules.dart';
import '../swipe_fork.dart';

/// The two colours a choice can take, derived from the theme.
///
/// Talk is the theme's own `success`. No theme has a violet, so vanish rotates
/// the accent's hue to violet and keeps its saturation and lightness (clamped
/// so it reads on any surface): it follows the theme without a hard-coded hex.
class ForkPalette {
  ForkPalette(AppTheme theme)
      : talk = theme.success,
        vanish = VanishPalette(theme).vanish;

  final Color talk;
  final Color vanish;

  Color of(ForkOption o) => o.isVanish ? vanish : talk;

  /// A readable glyph colour on top of [c].
  static Color onColor(Color c) => VanishPalette.onColor(c);
}

/// Every word the swipe-up shows, from the app's localizations.
class ForkLabels {
  const ForkLabels(this.l);
  final AppLocalizations l;

  String title(ForkOption o) => switch (o.kind) {
        ForkKind.vanishOn => l.forkChipVanish,
        ForkKind.vanishOff => l.forkChipTurnOff,
        ForkKind.startHuddle => l.forkChipTalk,
        ForkKind.joinHuddle => l.forkChipJoin,
      };

  String _single(ForkOption o) => switch (o.kind) {
        ForkKind.vanishOn => l.forkSubVanishOn,
        ForkKind.vanishOff => l.forkSubVanishOff,
        ForkKind.startHuddle => l.forkSubTalk,
        ForkKind.joinHuddle => l.forkSubJoin,
      };

  String _release(ForkOption o) => switch (o.kind) {
        ForkKind.vanishOn => l.forkReleaseVanishOn,
        ForkKind.vanishOff => l.forkReleaseVanishOff,
        ForkKind.startHuddle => l.forkReleaseTalk,
        ForkKind.joinHuddle => l.forkReleaseJoin,
      };

  /// The hint lines for the controller's current view, while a finger is down.
  (String, String?) hint(SwipeForkController c) {
    final only = c.viewLeft ?? c.viewRight;
    final side = c.armedSide;
    if (side != null) {
      final o = side == ForkSide.left ? c.viewLeft : c.viewRight;
      return (_release(o!), l.forkDragDownCancel);
    }
    return (
      l.forkHintSwipeUp,
      c.viewSingle ? _single(only!) : l.forkSubChoose,
    );
  }
}

/// Where the capsules sit and how big they are, for one frame.
class ForkGeometry {
  const ForkGeometry(this.width, this.dockHeight);

  static const margin = 12.0;
  static const gap = 6.0;

  /// Room under the capsules for the hint while a finger is down.
  static const hintRoom = 36.0;

  /// The space left between the capsules and the dock when nothing is hinted.
  static const restGap = 8.0;

  final double width;

  /// How tall the dock is, from the bottom of the screen.
  final double dockHeight;

  double get usable => math.max(0, width - 2 * margin);

  /// The bottom edge of the capsules, from the bottom of the screen.
  double bottom(double hintT) => dockHeight + restGap + hintRoom * hintT;

  /// The capsule widths `(left, right)` for the controller's current frame.
  /// An armed capsule stretches over the other, as the chat row's does.
  (double, double) widths(SwipeForkController c) {
    final l = c.viewLeft != null, r = c.viewRight != null;
    if (l != r) return (l ? usable : 0, r ? usable : 0);
    final each = (usable - gap) / 2;
    final aL = c.armLeft.value, aR = c.armRight.value;
    final wl = each * (1 - aR) + (usable - gap - each) * aL;
    final wr = each * (1 - aL) + (usable - gap - each) * aR;
    return (math.max(0, wl), math.max(0, wr));
  }
}

/// The swipe-up's picture: capsules growing up out of the composer's edge, the
/// chat list's row-swipe capsules turned on their side. Mount it above the
/// whole screen; it is inert until a gesture (or its settled-open state, which
/// takes taps) is on screen. The capsule tree is tiny and repaints from the
/// controller: a pull never rebuilds the transcript, and nothing here is a
/// blur.
class SwipeForkOverlay extends StatelessWidget {
  const SwipeForkOverlay({
    super.key,
    required this.controller,
    this.dockHeight = _defaultDock,
  });

  static double _defaultDock() => 72;

  final SwipeForkController controller;

  /// The dock's height from the bottom of the screen, read each frame.
  final double Function() dockHeight;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final c = controller
      ..calm = MotionScope.of(context).calm
      ..rtl = Directionality.of(context) == TextDirection.rtl
      ..midX = MediaQuery.sizeOf(context).width / 2;
    // The keyboard coming up closes settled-open capsules.
    if (c.isOpen && MediaQuery.viewInsetsOf(context).bottom > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => c.dismiss());
    }
    final labels = ForkLabels(AppLocalizations.of(context));
    final palette = ForkPalette(theme);
    return ValueListenableBuilder<bool>(
      valueListenable: c.visible,
      builder: (context, on, _) {
        if (!on) return const SizedBox.shrink();
        return Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
            builder: (context, box) => AnimatedBuilder(
              animation: c.repaint,
              builder: (context, _) => _tray(
                context,
                theme,
                labels,
                palette,
                ForkGeometry(box.maxWidth, dockHeight()),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tray(
    BuildContext context,
    AppTheme theme,
    ForkLabels labels,
    ForkPalette palette,
    ForkGeometry geo,
  ) {
    final c = controller;
    final open = c.isOpen;
    final rest = SwipeForkController.restReveal;
    final reveal = math.max(0.0, c.reveal.value);
    // Calm: no growth, a crossfade at the resting height.
    final h = c.calm ? (reveal > 0 ? rest : 0.0) : reveal;
    final calmAlpha = c.calm ? (reveal / rest).clamp(0.0, 1.0) : 1.0;
    final fade = c.fade.value.clamp(0.0, 1.0);
    final alpha = calmAlpha * (1 - fade);
    final hintT = c.hintT.value.clamp(0.0, 1.0);
    final (wl, wr) = geo.widths(c);
    final bottom = geo.bottom(hintT);

    Widget capsule(ForkSide side, ForkOption? o, double w) {
      if (o == null || w < 1 || h < 1) return const SizedBox.shrink();
      var dx = 0.0;
      final s = c.shake.value;
      if (s > 0 && s < 1 && c.machine.armedSide == side) {
        dx = math.sin(s * math.pi * 4) * 10 * (1 - s);
      }
      final action = SwipeAction(
        label: labels.title(o),
        icon: _icon(o),
        color: palette.of(o),
        onTap: () => c.tapSide(side),
      );
      return Positioned(
        left: side == ForkSide.left ? ForkGeometry.margin + dx : null,
        right: side == ForkSide.right ? ForkGeometry.margin - dx : null,
        width: w,
        top: 0,
        bottom: 0,
        child: SwipeCapsule(
          action: action,
          extent: math.min(w, h),
          onTap: (a) => a.onTap(),
        ),
      );
    }

    final reason = c.failReason;
    final hint = reason != null
        ? (reason, null)
        : c.holding
            ? labels.hint(c)
            : null;
    final hintAlpha = hintT * (reveal / c.machine.openAt).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (open) ...[
          // Above the dock: absorbs a tap or a scroll and closes. The list
          // underneath stays put, as an open chat row eats the tap that would
          // open the chat.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: geo.dockHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: c.dismiss,
              onVerticalDragStart: (_) => c.dismiss(),
              onHorizontalDragStart: (_) => c.dismiss(),
            ),
          ),
          // The dock itself keeps working: a touch on it closes the capsules
          // and goes on to the composer.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: geo.dockHeight,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => c.dismiss(),
            ),
          ),
        ],
        Positioned(
          left: 0,
          right: 0,
          bottom: bottom + fade * -10,
          height: h,
          child: Opacity(
            opacity: alpha,
            child: IgnorePointer(
              ignoring: !open,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  capsule(ForkSide.left, c.viewLeft, wl),
                  capsule(ForkSide.right, c.viewRight, wr),
                ],
              ),
            ),
          ),
        ),
        if (hint != null && hintAlpha > 0.01)
          Positioned(
            left: ForkGeometry.margin,
            right: ForkGeometry.margin,
            bottom: geo.dockHeight + ForkGeometry.restGap,
            height: ForkGeometry.hintRoom,
            child: IgnorePointer(
              child: Opacity(
                opacity: hintAlpha * (1 - fade),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hint.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.bodySoft.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: reason != null ? theme.danger : theme.ink,
                        ),
                      ),
                      if (hint.$2 != null)
                        Text(
                          hint.$2!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.bodySoft.copyWith(
                            fontSize: 11,
                            letterSpacing: 0,
                            color: theme.inkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The glyph each option wears on its capsule.
IconData _icon(ForkOption o) => switch (o.kind) {
      ForkKind.vanishOn => CupertinoIcons.timer,
      ForkKind.vanishOff => CupertinoIcons.xmark_circle,
      ForkKind.startHuddle => CupertinoIcons.waveform,
      ForkKind.joinHuddle => CupertinoIcons.person_2_fill,
    };

/// Public so the discoverability peek and tests share the colours and glyphs.
IconData forkIconFor(ForkOption o) => _icon(o);
