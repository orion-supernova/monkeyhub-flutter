import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'chrome_motion.dart';
import 'ios_kit.dart';
import 'user_avatar.dart';

/// The violet a secret room wears, in [theme]'s own terms: the shared purple
/// tile tone, so a secret room reads the same everywhere and a theme change
/// moves it with the rest of the palette's contrast rules.
Color secretRoomTint(AppTheme theme) => tileColor(theme, TileTone.purple);

/// The living card at the top of the new-room sheet: the room as it will look
/// to the people in it, reacting to every choice made below.
///
/// An emoji avatar, the name (a quiet placeholder until one is typed), a
/// one-line subtitle that slides to its next value whenever a choice changes
/// it ("Invite only · you + 2 · secret · 1m after seen"), the faces of the
/// people picked so far, and a SECRET badge that drops in when the room is
/// secret. A secret room turns the whole card deep violet.
///
/// Pure display: the sheet owns every value. The avatar kicks (a pop) when
/// [emoji] changes, the same glyph kick the chat chrome uses; the picked
/// faces spring in one at a time. Calm motion swaps instead of sliding.
class RoomPreviewCard extends StatelessWidget {
  const RoomPreviewCard({
    super.key,
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.secret,
    this.people = const [],
    this.api,
  });

  final String emoji;

  /// The typed name, or empty for the placeholder.
  final String name;
  final String subtitle;
  final bool secret;

  /// Everyone picked to be invited, in the order they were picked. The card
  /// shows the first [maxFaces].
  final List<ChatUser> people;
  final ChatApi? api;

  static const maxFaces = 4;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final calm = MotionScope.of(context).calm;
    final violet = secretRoomTint(theme);
    final fill = secret
        ? Color.lerp(theme.surfaceRaised, violet, theme.isLight ? 0.16 : 0.30)!
        : theme.surfaceRaised;
    final edge = secret
        ? violet.withValues(alpha: 0.55)
        : theme.ink.withValues(alpha: theme.isLight ? 0.08 : 0.10);
    final trimmed = name.trim();
    final shown = people.take(maxFaces).toList();

    return AnimatedContainer(
      duration: calm ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: edge, width: 1),
      ),
      child: Row(
        children: [
          KickGlyph(
            kick: GlyphKick.pop,
            trigger: emoji,
            amplitude: 1.4,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: secret
                    ? violet.withValues(alpha: 0.28)
                    : quietFill(theme),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 28, height: 1)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trimmed.isEmpty ? l10n.newRoomPreviewUntitled : trimmed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyEmph.copyWith(
                          fontSize: 17,
                          color: trimmed.isEmpty ? theme.inkMuted : theme.ink,
                        ),
                      ),
                    ),
                    // The badge takes its room only while it shows, and pops
                    // in on an elastic curve rather than blinking on.
                    AnimatedSize(
                      duration:
                          calm ? Duration.zero : const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: secret
                          ? Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _SecretBadge(
                                label: l10n.newRoomPreviewSecretBadge,
                                color: violet,
                              ),
                            )
                          : const SizedBox(width: 0, height: 0),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Up to two lines: the longest subtitle ("Findable · locked ·
                // you + 3 · secret · 30s after sent") does not fit one beside
                // the faces. The card grows by a line rather than clipping.
                AnimatedSize(
                  duration:
                      calm ? Duration.zero : const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  child: SlideSwap(
                    child: Text(
                      subtitle,
                      key: ValueKey(subtitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.caption.copyWith(
                        color: theme.inkSoft,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(width: 8),
            _FaceStack(users: shown, api: api, ring: fill),
          ],
        ],
      ),
    );
  }
}

/// The SECRET badge: pops in with an elastic overshoot.
class _SecretBadge extends StatelessWidget {
  const _SecretBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final calm = MotionScope.of(context).calm;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: calm ? 1 : 0, end: 1),
      duration: calm ? Duration.zero : const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, t, child) =>
          Transform.scale(scale: t, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: theme.caption.copyWith(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Overlapping faces of the people picked so far; each springs in when it
/// arrives (the card's counterpart of tapping a chip below).
class _FaceStack extends StatelessWidget {
  const _FaceStack({required this.users, required this.api, required this.ring});
  final List<ChatUser> users;
  final ChatApi? api;
  final Color ring;

  static const _size = 26.0;
  static const _step = 17.0;

  @override
  Widget build(BuildContext context) {
    final calm = MotionScope.of(context).calm;
    final width = _size + _step * (users.length - 1);
    return SizedBox(
      width: width,
      height: _size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < users.length; i++)
            Positioned(
              left: i * _step,
              top: 2,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(users[i].id),
                tween: Tween(begin: calm ? 1 : 0, end: 1),
                duration: calm ? Duration.zero : const Duration(milliseconds: 560),
                curve: Curves.elasticOut,
                builder: (context, t, child) =>
                    Transform.scale(scale: t.clamp(0.0, 1.4), child: child),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ring, width: 2),
                  ),
                  child: UserAvatar(
                    user: users[i],
                    size: _size - 4,
                    api: api,
                    showStatus: false,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
