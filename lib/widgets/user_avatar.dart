import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.ringColor,
    this.ring = false,
    this.api,
    this.showStatus = true,
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

  String get _initials => user.displayInitial;

  int get _seed {
    // Deterministic seed from user id so the gradient is stable.
    int hash = 0;
    for (final c in user.id.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return hash;
  }

  static const _amber = Color(0xFFE0A33C);
  static const _awayFreshWindow = Duration(minutes: 5);
  // A client that stopped heartbeating is treated as offline server-side after
  // ~2 min; give the local self-heal a little slack over that so a genuinely
  // fresh "online" never flickers gray between heartbeats.
  static const _onlineFreshWindow = Duration(minutes: 3);

  Color? _statusColor(AppTheme theme) {
    switch (user.status) {
      case 'online':
        // Belt-and-suspenders for the server staleness fallback: if we somehow
        // hold a stale 'online' whose lastSeen is old, don't show a live green
        // dot. (The server normally sends 'offline' already.)
        final ls = user.lastSeen;
        if (ls != null &&
            DateTime.now().difference(ls) > _onlineFreshWindow) {
          return theme.inkMuted;
        }
        return theme.success;
      case 'away':
        // If we know when they were last seen, only stay amber while still
        // recently active; otherwise demote to gray so a stale "away" doesn't
        // misrepresent presence. Without a lastSeen (hidden or unavailable),
        // fall back to amber — that's all we know.
        final ls = user.lastSeen;
        if (ls != null) {
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

  Widget _withStatus(BuildContext context, AppTheme theme, Widget child) {
    if (!showStatus) return child;
    final color = _statusColor(theme);
    if (color == null) return child;
    final dot = (size * 0.30).clamp(8.0, 16.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -dot * 0.1,
          bottom: -dot * 0.1,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: theme.background, width: 1.5),
              boxShadow: user.status == 'online'
                  ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6)]
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final gradient = theme.avatarGradient(_seed);
    final angle = (_seed % 360) * math.pi / 180;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
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
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.25),
                blurRadius: size * 0.3,
                spreadRadius: -size * 0.1,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: RemoteImage(
            storageId: user.avatarStorageId!,
            api: api!,
            width: size,
            height: size,
            borderRadius: BorderRadius.circular(size),
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
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment(-dx, -dy),
            end: Alignment(dx, dy),
          ),
          border: ringBorder,
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.35),
              blurRadius: size * 0.4,
              spreadRadius: -size * 0.1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          _initials,
          style: theme.label.copyWith(
            fontSize: size * 0.34,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
