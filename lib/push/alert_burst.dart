/// Whether a new message in a room should make a sound, or arrive quietly.
///
/// An active group sending twenty lines in a minute used to buzz twenty times.
/// Every mainstream messenger solves it the same way: the FIRST message of a
/// burst alerts, the rest of the burst lands silently in the same stack, and
/// a conversation that keeps going still nudges every few minutes so it is
/// not mistaken for one that stopped.
///
/// The same rule, with the same two numbers, runs on every surface that
/// alerts — keep them in step:
///   - here, for the desktop builds' ping and banner;
///   - ios/NotificationService/NotificationService.swift (`AlertBurst`);
///   - android/.../ChatNotifications.kt (`AlertBurst`).
/// It runs on the device, not the server, because a buzz is per device: the
/// phone in your pocket should not stay quiet because the laptop in front of
/// you chimed. It also costs the backend nothing per message per recipient.
class AlertBurst {
  AlertBurst({
    this.gap = defaultGap,
    this.reminder = defaultReminder,
  });

  /// A message within this long of the room's previous one is the same burst.
  static const defaultGap = Duration(seconds: 45);

  /// However long the burst runs, it alerts again after this long.
  static const defaultReminder = Duration(minutes: 3);

  final Duration gap;
  final Duration reminder;

  final Map<String, ({DateTime seen, DateTime alerted})> _rooms = {};

  /// Records a message in [roomId] at [now] and says whether it should alert.
  /// Being mentioned always does: that is someone asking for you by name.
  bool shouldAlert(String roomId, DateTime now, {bool mention = false}) {
    final prev = _rooms[roomId];
    if (prev != null &&
        !mention &&
        now.difference(prev.seen) < gap &&
        now.difference(prev.alerted) < reminder) {
      _rooms[roomId] = (seen: now, alerted: prev.alerted);
      return false;
    }
    _rooms[roomId] = (seen: now, alerted: now);
    return true;
  }

  void clear() => _rooms.clear();
}
