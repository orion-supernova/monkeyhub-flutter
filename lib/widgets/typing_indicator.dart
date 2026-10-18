import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'speaker_scope.dart';
import 'user_avatar.dart';

/// Wording for "who is typing", shared by every surface that shows it — the
/// classic room header, the compact pill, room cards and grid tiles. Kept in
/// one place because three hand-rolled copies had drifted apart, so the same
/// two people typing read differently depending on which screen you were on.
///
///   1  → mom is typing
///   2  → mom and dad are typing
///   3+ → mom, dad +2 are typing
///
/// No trailing ellipsis: every surface that shows this label also shows
/// [TypingDots] beside it, and the animated dots ARE the ellipsis. Printing
/// "typing…" next to them rendered the same idea twice, six dots in a row.
String typingLabel(BuildContext context, List<ChatUser> typists) {
  if (typists.isEmpty) return '';
  final l10n = AppLocalizations.of(context);
  final names = typists.map((u) => u.displayName).toList();
  if (names.length == 1) return l10n.typingIndicatorOnePersonTyping(names[0]);
  if (names.length == 2) {
    return l10n.typingIndicatorTwoPeopleTyping(names[0], names[1]);
  }
  return l10n.typingIndicatorManyPeopleTyping(
      '${names.length - 2}', names[0], names[1]);
}

/// Three dots that fade in sequence. Also lifts each dot slightly at the peak
/// so it reads as a bounce at the larger sizes used by the compact pill.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, required this.color, this.size = 3});

  final Color color;
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.size * 0.7;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((t * 3) - i).clamp(0.0, 1.0);
            final lift = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            final a = 0.3 + 0.7 * lift;
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : gap),
              child: Transform.translate(
                offset: Offset(0, -widget.size * 0.5 * lift),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: a),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Overlapping avatars for everyone currently typing, newest-first, capped so
/// a busy room doesn't push the row off screen.
class _TypistAvatars extends StatelessWidget {
  const _TypistAvatars({required this.typists, required this.api});

  final List<ChatUser> typists;
  final ChatApi? api;

  /// The message row's own avatar size, so one person typing puts the dots
  /// exactly where that person's next bubble will appear. Extra typists
  /// overlap into the same slot and widen it from there.
  static const size = 28.0;

  static const _max = 3;

  /// Gap punched around a stacked avatar so it reads as separate from the one
  /// behind it. Taken OUT of the avatar rather than added around it: a border
  /// grows its box, and a 31px circle in a 28px slot got clipped square by the
  /// Stack — flat top and bottom on every face.
  static const _ring = 1.5;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final shown = typists.take(_max).toList();
    final overlap = size * 0.35;
    final stacked = shown.length > 1;
    // One typist needs no separator, and without it the avatar is pixel-for-
    // pixel the one on their messages.
    final inset = stacked ? _ring : 0.0;
    return SizedBox(
      width: size + (shown.length - 1) * (size - overlap),
      height: size,
      child: Stack(
        // UserAvatar paints a soft glow outside its own box; the default hard
        // edge would shave it off flat against the slot.
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                padding: EdgeInsets.all(inset),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Shows through the padding as a hairline ring, so stacked
                  // avatars separate instead of smearing into each other.
                  color: stacked ? theme.surface : null,
                ),
                child: Builder(builder: (context) {
                  // Ringed exactly like the face on this person's messages —
                  // the row is a message that hasn't arrived yet, so it should
                  // be recognisable as theirs before a word of it exists.
                  final ring = SpeakerScope.markOf(
                    context,
                    shown[i].id,
                    on: ThemeScope.of(context).background,
                  );
                  return UserAvatar(
                    user: shown[i],
                    size: size - inset * 2,
                    api: api,
                    showStatus: false,
                    ring: ring != null,
                    ringColor: ring,
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// The in-room indicator: a message row that hasn't arrived yet — the typist's
/// avatar, then three dots inside an incoming bubble. It is the newest row of
/// the transcript, so it lines up with the conversation above it and pushes it
/// up exactly like a real message would.
///
/// Renders nothing (and occupies no height) when nobody is typing, so it can
/// live permanently at the bottom of the list without a conditional item
/// count.
class TypingRow extends StatefulWidget {
  const TypingRow({
    super.key,
    required this.typists,
    this.api,
    this.showAvatars = true,
  });

  final List<ChatUser> typists;
  final ChatApi? api;

  /// False in DMs, matching the bubbles above: with one other person in the
  /// room, whose dots these are was never in question.
  final bool showAvatars;

  @override
  State<TypingRow> createState() => _TypingRowState();
}

class _TypingRowState extends State<TypingRow> {
  /// The last non-empty set of typists. Held so the row can keep rendering real
  /// avatars while it animates *out* — dropping straight to the live (now
  /// empty) list would blank them mid-fade.
  List<ChatUser> _last = const [];

  @override
  void didUpdateWidget(TypingRow old) {
    super.didUpdateWidget(old);
    if (widget.typists.isNotEmpty) _last = widget.typists;
  }

  @override
  void initState() {
    super.initState();
    _last = widget.typists;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final visible = widget.typists.isNotEmpty;
    final shown = visible ? widget.typists : _last;
    return IgnorePointer(
      // AnimatedSize collapses the reserved height once the fade-out finishes,
      // so an idle room gives the space back to the transcript without the row
      // popping out of existence.
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.4),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            onEnd: () {
              // Only release the retained set after the exit animation, and
              // only if nobody started typing again in the meantime.
              if (!visible && _last.isNotEmpty && mounted) {
                setState(() => _last = const []);
              }
            },
            child: shown.isEmpty
                ? const SizedBox(width: double.infinity, height: 0)
                : Padding(
                    // Matches MessageBubble's own vertical inset for an
                    // ungrouped row, so the dots sit off the last bubble by
                    // the same gap two messages sit off each other.
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      // The dots bubble is short enough that this rarely
                      // differs from centre, but it keeps the avatar sitting
                      // on the bubble's baseline the way a run's closing
                      // avatar does.
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.showAvatars) ...[
                          _TypistAvatars(typists: shown, api: widget.api),
                          const SizedBox(width: 8),
                        ],
                        Builder(builder: (context) {
                          // Only ONE typist gets the colour treatment. Two
                          // people share one bubble here, and washing it in the
                          // first one's colour would name the wrong person —
                          // worse than naming nobody.
                          final solo = shown.length == 1 ? shown.first.id : null;
                          final authored = theme.messageBubbleDecoration(
                              isMine: false, ephemeral: false);
                          final fill = authored.color;
                          final wash = fill == null
                              ? null
                              : SpeakerScope.washOf(context, solo,
                                  surface: fill);
                          final dots = SpeakerScope.markOf(context, solo,
                                  on: wash ?? fill ?? theme.surfaceRaised) ??
                              theme.inkSoft;
                          return Container(
                            // The incoming-bubble decoration itself, so the row
                            // inherits every theme's bubble treatment for free
                            // and reads as a message that hasn't landed yet.
                            decoration: theme.bubbleDecoration(
                              isMine: false,
                              ephemeral: false,
                              // A tail is right here: the dots are one incoming
                              // message that hasn't landed, not part of a run.
                              style: SettingsStore.instance.bubbleStyle,
                              fill: wash,
                              edge: wash == null
                                  ? null
                                  : SpeakerScope.markOf(context, solo,
                                      on: fill!),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: TypingDots(color: dots, size: 5),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The compact one-line form used on room cards and grid tiles, where the
/// typing row replaces the last-message preview.
class TypingLine extends StatelessWidget {
  const TypingLine({super.key, required this.typists, this.fontSize});

  final List<ChatUser> typists;

  /// The preview line's size, so typing replaces it without the line
  /// jumping; the theme's soft body size when null.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        TypingDots(color: theme.accent, size: 4),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            typingLabel(context, typists),
            // Upright, in the accent — the Telegram treatment. A slant
            // asked of a face with no italic cut is a synthetic skew, which
            // in a serif or a display face reads as a rendering fault.
            style: theme.bodySoft.copyWith(
              color: theme.accent,
              fontSize: fontSize,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
