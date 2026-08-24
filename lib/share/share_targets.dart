import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../media/file_url_cache.dart';
import '../models/chat_room.dart';
import '../theme/app_theme.dart';

/// One person or group the OS may offer directly in the share sheet's top row.
///
/// The icon is described rather than rasterised: a URL when the target has a
/// real avatar, and a two-colour gradient plus an initial when it does not.
/// Native draws the fallback, which keeps a 96 px circle off the platform
/// channel and lets each OS render at its own screen density — Android wants an
/// adaptive-icon-sized bitmap, iOS wants an `INImage`, and neither is the size
/// the other one wants.
@immutable
class ShareTarget {
  const ShareTarget({
    required this.roomId,
    required this.title,
    required this.initial,
    required this.gradientStart,
    required this.gradientEnd,
    this.avatarUrl,
    this.isGroup = false,
  });

  /// Doubles as the shortcut id on Android and the conversation identifier in
  /// the iOS `INSendMessageIntent` — which is what comes back as
  /// `SharedPayload.targetRoomId` when the suggestion is tapped.
  final String roomId;

  final String title;

  /// Single grapheme, already upper-cased. Empty is allowed; native falls back
  /// to a glyph.
  final String initial;

  final int gradientStart;
  final int gradientEnd;

  /// Absolute, unsigned, permanent — see [FileUrlCache]. Null when the target
  /// has no avatar set, or when its URL has not been resolved yet; native
  /// draws the gradient in both cases rather than blocking on a fetch.
  final String? avatarUrl;

  final bool isGroup;

  Map<String, Object?> toChannel() => {
        'id': roomId,
        'title': title,
        'initial': initial,
        'gradientStart': gradientStart,
        'gradientEnd': gradientEnd,
        'avatarUrl': avatarUrl,
        'isGroup': isGroup,
      };

  @override
  bool operator ==(Object other) =>
      other is ShareTarget &&
      other.roomId == roomId &&
      other.title == title &&
      other.initial == initial &&
      other.gradientStart == gradientStart &&
      other.gradientEnd == gradientEnd &&
      other.avatarUrl == avatarUrl &&
      other.isGroup == isGroup;

  @override
  int get hashCode => Object.hash(
      roomId, title, initial, gradientStart, gradientEnd, avatarUrl, isGroup);
}

/// Most suggestions handed to the OS at once.
///
/// Android will not accept more than `getMaxShortcutCountPerActivity` (15 on
/// current releases, 5 guaranteed) and silently drops the overflow; iOS ranks
/// donations itself and shows three or four. Eight is comfortably inside both
/// and is about where a "recent chats" list stops being recent.
const int kMaxShareTargets = 8;

/// Publishes the app's chats to the OS as share-sheet suggestions.
///
/// Two verbs, because the two platforms rank suggestions in opposite
/// directions and pretending otherwise produces a share sheet that suggests the
/// wrong people on one of them:
///
///   * [sync] hands over the whole current list. Android's sharing-shortcut API
///     *is* a list — publish it and those are the targets — so this is the call
///     that matters there. iOS ignores it.
///   * [touch] says "the user just messaged this chat". iOS ranks donated
///     `INSendMessageIntent`s by recency and frequency and has no list to
///     replace, so this is the call that matters there. Android uses it to bump
///     the shortcut's rank.
///
/// Every method is a no-op off iOS/Android, and swallows
/// [MissingPluginException] so a platform build without the native half is
/// merely featureless rather than broken.
class ShareTargets {
  ShareTargets._();
  static final ShareTargets instance = ShareTargets._();

  static const MethodChannel _channel = MethodChannel('monkeyhub/share');

  bool get _supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// What was last successfully published, so an unchanged room list costs no
  /// platform round trip. The rooms subscription re-fires on every message in
  /// every room, which without this would be a shortcut republish per message.
  List<ShareTarget> _published = const [];

  Future<void> sync(List<ShareTarget> targets) async {
    if (!_supported) return;
    final capped = targets.take(kMaxShareTargets).toList(growable: false);
    if (listEquals(capped, _published)) return;
    _published = capped;
    await _invoke('publishTargets', {
      'targets': [for (final t in capped) t.toChannel()],
    });
  }

  Future<void> touch(ShareTarget target) async {
    if (!_supported) return;
    await _invoke('touchTarget', target.toChannel());
  }

  /// Signing out. The suggestions name people, so they cannot outlive the
  /// session that could see them — an account switch on a shared phone would
  /// otherwise leave the previous user's chats in the next one's share sheet.
  Future<void> clear() async {
    if (!_supported) return;
    _published = const [];
    await _invoke('clearTargets', const <String, Object?>{});
  }

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Platform build without the native half.
    } catch (e) {
      debugPrint('share targets: $method failed: $e');
    }
  }

  @visibleForTesting
  void debugReset() => _published = const [];
}

/// Turns the repository's room list into share-sheet suggestions.
///
/// The ordering, the filtering and the titles are deliberately the same rules
/// [showForwardTargetSheet] uses — a suggestion the sheet would refuse to list
/// is a suggestion that opens a chat the share cannot be sent to.
///
/// Rooms whose avatar URL is not cached yet are published with their gradient,
/// and the resolution is kicked off behind them so the next pass has it. This
/// never awaits a network call on purpose: a suggestion that shows the app's
/// own initials circle for one publish cycle is invisible, and a room list that
/// blocks on N `files:getFileUrl` queries is not.
List<ShareTarget> buildShareTargets({
  required ChatRepository repo,
  required AppTheme theme,
  required String savedMessagesTitle,
  required String directMessageFallbackTitle,
}) {
  final rooms = <ChatRoom>[];
  for (final r in repo.rooms) {
    if (!r.isMember) continue;
    if (r.isArchived) continue;
    if (!repo.capabilitiesFor(r).canReceiveForwards) continue;
    rooms.add(r);
  }
  rooms.sort((a, b) {
    final at = a.lastMessageTime, bt = b.lastMessageTime;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });

  return [
    for (final room in rooms.take(kMaxShareTargets))
      shareTargetFor(
        repo: repo,
        theme: theme,
        room: room,
        savedMessagesTitle: savedMessagesTitle,
        directMessageFallbackTitle: directMessageFallbackTitle,
      ),
  ];
}

/// One room's suggestion. Split out of [buildShareTargets] so a single send can
/// bump its own chat's rank ([ShareTargets.touch]) without rebuilding the list.
ShareTarget shareTargetFor({
  required ChatRepository repo,
  required AppTheme theme,
  required ChatRoom room,
  required String savedMessagesTitle,
  required String directMessageFallbackTitle,
}) {
  final peer = room.isDm ? repo.otherUserFor(room) : null;
  final title = room.isSavedMessages
      ? savedMessagesTitle
      : room.isDm
          ? (peer?.displayName ?? directMessageFallbackTitle)
          : room.name;
  // The avatar seed is the USER's id for a DM and the ROOM's for a group — the
  // same two seeds `UserAvatar` and the room tiles paint from, so a suggestion
  // looks like the row it stands for rather than like a differently-coloured
  // stranger.
  final gradient = theme.avatarGradient(_seedOf(peer?.id ?? room.id));
  final storageId = peer?.avatarStorageId ?? room.avatarStorageId;
  String? avatarUrl;
  if (storageId != null && storageId.isNotEmpty) {
    avatarUrl = FileUrlCache.instance.peek(storageId);
    if (avatarUrl == null) {
      // Warm it for the next pass. `resolve` dedupes in flight, so this costs
      // nothing when the chat list is already resolving the same id.
      unawaited(FileUrlCache.instance
          .resolve(storageId, () => repo.api.getFileUrl(storageId))
          .catchError((Object _) => null));
    }
  }
  return ShareTarget(
    roomId: room.id,
    title: title,
    initial: _initialOf(title),
    gradientStart: _argb(gradient.first),
    gradientEnd: _argb(gradient.length > 1 ? gradient[1] : gradient.first),
    avatarUrl: avatarUrl,
    isGroup: !room.isDm,
  );
}

/// The same hash `UserAvatar._seed` computes. Duplicated rather than exported
/// because the widget's copy is a private getter over a `ChatUser`, and this
/// needs it for a room id too.
int _seedOf(String id) {
  int hash = 0;
  for (final c in id.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  return hash;
}

String _initialOf(String title) {
  final t = title.trim();
  if (t.isEmpty) return '';
  // `characters` would be the correct grapheme split, but an initial is one
  // code point in every script this renders and pulling in the package for a
  // fallback glyph is not worth it. An emoji title falls back to the surrogate
  // pair's first half rendering as nothing, which is exactly the empty-initial
  // case native already handles.
  final first = t.runes.first;
  return String.fromCharCode(first).toUpperCase();
}

int _argb(Color c) =>
    (((c.a * 255).round() & 0xff) << 24) |
    (((c.r * 255).round() & 0xff) << 16) |
    (((c.g * 255).round() & 0xff) << 8) |
    ((c.b * 255).round() & 0xff);

/// Keeps the OS's suggestions in step with the chat list.
///
/// Listens to the repository and republishes on a trailing debounce. The debounce
/// is the load-bearing part: `rooms:listUserRooms` re-fires on every message in
/// every room the user is in, and each republish is a platform round trip that
/// re-fetches avatars — so an active group chat would otherwise redraw the share
/// sheet's suggestions several times a second.
class ShareTargetsSync {
  ShareTargetsSync({
    required ChatRepository repo,
    required AppTheme Function() theme,
    required String Function() savedMessagesTitle,
    required String Function() directMessageFallbackTitle,
    Duration debounce = const Duration(seconds: 2),
  })  : _repo = repo,
        _theme = theme,
        _savedMessagesTitle = savedMessagesTitle,
        _directMessageFallbackTitle = directMessageFallbackTitle,
        _debounce = debounce {
    _repo.addListener(_onRepoChange);
  }

  final ChatRepository _repo;
  final AppTheme Function() _theme;
  final String Function() _savedMessagesTitle;
  final String Function() _directMessageFallbackTitle;
  final Duration _debounce;

  Timer? _timer;

  void _onRepoChange() {
    _timer?.cancel();
    _timer = Timer(_debounce, publishNow);
  }

  /// Publishes immediately, skipping the debounce. Called on sign-in so the
  /// first share after an install has something to suggest.
  void publishNow() {
    _timer?.cancel();
    _timer = null;
    if (_repo.userId == null) return;
    unawaited(ShareTargets.instance.sync(buildShareTargets(
      repo: _repo,
      theme: _theme(),
      savedMessagesTitle: _savedMessagesTitle(),
      directMessageFallbackTitle: _directMessageFallbackTitle(),
    )));
  }

  void dispose() {
    _timer?.cancel();
    _repo.removeListener(_onRepoChange);
  }
}
