import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialLocalizations;

import '../data/settings_store.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'chrome_motion.dart';
import 'glass_reveal.dart';
import 'liquid_glass.dart';
import 'spring_press.dart';

/// The card over the composer that says what the next send is ABOUT —
/// replying to a message, or editing one. One shell for both, so the two
/// cannot drift into different shapes again (they had: two copies of the
/// same hand-built strip, each with its own colours).
///
/// Made of the composer's own material: glass in the floating style, the
/// raised plate in classic. A [ContextRail] in [tone] on the leading edge,
/// a glyph, a title and a line, an optional thumbnail, and a drawn ×.
///
/// Motion, in order: the card rises 8pt and fades in, the rail draws itself
/// in from the middle, the glyph gives one [kick]; retargeting to another
/// message ([contentKey] changes) slides the old title/line up and out and
/// the new one in, and kicks the glyph again.
class ComposerContextCard extends StatefulWidget {
  const ComposerContextCard({
    super.key,
    required this.tone,
    required this.titleInk,
    required this.icon,
    required this.kick,
    required this.title,
    required this.line,
    required this.contentKey,
    required this.onCancel,
    this.thumb,
    this.kickAmplitude = 1,
  });

  /// The rail and the glyph: whose message this is about (the speaker's
  /// colour for a reply, the accent for your own edit).
  final Color tone;
  final Color titleInk;
  final IconData icon;
  final GlyphKick kick;
  final String title;
  final String line;

  /// What the card currently shows — the message id. A change slides the
  /// content rather than rebuilding the card.
  final Object contentKey;
  final VoidCallback onCancel;
  final Widget? thumb;

  /// Scales (and with a negative value, mirrors) the glyph's kick.
  final double kickAmplitude;

  @override
  State<ComposerContextCard> createState() => _ComposerContextCardState();
}

class _ComposerContextCardState extends State<ComposerContextCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  int _kicks = 0;

  @override
  void initState() {
    super.initState();
    _enter
      ..addListener(_kickOnSettle)
      ..forward();
  }

  /// The glyph's kick lands as the card settles, not under it — driven off
  /// the entrance itself so no timer can outlive the card.
  void _kickOnSettle() {
    if (_enter.value < 0.6) return;
    _enter.removeListener(_kickOnSettle);
    setState(() => _kicks++);
  }

  @override
  void didUpdateWidget(ComposerContextCard old) {
    super.didUpdateWidget(old);
    if (old.contentKey != widget.contentKey) _kicks++;
  }

  @override
  void dispose() {
    _enter.removeListener(_kickOnSettle);
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final glass = SettingsStore.instance.chatStyle != ChatStyle.classic;
    final calm = MotionScope.of(context).calm;
    if (calm && _enter.value < 1) {
      // Reduce Motion: in place at once, and no kick (the listener would
      // also setState mid-build).
      _enter
        ..removeListener(_kickOnSettle)
        ..value = 1;
    }

    final content = Row(
      children: [
        const SizedBox(width: 8),
        // A fixed height: the row centres its children, so a rail asked to
        // fill would be given none.
        SizedBox(
          height: 32,
          child: ContextRail(color: widget.tone, animateIn: true),
        ),
        const SizedBox(width: 10),
        KickGlyph(
          kick: widget.kick,
          trigger: _kicks,
          amplitude: widget.kickAmplitude,
          child: Icon(widget.icon, size: 16, color: widget.tone),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SlideSwap(
            child: Column(
              key: ValueKey(widget.contentKey),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // As written, never upper-cased (Turkish i), on the body face.
                Text(
                  widget.title,
                  style: theme.bodySoft.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.titleInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  widget.line,
                  style: theme.bodySoft.copyWith(
                    fontSize: 14,
                    color: theme.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        if (widget.thumb case final thumb?) ...[
          const SizedBox(width: 10),
          thumb,
        ],
        const SizedBox(width: 2),
        // THE press — a spring, a focus stop and a spoken name.
        SpringPress(
          onTap: widget.onCancel,
          haptic: false,
          semanticLabel: MaterialLocalizations.of(context).closeButtonLabel,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: DrawnCloseGlyph(color: theme.inkMuted, size: 11),
            ),
          ),
        ),
        const SizedBox(width: 2),
      ],
    );

    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: IntrinsicHeight(child: content),
    );

    final plate = glass
        ? LiquidGlass(
            shape: LiquidGlassShape.rounded,
            radius: 18,
            child: body,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: theme.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
            ),
            child: body,
          );

    return Padding(
      // The composer's own side insets, so the card's edges line up with the
      // field under it.
      padding: EdgeInsets.fromLTRB(glass ? 16 : 14, 6, glass ? 16 : 14, 0),
      child: AnimatedBuilder(
        animation: _enter,
        child: plate,
        builder: (_, child) {
          final t = Curves.easeOutCubic.transform(_enter.value);
          final lifted = Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          );
          // Glass is grown, never faded: a BackdropFilter in an opacity layer
          // blurs that layer's empty buffer and flashes flat (GlassReveal).
          return glass
              ? GlassReveal(
                  t: t,
                  from: 0.94,
                  alignment: Alignment.bottomCenter,
                  child: lifted,
                )
              : Opacity(opacity: t, child: lifted);
        },
      ),
    );
  }
}
