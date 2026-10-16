import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../privacy/capture_protection.dart';
import '../theme/theme_scope.dart';
import '../widgets/capture_shield.dart';
import '../widgets/dust_dissolve.dart';
import '../widgets/liquid_glass.dart';
import '../l10n/text_case.dart';
import '../widgets/viewer_chrome.dart';

/// Fullscreen viewer for a view-once photo.
///
/// Deliberately NOT [FullscreenImageViewer], and the difference is the whole
/// point. That one renders through `RemoteImage` → `CachedNetworkImage`, which
/// keeps a persistent on-disk cache, and resolves its URL through
/// `FileUrlCache`, which persists URLs across launches. Either would leave a
/// readable copy of the photo on the device after the server had deleted it —
/// the feature would be theatre.
///
/// This takes bytes that are already in memory, hands them to [Image.memory],
/// and never writes them anywhere. When the route pops they are garbage.
///
/// Two more things happen here, both because a photo that can only be seen once
/// is exactly the photo people try to capture:
///
///  * A [CaptureProtection] scope is held for the life of the route, which
///    forces Android's FLAG_SECURE on regardless of the user's global setting,
///    and drives the iOS recording/mirroring shield.
///  * Leaving the app closes the picture. On iOS the screenshot gesture and
///    Control Center both raise `inactive`, so this also means you cannot line
///    up a capture and leave the photo sitting there while you do it.
///
/// Closing it is the end of the one look, and reads as one: the picture burns
/// to dust where it is ([DustDissolve], as the play-once video note's circle
/// does) while the black lifts off the chat, which already shows the tile as
/// opened underneath ([onBurn]). Leaving the app, and Reduce Motion, skip the
/// burn and close at once.
class ViewOnceViewer extends StatefulWidget {
  const ViewOnceViewer({super.key, required this.bytes, this.onBurn});

  final Uint8List bytes;

  /// The look is over and the picture has started to burn: the tile it was
  /// opened from can show itself spent now, under the dust.
  final VoidCallback? onBurn;

  /// No Hero to fly, because the sealed bubble never held the picture. Not
  /// opaque only so the chat can show through as the picture burns away; until
  /// then the page is solid black over it.
  static Future<void> open(
    BuildContext context, {
    required Uint8List bytes,
    VoidCallback? onBurn,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => ViewOnceViewer(bytes: bytes, onBurn: onBurn),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TransformationController _xform = TransformationController();

  /// Guards against popping twice — a drag-dismiss and a lifecycle change can
  /// land in the same frame.
  bool _closing = false;

  /// The picture is turning to dust; [_lift] takes the black and the chrome
  /// away over the first half of it.
  bool _burning = false;
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: DustDissolve.defaultDuration * 0.55,
  );
  late final Animation<double> _shown = ReverseAnimation(
    CurvedAnimation(parent: _lift, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CaptureProtection.instance.pushScope();
    CaptureProtection.instance.ensureListening();
  }

  @override
  void dispose() {
    CaptureProtection.instance.popScope();
    WidgetsBinding.instance.removeObserver(this);
    _lift.dispose();
    _xform.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    // Gone at once, mid-burn too: the app switcher's snapshot must not catch
    // half a picture.
    if (_burning) return _burnt();
    _close(burn: false);
  }

  void _close({bool burn = true}) {
    if (_closing || !mounted) return;
    _closing = true;
    if (burn && !MediaQuery.disableAnimationsOf(context)) {
      setState(() => _burning = true);
      _lift.forward();
      widget.onBurn?.call();
      return;
    }
    widget.onBurn?.call();
    Navigator.of(context).pop();
  }

  /// The dust has settled, or the app left mid-burn.
  void _burnt() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      Navigator.of(context).pop();
    } else if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  bool get _zoomed => _xform.value.getMaxScaleOnAxis() > 1.05;

  @override
  Widget build(BuildContext context) {
    // Material + DefaultTextStyle so nothing here can fall back to Flutter's
    // debug text rendering — on the theme's body face, not a bare style with
    // no family (which dropped to boxes in the preview and the system
    // fallback on device).
    final theme = ThemeScope.of(context);
    // Back is a close like any other, and so a burn.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: theme.body.copyWith(
            color: Colors.white,
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Black void around a photo that doesn't fill the screen, like
              // Photos — a blurred copy of the picture read as a smudge. It
              // lifts off the chat as the picture burns.
              FadeTransition(
                opacity: _shown,
                child: const ColoredBox(color: Colors.black),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Only when un-zoomed: while zoomed the vertical drag belongs
                // to the pan, not to dismissal.
                onVerticalDragEnd: (d) {
                  if (_zoomed || _closing) return;
                  if (d.velocity.pixelsPerSecond.dy.abs() > 300) _close();
                },
                child: InteractiveViewer(
                  transformationController: _xform,
                  minScale: 1,
                  maxScale: 5,
                  // Always the whole picture — never a `cover` crop, which cut a
                  // portrait shot's sides off on a tall phone.
                  child: Center(
                    child: DustDissolve(
                      active: _burning,
                      onDone: _burnt,
                      child: Image.memory(
                        widget.bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _shown,
                  child: IgnorePointer(
                    ignoring: _closing,
                    child: ViewerTopBar(
                      onClose: _close,
                      center: const ViewOnceBadge(),
                    ),
                  ),
                ),
              ),
              // Deliberately no save, share, or download control.
              const CaptureShield(),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1 · view once" marker, so it is unambiguous what is being looked at and why
/// it will not be here again. On the media glass capsule every note over a
/// photo wears ([MediaNoteCapsule]'s material), not a flat white wash.
///
/// Public because the play-once video note's focus wears it too, with its own
/// [label]; one badge, so "once" looks the same over a photo and over a face.
class ViewOnceBadge extends StatelessWidget {
  const ViewOnceBadge({super.key, this.label});

  /// What follows the "1". Null is the photo viewer's "View once".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final style = theme.body.copyWith(
      color: MediaGlass.ink,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    );
    return LiquidGlass(
      tone: GlassTone.media,
      shape: LiquidGlassShape.capsule,
      // The bar's own rule, which its × already follows: blur-free while the
      // route fades in or out, or this capsule frosts the fade's empty buffer
      // (a grey wash) and snaps to real glass when the route lands.
      still: ViewerTopBar.stillOf(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 13, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MediaGlass.ink.withValues(alpha: 0.85),
                  width: 1.4,
                ),
              ),
              child: Text(
                '1',
                style: style.copyWith(height: 1, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              sentenceCaseOf(
                context,
                label ?? AppLocalizations.of(context).viewOnceViewerBadgeLabel,
              ),
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
