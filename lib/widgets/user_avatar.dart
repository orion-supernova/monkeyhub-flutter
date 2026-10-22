import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../data/presence_store.dart';
import '../data/settings_store.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'chat_list_row.dart' show monogramGradient;
import 'remote_image.dart';

/// Diameter of the peer's avatar in the chat header. Shared because the call
/// screen borrows that decode as its stand-in (see
/// [UserAvatar.placeholderDecodeWidth]); a header at another size would miss
/// the cache and slide the call screen up on a shimmer again.
const kChatHeaderAvatarSize = 34.0;

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.ringColor,
    this.ring = false,
    this.api,
    this.showStatus = true,
    this.placeholderDecodeWidth,
  });

  final ChatUser user;
  final double size;
  final Color? ringColor;
  final bool ring;

  /// Pass `api` to fetch the storageId-backed avatar. When null (or no
  /// `avatarStorageId`), we fall back to the gradient + initials.
  final ChatApi? api;

  /// When true (default) and `user.status` is non-null, paints a small dot
  /// overlay in the bottom-right corner indicating online/away/offline.
  final bool showStatus;

  /// See [RemoteImage.placeholderDecodeWidth]: a smaller decode of the same
  /// picture, already on screen elsewhere, to stand in while this size
  /// decodes.
  final int? placeholderDecodeWidth;

  String get _initials => user.displayInitial;

  int get _seed {
    // Deterministic seed from user id so the gradient is stable.
    int hash = 0;
    for (final c in user.id.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return hash;
  }

  Widget _withStatus(BuildContext context, AppTheme theme, Widget child) {
    if (!showStatus) return child;
    final dot = (size * 0.30).clamp(8.0, 16.0);
    // The Stack is here whenever a dot COULD show, not only while one does: a
    // presence change then only swaps the dot, and never remounts the face and
    // reloads its image.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -dot * 0.1,
          bottom: -dot * 0.1,
          child: PresenceDot(user: user, dot: dot),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hasRemote = api != null &&
        user.avatarStorageId != null &&
        user.avatarStorageId!.isNotEmpty;

    final ringBorder =
        ring ? Border.all(color: ringColor ?? theme.accent, width: 1.5) : null;

    if (hasRemote) {
      return _withStatus(
        context,
        theme,
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: ringBorder,
          ),
          clipBehavior: Clip.antiAlias,
          child: RemoteImage(
            storageId: user.avatarStorageId!,
            api: api!,
            width: size,
            height: size,
            borderRadius: BorderRadius.circular(size),
            placeholderDecodeWidth: placeholderDecodeWidth,
          ),
        ),
      );
    }

    return _withStatus(
      context,
      theme,
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // One hue, lit from above — the same face a lettered room wears.
          // Two hues picked independently at random were how a list ended
          // up with a green-to-red disc beside an orange-to-purple one, and
          // the glow under each was the most Android thing on the row.
          gradient: monogramGradient(theme, _seed),
          border: ringBorder,
        ),
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: TextStyle(
            fontFamily: 'CupertinoSystemDisplay',
            fontSize: size * 0.40,
            fontWeight: FontWeight.w600,
            height: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The store the presence widgets lease from. Tests swap in a private one, or
/// null (test/flutter_test_config.dart does) so a widget leases nothing, arms
/// no timers, and just shows the status its user object carries.
@visibleForTesting
PresenceStore? presenceStoreForWidgets = PresenceStore.instance;

/// What a [PresenceBuilder] hands its builder.
@immutable
class PresenceView {
  const PresenceView({this.status, this.lastSeen, this.live = false});

  /// `online`, `away`, `offline`, or null when nothing is known or shown.
  final String? status;
  final DateTime? lastSeen;

  /// True when it came from [PresenceStore], false when it fell back to the
  /// `status` the user object arrived with (old server, or not loaded yet).
  final bool live;
}

/// Leases [user]'s presence for as long as it is mounted and rebuilds with it.
///
/// The one door every text display of presence goes through: it holds the
/// lease (so the store's single subscription covers this person), listens to
/// both their value and the store's legacy flag, and falls back to
/// `user.status` / `user.lastSeen` when the store has nothing, so an old
/// server and the first frame both read as they always did.
class PresenceBuilder extends StatefulWidget {
  const PresenceBuilder({super.key, required this.user, required this.builder});

  final ChatUser user;
  final Widget Function(BuildContext context, PresenceView presence) builder;

  @override
  State<PresenceBuilder> createState() => _PresenceBuilderState();
}

class _PresenceBuilderState extends State<PresenceBuilder> {
  PresenceLease? _lease;
  late Listenable _listenable;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(PresenceBuilder old) {
    super.didUpdateWidget(old);
    if (old.user.id != widget.user.id) {
      _lease?.release();
      _bind();
    }
  }

  void _bind() {
    final store = presenceStoreForWidgets;
    final id = widget.user.id;
    _lease = id.isEmpty ? null : store?.lease([id]);
    _listenable = store == null
        ? const _Never()
        : Listenable.merge([store, store.of(id)]);
  }

  @override
  void dispose() {
    _lease?.release();
    super.dispose();
  }

  PresenceView _view() {
    final store = presenceStoreForWidgets;
    final info = store == null || store.legacy
        ? null
        : store.peek(widget.user.id);
    if (info != null) {
      final ls = info.lastSeen;
      return PresenceView(
        status: info.status,
        lastSeen: ls == null ? null : DateTime.fromMillisecondsSinceEpoch(ls),
        live: true,
      );
    }
    return PresenceView(
      status: widget.user.status,
      lastSeen: widget.user.lastSeen,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _listenable,
    builder: (context, _) => widget.builder(context, _view()),
  );
}

class _Never implements Listenable {
  const _Never();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

/// The little online/away/offline dot in an avatar's corner.
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.user, required this.dot});

  final ChatUser user;
  final double dot;

  static const _amber = Color(0xFFE0A33C);
  static const _awayFreshWindow = Duration(minutes: 5);
  // A client that stopped heartbeating is treated as offline server-side after
  // ~2 min; give the local self-heal a little slack over that so a genuinely
  // fresh "online" never flickers gray between heartbeats.
  static const _onlineFreshWindow = Duration(minutes: 3);

  /// The dot's colour for [v], or null for no dot. The staleness checks guard
  /// the legacy path only: a live value is already the server's derived
  /// answer, and a throttled `lastSeen` must not gray out someone online.
  @visibleForTesting
  static Color? colorFor(AppTheme theme, PresenceView v) {
    switch (v.status) {
      case 'online':
        // Belt-and-suspenders for the server staleness fallback: if we somehow
        // hold a stale 'online' whose lastSeen is old, don't show a live green
        // dot. (The server normally sends 'offline' already.)
        final ls = v.lastSeen;
        if (!v.live &&
            ls != null &&
            DateTime.now().difference(ls) > _onlineFreshWindow) {
          return theme.inkMuted;
        }
        return theme.success;
      case 'away':
        // If we know when they were last seen, only stay amber while still
        // recently active; otherwise demote to gray so a stale "away" doesn't
        // misrepresent presence. Without a lastSeen (hidden or unavailable),
        // fall back to amber, that's all we know.
        final ls = v.lastSeen;
        if (!v.live && ls != null) {
          return DateTime.now().difference(ls) <= _awayFreshWindow
              ? _amber
              : theme.inkMuted;
        }
        return _amber;
      case 'offline':
        return theme.inkMuted;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Plenty of avatars are built `const` inside parents that never rebuild, so
    // the Settings toggle and the presence value both have to reach the dot
    // themselves.
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        if (!SettingsStore.instance.showPresenceDots) {
          return const SizedBox.shrink();
        }
        return PresenceBuilder(
          user: user,
          builder: (context, v) {
            final color = colorFor(theme, v);
            if (color == null) return const SizedBox.shrink();
            return Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: theme.background, width: 1.5),
              ),
            );
          },
        );
      },
    );
  }
}
