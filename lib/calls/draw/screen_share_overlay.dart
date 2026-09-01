import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme_scope.dart';
import '../call_service.dart';
import '../group_call_service.dart';
import 'draw_canvas.dart';
import 'draw_model.dart';

/// The drawing layer over the whole app while THIS device shares its screen.
///
/// On a phone the captured frame is the display, so the strokes the others
/// draw over "the shared screen" are strokes over whatever is on this
/// device's display — a chat, a photo, the settings page. That is where
/// the presenter has to see them, and where the presenter draws too, with
/// the pen on the in-call pill. This sits above every route (in the app's
/// root stack) and maps the shared frame's unit square onto the window.
/// Inert to touch unless the pen is armed, so the app underneath keeps
/// working while the strokes land on it.
///
/// Armed, it takes every touch — that is what makes it a pen — so it has to
/// carry its own way out: a "stop drawing" chip at the top, above the
/// canvas, which is the one thing that stays tappable. Without it the
/// presenter could draw and do nothing else: not mute, not stop the share,
/// not put the pen down.
///
/// On a desktop share of the app's own window the same mapping holds; a
/// share of another window or a whole display shows nothing here — the
/// strokes are on the call screen's stage instead.
class ScreenShareOverlay extends StatelessWidget {
  const ScreenShareOverlay({super.key, required this.call, required this.group});

  final CallService call;
  final GroupCallService? group;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    return AnimatedBuilder(
      animation: Listenable.merge([
        call,
        ?group,
        call.drawArmed,
        ?group?.drawArmed,
      ]),
      builder: (context, _) {
        final DrawModel model;
        final ValueNotifier<bool> armedNotifier;
        if (call.localScreenSharing) {
          model = call.drawModel;
          armedNotifier = call.drawArmed;
        } else if (group != null && group.localScreenSharing) {
          model = group.drawModel;
          armedNotifier = group.drawArmed;
        } else {
          return const SizedBox.shrink();
        }
        final armed = armedNotifier.value;
        final theme = ThemeScope.of(context);
        final me = call.userId ?? group?.userId ?? 'me';
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: DrawCanvas(
                  model: model,
                  armed: armed,
                  inkColor: drawColorFor(me, theme),
                ),
              ),
              if (armed)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 10,
                  right: 12,
                  child: _StopDrawingChip(
                    onTap: () => armedNotifier.value = false,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StopDrawingChip extends StatelessWidget {
  const _StopDrawingChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.draw_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                l10n.screenShareStopDrawing,
                style: theme.monoTiny.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
