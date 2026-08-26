import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

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
  // This runs on every bubble build, for every message in the room, so the two
  // rejections below come before anything that allocates.
  //
  // A paragraph is not three emoji, and its length says so in constant time.
  // Generous, because the trim has not happened yet.
  if (text.length > 128) return null;
  // And the overwhelmingly common message is plain prose. No emoji is ASCII —
  // not even a keycap, whose U+20E3 puts it well out of the range — so a scan
  // of the code units rejects ordinary text without a trimmed copy or a
  // grapheme segmenter ever being allocated.
  var ascii = true;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) >= 0x80) {
      ascii = false;
      break;
    }
  }
  if (ascii) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  // The real ceiling, now that the whitespace is gone. Three of the longest
  // RGI sequences (a tag-sequence flag is 14 code units) plus their separators
  // fit inside this.
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
/// Three animations, and the difference between them is the whole design:
///
///  * **The entrance** — every emoji. A staggered overshooting pop.
///  * **The burst** — hearts only. Small hearts spray out of the glyph on the
///    first beat and fall away. This is an *arrival*, so it fires with the
///    entrance and is spent with it.
///  * **The heartbeat** — hearts only, and it never stops. A heart that beat
///    twice and then sat still reads as a rendering glitch; the charm is that
///    it keeps going, so it loops for as long as the message is on screen.
///    [TickerMode] pauses it whenever the room is not the visible route, so a
///    transcript left behind on the navigator stack costs nothing.
///
/// The entrance and the burst are spent once per *message* rather than once
/// per row: a transcript recycles rows as it scrolls, so an arrival tied to
/// the widget's lifetime would fire again every time the reader passed the
/// same message. [identity] is what "the same message" means — the client id
/// where there is one, because an optimistic send changes `id` the moment the
/// server confirms it, and without that the sender would watch their own emoji
/// pop twice. A tap replays both.
///
/// All three stop dead under Reduce Motion.
///
/// One consequence for tests: a heart message never settles, so
/// `pumpAndSettle` on one will time out. Pump a fixed span instead.
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
    with TickerProviderStateMixin {
  /// Messages whose arrival has already been spent. Bounded rather than
  /// unbounded because a long-lived session scrolling a busy room would
  /// otherwise accumulate one string per emoji message forever; dropping the
  /// whole set at the ceiling costs, at worst, one replayed pop.
  static final Set<String> _played = <String>{};
  static const int _playedCeiling = 512;

  static const int _popMs = 460;
  static const int _burstMs = 1250;

  /// One cycle of the heartbeat: two thumps and the rest after them.
  ///
  /// About 52 beats a minute — slower than a real resting pulse on purpose.
  /// This runs for as long as the message is on screen, and anything at a
  /// lifelike rate turns from alive into insistent inside ten seconds.
  static const Duration _beatDuration = Duration(milliseconds: 1150);

  /// Which clusters are hearts, resolved once: it is asked per glyph per
  /// frame, and it drives whether there is a second ticker at all.
  late final List<bool> _isHeart = [
    for (final c in widget.clusters) isHeartEmoji(c),
  ];
  late final bool _hearted = _isHeart.contains(true);

  /// The arrival: pop, then — hearts only — the burst, back to back on one
  /// controller so a replay re-runs both in step.
  late final int _introMs = _popMs + (_hearted ? _burstMs : 0);
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: Duration(milliseconds: _introMs));

  /// Hearts only, and only where motion is allowed — so a message with no
  /// heart in it has no second ticker, and a calm reader has neither.
  AnimationController? _pulse;

  /// The whole drawn subtree, assembled once and then left alone.
  ///
  /// This is the shape the performance depends on, so it is worth stating
  /// plainly. A beating heart asks the engine for a frame forever, so the cost
  /// of *one* of those frames is the only number that matters, and everything
  /// here exists to keep it near zero:
  ///
  ///  * the row, the glyph paragraphs and the burst layer are built once, so a
  ///    frame reconciles nothing and lays out nothing;
  ///  * each glyph sits behind its own [RepaintBoundary], so the transform that
  ///    animates it composites a cached raster instead of re-rasterising a
  ///    56pt colour glyph sixty times a second — which is the one thing here
  ///    that would genuinely have cost frames;
  ///  * only the glyphs that actually move listen to the beat, so the two
  ///    ordinary emoji beside a heart go completely still once they land;
  ///  * the burst's painter repaints off the arrival alone, so it stops being
  ///    visited at all once that controller does.
  ///
  /// What is left per frame is a handful of transform matrices handed to the
  /// compositor.
  late Widget _content;

  /// The gap between two clusters. Emoji already carry generous side bearings,
  /// so this only has to keep two round faces from touching.
  static const double _gap = 4;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = ThemeScope.of(context);
    final size = JumboEmojiBubble.glyphSize(widget.clusters.length);
    final glyphs = [
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
    // Motion mid-session should stop getting motion without leaving the room.
    if (MotionScope.of(context).calm) {
      _intro.value = 1;
      _pulse?.stop();
      _played.add(widget.identity);
    } else {
      _playArrivalIfUnspent();
      if (_hearted) {
        _pulse ??= AnimationController(vsync: this, duration: _beatDuration);
        if (!_pulse!.isAnimating) _startBeat();
      }
    }
    _content = _assemble(glyphs, size);
  }

  /// Wires [glyphs] to the controllers. Called once per dependency change, and
  /// never per frame — see [_content].
  Widget _assemble(List<Widget> glyphs, double size) {
    final count = glyphs.length;
    // A glyph that never moves after the entrance must not listen to the beat,
    // or an ordinary emoji standing next to a heart would rebuild forever for
    // a scale it is not using.
    final beating = <Listenable>[_intro, ?_pulse];
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          AnimatedBuilder(
            animation: _isHeart[i] && _pulse != null
                ? Listenable.merge(beating)
                : _intro,
            // Hoisted past the builder, and boundaried: the paragraph inside is
            // laid out once and rasterised once, and every frame after that is
            // the transform above it moving a finished layer.
            child: RepaintBoundary(child: glyphs[i]),
            builder: (context, child) {
              final pop = _popT;
              final beat = _isHeart[i] && _pulse != null
                  ? _beat(_pulse!.value)
                  : 0.0;
              return Opacity(
                // A no-op at 1, which is where this sits for all but the first
                // fifth of a second of the message's life.
                opacity: (pop * 2.6).clamp(0.0, 1.0),
                child: Transform.scale(
                  // The entrance and the beat multiply rather than one winning:
                  // a heart that arrives mid-thump should still arrive.
                  scale: _entrance(pop, i, count) * (1 + beat),
                  child: child,
                ),
              );
            },
          ),
        ],
      ],
    );
    if (!_hearted) return row;

    final tints = [
      for (var i = 0; i < count; i++)
        if (_isHeart[i]) MapEntry(i, heartTint(widget.clusters[i])),
    ];
    final reach = size * _reach;
    // Painted BEHIND the glyphs, and allowed to overflow the row — which is
    // where the effect lives. The motes emerge from behind the heart rather
    // than appearing on top of it, and `Clip.none` is what permits that; no
    // ancestor between here and the transcript's own viewport clips.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -reach,
          right: -reach,
          top: -reach,
          // Far less headroom below: the fan is aimed upward, and the only
          // thing under this row is its own timestamp.
          bottom: -size * 0.5,
          child: IgnorePointer(
            child: RepaintBoundary(
              // Driven by the arrival alone. Once that controller stops the
              // layer is clean forever, so the beat's frames skip this subtree
              // entirely instead of calling a painter that would only return.
              child: CustomPaint(
                painter: _HeartBurst(
                  arrival: _intro,
                  popSpan: _popSpan,
                  inset: reach,
                  glyph: size,
                  tints: tints,
                  count: count,
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

  /// Starts the loop on the phase that puts its next thump exactly where the
  /// burst leaves the glyph — so the hearts are thrown BY the beat rather than
  /// alongside it. Once the two clocks drift apart they stay apart, which is
  /// fine: the only beat that has to land on something is the first.
  void _startBeat() {
    final pulse = _pulse!;
    if (_intro.isAnimating) {
      final untilBurst = (1 - _intro.value) * _popSpan * _introMs;
      final phase = _thumpAt - untilBurst / _beatDuration.inMilliseconds;
      pulse.value = phase - phase.floorToDouble();
    } else {
      // Nothing to land on — this message arrived long ago and is only being
      // scrolled back into view. Offset it by its own identity instead, so
      // three hearts on screen at once beat like three hearts rather than like
      // a metronome driving all of them.
      pulse.value = (widget.identity.hashCode & 0x3FF) / 0x400;
    }
    pulse.repeat();
  }

  void _playArrivalIfUnspent() {
    if (_intro.isAnimating || _intro.value > 0) return;
    if (_played.contains(widget.identity)) {
      _intro.value = 1;
      return;
    }
    if (_played.length >= _playedCeiling) _played.clear();
    _played.add(widget.identity);
    _intro.forward();
  }

  @override
  void dispose() {
    _pulse?.dispose();
    _intro.dispose();
    super.dispose();
  }

  /// Where the pop ends and the burst begins, as a fraction of [_intro].
  double get _popSpan => _popMs / _introMs;

  double get _popT => (_intro.value / _popSpan).clamp(0.0, 1.0);

  /// How much bigger a heart is, [u] fractions of the way through one beat.
  ///
  /// Two thumps — the second softer and close behind the first, the way a
  /// heartbeat actually reads — and then a long rest, which is what makes it a
  /// heartbeat rather than a throb. Distance to a thump's centre is measured
  /// *around* the cycle, so the loop point is as smooth as the middle.
  /// Where in a cycle the loud thump sits. Shared by [_beat] and [_startBeat],
  /// which is the point — the phase maths and the curve have to name the same
  /// instant or the burst leaves on silence.
  static const double _thumpAt = 0.08;

  static double _beat(double u) {
    double thump(double centre, double width, double height) {
      var d = (u - centre).abs();
      if (d > 0.5) d = 1 - d;
      final z = d / width;
      return height * math.exp(-z * z);
    }

    final beat = thump(_thumpAt, 0.042, 0.13) + thump(0.23, 0.048, 0.075);
    // Snapped to exactly zero through the rest. A Gaussian never truly reaches
    // it, and the difference between 1.0 and 1.0000000001 is invisible on
    // screen but not to `RenderTransform`, which compares matrices and skips
    // the repaint when they match. This is what makes two thirds of every
    // cycle cost nothing at all rather than a paint pass for no visible
    // change.
    return beat < 0.001 ? 0 : beat;
  }

  /// A tap replays the arrival. Deliberately a [Listener] and not a tap
  /// recognizer: the bubble above this one already runs a long-press (the
  /// action menu) and a double-tap (react) in its own arena, and a recognizer
  /// down here would win that arena on the first tap up and swallow the react
  /// gesture. A pointer listener never enters the arena at all, so both still
  /// work and a double-tap now both reacts *and* replays — which is the right
  /// answer anyway.
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
    _intro.forward(from: 0);
    // Re-phased after the intro is rewound, so the replayed burst leaves on a
    // thump instead of wherever in its cycle the loop happened to be.
    if (_pulse != null) _startBeat();
  }

  @override
  Widget build(BuildContext context) {
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
        child: RepaintBoundary(
          // The heartbeat runs for as long as the message is on screen, and
          // without this the transcript rows sharing this layer would be
          // walked on every one of its frames.
          child: _content,
        ),
      ),
    );
  }

  /// How far a mote can travel, as a multiple of the glyph's point size.
  ///
  /// Deliberately about one glyph: further than this and the spray climbs into
  /// the message above, which reads as a bug in the row above rather than as a
  /// flourish on this one.
  static const double _reach = 1.4;

  /// A single overshooting arc per glyph, offset by [i].
  ///
  /// The stagger lives in the curve's input, not in a delay: each glyph runs
  /// the same arc a beat later than the one before it, and the last one still
  /// lands inside the entrance's own window.
  static double _entrance(double pop, int i, int count) {
    if (pop >= 1) return 1;
    const stagger = 0.16;
    final u =
        ((pop - i * stagger) / (1 - (count - 1) * stagger)).clamp(0.0, 1.0);
    return 0.32 + 0.68 * Curves.easeOutBack.transform(u);
  }
}

/// The hue to draw a heart's motes in — the glyph's own colour, so a 💙 sprays
/// blue and a 💛 yellow.
Color heartTint(String cluster) {
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
      // Not black. The motes are drawn on the transcript's ground, which on a
      // dark theme is already near black; this is a black heart's colour as
      // dark as it can be and still be seen leaving the glyph.
      return const Color(0xFF6E7681);
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

/// Small hearts thrown out of a jumbo heart and falling away.
///
/// A *burst*, not a stream: every mote leaves within the first fifth of the
/// animation, in an upward fan, decelerating as it goes and then dropping —
/// which is what makes it read as one event rather than as a smoke machine.
/// The earlier version launched them in sequence up a narrow column, which
/// climbed into the message above and never stopped looking like a leak.
///
/// Vector paths rather than more copies of the emoji: a glyph would need a
/// `saveLayer` per mote to fade, and at this size the silhouette is the whole
/// read anyway — the colour comes from [heartTint].
class _HeartBurst extends CustomPainter {
  const _HeartBurst({
    required this.arrival,
    required this.popSpan,
    required this.inset,
    required this.glyph,
    required this.tints,
    required this.count,
    required this.seed,
  }) : super(repaint: arrival);

  /// The arrival controller, read directly rather than rebuilt into: passing
  /// it as `repaint` means the widget above this painter is built once and the
  /// canvas is redrawn straight off the ticker — and, once the arrival stops,
  /// not at all.
  final Animation<double> arrival;

  /// Where the pop ends and the burst begins, in [arrival]'s own 0..1.
  final double popSpan;

  /// How far this canvas extends past the glyph row on the left, right and
  /// top — needed to place a mote's origin back on the row itself.
  final double inset;

  /// The emoji's point size, which every distance below is a multiple of.
  final double glyph;

  /// `(index in the row, colour)` for each heart. The index is what puts the
  /// burst under the right glyph in a two-heart message.
  final List<MapEntry<int, Color>> tints;

  /// How many glyphs the row holds, heart or not.
  final int count;

  /// Deterministic jitter, so a message looks the same on every replay and two
  /// messages side by side do not.
  final int seed;

  /// Motes per heart. Enough to read as a handful at a glance; past about a
  /// dozen they stop being countable and start being confetti.
  static const int _perHeart = 14;

  /// The window every mote has left the glyph by, as a fraction of [t].
  static const double _launch = 0.14;

  @override
  void paint(Canvas canvas, Size size) {
    if (tints.isEmpty) return;
    final t = ((arrival.value - popSpan) / (1 - popSpan)).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return;
    // The row itself, inside the padding this canvas was grown by.
    final rowWidth = size.width - inset * 2;
    final rowBottom = size.height - glyph * 0.5;

    for (final tint in tints) {
      final rnd = math.Random(seed ^ (tint.key * 0x9E3779B9));
      // The optical centre of this glyph. Emoji in a row are close enough to
      // the same width that dividing the row evenly lands inside the right
      // one, which is all this needs.
      final cx = inset + rowWidth * (tint.key + 0.5) / count;
      final cy = rowBottom - glyph * 0.55;

      for (var i = 0; i < _perHeart; i++) {
        final jAngle = rnd.nextDouble();
        final jSpeed = rnd.nextDouble();
        final jSize = rnd.nextDouble();
        final jSpin = rnd.nextDouble();
        final u = (t - rnd.nextDouble() * _launch) / (1 - _launch);
        if (u <= 0 || u >= 1) continue;

        // A fan around straight up, wide enough to look thrown and narrow
        // enough that nothing flies sideways into the next message.
        final angle = -math.pi / 2 + (jAngle - 0.5) * 2.1;
        // Fast out, then coasting: the mote covers most of its distance in
        // the first third, which is the difference between thrown and drifting.
        final travel = 1 - math.pow(1 - u, 2.6).toDouble();
        final dist = glyph * (0.55 + 0.75 * jSpeed) * travel;
        final x = cx + math.cos(angle) * dist;
        // …and then gravity takes over, so the fan closes into a fall.
        final y = cy + math.sin(angle) * dist + glyph * 0.9 * u * u;

        final grow = u < 0.14 ? u / 0.14 : 1.0;
        final s = glyph * (0.12 + 0.14 * jSize) * grow * (1 - 0.25 * u);
        final alpha =
            math.min(u / 0.07, (1 - u) / 0.5).clamp(0.0, 1.0) * 0.95;
        if (alpha <= 0.01 || s <= 0.5) continue;

        canvas.save();
        canvas.translate(x, y);
        // A slow tumble, seeded off the same jitter as the throw so a mote
        // that flies left leans left.
        canvas.rotate((jSpin - 0.5) * 1.4 * u + (jAngle - 0.5) * 0.6);
        canvas.drawPath(
          _heart(s),
          Paint()..color = tint.value.withValues(alpha: alpha),
        );
        canvas.restore();
      }
    }
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
  bool shouldRepaint(_HeartBurst old) =>
      old.arrival != arrival || old.glyph != glyph || old.seed != seed;
}
