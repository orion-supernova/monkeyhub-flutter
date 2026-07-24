import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';
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
String typingLabel(List<ChatUser> typists) {
  if (typists.isEmpty) return '';
  final names = typists.map((u) => u.displayName).toList();
  if (names.length == 1) return '${names[0]} is typing';
  if (names.length == 2) return '${names[0]} and ${names[1]} are typing';
  return '${names[0]}, ${names[1]} +${names.length - 2} are typing';
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
/// a busy room doesn't push the label off screen.
class _TypistAvatars extends StatelessWidget {
  const _TypistAvatars({required this.typists, required this.api});

  final List<ChatUser> typists;
  final ChatApi? api;

  static const size = 20.0;

  static const _max = 3;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final shown = typists.take(_max).toList();
    final overlap = size * 0.35;
    return SizedBox(
      width: size + (shown.length - 1) * (size - overlap),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // A hairline ring in the surface colour separates stacked
                  // avatars from each other rather than letting them smear.
                  border: Border.all(color: theme.surface, width: 1.5),
                ),
                child: UserAvatar(
                  user: shown[i],
                  size: size,
                  api: api,
                  showStatus: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The compact-design in-room indicator: a frosted capsule that floats just
/// above the composer, showing who's typing with stacked avatars and dots.
///
/// Renders nothing (and occupies no height) when nobody is typing, so it can
/// be dropped straight into the compact chrome column without disturbing the
/// message list's padding — it hovers over the conversation the same way
/// `_FloatingDateChip` does.
class TypingPill extends StatefulWidget {
  const TypingPill({super.key, required this.typists, this.api});

  final List<ChatUser> typists;
  final ChatApi? api;

  @override
  State<TypingPill> createState() => _TypingPillState();
}

class _TypingPillState extends State<TypingPill> {
  /// The last non-empty set of typists. Held so the pill can keep rendering
  /// real names and avatars while it animates *out* — dropping straight to the
  /// live (now empty) list would blank the text mid-fade.
  List<ChatUser> _last = const [];

  @override
  void didUpdateWidget(TypingPill old) {
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
      // so an idle room gives the composer back its space without the pill
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
                    // 16 matches the compact composer's own inset rather than
                    // the transcript's 20: the pill floats directly above the
                    // composer, so a stagger against the capsule 8px below it
                    // reads louder than a 4px offset from bubbles further up.
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // The capsule hugs its row, so it is normally just wide
                      // enough for "mom is typing…". The cap only bites when a
                      // busy room produces a long label: it then ellipsizes at
                      // the same width a message bubble would, instead of
                      // running the full width of a desktop chat column.
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: messageMaxWidth(context)),
                        child: LiquidGlass(
                          shape: LiquidGlassShape.capsule,
                          // Tight on the avatar side (a circle needs no help
                          // from the stadium cap), roomier past the dots so
                          // they don't crowd the curve.
                          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TypistAvatars(typists: shown, api: widget.api),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  typingLabel(shown),
                                  // Status, not content — reads as chrome
                                  // beside the messages it sits over.
                                  style: theme.monoTiny
                                      .copyWith(color: theme.inkSoft),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 4 to match TypingLine, and proportionate to
                              // monoTiny — at 5 the dots outweighed the label.
                              TypingDots(color: theme.accent, size: 4),
                            ],
                          ),
                        ),
                      ),
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
  const TypingLine({super.key, required this.typists});

  final List<ChatUser> typists;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        TypingDots(color: theme.accent, size: 4),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            typingLabel(typists),
            style: theme.bodySoft
                .copyWith(color: theme.accent, fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
