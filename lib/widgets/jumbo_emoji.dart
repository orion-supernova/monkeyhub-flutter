import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// The most emoji a message can carry and still be drawn big.
///
/// Three is the line every messenger that does this draws, and it is not
/// arbitrary: at four the glyphs have to shrink far enough that they stop
/// reading as a gesture and start reading as small text without a bubble —
/// which is worse than the bubble they gave up.
const int kJumboEmojiMax = 3;

/// The emoji in [text] when the message is *nothing but* emoji — at most
/// [kJumboEmojiMax] of them — and null for everything else.
///
/// Whitespace between the emoji is allowed and dropped; a single other
/// character anywhere disqualifies the whole message, because "🎉 nice" is a
/// sentence and wants a sentence's bubble.
///
/// One grapheme cluster is one emoji, so a family (👨‍👩‍👧‍👦), a flag (🇹🇷), a
/// keycap (1️⃣) and a skin-toned hand (👍🏽) each count once no matter how many
/// code points they are built from.
List<String>? jumboEmojiRun(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  // A cheap ceiling before touching the grapheme splitter. Three of the
  // longest RGI sequences (a tag-sequence flag is 14 code units) plus their
  // separators fit inside this; anything longer cannot be three emoji and is
  // not worth segmenting to find out.
  if (trimmed.length > 64) return null;
  final run = <String>[];
  for (final cluster in trimmed.characters) {
    if (cluster.trim().isEmpty) continue;
    if (!_isEmojiCluster(cluster)) return null;
    run.add(cluster);
    if (run.length > kJumboEmojiMax) return null;
  }
  return run.isEmpty ? null : run;
}

/// Whether [cluster] — one grapheme cluster — is an emoji.
bool _isEmojiCluster(String cluster) {
  final runes = cluster.runes.toList(growable: false);
  if (runes.isEmpty) return false;
  final base = runes.first;
  // Keycaps are the one emoji whose base is an ordinary ASCII character; the
  // enclosing mark at the end is what makes 1️⃣ an emoji and `1` a digit.
  if (runes.length > 1 && runes.last == 0x20E3) {
    return base == 0x23 || base == 0x2A || (base >= 0x30 && base <= 0x39);
  }
  if (_hasEmojiPresentation(base)) return true;
  // Everything else pictographic defaults to a TEXT face — ©, ™, ☺, ✈ — and
  // only becomes an emoji when the sender's keyboard asked for the colour one
  // with U+FE0F. Without this clause a lone "©" would render an inch tall.
  if (_isPictograph(base)) {
    return runes.contains(0xFE0F) || _bareEmoji.contains(base);
  }
  return false;
}

/// Text-default pictographs common enough that people type them bare — from a
/// hardware keyboard, or pasted out of somewhere that stripped the variation
/// selector — and that nobody has ever meant as typography.
const Set<int> _bareEmoji = {
  0x2764, // ❤
  0x2665, // ♥
};

/// The blocks that hold every Extended_Pictographic character. Deliberately
/// coarse: membership here only *permits* [_isEmojiCluster] to look for a
/// U+FE0F, it never decides on its own.
bool _isPictograph(int cp) {
  if (cp == 0xA9 || cp == 0xAE) return true;
  if (cp == 0x203C || cp == 0x2049) return true;
  if (cp == 0x2122 || cp == 0x2139) return true;
  if (cp >= 0x2194 && cp <= 0x21AA) return true;
  if (cp >= 0x231A && cp <= 0x23FA) return true;
  if (cp == 0x24C2) return true;
  if (cp >= 0x25AA && cp <= 0x25FE) return true;
  if (cp >= 0x2600 && cp <= 0x27BF) return true;
  if (cp >= 0x2934 && cp <= 0x2935) return true;
  if (cp >= 0x2B00 && cp <= 0x2BFF) return true;
  if (cp == 0x3030 || cp == 0x303D) return true;
  if (cp == 0x3297 || cp == 0x3299) return true;
  if (cp >= 0x1F000 && cp <= 0x1FAFF) return true;
  return false;
}

/// Unicode's Emoji_Presentation=Yes set, as sorted `[lo, hi]` pairs: the code
/// points that are drawn in colour with no variation selector at all. This is
/// the half of the emoji question that can be answered from the base rune
/// alone, which is why it is a table rather than a heuristic.
///
/// Sorted and non-overlapping, so [_hasEmojiPresentation] can binary-search it.
const List<int> _emojiPresentation = [
  0x231A, 0x231B, 0x23E9, 0x23EC, 0x23F0, 0x23F0, 0x23F3, 0x23F3, //
  0x25FD, 0x25FE, 0x2614, 0x2615, 0x2648, 0x2653, 0x267F, 0x267F, //
  0x2693, 0x2693, 0x26A1, 0x26A1, 0x26AA, 0x26AB, 0x26BD, 0x26BE, //
  0x26C4, 0x26C5, 0x26CE, 0x26CE, 0x26D4, 0x26D4, 0x26EA, 0x26EA, //
  0x26F2, 0x26F3, 0x26F5, 0x26F5, 0x26FA, 0x26FA, 0x26FD, 0x26FD, //
  0x2705, 0x2705, 0x270A, 0x270B, 0x2728, 0x2728, 0x274C, 0x274C, //
  0x274E, 0x274E, 0x2753, 0x2755, 0x2757, 0x2757, 0x2795, 0x2797, //
  0x27B0, 0x27B0, 0x27BF, 0x27BF, 0x2B1B, 0x2B1C, 0x2B50, 0x2B50, //
  0x2B55, 0x2B55, 0x1F004, 0x1F004, 0x1F0CF, 0x1F0CF, 0x1F18E, 0x1F18E, //
  0x1F191, 0x1F19A, 0x1F1E6, 0x1F1FF, 0x1F201, 0x1F201, 0x1F21A, 0x1F21A, //
  0x1F22F, 0x1F22F, 0x1F232, 0x1F236, 0x1F238, 0x1F23A, 0x1F250, 0x1F251, //
  0x1F300, 0x1F320, 0x1F32D, 0x1F335, 0x1F337, 0x1F37C, 0x1F37E, 0x1F393, //
  0x1F3A0, 0x1F3CA, 0x1F3CF, 0x1F3D3, 0x1F3E0, 0x1F3F0, 0x1F3F4, 0x1F3F4, //
  0x1F3F8, 0x1F43E, 0x1F440, 0x1F440, 0x1F442, 0x1F4FC, 0x1F4FF, 0x1F53D, //
  0x1F54B, 0x1F54E, 0x1F550, 0x1F567, 0x1F57A, 0x1F57A, 0x1F595, 0x1F596, //
  0x1F5A4, 0x1F5A4, 0x1F5FB, 0x1F64F, 0x1F680, 0x1F6C5, 0x1F6CC, 0x1F6CC, //
  0x1F6D0, 0x1F6D2, 0x1F6D5, 0x1F6D7, 0x1F6DC, 0x1F6DF, 0x1F6EB, 0x1F6EC, //
  0x1F6F4, 0x1F6FC, 0x1F7E0, 0x1F7EB, 0x1F7F0, 0x1F7F0, 0x1F90C, 0x1F93A, //
  0x1F93C, 0x1F945, 0x1F947, 0x1F9FF, 0x1FA70, 0x1FA7C, 0x1FA80, 0x1FA89, //
  0x1FA8F, 0x1FAC6, 0x1FACE, 0x1FADC, 0x1FADF, 0x1FAE9, 0x1FAF0, 0x1FAF8, //
];

bool _hasEmojiPresentation(int cp) {
  var lo = 0;
  var hi = _emojiPresentation.length ~/ 2 - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (cp < _emojiPresentation[mid * 2]) {
      hi = mid - 1;
    } else if (cp > _emojiPresentation[mid * 2 + 1]) {
      lo = mid + 1;
    } else {
      return true;
    }
  }
  return false;
}

/// Every heart in Unicode's emoji set, by base code point.
///
/// The base is enough: a heart is never a ZWJ sequence and never takes a skin
/// tone, so ❤️ and ❤ and 💗 all reduce to one rune each.
const Set<int> _hearts = {
  0x2764, // ❤
  0x2665, // ♥
  0x1F493, // 💓
  0x1F494, // 💔
  0x1F495, // 💕
  0x1F496, // 💖
  0x1F497, // 💗
  0x1F498, // 💘
  0x1F499, // 💙
  0x1F49A, // 💚
  0x1F49B, // 💛
  0x1F49C, // 💜
  0x1F49D, // 💝
  0x1F49E, // 💞
  0x1F49F, // 💟
  0x1F5A4, // 🖤
  0x1F90D, // 🤍
  0x1F90E, // 🤎
  0x1F9E1, // 🧡
};

/// Whether [cluster] is one of the hearts that earns the extra flourish.
bool isHeartEmoji(String cluster) =>
    cluster.isNotEmpty && _hearts.contains(cluster.runes.first);

/// A message that is nothing but emoji, drawn big and bare.
///
/// No bubble. The whole point of the treatment is that a lone 🎉 is a
/// *gesture*, not a sentence, and a fill with a tail around it insists on the
/// opposite; alignment in the row already says who sent it, exactly as it does
/// for the photo tiles, which gave up their bubble for the same reason.
///
/// The timestamp moves out to the row underneath — see `messageStampsInline`,
/// which reads the same condition — because there is no longer any surface to
/// tuck one into. A lozenge floating beside a transparent glyph would read as a
/// detached label, which is the same answer the round video note reached.
///
/// The entrance plays once per message rather than on every build: a
/// transcript recycles rows as it scrolls, so an animation tied to the widget's
/// lifetime would fire again every time the reader passed the same message.
/// [identity] is what "the same message" means — the client id where there is
/// one, because an optimistic send changes `id` the moment the server confirms
/// it, and without that the sender would watch their own emoji pop twice.
class JumboEmojiBubble extends StatefulWidget {
  const JumboEmojiBubble({
    super.key,
    required this.identity,
    required this.clusters,
    required this.isMine,
  });

  /// Stable across an optimistic send's id swap. See the class doc.
  final String identity;

  /// 1..[kJumboEmojiMax] grapheme clusters, from [jumboEmojiRun].
  final List<String> clusters;

  final bool isMine;

  /// Point size per emoji count, indexed by `count - 1`.
  ///
  /// Three glyphs have to fit the bubble's max width on the narrowest phone
  /// alongside the gutter the tail would have taken, which is what sets the
  /// bottom of the ladder; one glyph gets to be as big as a reaction to a
  /// photo, which is what the treatment is imitating.
  static const List<double> _glyphSizes = [56, 46, 38];

  static double glyphSize(int count) =>
      _glyphSizes[count.clamp(1, kJumboEmojiMax) - 1];

  @override
  State<JumboEmojiBubble> createState() => _JumboEmojiBubbleState();
}

class _JumboEmojiBubbleState extends State<JumboEmojiBubble>
    with SingleTickerProviderStateMixin {
  /// Messages whose entrance has already been spent. Bounded rather than
  /// unbounded because a long-lived session scrolling a busy room would
  /// otherwise accumulate one string per emoji message forever; dropping the
  /// whole set at the ceiling costs, at worst, one replayed pop.
  static final Set<String> _played = <String>{};
  static const int _playedCeiling = 512;

  /// The pop, and then — hearts only — the flourish, back to back on one
  /// controller so there is a single ticker per bubble.
  static const int _popMs = 460;
  static const int _flourishMs = 1500;

  late final bool _hearted = widget.clusters.any(isHeartEmoji);
  late final int _totalMs = _popMs + (_hearted ? _flourishMs : 0);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs),
  );

  /// Built in [didChangeDependencies] and handed to the [AnimatedBuilder]
  /// untouched, so a frame of animation re-wraps them in transforms without
  /// re-laying-out a single paragraph. Rebuilt only when the theme changes,
  /// which is the one thing their style depends on.
  late List<Widget> _glyphs;

  /// The gap between two clusters. Emoji already carry generous side bearings,
  /// so this only has to keep two round faces from touching.
  static const double _gap = 4;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = ThemeScope.of(context);
    final size = JumboEmojiBubble.glyphSize(widget.clusters.length);
    _glyphs = [
      for (final cluster in widget.clusters)
        Text(
          cluster,
          textAlign: TextAlign.center,
          // Derived from the theme's own body style rather than a bare
          // `TextStyle`, and with both the colour and the decoration stated
          // outright: a bubble is also lifted into the action-menu overlay,
          // where an inherited style is not guaranteed to be a real one, and
          // the fallback Flutter substitutes there is red monospace under a
          // double yellow rule.
          style: theme.body.copyWith(
            fontSize: size,
            // Emoji sit on a very tall default line box. Tightening it is what
            // keeps the row's vertical rhythm from lurching around a message
            // that is otherwise the height of two lines of text.
            height: 1.12,
            color: theme.ink,
            decoration: TextDecoration.none,
          ),
        ),
    ];
    // `MotionScope` is read here rather than in initState for the same reason
    // the style is: it depends on MediaQuery, and a reader who flips Reduce
    // Motion mid-session should stop getting entrances without leaving the
    // room.
    if (MotionScope.of(context).calm) {
      _c.value = 1;
      _played.add(widget.identity);
      return;
    }
    if (_c.isAnimating || _c.value > 0) return;
    if (_played.contains(widget.identity)) {
      _c.value = 1;
      return;
    }
    if (_played.length >= _playedCeiling) _played.clear();
    _played.add(widget.identity);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Where the pop ends and the flourish begins, as a fraction of [_c].
  double get _popSpan => _popMs / _totalMs;

  double get _popT => (_c.value / _popSpan).clamp(0.0, 1.0);

  double get _flourishT => _hearted
      ? ((_c.value - _popSpan) / (1 - _popSpan)).clamp(0.0, 1.0)
      : 0.0;

  /// Two quick bumps — the second softer than the first, the way a heartbeat
  /// actually reads — over the first third of the flourish.
  static double _beat(double u) {
    double bump(double centre, double width, double height) {
      final d = (u - centre) / width;
      return height * math.exp(-d * d);
    }

    return bump(0.10, 0.055, 1.0) + bump(0.27, 0.070, 0.62);
  }

  /// A tap replays it. Deliberately a [Listener] and not a tap recognizer:
  /// the bubble above this one already runs a long-press (the action menu) and
  /// a double-tap (react) in its own arena, and a recognizer down here would
  /// win that arena on the first tap up and swallow the react gesture. A
  /// pointer listener never enters the arena at all, so both still work and a
  /// double-tap now both reacts *and* replays — which is the right answer
  /// anyway.
  Offset? _down;
  int _downMs = 0;

  void _onDown(PointerDownEvent e) {
    _down = e.position;
    _downMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _onUp(PointerUpEvent e) {
    final down = _down;
    _down = null;
    if (down == null) return;
    // A drag is a scroll, and a hold is the action menu opening over the top
    // of this — neither is a request to see the animation again.
    if ((e.position - down).distance > kTouchSlop) return;
    if (DateTime.now().millisecondsSinceEpoch - _downMs >= 400) return;
    if (MotionScope.of(context).calm) return;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final count = widget.clusters.length;
    final size = JumboEmojiBubble.glyphSize(count);
    return Listener(
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: (_) => _down = null,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        // Breathing room on the sides only. The row's own vertical rhythm
        // (MessageGap) already brackets this, and the tightened line height
        // above leaves the glyph very little slack of its own.
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _frame(theme, size, count),
        ),
      ),
    );
  }

  Widget _frame(AppTheme theme, double size, int count) {
    final pop = _popT;
    final flourish = _flourishT;
    final beat = flourish > 0 ? _beat(flourish) : 0.0;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Transform.scale(
            // The stagger lives in the curve's input, not in a delay: each
            // glyph runs the same arc a beat later than the one before it, and
            // the last one still lands inside the pop's own window.
            scale: _entrance(pop, i, count) *
                (isHeartEmoji(widget.clusters[i]) ? 1 + 0.16 * beat : 1.0),
            child: Opacity(
              opacity: (pop * 2.6).clamp(0.0, 1.0),
              child: _glyphs[i],
            ),
          ),
        ],
      ],
    );

    if (!_hearted || flourish <= 0 || flourish >= 1) return row;

    // Painted behind the glyphs and allowed to overflow upward, which is where
    // the whole effect lives. `Clip.none` on the Stack is what permits it; no
    // ancestor between here and the transcript's own viewport clips.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -14,
          right: -14,
          bottom: 0,
          top: -_riseHeight,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HeartFlourish(
                  t: flourish,
                  colors: [
                    for (final c in widget.clusters)
                      if (isHeartEmoji(c)) heartTint(c, theme),
                  ],
                  glyph: size,
                  seed: widget.identity.hashCode,
                ),
              ),
            ),
          ),
        ),
        row,
      ],
    );
  }

  /// How far above the glyph the motes are allowed to climb.
  static const double _riseHeight = 64;

  /// A single overshooting arc per glyph, offset by [i].
  static double _entrance(double pop, int i, int count) {
    if (pop >= 1) return 1;
    const stagger = 0.16;
    final u = ((pop - i * stagger) / (1 - (count - 1) * stagger))
        .clamp(0.0, 1.0);
    return 0.32 + 0.68 * Curves.easeOutBack.transform(u);
  }
}

/// The hue to draw a heart's motes in — the glyph's own colour, so a 💙 rains
/// blue and a 🖤 rains something that can still be seen against the theme.
Color heartTint(String cluster, AppTheme theme) {
  switch (cluster.runes.first) {
    case 0x1F9E1: // 🧡
      return const Color(0xFFF5871F);
    case 0x1F49B: // 💛
      return const Color(0xFFF5C518);
    case 0x1F49A: // 💚
      return const Color(0xFF3FB950);
    case 0x1F499: // 💙
      return const Color(0xFF3D8BFD);
    case 0x1F49C: // 💜
    case 0x1F49F: // 💟
      return const Color(0xFF9E6BFF);
    case 0x1F5A4: // 🖤
      // Not black: the motes are drawn ON the transcript's ground, which on a
      // dark theme is already near black. This is "a black heart's colour, as
      // dark as it can be and still be a mote", not the glyph's fill.
      return theme.ink;
    case 0x1F90D: // 🤍
      return const Color(0xFFE8E8EC);
    case 0x1F90E: // 🤎
      return const Color(0xFF9C6644);
    case 0x1F495: // 💕
    case 0x1F496: // 💖
    case 0x1F497: // 💗
    case 0x1F49D: // 💝
      return const Color(0xFFFF6FA5);
    default: // ❤ ♥ 💓 💔 💘 💞
      return const Color(0xFFF2385A);
  }
}

/// Small hearts drifting up off a jumbo heart, plus one ring on the first beat.
///
/// Vector paths rather than more copies of the emoji: a glyph would need a
/// `saveLayer` per mote to fade, and at this size the silhouette is the whole
/// read anyway — the colour comes from [heartTint].
class _HeartFlourish extends CustomPainter {
  const _HeartFlourish({
    required this.t,
    required this.colors,
    required this.glyph,
    required this.seed,
  });

  /// 0..1 across the flourish.
  final double t;

  /// One per heart in the message; motes cycle through them.
  final List<Color> colors;

  /// The emoji's point size, which sets the motes' and the ring's scale.
  final double glyph;

  /// Deterministic jitter, so a message looks the same on every replay and
  /// two messages side by side do not.
  final int seed;

  static const int _count = 9;

  /// Fraction of [t] one mote is alive for. The launches are spread across the
  /// remainder, so the last one is still climbing as the flourish ends.
  static const double _life = 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;
    final rnd = math.Random(seed);
    final ring = _ringT();
    if (ring > 0) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - ring)
        ..color = colors.first
            .withValues(alpha: 0.34 * (1 - ring) * (1 - ring));
      canvas.drawCircle(
        Offset(size.width / 2, size.height - glyph * 0.5),
        glyph * (0.42 + 0.75 * ring),
        p,
      );
    }

    final launchSpread = 1 - _life;
    for (var i = 0; i < _count; i++) {
      // Drawn before the early-out so the sequence advances identically on
      // every frame — otherwise a mote's jitter would change as its
      // neighbours came and went.
      final jx = rnd.nextDouble();
      final jsize = rnd.nextDouble();
      final jsway = rnd.nextDouble();
      final u = (t - (i / _count) * launchSpread) / _life;
      if (u <= 0 || u >= 1) continue;

      final arc = math.sin(u * math.pi);
      final x = size.width * (0.18 + 0.64 * jx) +
          math.sin((u * 2.1 + jsway * 6.28)) * glyph * 0.22;
      final y = size.height - glyph * 0.35 - u * (size.height - glyph * 0.2);
      final s = glyph * (0.16 + 0.13 * jsize) * (0.55 + 0.45 * arc);

      final paint = Paint()
        ..color = colors[i % colors.length]
            .withValues(alpha: (0.85 * arc).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      // A slow tumble, tied to the sway so a mote that drifts left leans left.
      canvas.rotate(math.sin(u * 2.4 + jsway * 6.28) * 0.35);
      canvas.drawPath(_heart(s), paint);
      canvas.restore();
    }
  }

  /// 0 outside the ring's window, 0..1 across it.
  double _ringT() {
    const end = 0.30;
    if (t <= 0 || t >= end) return 0;
    return t / end;
  }

  /// A heart of width and height [s], centred on the origin.
  static Path _heart(double s) {
    final p = Path()..moveTo(0, s * 0.36);
    p.cubicTo(-s * 0.56, -s * 0.06, -s * 0.50, -s * 0.46, 0, -s * 0.18);
    p.cubicTo(s * 0.50, -s * 0.46, s * 0.56, -s * 0.06, 0, s * 0.36);
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(_HeartFlourish old) =>
      old.t != t || old.glyph != glyph || old.seed != seed;
}
