import 'package:flutter/widgets.dart';

/// Watches the root navigator so a screen can tell when it is uncovered.
///
/// Handed to `MaterialApp.navigatorObservers` in `app.dart`, alongside the
/// diagnostics tracker. Created once at the top level for the same reason that
/// list is built once: an observer rebuilt on every theme change would detach
/// from the navigator and lose the route stack it exists to follow.
final RouteObserver<PageRoute<dynamic>> appRoutes =
    RouteObserver<PageRoute<dynamic>>();

/// Re-runs a screen's fetch when the route on top of it pops away.
///
/// The problem this solves is specific to one-shot lists. A section screen
/// fetches in `initState`, and the shell disposes it on every section switch —
/// so hopping between tabs happens to refetch, and the staleness never shows.
/// A *pushed* route is different: it lays a screen on top and leaves the one
/// underneath fully alive, so whatever the user changed up there is invisible
/// when they come back down. Discover sends you into a public room, you set
/// that room to private, you back out — and Discover is still offering it,
/// because nothing has re-run since the screen was built.
///
/// Only `didPopNext` is used, deliberately. `didPush` would double the fetch
/// that `initState` already did, and `didPushNext` fires as the screen is being
/// covered, when nobody can see the result.
///
/// The refresh is not gated on anything having plausibly changed. A screen has
/// no way to know what happened on top of it — the room could have been
/// renamed, locked, emptied or deleted, by this user or another — and one query
/// on the way back from a pushed route is far cheaper than the class of bug
/// that guessing produces.
mixin RefreshOnReturn<T extends StatefulWidget> on State<T>
    implements RouteAware {
  /// Re-fetch whatever this screen holds. Called when a pushed route pops back
  /// to this one; safe to make a no-op when there is nothing to fetch.
  void onReturnToScreen();

  ModalRoute<dynamic>? _subscribed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _subscribed) return;
    // Subscribing twice for one route leaks a registration the observer never
    // drops, and `didChangeDependencies` runs far more often than the route
    // changes — an inherited widget above this screen is enough.
    if (_subscribed != null) appRoutes.unsubscribe(this);
    _subscribed = route;
    if (route is PageRoute) appRoutes.subscribe(this, route);
  }

  @override
  void dispose() {
    if (_subscribed != null) appRoutes.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (mounted) onReturnToScreen();
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
