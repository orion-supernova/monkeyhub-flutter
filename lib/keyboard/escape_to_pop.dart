import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Makes Esc go back from any pushed route, the way it does in every desktop
/// app and every browser-hosted one.
///
/// ## The gap this fills
///
/// `WidgetsApp` binds Esc to [DismissIntent], but the only action listening
/// for it is the one each `ModalRoute` installs, and that one is enabled only
/// when the route is `barrierDismissible`. Dialogs and popups qualify. Every
/// full-screen push in this app does not: the photo viewer, the media pager,
/// settings pages, profile. So Esc reached nothing and the only way out was
/// the close button.
///
/// That route action is the nearest [DismissIntent] handler to every focused
/// widget, and the lookup stops at the nearest one whether or not it is
/// enabled, so a fallback [Actions] above the navigator would never be
/// reached. This listens one level earlier instead: a key event bubbles up
/// the focus tree BEFORE `WidgetsApp`'s shortcut table sees it, and this sits
/// between the two. It asks the same question the shortcut table would (is
/// there an enabled Esc action for the focused widget?) and runs that action
/// when there is, so dialogs and popups keep their own exits.
/// Anything bound closer to the focus ([ViewerKeys], a field's own handler)
/// has already taken the key before it gets here.
///
/// ## What it pops
///
/// The navigator nearest the focused widget that can actually pop, walking out
/// through nested navigators, and only via [NavigatorState.maybePop], so a
/// route guarded by `PopScope` gets its usual say. With nothing to pop the key
/// goes unhandled, which on web leaves it to the browser.
///
/// Ungated by platform on purpose, per platform.dart: inert without a keyboard,
/// and a tablet with a Bluetooth keyboard deserves it too.
///
/// Must sit inside `MaterialApp.builder`, i.e. above the root navigator.
class EscapeToPop extends StatelessWidget {
  const EscapeToPop({super.key, required this.navigatorKey, required this.child});

  /// The root navigator, used when focus sits outside every route (nothing
  /// focused yet, or focus parked on the app's own root scope).
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: child,
    );
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape ||
        event is! KeyDownEvent ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null) {
      // Esc mid-composition belongs to the input method: it abandons the
      // candidate, and taking it would close the screen under a half-typed
      // word instead.
      final field = focused.findAncestorStateOfType<EditableTextState>();
      if (field != null && field.textEditingValue.composing.isValid) {
        return KeyEventResult.ignored;
      }
      final own = Actions.maybeFind<DismissIntent>(
        focused,
        intent: const DismissIntent(),
      );
      if (own != null && own.isEnabled(const DismissIntent())) {
        // Run it here rather than step aside. On macOS a focused text field
        // maps Esc to "do nothing, stop propagating" (AppKit's
        // cancelOperation), and that table sits between this widget and
        // the one that would turn Esc into a dismiss, so a dialog with its
        // field focused could never be closed from the keyboard.
        Actions.of(focused).invokeAction(own, const DismissIntent(), focused);
        return KeyEventResult.handled;
      }
    }
    final nav = _target(focused);
    if (nav == null) return KeyEventResult.ignored;
    nav.maybePop();
    return KeyEventResult.handled;
  }

  NavigatorState? _target(BuildContext? focused) {
    // A route that cannot pop can still ANSWER a back: a `PopScope` that
    // refuses it is told it was asked. That is how the wide shell's open chat
    // closes, since it lives on the bottom route and has nowhere to pop to.
    final route = focused == null ? null : ModalRoute.of(focused);
    if (route != null &&
        route.isCurrent &&
        route.popDisposition == RoutePopDisposition.doNotPop) {
      return route.navigator;
    }
    var nav = focused == null ? null : Navigator.maybeOf(focused);
    nav ??= navigatorKey.currentState;
    // `Navigator.maybeOf(nav.context)` would hand back `nav` itself, since a
    // navigator's own element counts as "of" it. Step to the parent instead.
    while (nav != null && !nav.canPop()) {
      nav = nav.context.findAncestorStateOfType<NavigatorState>();
    }
    return nav;
  }
}
