import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Gives a raw [OverlayEntry] the two things a real route would have supplied
/// for free: Esc-to-dismiss, and a focus scope Tab can't walk out of.
///
/// Several surfaces in this app insert straight into `Overlay.of(context,
/// rootOverlay: true)` rather than pushing a route, because they anchor to a
/// widget's rect and run their own entrance animation. The cost is that they
/// get no `ModalRoute`: Esc does nothing, and because there's no `FocusScope`
/// either, Tab traversal walks straight through the scrim into the widgets
/// underneath — which are supposed to be blocked.
///
/// Wrap this INSIDE the overlay's own `State.build`, not around the
/// `OverlayEntry` builder, and pass the same animated close the scrim tap uses
/// so Esc gets the identical exit transition and the same re-entrancy guard.
class OverlayModalScope extends StatefulWidget {
  const OverlayModalScope({
    super.key,
    required this.onDismiss,
    required this.child,
  });

  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<OverlayModalScope> createState() => _OverlayModalScopeState();
}

class _OverlayModalScopeState extends State<OverlayModalScope> {
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'OverlayModalScope');
  FocusNode? _restoreTo;

  @override
  void initState() {
    super.initState();
    // Remember where focus was — usually the composer — so dismissing puts the
    // user back where they started rather than nowhere.
    _restoreTo = FocusManager.instance.primaryFocus;
    // Overlay entries build outside the normal route lifecycle, so autofocus
    // alone isn't dependable. A FocusScopeNode can hold primary focus itself,
    // which is what routes Esc here even when the overlay's contents are all
    // non-focusable GestureDetectors.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scope.requestFocus();
    });
  }

  @override
  void dispose() {
    final restore = _restoreTo;
    _scope.dispose();
    if (restore != null && restore.context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (restore.context != null) restore.requestFocus();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scope,
      autofocus: true,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                widget.onDismiss();
                return null;
              },
            ),
          },
          child: widget.child,
        ),
      ),
    );
  }
}
