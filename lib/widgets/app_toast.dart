import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

/// A brief confirmation that shows ABOVE whatever is on screen — including a
/// modal bottom sheet.
///
/// `ScaffoldMessenger` cannot do this. A snackbar belongs to a Scaffold, and a
/// bottom sheet is a route stacked on top of one, so a snackbar raised from
/// inside a sheet renders *behind* it. The copy confirmations in the invite
/// sheet were being shown correctly and were simply invisible, which is a
/// worse failure than not showing them: the code silently looked right.
///
/// This inserts into the ROOT overlay instead. Entries added last paint last,
/// so it lands over the sheet, its scrim, and anything else in the stack.
///
/// Anchored to the TOP. A bottom-anchored toast over a bottom sheet covers the
/// buttons the user just tapped, and on a sheet that reaches the top of the
/// screen there is nowhere at the bottom left to put it.
///
/// Deliberately not a queue: a second toast replaces the first rather than
/// waiting behind it. These confirm a tap, and a confirmation that arrives
/// after the tap-after-next is describing the wrong thing — the exact bug the
/// snackbar version had when copy-link and copy-code were tapped in sequence.
void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _ToastHost.instance.show(overlay, message, ThemeScope.of(context));
}

/// Owns the single live toast, so showing a second one cancels the first
/// cleanly instead of leaking a timer and an entry.
class _ToastHost {
  _ToastHost._();
  static final _ToastHost instance = _ToastHost._();

  OverlayEntry? _entry;
  Timer? _timer;

  void show(OverlayState overlay, String message, dynamic theme) {
    _dismiss();
    final entry = OverlayEntry(
      builder: (context) => _Toast(message: message, theme: theme),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 1900), _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    _timer = null;
    // `mounted` guard: the route the overlay belonged to can be gone by the
    // time the timer fires — closing the sheet immediately after a copy is a
    // completely ordinary thing to do.
    if (_entry?.mounted ?? false) _entry!.remove();
    _entry = null;
  }
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.theme});

  final String message;
  final dynamic theme;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      // Just under the status bar, and inset from both edges so it reads as a
      // floating pill rather than a banner welded to the top.
      top: top + 10,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _ctrl,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.35),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
            ),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: theme.surfaceRaised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 16, color: theme.accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: theme.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
