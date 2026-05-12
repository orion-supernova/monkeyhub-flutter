import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/theme_scope.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.ringColor,
    this.ring = false,
  });

  final User user;
  final double size;
  final Color? ringColor;
  final bool ring;

  String get _initials {
    final parts = user.name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final gradient = theme.avatarGradient(user.avatarSeed);
    final angle = (user.avatarSeed % 360) * math.pi / 180;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment(-dx, -dy),
          end: Alignment(dx, dy),
        ),
        border: ring ? Border.all(color: ringColor ?? theme.accent, width: 1.5) : null,
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
    );
  }
}
