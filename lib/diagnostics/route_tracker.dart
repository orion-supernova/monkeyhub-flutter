import 'package:flutter/widgets.dart';

import 'diag_event.dart';
import 'diag_log.dart';

/// Keeps [DiagLog.currentScreen] pointing at the top route, and records the
/// transitions.
///
/// Screen attribution is the single best idea in the reference implementation
/// this feature is modelled on: "which screen fired this call" turns a flat
/// list of function names into something you can reason about. It goes further
/// here by also logging the push/pop itself — a route that opens and closes
/// repeatedly is its own bug signature, and one worth being able to see next to
/// the layout and lifecycle events it would be interleaved with.
class DiagRouteTracker extends NavigatorObserver {
  final List<String> _stack = [];

  void _sync() => DiagLog.currentScreen = _stack.isEmpty ? null : _stack.last;

  String _nameOf(Route<dynamic>? route) {
    if (route == null) return '?';
    final n = route.settings.name;
    if (n != null && n.isNotEmpty) return n;
    // Most routes here are unnamed page routes pushed with a builder, so there
    // is no better handle than the route type. Deliberately staying on the
    // widgets layer rather than importing material for one `is` check.
    return route is PageRoute ? 'page' : route.runtimeType.toString();
  }

  void _log(String event, String detail) {
    if (!DiagLog.enabled) return;
    DiagLog.add(
      cat: DiagCat.nav,
      sev: DiagSev.info,
      event: event,
      detail: detail,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(_nameOf(route));
    _sync();
    _log('push', '${_nameOf(previousRoute)} → ${_nameOf(route)}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_stack.isNotEmpty) _stack.removeLast();
    _sync();
    _log('pop', '${_nameOf(route)} → ${_nameOf(previousRoute)}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(_nameOf(route));
    _sync();
    _log('remove', _nameOf(route));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_stack.isNotEmpty) _stack.removeLast();
    if (newRoute != null) _stack.add(_nameOf(newRoute));
    _sync();
    _log('replace', '${_nameOf(oldRoute)} → ${_nameOf(newRoute)}');
  }
}
