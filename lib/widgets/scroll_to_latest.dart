import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'chat_composer.dart' show composerTrailingCenter;
import 'chrome_motion.dart';
import 'count_bump.dart';
import 'glass_pill.dart';
import 'hover_hint.dart';
import 'ios_kit.dart' show groupedMetaStyle;
import 'liquid_glass.dart';
import '../ui/native/native_control.dart';

/// Tracks whether a `reverse: true` transcript is scrolled away from its bottom.
///
/// Both chat surfaces render their list reversed, so `position.pixels` IS the
/// distance from the newest message — no arithmetic against `maxScrollExtent`
/// needed, and none of it changes when a page of older history is prepended.
///
/// Two thresholds, not one. With a single boundary the affordance flickers
/// whenever the reader parks on it, and an iOS rubber-band settle can cross it
/// several times in one gesture; [showAbove] / [hideBelow] make the state
/// sticky. [ValueNotifier] already suppresses a notification when the value is
/// unchanged, so the overwhelmingly common scroll frame costs one comparison
/// and rebuilds nothing.
class BottomProximity extends ValueNotifier<bool> {
  BottomProximity() : super(false);

  /// Distance from the bottom, in pixels, past which the affordance appears.
  /// About half a bubble: the button is small and out at the edge now, so it
  /// can come up as soon as the reader has scrolled at all, rather than only
  /// after a whole screen (it used to be 240).
  static const double showAbove = 48;

  /// …and within which it goes away again. Deliberately far below [showAbove];
  /// the band between the two is the sticky one. Both boundaries belong to the
  /// hidden side, so exactly [showAbove] is not yet shown and exactly
  /// [hideBelow] is already gone.
  static const double hideBelow = 12;

  void update(ScrollPosition position) => updateMetrics(
        pixels: position.pixels,
        maxScrollExtent: position.maxScrollExtent,
      );

  /// Split out from [update] so the hysteresis can be tested without pumping a
  /// widget tree.
  void updateMetrics({
    required double pixels,
    required double maxScrollExtent,
  }) {
    // A transcript that doesn't fill its viewport has no "away" to be. Also
    // covers the frame before the first layout, where both are zero.
    if (maxScrollExtent <= 0) {
      value = false;
      return;
    }
    // Overscrolling past the newest message reads as a negative offset on iOS.
    // It is emphatically "at the bottom", and must not trip `> showAbove`.
    if (value) {
      if (pixels <= hideBelow) value = false;
    } else {
      if (pixels > showAbove) value = true;
    }
  }
}

/// Scrolls a `reverse: true` transcript back to the newest message, cheaply.
///
/// A plain `animateTo(0)` from far up forces `ListView.builder` to lay out
/// every row in between, spread across the animation's frames — the further
/// you are the worse it drops. Teleporting to within a viewport-and-a-bit of
/// the bottom first means only that last stretch is ever built, so the motion
/// costs the same whether the reader was one screen up or a thousand.
///
/// Short hops (returning to the bottom right after a send) never hit the jump
/// branch and animate the whole way, as they should.
void scrollToLatest(
  ScrollController controller, {
  Duration duration = const Duration(milliseconds: 280),
  Curve curve = Curves.easeOutCubic,
}) {
  if (!controller.hasClients) return;
  final pos = controller.position;
  // Already there — or bouncing past it. Animating would fight the ballistic.
  if (pos.pixels <= 0) return;
  final cutoff = pos.viewportDimension * 1.2;
  if (pos.pixels > cutoff && cutoff < pos.maxScrollExtent) {
    controller.jumpTo(cutoff);
  }
  controller.animateTo(0, duration: duration, curve: curve);
}

/// Mounts [ScrollToLatestPill] only while it is visible or animating. See
/// [TransientPillSlot], which is the whole of it — this name stays because it
/// is what both transcripts ask for, and because "the scroll-to-latest slot"
/// says where in the layout it goes.
class ScrollToLatestSlot extends StatelessWidget {
  const ScrollToLatestSlot({
    super.key,
    required this.visible,
    required this.onTap,
    this.count = 0,
  });

  final bool visible;
  final VoidCallback onTap;

  /// Unread messages below the viewport. Zero shows the bare chevron.
  final int count;

  @override
  Widget build(BuildContext context) => TransientPillSlot(
        visible: visible,
        child: ScrollToLatestPill(onTap: onTap, count: count),
      );
}

/// Returns the reader to the newest message: a round glass button at the
/// transcript's right edge with a chevron, and the number of unread messages
/// waiting below riding its top edge — the iMessage / Telegram shape.
///
/// It used to be a centred capsule reading "Jump to latest". A word-label is
/// the wrong size for a fixture that sits over the transcript every time the
/// reader scrolls up: it covered the bubbles it was floating over, and a
/// round button by the thumb says the same thing in a glyph.
class ScrollToLatestPill extends StatelessWidget {
  const ScrollToLatestPill({super.key, required this.onTap, this.count = 0});

  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return ChatScrollFab(
      onTap: onTap,
      count: count,
      kick: GlyphKick.dip,
      kickOnIncrease: GlyphKick.dip,
      symbol: 'chevron.down',
      semanticLabel: l10n.reactionBubbleJumpToLatestSemanticLabel,
      glyph: Padding(
        // The chevron's ink sits high in its box; this centres it optically.
        padding: const EdgeInsets.only(top: 2),
        child: Icon(CupertinoIcons.chevron_down, size: 16, color: theme.ink),
      ),
    );
  }
}

/// The room's `@` button: jumps to the oldest mention of the reader they have
/// not yet seen, stacked above [ScrollToLatestPill]. Each tap goes to the next
/// one; a mention leaves the stack only once its bubble has been on screen.
/// Long-press clears the whole stack ([onClearAll]).
class MentionJumpButton extends StatelessWidget {
  const MentionJumpButton({
    super.key,
    required this.count,
    required this.onTap,
    this.onClearAll,
    this.capped = false,
  });

  final int count;
  final bool capped;
  final VoidCallback onTap;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return ChatScrollFab(
      onTap: onTap,
      onLongPress: onClearAll == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onClearAll!();
            },
      count: count,
      countCapped: capped,
      kick: GlyphKick.pop,
      // A new mention rocks the @ once: something addressed to you arrived.
      kickOnIncrease: GlyphKick.rock,
      symbol: 'at',
      accentSymbol: true,
      semanticLabel: l10n.roomScreenJumpToMentionSemanticLabel(count),
      glyph: Text(
        '@',
        // The theme's own body face, like every in-content badge
        // ([CountBadge]): on Paper it is a serif @, on a character theme
        // that theme's letter. Only tab-bar badges keep the system face.
        style: theme.body.copyWith(
          fontSize: 17,
          height: 1,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: theme.accent,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// The round glass button both scroll affordances are made of: a 40pt
/// [LiquidGlass] disc with a glyph, and an optional count capsule centred on
/// its top edge. One widget so the `@` and the chevron can never drift apart.
/// How far in from the transcript's right edge the scroll buttons' column
/// sits, so each disc is centred on the composer's trailing button below it.
double scrollFabRightInset({required bool classic}) =>
    composerTrailingCenter(classic: classic) - ChatScrollFab.size / 2;

class ChatScrollFab extends StatefulWidget {
  const ChatScrollFab({
    super.key,
    required this.glyph,
    required this.onTap,
    required this.semanticLabel,
    this.onLongPress,
    this.count = 0,
    this.countCapped = false,
    this.quietCount = false,
    this.kick = GlyphKick.pop,
    this.kickOnIncrease,
    this.symbol,
    this.accentSymbol = false,
  });

  /// The SF Symbol of [glyph], for native controls: with it the disc is a
  /// native glass button (its count drawn natively too, its kicks the
  /// symbol's own bounce); without it, the Flutter disc everywhere.
  final String? symbol;

  /// The symbol in the accent (the `@`), not the label colour.
  final bool accentSymbol;

  /// Edge of the disc. Well under the composer's 44pt buttons: this floats
  /// over content rather than sitting in a bar, and should yield to it. The
  /// hosts centre it on the composer's trailing button (see
  /// [composerTrailingCenter]) so the column reads as one line of controls.
  static const double size = 34;

  final Widget glyph;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String semanticLabel;
  final int count;

  /// The count stopped at the server's cap: render it as "N+".
  final bool countCapped;

  /// A neutral capsule instead of the accent one, for a number that is
  /// information rather than something waiting for the reader (how deep the
  /// jump-back trail goes).
  final bool quietCount;

  /// The glyph's nudge when tapped — what the button does, in one move.
  final GlyphKick kick;

  /// The glyph's nudge when [count] goes UP (a new unread, a new mention),
  /// so a change the reader did not cause still catches the eye once. Null
  /// keeps it still.
  final GlyphKick? kickOnIncrease;

  @override
  State<ChatScrollFab> createState() => _ChatScrollFabState();
}

class _ChatScrollFabState extends State<ChatScrollFab> {
  int _taps = 0;
  int _rises = 0;

  @override
  void didUpdateWidget(ChatScrollFab old) {
    super.didUpdateWidget(old);
    if (widget.kickOnIncrease != null && widget.count > old.count) _rises++;
  }

  void _tap() {
    setState(() => _taps++);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    const size = ChatScrollFab.size;
    // The tap's kick and the arrival's kick are separate glyph layers so each
    // keeps its own character and neither cancels the other mid-move.
    Widget glyph = KickGlyph(
      kick: widget.kick,
      trigger: _taps,
      child: widget.glyph,
    );
    final rise = widget.kickOnIncrease;
    if (rise != null) {
      glyph = KickGlyph(kick: rise, trigger: _rises, child: glyph);
    }
    Widget disc = LiquidGlass(
      size: const Size(size, size),
      onTap: _tap,
      semanticLabel: widget.semanticLabel,
      child: Center(child: glyph),
    );
    final symbol = widget.symbol;
    if (symbol != null && NativeControl.readyIn(context)) {
      return _native(context, symbol, disc);
    }
    final longPress = widget.onLongPress;
    if (longPress != null) {
      disc = GestureDetector(onLongPress: longPress, child: disc);
    }
    return HoverHint(
      label: widget.semanticLabel,
      child: SizedBox(
        width: size,
        // Room above the disc for the capsule's top half, so the badge
        // straddles the disc's top edge while staying inside this widget's
        // bounds (and its hit area) rather than hanging off it.
        height: size + 9,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            disc,
            if (widget.count > 0)
              Positioned(
                top: 0,
                child: IgnorePointer(
                  // Pops on every change, like the room list's badges.
                  child: CountBump(
                    count: widget.count,
                    child: _FabCount(
                      count: widget.count,
                      capped: widget.countCapped,
                      quiet: widget.quietCount,
                      theme: theme,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension on _ChatScrollFabState {
  /// The disc as native glass. Its count straddles the top edge natively
  /// (a Flutter badge would sit under the native view), and taps go to the
  /// native button, with its own press, unless there is a long-press (the
  /// `@` button's clear-all): then the disc only draws and Flutter keeps
  /// both gestures.
  Widget _native(BuildContext context, String symbol, Widget flutterDisc) {
    const size = ChatScrollFab.size;
    final theme = ThemeScope.of(context);
    final count = widget.count;
    final digits = count <= 0
        ? null
        : (count > 99 ? '99+' : (widget.countCapped ? '$count+' : '$count'));
    final longPress = widget.onLongPress;
    Widget control = NativeControl(
      size: const Size(size, size),
      // The Flutter disc and its count, for a moment the native one cannot
      // show (covered, mid-fade).
      standIn: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          flutterDisc,
          if (digits != null)
            Positioned(
              top: -9,
              child: _FabCount(
                count: count,
                capped: widget.countCapped,
                quiet: widget.quietCount,
                theme: theme,
              ),
            ),
        ],
      ),
      spec: NativeSpec.symbolButton(
        symbol: symbol,
        label: widget.semanticLabel,
        size: size,
        symbolSize: 15,
        badge: digits,
        badgeQuiet: widget.quietCount,
        kickTick: _taps + _rises,
        accentSymbol: widget.accentSymbol,
        passthrough: longPress != null,
      ),
      onEvent: (event, _) {
        if (event == 'tap') _tap();
      },
    );
    if (longPress != null) {
      control = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        onLongPress: longPress,
        child: control,
      );
    }
    return HoverHint(
      label: widget.semanticLabel,
      // Same footprint as the Flutter disc: room above for the count.
      child: SizedBox(
        width: size,
        height: size + 9,
        child: Align(alignment: Alignment.bottomCenter, child: control),
      ),
    );
  }
}

class _FabCount extends StatelessWidget {
  const _FabCount({
    required this.count,
    required this.capped,
    required this.quiet,
    required this.theme,
  });

  final int count;
  final bool capped;
  final bool quiet;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final digits = count > 99 ? '99+' : (capped ? '$count+' : '$count');
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4.5),
      decoration: BoxDecoration(
        color: quiet ? theme.surfaceRaised : theme.accent,
        borderRadius: BorderRadius.circular(999),
        // Lifted off the glass by a soft shadow rather than a ring of the page
        // colour: a ring is a flat fill, and over a picture or gradient
        // background (Retro Wave's sunset, a starfield) it drew a mismatched
        // circle. A shadow reads the same over anything.
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.30),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          digits,
          // The badge token on the theme's body face with tabular digits —
          // the same rule as [CountBadge], at the size this capsule allows.
          style: groupedMetaStyle(theme).copyWith(
            fontSize: 10.5,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: quiet ? theme.ink : theme.accentInk,
            decoration: TextDecoration.none,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
