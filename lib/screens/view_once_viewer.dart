import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../privacy/capture_protection.dart';
import '../theme/theme_scope.dart';
import '../widgets/capture_shield.dart';
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
class ViewOnceViewer extends StatefulWidget {
  const ViewOnceViewer({super.key, required this.bytes});

  final Uint8List bytes;

  /// Opaque route on purpose — there is no thumbnail underneath to show through
  /// and no Hero to fly, because the sealed bubble never held the picture.
  static Future<void> open(BuildContext context, {required Uint8List bytes}) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => ViewOnceViewer(bytes: bytes),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<ViewOnceViewer> createState() => _ViewOnceViewerState();
}

class _ViewOnceViewerState extends State<ViewOnceViewer>
    with WidgetsBindingObserver {
  final TransformationController _xform = TransformationController();

  /// Guards against popping twice — a drag-dismiss and a lifecycle change can
  /// land in the same frame.
  bool _closing = false;

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
    _xform.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _close();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  bool get _zoomed => _xform.value.getMaxScaleOnAxis() > 1.05;

  @override
  Widget build(BuildContext context) {
    // Material + DefaultTextStyle so nothing here can fall back to Flutter's
    // debug text rendering — on the theme's body face, not a bare style with
    // no family (which dropped to boxes in the preview and the system
    // fallback on device).
    final theme = ThemeScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body.copyWith(
          color: Colors.white,
          fontSize: 13,
          decoration: TextDecoration.none,
        ),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The badge and the close button used to sit on dead black above
              // a `contain`-fitted photo, which read as a toolbar over a
              // letterbox rather than as a fullscreen picture. The blurred copy
              // fills that space with the photograph's own colour.
              //
              // Decoded from the SAME in-memory bytes, at 96px: nothing is
              // written to disk and nothing new is fetched, which is the
              // property this whole screen exists to preserve.
              // Black void around a photo that doesn't fill the screen, like
          // Photos — the blurred copy of the picture read as a smudge.
          const ColoredBox(color: Colors.black),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Only when un-zoomed: while zoomed the vertical drag belongs
                // to the pan, not to dismissal.
                onVerticalDragEnd: (d) {
                  if (_zoomed) return;
                  if (d.velocity.pixelsPerSecond.dy.abs() > 300) _close();
                },
                child: InteractiveViewer(
                  transformationController: _xform,
                  minScale: 1,
                  maxScale: 5,
                  // Always the whole picture — never a `cover` crop, which cut a
                  // portrait shot's sides off on a tall phone.
                  child: Center(
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ViewerTopBar(
                  onClose: _close,
                  center: const _ViewOnceBadge(),
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
class _ViewOnceBadge extends StatelessWidget {
  const _ViewOnceBadge();

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
                AppLocalizations.of(context).viewOnceViewerBadgeLabel,
              ),
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
