import 'package:flutter/material.dart';

import '../../data/ui_selection_store.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/route_depth.dart';

/// The split shell's third pane: room info (or a member's profile) beside the
/// open chat, instead of a full-screen push over the rail and the chat list.
///
/// ## Why a pane, and why its own navigator
///
/// Pushed on the root navigator, room info covered the whole window — the
/// rail, the list and the conversation it was about — which is a phone's
/// answer to a desktop's question. Here it slides in at the right edge and the
/// chat stays readable beside it.
///
/// Room info is not one page but a small stack of them (members, a profile, the
/// shared-content browser, …), and every one of those pushes with a plain
/// `Navigator.of(context).push`. Giving the pane its own [Navigator] catches
/// all of them inside the pane with no change to any of those screens, the
/// same trick the settings detail pane plays (see home_shell.dart).
///
/// ## Results still reach the room
///
/// [open] returns the pushed route's future, so `RoomScreen`'s "show in chat"
/// round trip (room info's saved list and media browser pop a message to jump
/// to) works exactly as it does through a full-screen push.
///
/// ## Docked or floating
///
/// When the chat can spare the width it narrows and the pane sits beside it
/// (docked). When it cannot — a 1024px window with the list at full width
/// leaves the chat ~580px — the pane floats over the chat's right edge
/// instead, so the conversation is covered rather than crushed to a sliver.
/// The two differ only in the chat's right inset, so a resize across the line
/// never remounts either side.
///
/// ## Cost
///
/// The slide is a translation of a [RepaintBoundary] — no blur, no relayout of
/// the transcript per frame. A docked chat relayouts exactly once on the way
/// in (when it narrows, at the start) and once on the way out (when it widens,
/// after the pane has left). Closed, the pane is [Offstage] with its tickers
/// off.
class RoomSidePane extends StatefulWidget {
  const RoomSidePane({super.key, required this.roomId, required this.child});

  /// The room the chat beside the pane shows. A change closes the pane: what
  /// it holds was opened by, and reports back to, the previous room's screen.
  final String? roomId;

  /// The chat. Built once by the shell and passed through untouched.
  final Widget child;

  /// Width of the pane. Wide enough for room info's grouped rows without
  /// truncating a member's name; narrow enough to leave a docked chat a real
  /// column on a laptop.
  static const double width = 340;

  /// The narrowest chat the pane will dock beside. Below it the pane floats
  /// over the chat instead (see the class doc).
  static const double minChatBeside = 480;

  /// The pane hosting [context], or null where there is none (the phone
  /// shell, a pushed full-screen room). Callers push full-screen on null,
  /// exactly as before the pane existed.
  ///
  /// Not a dependency: this is asked at tap time, never during build.
  static RoomSidePaneState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<RoomSidePaneState>();

  @override
  State<RoomSidePane> createState() => RoomSidePaneState();
}

class RoomSidePaneState extends State<RoomSidePane>
    with SingleTickerProviderStateMixin {
  final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();

  /// Where focus goes when the pane closes with focus inside it. Without a
  /// home to return to, focus would stay parked on the pane's empty base route,
  /// and the next Esc would land there instead of on the chat.
  final FocusNode _chatFocus = FocusNode(
    debugLabel: 'RoomSidePane.chat',
    skipTraversal: true,
  );

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  ));

  /// Something is open in the pane. Flips the moment [open]/[close] is
  /// called, or the moment the last page in it has popped itself.
  bool _open = false;

  /// The pane takes up layout: mounted, and a docked chat narrowed for it.
  /// Set at the START of opening and cleared at the END of closing, so the
  /// chat reflows once each way rather than once per animation frame.
  bool _shown = false;

  /// Identifies what the pane's root page is, so asking for the same thing
  /// again closes it (the info button toggles, as it does in Messages).
  Object? _tag;

  bool get isOpen => _open;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slide.duration = ThemeScope.of(context).motionMed;
  }

  @override
  void didUpdateWidget(RoomSidePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId && (_open || _shown)) {
      // A different conversation. Snap shut rather than slide: the chat
      // itself is being swapped in the same frame, so a pane easing out over
      // the NEW room would be describing the old one.
      _open = false;
      _tag = null;
      _nav.currentState?.popUntil((r) => r.isFirst);
      _slide.value = 0;
      _reclaimFocus();
      _shown = false;
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  /// Shows [builder]'s page as the pane's root, replacing whatever it held,
  /// and returns what that page eventually pops with.
  ///
  /// [tag] names the page; opening the page already at the root with the same
  /// tag closes the pane instead (and completes with null).
  Future<T?> open<T>(WidgetBuilder builder, {Object? tag}) {
    final nav = _nav.currentState;
    if (nav == null) return Future<T?>.value();
    if (_open && tag != null && tag == _tag) {
      close();
      return Future<T?>.value();
    }
    // Replacing what is there completes ITS future with null. The listener
    // below then finds the new page already pushed and leaves the pane open.
    nav.popUntil((r) => r.isFirst);
    _open = true;
    _tag = tag;
    if (!_shown) setState(() => _shown = true);
    _slide.forward();
    final future = nav.push<T>(_PaneRootRoute<T>(
      builder: builder,
      // Held for the length of the slide out, so the page is still drawn
      // while the pane carries it off rather than vanishing first and
      // leaving an empty panel to slide.
      reverseDuration: _slide.duration!,
    ));
    future.whenComplete(() {
      if (!mounted) return;
      final n = _nav.currentState;
      if (n == null || !n.canPop()) _collapse();
    });
    return future;
  }

  /// Closes the pane: pops everything in it (each open page's future completes
  /// with null) and slides it away.
  void close() {
    if (!_open) return;
    // The futures settle on a microtask and call [_collapse]; flip state now
    // so a second close in the same frame is a no-op.
    _nav.currentState?.popUntil((r) => r.isFirst);
    _collapse();
  }

  void _collapse() {
    // Once only. [close] collapses up front and every page it popped then
    // settles here too; restarting the reverse for each would cancel the one
    // in flight, and a cancel is what lets the pane drop out of layout.
    if (!_open) return;
    _open = false;
    _tag = null;
    _reclaimFocus();
    _slide.reverse().whenCompleteOrCancel(() {
      if (mounted && !_open && _shown) setState(() => _shown = false);
    });
  }

  void _reclaimFocus() {
    if (_nav.currentState?.focusNode.hasFocus ?? false) {
      _chatFocus.requestFocus();
    }
  }

  /// A pop that reached the pane's empty base route.
  ///
  /// Room info's Leave and Delete pop TWICE — once for itself, once for the
  /// room under it — which on a phone takes the user back to the list. The
  /// second pop lands here, and the pane answers it the way the phone does: by
  /// closing the conversation.
  ///
  /// `maybePop` awaits the route before acting, so by the time that second pop
  /// arrives the first has already settled and the pane is sliding out. That
  /// slide is the window this answers in. Nothing else reaches an empty pane
  /// then: the outgoing page ignores pointers while it leaves, and focus has
  /// already gone back to the chat, so Esc goes there.
  void _onBasePop() {
    if (!_open && _slide.status != AnimationStatus.reverse) return;
    UiSelectionStore.instance.selectRoom(null);
    close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final docked = constraints.maxWidth - RoomSidePane.width >=
            RoomSidePane.minChatBeside;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: _shown && docked ? RoomSidePane.width : 0,
              child: Focus(focusNode: _chatFocus, child: widget.child),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: RoomSidePane.width,
              child: Offstage(
                offstage: !_shown,
                child: TickerMode(
                  enabled: _shown,
                  child: SlideTransition(
                    position: _offset,
                    child: RepaintBoundary(
                      child: DecoratedBox(
                        // Opaque, so a floating pane hides the chat under it
                        // and a page with a transparent scaffold still reads
                        // as a surface. The hairline matches the shell's own
                        // dividers; the shadow only when floating, where the
                        // pane sits ON the chat rather than beside it.
                        decoration: BoxDecoration(
                          color: theme.background,
                          border: Border(
                            left: BorderSide(color: theme.divider, width: 0.5),
                          ),
                          boxShadow: docked
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 24,
                                  ),
                                ],
                        ),
                        child: _paneSized(
                          context,
                          Size(RoomSidePane.width, constraints.maxHeight),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The pages in here size themselves from [MediaQuery], which above the
  /// pane describes the whole window: on a 1440px window `readableInset`
  /// centred a 720px column by padding 360px a side, inside a 340px pane, and
  /// room info laid out to nothing (an empty dark panel). So the pane is their
  /// screen.
  ///
  /// The [LayoutScope] is deliberately NOT narrowed: it answers "is this the
  /// split shell", and a DM opened from a member's profile in here must still
  /// land in the chat pane rather than push inside this one.
  Widget _paneSized(BuildContext context, Size size) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: _navigator,
      );

  /// Built once: the [LayoutBuilder] above reruns on every resize frame, and
  /// handing it the identical widget keeps the navigator out of that.
  late final Widget _navigator = Navigator(
    key: _nav,
    // Room info and the rest open over the empty base, so their back is a ×
    // on the split shell. See [GlassBackButton].
    observers: [RouteDepthObserver()],
    onGenerateInitialRoutes: (navigator, initialRoute) => [
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBasePop();
          },
          child: const SizedBox.expand(),
        ),
      ),
    ],
  );
}

/// The root page of the pane. Appears instantly (the pane's own slide is the
/// entrance) and, on the way out, stays drawn for [reverseDuration] without a
/// transition of its own, so the pane carries it off screen.
class _PaneRootRoute<T> extends PageRouteBuilder<T> {
  _PaneRootRoute({
    required WidgetBuilder builder,
    required Duration reverseDuration,
  }) : super(
          pageBuilder: (context, _, _) => builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: reverseDuration,
          transitionsBuilder: (_, _, _, child) => child,
        );
}
