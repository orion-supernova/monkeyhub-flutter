import 'dart:async';

import 'package:flutter/material.dart';

import '../keyboard/overlay_modal_scope.dart';
import '../theme/theme_scope.dart';
import '../widgets/glass_surface.dart';
import 'call_models.dart';

/// Anchored frosted popover for picking a call kind. Mirrors the overlay
/// shape used by [showMessageActionMenu]: insert a root-overlay entry with
/// a tap-to-dismiss scrim and a [GlassSurface] floated near the anchor.
Future<CallMediaKind?> showCallPicker({
  required BuildContext context,
  required GlobalKey anchorKey,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final anchorCtx = anchorKey.currentContext;
  if (anchorCtx == null) return null;
  final rb = anchorCtx.findRenderObject() as RenderBox?;
  if (rb == null || !rb.attached) return null;

  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (overlayBox == null) return null;

  final topLeft = rb.localToGlobal(Offset.zero, ancestor: overlayBox);
  final anchorRect = topLeft & rb.size;
  final overlaySize = overlayBox.size;
  final safeInsets = MediaQuery.paddingOf(context);

  final completer = Completer<CallMediaKind?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CallPickerOverlay(
      anchorRect: anchorRect,
      overlaySize: overlaySize,
      safeInsets: safeInsets,
      onResolve: (result) {
        if (!completer.isCompleted) completer.complete(result);
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _CallPickerOverlay extends StatefulWidget {
  const _CallPickerOverlay({
    required this.anchorRect,
    required this.overlaySize,
    required this.safeInsets,
    required this.onResolve,
  });

  final Rect anchorRect;
  final Size overlaySize;
  final EdgeInsets safeInsets;
  final ValueChanged<CallMediaKind?> onResolve;

  @override
  State<_CallPickerOverlay> createState() => _CallPickerOverlayState();
}

class _CallPickerOverlayState extends State<_CallPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close(CallMediaKind? result) async {
    if (_closing) return;
    _closing = true;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onResolve(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    const horizontalMargin = 12.0;
    const gap = 6.0;

    final maxRight = widget.overlaySize.width - widget.safeInsets.right - horizontalMargin;
    final minLeft = widget.safeInsets.left + horizontalMargin;
    final right = (widget.overlaySize.width - widget.anchorRect.right)
        .clamp(horizontalMargin + widget.safeInsets.right, double.infinity);
    final top = widget.anchorRect.bottom + gap;
    final available = (maxRight - minLeft).clamp(0.0, widget.overlaySize.width);

    // Only the scrim animates; the surface itself appears instantly to keep
    // BackdropFilter off the per-frame compositing path (animating a blur is
    // the main source of jank here).
    return Material(
      type: MaterialType.transparency,
      // Esc closes the picker, same as tapping the scrim.
      child: OverlayModalScope(
        onDismiss: () => _close(null),
        child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(null),
              child: FadeTransition(
                opacity: _ctrl,
                child: Container(color: Colors.black.withValues(alpha: 0.18)),
              ),
            ),
          ),
          Positioned(
            top: top,
            right: right,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: available),
              child: IntrinsicWidth(
                child: GlassSurface(
                  radius: theme.radiusLg,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CallPickerRow(
                        icon: Icons.call,
                        label: 'VOICE CALL',
                        onTap: () => _close(CallMediaKind.audio),
                      ),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: theme.divider,
                      ),
                      _CallPickerRow(
                        icon: Icons.videocam,
                        label: 'VIDEO CALL',
                        onTap: () => _close(CallMediaKind.video),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _CallPickerRow extends StatelessWidget {
  const _CallPickerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.accent),
            const SizedBox(width: 12),
            Text(label, style: theme.label),
          ],
        ),
      ),
    );
  }
}
