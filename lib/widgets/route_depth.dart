import 'package:flutter/widgets.dart';

/// How deep a route sits in its navigator: 0 for the base, 1 for the first
/// page pushed over it, and so on.
///
/// The one question it answers is the one [GlassBackButton] asks on desktop:
/// does popping this page go *back* to an earlier page, or does it close
/// something and land on the shell? A navigator never says what lies under a
/// route, so every navigator a page can be pushed on carries one of these
/// observers (the root's, the room side pane's, the section panes', the
/// settings pane's). A route pushed on a navigator without one reads as
/// unknown, and the button keeps its chevron.
class RouteDepthObserver extends NavigatorObserver {
  static final Expando<int> _depth = Expando('routeDepth');

  /// The depth of [route], or null when no observer saw it arrive.
  static int? of(Route<dynamic>? route) => route == null ? null : _depth[route];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depth[route] =
        previousRoute == null ? 0 : (_depth[previousRoute] ?? 0) + 1;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null) return;
    _depth[newRoute] = oldRoute == null ? 0 : (_depth[oldRoute] ?? 0);
  }
}
