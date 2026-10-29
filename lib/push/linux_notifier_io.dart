import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Desktop notifications for the Linux build, through the desktop's own
/// notification daemon (org.freedesktop.Notifications — GNOME Shell, KDE
/// Plasma, dunst, mako, swaync all speak it).
///
/// Linux has no push service. APNs and FCM have no Linux client and Web Push
/// needs a browser, so a message only reaches this build over the Convex
/// socket the running app already holds — exactly how Slack, Discord and
/// Telegram Desktop do it. Before this the only thing that socket produced
/// was [MessageAlerts]' ping: no banner, nothing in the notification list, and
/// a window behind another one never said who wrote.
///
/// One notification per room, replaced in place (`replaces_id`), so an active
/// group is a single entry that keeps its latest line rather than a column of
/// them — the same shape the phones now use.
class LinuxNotifier {
  LinuxNotifier._();
  static final LinuxNotifier instance = LinuxNotifier._();

  static const _iface = 'org.freedesktop.Notifications';
  static const _window = MethodChannel('monkeyhub/window');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  DBusRemoteObject? _daemon;
  final List<StreamSubscription<DBusSignal>> _subs = [];

  /// Daemon id ↔ room, so a room's next message replaces its notification
  /// and a click on one opens the right room.
  final Map<String, int> _idByRoom = {};
  final Map<int, String> _roomById = {};

  /// The activation token the daemon hands over just before a click, which
  /// is what lets a Wayland compositor raise the window instead of flashing
  /// it. Keyed by notification id.
  final Map<int, String> _tokens = {};

  /// Set once, by the first failure: a desktop with no daemon is not going to
  /// grow one mid-session, and asking again per message only spams the log.
  bool _broken = false;

  void Function(String roomId)? _onOpenRoom;
  void setOnOpenRoom(void Function(String roomId) cb) => _onOpenRoom = cb;

  DBusRemoteObject _connect() {
    final existing = _daemon;
    if (existing != null) return existing;
    final client = DBusClient.session();
    final daemon = _daemon = DBusRemoteObject(
      client,
      name: _iface,
      path: DBusObjectPath('/org/freedesktop/Notifications'),
    );
    _subs.add(
      DBusRemoteObjectSignalStream(
        object: daemon,
        interface: _iface,
        name: 'ActivationToken',
        signature: DBusSignature('us'),
      ).listen((s) {
        _tokens[s.values[0].asUint32()] = s.values[1].asString();
      }),
    );
    _subs.add(
      DBusRemoteObjectSignalStream(
        object: daemon,
        interface: _iface,
        name: 'ActionInvoked',
        signature: DBusSignature('us'),
      ).listen((s) {
        final id = s.values[0].asUint32();
        final room = _roomById[id];
        if (room == null) return;
        unawaited(_present(_tokens.remove(id)));
        _onOpenRoom?.call(room);
      }),
    );
    _subs.add(
      DBusRemoteObjectSignalStream(
        object: daemon,
        interface: _iface,
        name: 'NotificationClosed',
        signature: DBusSignature('uu'),
      ).listen((s) {
        final id = s.values[0].asUint32();
        _tokens.remove(id);
        final room = _roomById.remove(id);
        if (room != null && _idByRoom[room] == id) _idByRoom.remove(room);
      }),
    );
    return daemon;
  }

  Future<void> _present(String? token) async {
    try {
      await _window.invokeMethod<void>('present', {'token': ?token});
    } catch (e) {
      debugPrint('LinuxNotifier: present failed: $e');
    }
  }

  String? _trayLabels;

  /// The tray menu's two items in the app's language. The native side builds
  /// them in English before Dart runs; this relabels them, and again on
  /// every language change. No-ops unless the words moved.
  void setTrayLabels({required String open, required String quit}) {
    if (!supported) return;
    final key = '$open\u0000$quit';
    if (_trayLabels == key) return;
    _trayLabels = key;
    _window
        .invokeMethod<void>('setTrayLabels', {'open': open, 'quit': quit})
        .catchError((Object e) => debugPrint('LinuxNotifier: tray labels: $e'));
  }

  /// The tarball ships its icon beside the binary; the AUR package moves it
  /// into the icon theme, where the bare name finds it.
  late final String _icon = () {
    try {
      final dir = File('/proc/self/exe').resolveSymbolicLinksSync();
      final png = File('${File(dir).parent.path}/monkeyhub.png');
      if (png.existsSync()) return Uri.file(png.path).toString();
    } catch (_) {}
    return 'monkeyhub';
  }();

  /// Shows (or replaces) [roomId]'s notification.
  ///
  /// [quiet] asks the daemon not to play its own sound, for the second and
  /// later messages of a burst; daemons that ignore the hint are no worse off
  /// than before.
  Future<void> show({
    required String roomId,
    required String title,
    required String body,
    bool quiet = false,
  }) async {
    if (!supported || _broken) return;
    try {
      final daemon = _connect();
      final reply = await daemon.callMethod(
        _iface,
        'Notify',
        [
          const DBusString('MonkeyHub'),
          DBusUint32(_idByRoom[roomId] ?? 0),
          DBusString(_icon),
          DBusString(title),
          DBusString(_escape(body)),
          DBusArray.string(const ['default', 'Open']),
          DBusDict.stringVariant({
            // Ties the notification to the launcher entry, which is how GNOME
            // and KDE group it under the app and honour its per-app settings.
            'desktop-entry': const DBusString('monkeyhub'),
            'category': const DBusString('im.received'),
            'urgency': const DBusByte(1),
            if (quiet) 'suppress-sound': const DBusBoolean(true),
          }),
          const DBusInt32(-1),
        ],
        replySignature: DBusSignature('u'),
      );
      final id = reply.values.first.asUint32();
      final old = _idByRoom[roomId];
      if (old != null && old != id) _roomById.remove(old);
      _idByRoom[roomId] = id;
      _roomById[id] = roomId;
    } catch (e) {
      _broken = true;
      debugPrint('LinuxNotifier: no notification daemon ($e)');
    }
  }

  /// Takes [roomId]'s notification down — the room was opened here.
  Future<void> dismissRoom(String roomId) async {
    final id = _idByRoom.remove(roomId);
    if (id == null) return;
    _roomById.remove(id);
    _tokens.remove(id);
    try {
      await _connect().callMethod(_iface, 'CloseNotification', [DBusUint32(id)]);
    } catch (_) {/* already gone */}
  }

  /// The body is markup to daemons that advertise `body-markup`, so a message
  /// reading "<b>" must not turn bold, and a stray "&" must not blank it.
  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
