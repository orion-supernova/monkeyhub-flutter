import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The keyboard half of every full-screen media viewer: Esc closes, the arrow
/// keys step through the set.
///
/// The app-wide [EscapeToPop] already turns Esc into a plain pop, but a viewer
/// usually needs its OWN close: the media pager hands the index it settled on
/// back to the grid, and the dismiss guards that keep a drag and a tap from
/// closing twice live in that method. Binding the key here routes it there.
///
/// Holds focus itself ([Focus.autofocus]) because a route's focus lands on its
/// own scope node, which sits ABOVE the page content, so a shortcut installed
/// inside the page would never see a key otherwise. Same reasoning as
/// [OverlayModalScope].
///
/// [onClose] may be null for a viewer whose Esc already goes the right way
/// through its route (the stories viewer's `PopScope` puts its reply panel
/// away first); the key then falls through to [EscapeToPop]. Arrows may be
/// null too, and then pass on to whatever else wants them, which is what a
/// text field inside the viewer needs.
///
/// Left and right follow reading direction: in an RTL locale the next item
/// sits to the left, as it does under a swipe.
class ViewerKeys extends StatelessWidget {
  const ViewerKeys({
    super.key,
    this.onClose,
    this.onPrevious,
    this.onNext,
    required this.child,
  });

  final VoidCallback? onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final left = rtl ? onNext : onPrevious;
    final right = rtl ? onPrevious : onNext;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): ?onClose,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): ?left,
        const SingleActivator(LogicalKeyboardKey.arrowRight): ?right,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
