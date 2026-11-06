import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'chat_list_row.dart' show MonogramAvatar;
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
/// The room's picture (or, before one is picked, the same lettered face a
/// room without a picture wears everywhere else, its initial following the
/// typed name), the name (a quiet placeholder until one is typed), a
/// one-line subtitle that slides to its next value whenever a choice changes
/// it ("Invite only · you + 2 · secret · 1m after seen"), the faces of the
/// people picked so far, and a SECRET badge that drops in when the room is
/// secret. A secret room turns the whole card deep violet.
///
/// Pure display: the sheet owns every value. The avatar kicks (a pop) when
/// [picture] changes, the same glyph kick the chat chrome uses; the picked
/// faces spring in one at a time. Calm motion swaps instead of sliding.
class RoomPreviewCard extends StatelessWidget {
  const RoomPreviewCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.secret,
    this.people = const [],
    this.api,
    this.picture,
    this.avatarSeed = 'new-room',
    this.onPictureTap,
    this.onPictureClear,
    this.pictureSemantic,
    this.pictureClearSemantic,
  });

  /// The cropped picture picked for the room, or null for the default face.
  final Uint8List? picture;

  /// Seeds the default face's colour, so it stays put while the name is typed.
  final String avatarSeed;

  /// Tap the avatar (or its camera badge) to pick a photo.
  final VoidCallback? onPictureTap;

  /// Long-press the avatar or tap the small x to drop the picked photo.
  final VoidCallback? onPictureClear;
  final String? pictureSemantic;
  final String? pictureClearSemantic;

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
          _PictureSlot(
            picture: picture,
            name: trimmed,
            seed: avatarSeed,
            secret: secret,
            violet: violet,
            ring: fill,
            onTap: onPictureTap,
            onClear: onPictureClear,
            semantic: pictureSemantic,
            clearSemantic: pictureClearSemantic,
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

/// The card's avatar: the picked photo or the default lettered face, a camera
/// badge at the bottom right, and (once a photo is picked) a small x at the top
/// left to drop it. A long-press drops it too.
class _PictureSlot extends StatelessWidget {
  const _PictureSlot({
    required this.picture,
    required this.name,
    required this.seed,
    required this.secret,
    required this.violet,
    required this.ring,
    required this.onTap,
    required this.onClear,
    required this.semantic,
    required this.clearSemantic,
  });

  final Uint8List? picture;
  final String name;
  final String seed;
  final bool secret;
  final Color violet;
  final Color ring;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final String? semantic;
  final String? clearSemantic;

  static const _size = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final pic = picture;
    final face = pic != null
        ? ClipOval(
            child: Image.memory(
              pic,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          )
        : MonogramAvatar(label: name, seed: seed, size: _size);
    Widget badge(IconData icon, Color fill, Color ink) => Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 2),
          ),
          child: Icon(icon, size: 10, color: ink),
        );
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SpringPress(
              onTap: onTap,
              onLongPress: pic != null ? onClear : null,
              semanticLabel: semantic,
              focusRadius: _size / 2,
              child: KickGlyph(
                kick: GlyphKick.pop,
                trigger: pic,
                amplitude: 1.2,
                child: face,
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: badge(CupertinoIcons.camera_fill,
                  secret ? violet : theme.accent, theme.accentInk),
            ),
          ),
          if (pic != null && onClear != null)
            Positioned(
              left: -6,
              top: -6,
              child: SpringPress(
                onTap: onClear,
                semanticLabel: clearSemantic,
                focusRadius: 12,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: badge(CupertinoIcons.xmark, theme.ink, ring),
                ),
              ),
            ),
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
