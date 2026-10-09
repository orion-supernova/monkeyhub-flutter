import 'dart:async';

import 'package:flutter/foundation.dart';

import 'web_document.dart';

/// The browser tab's title: `(3) MonkeyHub` while anything is unread,
/// `Alice – MonkeyHub` while a chat is open and nothing is, `MonkeyHub`
/// otherwise.
///
/// The count wins over the room, which is WhatsApp Web's and Telegram Web's
/// rule and for the same reason: the title is what you read from ANOTHER tab,
/// where the only useful question is "is anything waiting for me", and the
/// chat you have open is the one thing you already know. A tab strip truncates
/// from the right, so the count also has to come first to survive at all.
///
/// The count is [BadgeManager]'s total (via `WebBadge.set`), not the bare
/// unread-message sum, so the tab says the same number the installed app's
/// icon would: requests and invites need you just as much as a message does.
///
/// Writes are throttled. The count moves with every incoming message, and a
/// busy group can move it many times a second — a title that flickers through
/// each value is noise, and every write is a DOM mutation. The first change
/// lands at once, and the rest at most every [_minGap], always ending on the
/// latest value.
///
/// Off web nothing here is ever called: `MaterialApp.title` stays the constant
/// it always was, and a native window's title is the OS's business.
class WebTabTitle {
  WebTabTitle._();
  static final WebTabTitle instance = WebTabTitle._();

  static const String appName = 'MonkeyHub';
  static const Duration _minGap = Duration(milliseconds: 500);

  int _count = 0;
  String? _room;

  String _current = appName;

  /// What the tab says now. `MaterialApp.title` reads this, because its
  /// `Title` widget rewrites `document.title` on every rebuild of the app —
  /// a theme change used to reset `(3) MonkeyHub` to `MonkeyHub` until the
  /// next message arrived. Reading the live value makes that write agree.
  String get current => _current;

  Timer? _cooldown;
  bool _dirty = false;

  /// The pure rule, for tests.
  @visibleForTesting
  static String compose({required int count, String? room}) {
    if (count > 0) return '($count) $appName';
    final name = room?.trim();
    if (name != null && name.isNotEmpty) return '$name – $appName';
    return appName;
  }

  void setCount(int n) {
    if (n == _count) return;
    _count = n;
    _schedule();
  }

  /// The display name of the chat on screen, or null for none.
  void setRoom(String? name) {
    if (name == _room) return;
    _room = name;
    _schedule();
  }

  void _schedule() {
    if (!kIsWeb) return;
    if (_cooldown != null) {
      _dirty = true;
      return;
    }
    _write();
    _cooldown = Timer(_minGap, _cooled);
  }

  void _cooled() {
    _cooldown = null;
    if (!_dirty) return;
    _dirty = false;
    _schedule();
  }

  void _write() {
    final next = compose(count: _count, room: _room);
    if (next == _current) return;
    _current = next;
    WebDocument.setTitle(next);
  }
}
