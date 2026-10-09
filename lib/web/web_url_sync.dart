import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../theme/layout.dart';
import 'web_document.dart';
import 'web_tab_title.dart';

/// One place in the app, as the address bar spells it on web.
///
/// Hash URLs — `/web/#/c/<roomId>`, `#/feed`, `#/discover`, `#/settings`, and
/// `#/` for the chat list — because they are what the app already uses (no
/// `usePathUrlStrategy` anywhere) and they need nothing from whoever serves
/// the page. Path URLs would work behind today's Caddy block, whose
/// `try_files {path} /index.html` does rewrite `/web/*`, but every other way of
/// serving the build — `flutter run`, a static preview, the next host — would
/// 404 on reload, and a link someone pasted into a chat would go with it. The
/// `#` buys that robustness for one character.
@immutable
class WebLocation {
  const WebLocation.section(this.section) : roomId = null;
  const WebLocation.room(String this.roomId) : section = HomeSection.chat;

  static const WebLocation home = WebLocation.section(HomeSection.chat);

  final HomeSection section;
  final String? roomId;

  /// Convex ids are lowercase base32; the bound is generous on purpose so a
  /// server-side id format change degrades to "home", never to a crash, and
  /// so nothing that is plainly not an id is ever looked up.
  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// The location a path names, or null when it names none of ours.
  static WebLocation? parse(String path) {
    var p = path;
    final q = p.indexOf('?');
    if (q >= 0) p = p.substring(0, q);
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    if (p.isEmpty || p == '/') return home;
    final parts = p.split('/');
    // A leading '/' makes the first part empty.
    if (parts.first.isNotEmpty) return null;
    if (parts.length == 3 && parts[1] == 'c' && _id.hasMatch(parts[2])) {
      return WebLocation.room(parts[2]);
    }
    if (parts.length != 2) return null;
    return switch (parts[1]) {
      'feed' => const WebLocation.section(HomeSection.feed),
      'discover' => const WebLocation.section(HomeSection.discover),
      'settings' => const WebLocation.section(HomeSection.settings),
      _ => null,
    };
  }

  String get path {
    final id = roomId;
    if (id != null) return '/c/$id';
    return switch (section) {
      HomeSection.chat => '/',
      HomeSection.feed => '/feed',
      HomeSection.discover => '/discover',
      HomeSection.settings => '/settings',
    };
  }

  /// What is on screen, in these terms.
  ///
  /// A room counts only while it is actually visible. In the split shell the
  /// selection outlives a section switch — the chat pane keeps its room while
  /// you look at the Feed — so there the room is the location only on the Chat
  /// section. On a phone the room is a full-screen push over whatever tab was
  /// underneath, and the selection is cleared when it is popped, so a
  /// selection there always means a room on screen.
  static WebLocation of({
    required HomeSection section,
    required String? roomId,
    required bool paneShell,
  }) {
    if (roomId != null && (!paneShell || section == HomeSection.chat)) {
      return WebLocation.room(roomId);
    }
    return WebLocation.section(section);
  }

  @override
  bool operator ==(Object other) =>
      other is WebLocation && other.section == section && other.roomId == roomId;

  @override
  int get hashCode => Object.hash(section, roomId);

  @override
  String toString() => 'WebLocation($path)';
}

/// The root navigator's route stack, counted. Browser Back has to know whether
/// something is sitting above what the address bar accounts for — a sheet, a
/// dialog, room info pushed over a chat — because that is what Back should
/// close first, the way it did before the address bar meant anything.
class _RouteStack extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (i < 0) {
      if (newRoute != null) routes.add(newRoute);
      return;
    }
    if (newRoute == null) {
      routes.removeAt(i);
    } else {
      routes[i] = newRoute;
    }
  }
}

/// Keeps the browser's address bar and history in step with the chat and
/// section on screen, and the tab title with the chat's name. Web only;
/// [attach] is never called elsewhere.
///
/// **Writing.** One listener over [UiSelectionStore], [SettingsStore] and the
/// auth state. A notification costs one comparison: the location is derived
/// and compared with the last one written, and only a real move reaches the
/// engine. Writes are coalesced to a microtask, so a room switch that clears
/// and then sets the selection, or sets the selection and then the section,
/// is one history entry and not two.
///
/// **History.** The root navigator puts the web engine in single-entry mode
/// (`reportsRouteUpdateToEngine`), where Back only ever means "pop". This
/// switches it to multi-entry once that navigator exists, so each chat or
/// section is its own entry, and Back/Forward arrive as
/// `didPushRouteInformation` — which `app.dart` forwards to
/// [handleBrowserNavigation].
///
/// **Reading.** A reload or a pasted `#/c/<id>` is held until there is an
/// account and a room list to check it against, then opened through the same
/// `openRoom` a notification tap uses. An id this account cannot see lands on
/// the chat list, and the bogus entry is replaced rather than kept.
class WebUrlSync {
  WebUrlSync._();
  static final WebUrlSync instance = WebUrlSync._();

  /// Handed to `MaterialApp.navigatorObservers`.
  final NavigatorObserver routes = _RouteStack();
  _RouteStack get _stack => routes as _RouteStack;

  /// How long a deep link waits for its room to turn up before giving up and
  /// showing the chat list. Matches the spirit of `PendingPlaceholder`: the
  /// live room list never arrives offline, so the wait has to be bounded.
  static const Duration _pendingTimeout = Duration(seconds: 12);

  bool _attached = false;
  late GlobalKey<NavigatorState> _navKey;
  late ChatRepository _repo;
  late ValueGetter<bool> _signedIn;
  late void Function(String roomId) _openRoom;
  late ValueGetter<String?> _savedMessagesTitle;

  /// The path the address bar shows now: the last one written, or the one the
  /// browser just navigated to.
  String _shown = '/';
  bool _scheduled = false;

  /// The next write replaces the current entry instead of adding one: the
  /// first write after sign-in (it describes where the app restored to, not a
  /// step the user took), and the landing after a link that led nowhere.
  bool _replaceNext = true;

  WebLocation? _pending;
  Timer? _pendingTimer;
  bool _listeningToRepo = false;

  void attach({
    required GlobalKey<NavigatorState> navigatorKey,
    required ChatRepository repo,
    required Listenable auth,
    required ValueGetter<bool> signedIn,
    required void Function(String roomId) openRoom,
    required ValueGetter<String?> savedMessagesTitle,
  }) {
    if (!kIsWeb || _attached) return;
    _attached = true;
    _navKey = navigatorKey;
    _repo = repo;
    _signedIn = signedIn;
    _openRoom = openRoom;
    _savedMessagesTitle = savedMessagesTitle;
    _shown = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final initial = WebDocument.takeInitialRoute();
    if (initial != null) _pending = WebLocation.parse(initial);
    Listenable.merge([UiSelectionStore.instance, SettingsStore.instance, auth])
        .addListener(_onChange);
    _selectMultiEntryHistory();
    _onChange();
  }

  /// After the root navigator's `initState`, which selects single-entry
  /// history; the engine applies navigation messages in order, so this one
  /// wins.
  void _selectMultiEntryHistory() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_navKey.currentState == null) {
        _selectMultiEntryHistory();
        SchedulerBinding.instance.scheduleFrame();
        return;
      }
      SystemNavigator.selectMultiEntryHistory();
    });
  }

  /// The same mirror `_openRoomFromPush` and `openRoom` decide by
  /// ([LayoutX.usesSplitShell]); expanded always implies it.
  bool get _paneShell => gLastSplitShell;

  WebLocation _here() => WebLocation.of(
        section: SettingsStore.instance.section,
        roomId: UiSelectionStore.instance.roomId,
        paneShell: _paneShell,
      );

  void _onChange() {
    _tryResolvePending();
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(_flush);
  }

  void _flush() {
    _scheduled = false;
    if (!_signedIn()) {
      // Signed out: nothing in the address bar should name a chat, and the
      // next sign-in starts a fresh run of history.
      WebTabTitle.instance.setRoom(null);
      _replaceNext = true;
      if (_shown != '/') _write('/', replace: true);
      return;
    }
    final here = _here();
    final id = here.roomId;
    WebTabTitle.instance.setRoom(id == null ? null : _titleOf(id));
    final path = here.path;
    if (path == _shown) {
      _replaceNext = false;
      return;
    }
    final replace = _replaceNext;
    _replaceNext = false;
    _write(path, replace: replace);
  }

  /// The name the chat list shows for the room: the peer's for a DM, the
  /// room's own otherwise, "Saved Messages" for the self-chat.
  String? _titleOf(String roomId) {
    final room = _repo.roomById(roomId);
    if (room == null) return null;
    if (room.isSavedMessages) return _savedMessagesTitle();
    if (room.isDm) return _repo.otherUserFor(room)?.displayName;
    return room.name;
  }

  void _write(String path, {required bool replace}) {
    _shown = path;
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(path),
      replace: replace,
    );
  }

  /// Browser Back/Forward, or a hash edited by hand. Returns whether the
  /// location was ours; `app.dart` asks this BEFORE the invite parser, which
  /// would read a bare `/feed` as the invite code FEED.
  ///
  /// Every scheme-less path is claimed except `/j/…`: in multi-entry mode
  /// these arrive on every history step, and one left unclaimed reaches
  /// `WidgetsApp`, whose answer to an unknown path is `pushNamed` — a crash.
  /// An unknown one lands on the chat list instead.
  bool handleBrowserNavigation(Uri uri) {
    if (!kIsWeb || !_attached) return false;
    if (uri.hasScheme) return false;
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path.startsWith('/j/')) return false;
    _shown = path;
    final target = WebLocation.parse(path);
    if (target == null) _replaceNext = true;
    if (!_signedIn() || _navKey.currentState == null) {
      _setPending(target ?? WebLocation.home);
      return true;
    }
    _navigateTo(target ?? WebLocation.home);
    return true;
  }

  void _navigateTo(WebLocation target) {
    final nav = _navKey.currentState;
    if (nav == null) return;
    final here = _here();
    // Something sits above what the address bar describes — a sheet, a
    // dialog, a page pushed over the chat. Back closes THAT, as it did before
    // the address bar meant anything, and the bar is put back where the app
    // still is once the route has gone.
    final base = 1 + (!_paneShell && here.roomId != null ? 1 : 0);
    if (_stack.routes.length > base && _stack.routes.isNotEmpty) {
      _popTopThenResync(nav, _stack.routes.last);
      return;
    }
    if (target == here) return;
    _go(target, nav);
  }

  void _go(WebLocation target, NavigatorState nav) {
    final id = target.roomId;
    if (id != null) {
      if (_repo.roomById(id) != null) {
        _openRoom(id);
        return;
      }
      // Not a room this account can see (left, deleted, someone else's
      // link): the chat list, replacing the dead entry.
      _replaceNext = true;
      target = WebLocation.home;
    }
    nav.popUntil((r) => r.isFirst);
    if (target.section == HomeSection.chat && _paneShell) {
      UiSelectionStore.instance.selectRoom(null);
    }
    SettingsStore.instance.setSection(target.section);
    // The location may already have been what the app shows (a phone whose
    // room was popped lands on the tab beneath, which is this one), in which
    // case no store fires; settle the bar either way.
    _onChange();
  }

  /// Pops [top], then — once it has actually left, which is when a popped
  /// chat clears its selection — writes the location the app is now at if it
  /// is not the one the browser stepped to. A sheet that closed leaves the app
  /// where it was, so its entry is pushed back; a chat that closed lands where
  /// Back pointed, so nothing is written at all.
  void _popTopThenResync(NavigatorState nav, Route<dynamic> top) {
    void resync() {
      // After the frame that disposes the route AND after the selection
      // store's own deferred notification, which is a post-frame callback of
      // that same frame — a timer runs after both.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Timer.run(_onChange);
      });
      SchedulerBinding.instance.scheduleFrame();
    }

    nav.maybePop().then((popped) {
      if (!popped) {
        resync();
        return;
      }
      final anim = top is ModalRoute ? top.animation : null;
      if (anim == null || anim.status == AnimationStatus.dismissed) {
        resync();
        return;
      }
      void onStatus(AnimationStatus s) {
        if (s != AnimationStatus.dismissed) return;
        anim.removeStatusListener(onStatus);
        resync();
      }

      anim.addStatusListener(onStatus);
    });
  }

  // ── Deep links (reload, pasted URL, Back/Forward before sign-in) ──

  void _setPending(WebLocation target) {
    _pending = target;
    _tryResolvePending();
  }

  void _tryResolvePending() {
    final p = _pending;
    if (p == null) return;
    final nav = _navKey.currentState;
    if (!_signedIn() || nav == null) return;
    final id = p.roomId;
    if (id == null) {
      _clearPending();
      // A link is not a preference: steer this run, don't rewrite which
      // section the app opens on next time.
      SettingsStore.instance.setSection(p.section, persist: false);
      return;
    }
    if (_repo.roomById(id) != null) {
      _clearPending();
      _openRoom(id);
      return;
    }
    if (_repo.hasLiveRoomList) {
      _giveUpPending();
      return;
    }
    // The room list is still on its way. Listen to the repository only for as
    // long as this wait lasts — it notifies on every keystroke in every room.
    if (!_listeningToRepo) {
      _listeningToRepo = true;
      _repo.addListener(_tryResolvePending);
    }
    _pendingTimer ??= Timer(_pendingTimeout, _giveUpPending);
  }

  void _giveUpPending() {
    if (_pending == null) return;
    _clearPending();
    _replaceNext = true;
    _onChange();
  }

  void _clearPending() {
    _pending = null;
    _pendingTimer?.cancel();
    _pendingTimer = null;
    if (_listeningToRepo) {
      _listeningToRepo = false;
      _repo.removeListener(_tryResolvePending);
    }
  }
}
