import 'package:flutter/material.dart';

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
        final bool armed;
        if (call.localScreenSharing) {
          model = call.drawModel;
          armed = call.drawArmed.value;
        } else if (group != null && group.localScreenSharing) {
          model = group.drawModel;
          armed = group.drawArmed.value;
        } else {
          return const SizedBox.shrink();
        }
        final theme = ThemeScope.of(context);
        final me = call.userId ?? group?.userId ?? 'me';
        return Positioned.fill(
          child: DrawCanvas(
            model: model,
            armed: armed,
            inkColor: drawColorFor(me, theme),
          ),
        );
      },
    );
  }
}
