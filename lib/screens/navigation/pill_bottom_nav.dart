import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HapticFeedback;

import '../../data/glass_config.dart';
import '../../data/settings_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/spring.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/count_badge.dart';
import '../../widgets/liquid_glass.dart';
import 'destinations.dart';

/// How long a finger has to rest on the bar before the selection pill can be
/// dragged.
///
/// Well under [kLongPressTimeout]'s 500ms. That timeout is tuned for a
/// long-press that opens something *else* — a context menu — where firing early
/// steals a tap. Here the long press only picks up a control the finger is
/// already on, and there is nothing to steal: a press that turns out to be a
/// tap still selects the segment it started on. At 500ms the bar felt dead;
/// this is short enough to read as "the pill responds to pressure".
const Duration _kHoldToGrab = Duration(milliseconds: 220);

/// Horizontal travel that grabs the pill without waiting for [_kHoldToGrab].
///
/// Deliberately below [kTouchSlop] (18): the bar owns its whole width, there is
/// no scrollable competing for this gesture, so a drag can be recognised as
/// soon as it is unambiguously a drag rather than after it has out-waited a
/// hypothetical rival.
const double _kGrabSlop = 8;

/// How far the held pill swells past its resting edge, in logical pixels, on
/// **every** side. About its own centre on every segment — a selection that grew
/// off-centre because of where it happened to sit in the row read as a bug,
/// which is exactly what it was.
///
/// In points, not as a scale factor, and that is the whole point of this
/// constant. A uniform *factor* on a pill that is ~80x50 is not a uniform swell:
/// 1.32 put 12.8pt on each end and only 8pt on the top and bottom, so the thing
/// visibly ballooned sideways while barely lifting — the axes disagreed by 60%
/// and the eye reads that as a stretch, not as a lift. Equal points on every
/// side is what actually looks like one object being picked up. The per-axis
/// factors are derived from the pill's measured size in [_indicator].
///
/// Big enough to overflow the bar. That is deliberate and it is why the
/// indicator is painted outside the glass's clip (see [build]): a swell bounded
/// by the capsule is bounded by ~6pt, which is not a swell. Leaking is also the
/// honest depiction — the thing is being lifted towards you, so it should not
/// stay politely inside the plate it was lying on.
///
/// **This is the dial to turn for a bigger or smaller lift.** The two things
/// that bound it, at standard geometry: vertically, [kShellPadV] (6) is all the
/// room inside the bar, so at 16 the pill stands ~10pt proud top and bottom —
/// that leak is the effect. Horizontally, a segment's content starts
/// [kIndicatorInset] + (kIndicatorInset + 6) = 14pt past the pill's edge, so
/// much past ~16 and the swell starts covering the neighbouring destinations'
/// labels rather than merely crowding them.
const double _kGrabSwell = 16;

/// The pill's answer to a press that has not become a grab yet: a shallow
/// squish, the sign every iOS control gives that it felt the finger. Negative
/// because it shares the grab's 0..1 axis, so one spring drives the press, the
/// hold and the tap's pop alike — which also means it inherits the equal-points
/// treatment, and so squishes in by the same ~5pt on every side rather than
/// pinching in from the ends.
const double _kPressScale = -0.34;

/// How much the icon+label under the pill grow with it. Well under the pill's
/// own scale, so the content looks like it is being carried by the pill rather
/// than zooming with it — and because a segment's label is already close to the
/// width it ellipsizes at.
const double _kContentGrow = 0.08;

/// Squash-and-stretch along the direction of travel, per index/second of
/// indicator velocity, and the ceiling it saturates at.
///
/// This is the whole difference between a pill that slides and a pill that
/// flows. It costs nothing — the velocity is already being integrated — and it
/// is the one part of the motion a still screenshot cannot show.
const double _kStretchPerVelocity = 0.018;
const double _kMaxStretch = 0.08;

/// How far past the first/last segment a dragging finger can pull, in segments,
/// at infinite pull. Rubber-banded, so the resistance builds.
///
/// The pill does not actually *go* there — see [_kSquashAtWall]. This is the
/// scale on which "how hard are you pulling" is measured.
const double _kOverdrag = 0.22;

/// What the pill does with distance it cannot travel: compresses, and bulges
/// across by a fraction of what it loses along.
///
/// It does not slide off the end of the bar instead, however much room there
/// now is to do so — a selection floating past the last destination reads as
/// broken, where one that visibly resists reads as an edge. This is also what
/// absorbs a settle spring overshooting onto an end segment; both arrive here
/// as [_excess].
const double _kSquashAtWall = 0.11;

/// Excess (in segments) at which the squash saturates.
const double _kFullSquash = 0.22;

/// Spring tunings, as (response seconds, damping ratio) — see [Spring].
///
/// Settle overshoots slightly and takes its time: this replaced a 220ms
/// `easeOutCubic`, which is a curve that has done nearly all its travel in the
/// first third of its duration and so reads as a jump-cut with a smear on the
/// end. Follow is stiff and nearly critically damped, because a pill under a
/// finger that visibly lags or wobbles feels broken rather than fluid. Grab is
/// the loosest of the three — the wobble as the pill inflates and, especially,
/// as it snaps back on release is the point of it.
const double _kSettleResponse = 0.42;
const double _kSettleRatio = 0.78;
const double _kFollowResponse = 0.16;
const double _kFollowRatio = 0.92;
const double _kGrabResponse = 0.30;
const double _kGrabRatio = 0.62;

/// The tap's pop: the hold's swell, played fast.
///
/// A tap used to slide the indicator and nothing else, so the bar had two
/// vocabularies — hold it and it lifts, tap it and it merely relocates. These
/// two numbers are the whole of the fix, and what they deliberately do *not*
/// contain is a second amplitude or a second curve. The pop rides the same
/// [_grab] spring on the same 0..1 axis as the hold, so it reaches for the same
/// [_kGrabSwell] points on every side, at the same [_kGrabRatio] damping and so
/// with the same soft overshoot on the way back. Only the clock differs.
///
/// [_kPopResponse] is three quarters of the hold's, expressed as a fraction
/// rather than as `0.225` so the relationship survives someone retuning the
/// hold. Quicker than a hold, but only just — the first cut at this was half
/// the hold's response on a 60ms dwell, and the whole pop came and went inside
/// ~120ms, about seven frames. That measured fine and was invisible in the
/// hand: a tap reads as a single event, so an animation shorter than the eye's
/// settling time after the finger lands is one nobody sees. Being "spent before
/// the slide arrives" turned out to be the wrong target — the pop is *meant* to
/// be seen during the move, not squeezed in ahead of it.
///
/// [_kPopDwell] is the part a hold gets for free and a tap cannot: a held pill
/// is turned around by the finger lifting, and a tap has no finger left to wait
/// for. So the return leg is scheduled instead, and this dwell is the amplitude
/// dial — it decides how far up the arc the spring gets before it is pulled
/// back, because it turns around well before the spring would top out on its
/// own. At 60ms it reached ~0.81; at 120ms it gets most of the way to the
/// hold's full [_kGrabSwell] lift and holds there long enough to register,
/// putting the round trip near the [_kSettleResponse] slide's own length so the
/// two read as one gesture.
///
/// Turn this down for a smaller pop, not [_kGrabSwell] — that one is shared
/// with the hold, and moving it changes both.
const double _kPopResponse = _kGrabResponse * 3 / 4;
const Duration _kPopDwell = Duration(milliseconds: 120);

/// The floating bottom nav, stacked icon-over-label.
///
/// Went stacked when a fourth destination arrived: at four segments a 375pt
/// phone gives each item ~82pt, and after padding the side-by-side layout left
/// ~40pt for a label needing ~45pt, so "Settings" and "Discover" both
/// ellipsised — and worse once a badge appeared. Stacking also brings this into
/// line with the side rail, which was already icon-over-label, so compact and
/// expanded windows finally read as the same design.
///
/// Driven by two [Spring]s rather than implicit animations: one carries the
/// indicator through segment-index space, one carries how far the pill is
/// inflated. Implicit animations cannot do either job here — [AnimatedAlign]
/// restarts from scratch on every retarget (so a second tap mid-slide, or a
/// finger that never stops moving, throws away the velocity and stutters), and
/// nothing implicit can hand a *velocity* to the stretch. See [_frame] for how
/// little of the tree actually rebuilds per frame.
///
/// How much of the bottom inset the home indicator itself actually claims.
///
/// The inset a phone reports (34pt on a modern iPhone, ~24 for Android's
/// gesture bar) is not the size of the thing that must not be covered — it is
/// comfortable padding around a thin glyph near the edge. Floating chrome is
/// meant to live inside it; a full-width tab bar is the shape that fills it.
/// This is the part that is genuinely spoken for, and everything above it is
/// the designer's to spend.
const double kIndicatorKeepOut = 12;

/// Returns a [Positioned], so it must be placed directly in a [Stack].
///
/// Lives in its own file, and public, so a widget test can pump it. As a
/// private class inside the shell it was unreachable from `test/`, which is
/// exactly why a uniform 13.875pt horizontal offset on every segment shipped
/// unnoticed — see `test/pill_bottom_nav_layout_test.dart`.
class PillBottomNav extends StatefulWidget {
  const PillBottomNav({
    super.key,
    required this.active,
    required this.onSelect,
    required this.badges,
    this.profile,
  });
  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;

  /// Glass and layout to render with. Null — the shell — reads the live
  /// settings. The tuning screen passes an interpolated profile so the bar
  /// eases between looks instead of snapping.
  final GlassProfile? profile;

  /// Per-destination badge counts. Was a pair of named `chatBadge` /
  /// `settingsBadge` fields, which meant every new destination wanting a badge
  /// cost another constructor parameter.
  final Map<HomeSection, int> badges;

  @override
  State<PillBottomNav> createState() => _PillBottomNavState();
}

class _PillBottomNavState extends State<PillBottomNav>
    with SingleTickerProviderStateMixin {
  /// Where the pill is, in segment-index space: 1.5 is exactly between the
  /// second and third destinations, and slightly-negative is the first one
  /// rubber-banded past the start.
  late final Spring _position = Spring(
    response: _kSettleResponse,
    ratio: _kSettleRatio,
    value: navIndexOf(widget.active).toDouble(),
  );

  /// How inflated the pill is: 0 at rest, 1 held, [_kPressScale] pressed.
  final Spring _grab = Spring(response: _kGrabResponse, ratio: _kGrabRatio);

  /// The one thing that notifies per frame. Only the indicator and the four
  /// segments' icon/label styling listen, so a frame of spring motion rebuilds
  /// five small builders and repaints — it does not rebuild the glass, the
  /// blur, or the bar's layout.
  final _frame = _FrameNotifier();

  /// Created eagerly rather than `late`: a lazy field is first touched in
  /// [dispose] for a bar that was never animated, and creating a ticker while
  /// the element is unmounting looks up a deactivated widget's ancestors.
  late final Ticker _ticker;
  Duration? _lastTick;

  final _barKey = GlobalKey();

  /// The pointer currently owning the bar. A second finger is ignored outright
  /// — two fingers dragging one pill has no sensible meaning.
  int? _pointer;
  double _pressX = 0;
  double _lastX = 0;
  int _pressIndex = 0;
  bool _grabbed = false;

  /// Whether the finger has travelled far enough for this to be a drag rather
  /// than a press. Decides what a release means: where the pill ended up, or
  /// the segment that was pressed.
  bool _moved = false;

  /// Where the pill was when the grab began.
  ///
  /// A drag moves the pill by the finger's *travel* from [_pressX] — it does
  /// not move the pill *to* the finger. Teleporting it under the finger was the
  /// first cut and it was wrong: a long press is supposed to pick up the
  /// selection where it already is, and a pill that jumps a hundred points the
  /// instant you hold still is the opposite of picking something up. Keeping
  /// the offset also means the ends behave — you can drag the pill onto the
  /// last segment from anywhere, rather than having to reach the last segment.
  ///
  /// Measured from the touch-down point and not from wherever the drag was
  /// *recognised*, so [_kGrabSlop] is only ever a decision threshold and never
  /// a distance the pill silently loses. Recognisers normally subtract their
  /// slop, because they have to compete for a gesture they might not win; this
  /// one has no rival, so the honest rule — the pill moves as far as the
  /// finger moved — costs nothing.
  double _grabPosition = 0;

  /// The segment the pill would commit to right now. Not state — nothing
  /// rebuilds on it — it exists so the crossing haptic fires once per segment
  /// instead of once per pointer move.
  int _nearest = 0;
  Timer? _holdTimer;

  /// The return leg of a tap's pop, scheduled because a tap has no finger left
  /// to lift. See [_pop].
  Timer? _popTimer;

  /// Read in `build`, used by the pointer handlers, which run between builds.
  List<NavDest> _destinations = const [];
  bool _rtl = false;
  bool _calm = false;

  int get _count => _destinations.length;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant PillBottomNav old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    final target = navIndexOf(widget.active).toDouble();
    // A live drag owns the pill; the release settles it. Otherwise this is
    // someone else moving the selection — a keyboard, a deep link, the side
    // rail on a resize — and the pill should travel there on its own.
    if (_pointer != null) return;
    if (_calm) {
      // No notify: this is the build phase, and marking a descendant dirty
      // from here is exactly the "setState during build" error. The build that
      // is already on its way reads the snapped value.
      _position.snap(target);
    } else {
      _position.retarget(
        target,
        response: _kSettleResponse,
        ratio: _kSettleRatio,
      );
      _wake();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _popTimer?.cancel();
    _ticker
      ..stop()
      ..dispose();
    _frame.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- physics

  /// Runs the ticker only while something is moving. A nav bar is on screen for
  /// the whole session; a ticker left running would repaint it 120 times a
  /// second forever.
  void _wake() {
    if (_ticker.isActive) return;
    _lastTick = null;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    // First callback of a run has nothing to difference against.
    final dt = last == null
        ? 1 / 60
        : (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    _position.tick(dt);
    _grab.tick(dt);
    _frame.tick();
    // Stops even with a finger still down — a held, motionless pill has nothing
    // to draw, and the next move wakes it in the same frame it arrives in.
    if (_position.atRest && _grab.atRest) _ticker.stop();
  }

  // --------------------------------------------------------------- geometry

  double get _barWidth {
    final size = _barKey.currentContext?.size;
    return (size == null || size.width <= 0) ? 1 : size.width;
  }

  /// The segment a local x lands on.
  ///
  /// Mirrored under RTL. Pointer coordinates are always left-to-right pixels,
  /// but the [Row] above is mirrored and index 0 renders on the *right*, so
  /// without this every tap on a right-to-left bar selects the destination
  /// diagonally opposite the one under the finger.
  int _indexAt(double x) {
    final raw = (x / (_barWidth / _count)).floor().clamp(0, _count - 1);
    return _rtl ? _count - 1 - raw : raw;
  }

  /// The continuous position a dragging finger asks for, rubber-banded past
  /// the ends.
  ///
  /// Relative to [_grabPosition] and [_pressX], not absolute: see
  /// [_grabPosition]. The direction flip is the same RTL mirroring [_indexAt]
  /// does — dragging left moves *forwards* through the nav order on a mirrored
  /// bar.
  double _positionAt(double x) {
    final travel = (x - _pressX) / (_barWidth / _count);
    final p = _grabPosition + (_rtl ? -travel : travel);
    if (p < 0) return -_rubberBand(-p);
    final end = (_count - 1).toDouble();
    if (p > end) return end + _rubberBand(p - end);
    return p;
  }

  /// Asymptotic resistance: the first fraction of a segment of overpull comes
  /// almost free, and no amount of pull reaches [_kOverdrag].
  double _rubberBand(double overshoot) =>
      _kOverdrag * (1 - 1 / (1 + overshoot * 2));

  /// Where the pill is actually drawn: never outside the row of segments.
  double get _clampedPosition =>
      _position.value.clamp(0.0, (_count - 1).toDouble());

  /// How far past an end the pill *wanted* to be, signed — negative past the
  /// first segment, positive past the last. Zero in the middle of the bar,
  /// which is where it spends most of its life.
  ///
  /// Two things land here. A finger dragging past the end, rubber-banded by
  /// [_rubberBand]; and the settle spring overshooting onto an end segment,
  /// which for a jump across the whole bar is a quarter of a segment of
  /// travel that has nowhere to go.
  double get _excess {
    final end = (_count - 1).toDouble();
    if (_position.value < 0) return _position.value;
    if (_position.value > end) return _position.value - end;
    return 0;
  }

  // --------------------------------------------------------------- gestures

  /// A raw [Listener] rather than a [GestureDetector] because the bar is the
  /// only claimant on these pointers — it floats above the section, opaque, and
  /// no ancestor scrolls horizontally. Going through the arena would buy
  /// nothing and cost the thing that matters most here: a recognizer only
  /// starts reporting once it has *won*, which is precisely the first few
  /// frames in which the pill should already be moving under the finger.
  void _onPointerDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _pressX = _lastX = e.localPosition.dx;
    _pressIndex = _nearest = _indexAt(_pressX);
    _grabbed = false;
    _moved = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(_kHoldToGrab, _beginGrab);
    // A new gesture owns the grab spring from here, so the previous tap's
    // return leg must not fire into the middle of it and deflate a squish or an
    // inflate that this press has since asked for. Cancelling is safe without
    // also retargeting: every pointer-down is followed by [_endPointer], which
    // always aims the spring back at 0.
    _popTimer?.cancel();
    _popTimer = null;
    if (_calm) return;
    // Only the segment already wearing the pill can squish, because it is the
    // only one with anything drawn to squish.
    if (_pressIndex == navIndexOf(widget.active)) {
      _grab.retarget(_kPressScale, response: 0.24, ratio: 0.9);
    }
    _wake();
  }

  /// Picks the pill up. Deliberately moves nothing on its own: it inflates
  /// where it is, and the finger's travel so far — at most [_kGrabSlop], or a
  /// whole flick if the first move event was a big one — is applied from there.
  void _beginGrab() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_pointer == null || _grabbed) return;
    _grabbed = true;
    // Grabs it mid-flight if it is still travelling, rather than at the
    // destination it was heading for.
    _grabPosition = _position.value;
    _nearest = _grabPosition.round().clamp(0, _count - 1);
    if (!_calm) {
      HapticFeedback.mediumImpact();
      _grab.retarget(1, response: _kGrabResponse, ratio: _kGrabRatio);
    }
    _wake();
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    _lastX = e.localPosition.dx;
    final travelled = (_lastX - _pressX).abs() > _kGrabSlop;
    if (!_grabbed) {
      if (!travelled) return;
      // Falls through rather than returning: the move that crossed the slop is
      // still a move, and on a fast flick it can be most of the bar.
      _beginGrab();
    }
    if (travelled) _moved = true;
    _follow(_lastX);
  }

  void _follow(double x) {
    final p = _positionAt(x);
    if (_calm) {
      _position.snap(p);
    } else {
      _position.retarget(p, response: _kFollowResponse, ratio: _kFollowRatio);
    }
    final near = p.round().clamp(0, _count - 1);
    if (near != _nearest) {
      _nearest = near;
      if (!_calm) HapticFeedback.selectionClick();
    }
    // Safe from a pointer callback — this is not the build phase.
    _frame.tick();
    _wake();
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    final dragged = _moved;
    // Read before [_endPointer] clears it. A pill that was actually picked up
    // is already at the top of its arc and already on its way back down; popping
    // it again after the finger has gone reads as the release not taking.
    final held = _grabbed;
    final landing = _positionAt(e.localPosition.dx);
    _endPointer();
    if (dragged) {
      // Silent, and no pop: the drag already clicked as it crossed onto this
      // segment — clicking again on release turns one selection into two ticks
      // — and the pill it was carrying is mid-shrink, which is the motion the
      // release is supposed to end on.
      _commit(landing.round().clamp(0, _count - 1), haptic: false, pop: false);
    } else if (_withinBar(e.localPosition)) {
      // A press that never travelled — a tap, or a hold released in place —
      // selects what is under the finger, exactly as a tap always has. Holding
      // still is not a way to select nothing.
      _commit(_pressIndex, pop: !held);
    } else {
      // Slid off without ever taking the pill: the ordinary button-cancel.
      _settleToActive();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _endPointer();
    _settleToActive();
  }

  void _endPointer() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pointer = null;
    _grabbed = false;
    _moved = false;
    // The auto-shrink. Same spring the inflate used, so the pill leaves the
    // finger the way it arrived — with one soft overshoot — instead of
    // deflating on a curve.
    _grab.retarget(0, response: _kGrabResponse, ratio: _kGrabRatio);
    _wake();
  }

  /// Whether a release still counts as a tap on the bar. Generous vertically:
  /// a thumb reaching the bottom of a phone drifts, and a tap that lands 10pt
  /// low is a tap.
  bool _withinBar(Offset local) {
    final size = _barKey.currentContext?.size;
    if (size == null) return false;
    return (Offset.zero & size).inflate(16).contains(local);
  }

  void _settleToActive() => _moveTo(navIndexOf(widget.active).toDouble());

  void _moveTo(double target) {
    if (_calm) {
      _position.snap(target);
      _frame.tick();
      return;
    }
    _position.retarget(
      target,
      response: _kSettleResponse,
      ratio: _kSettleRatio,
    );
    _wake();
  }

  /// Select segment [i] and send the pill there.
  ///
  /// Always calls back, even for the segment that is already active — a nav bar
  /// re-tapping its own tab is a meaningful event to the shell, and swallowing
  /// it here would decide that for it.
  ///
  /// Order matters and is deliberate: the pop and the slide are both aimed
  /// *before* [PillBottomNav.onSelect] fires, and onSelect fires synchronously
  /// rather than from the end of an animation. So the section switches in the
  /// same frame the finger lifts, with the pop playing over the top of it — the
  /// scale is decoration on an instant switch, never a gate in front of one.
  void _commit(int i, {bool haptic = true, bool pop = true}) {
    if (i < 0 || i >= _count) return;
    if (pop) _pop();
    _moveTo(i.toDouble());
    final section = _destinations[i].section;
    if (haptic && section != widget.active && !_calm) {
      HapticFeedback.selectionClick();
    }
    widget.onSelect(section);
  }

  /// The tap's version of the hold's swell: same spring, same amplitude, over
  /// and done in about the time the hold takes just to leave the ground.
  ///
  /// Deliberately not its own [AnimationController]. A second driver would have
  /// to be composed into the very transform [_grab] already writes, and the two
  /// would then disagree about the pill's scale every time a tap landed on a
  /// press, a hold or another tap — which is most of the interesting cases. One
  /// spring, retargeted, has no such seam: [Spring.retarget] moves the target
  /// without touching value or velocity, so a tap arriving mid-pop, mid-squish
  /// or mid-deflate bends the curve the pill is already on instead of snapping
  /// to a stale start value and replaying from there. It also costs nothing
  /// when idle — the shared ticker stops itself the frame both springs are at
  /// rest (see [_onTick]) and no pop ever keeps it alive on its own.
  ///
  /// Nothing here touches [_position], so the pop cannot fight the slide: they
  /// are different quantities on different springs, composed once per frame in
  /// [_placed].
  void _pop() {
    // Calm motion means "stop decorating". The switch itself is untouched — see
    // [MotionScope] — and this is purely decoration on top of it.
    if (_calm) return;
    // A live gesture owns the grab spring, exactly as it owns the pill's
    // position in [didUpdateWidget]. Nothing on the pointer path reaches here
    // with a finger still down — [_onPointerUp] commits after [_endPointer] has
    // released it — but a keyboard or VoiceOver activation arriving mid-drag
    // would, and it has no business inflating something a finger is holding.
    if (_pointer != null) return;
    _popTimer?.cancel();
    _grab.retarget(1, response: _kPopResponse, ratio: _kGrabRatio);
    // The return leg a hold gets from the finger lifting. Rescheduled from
    // scratch on every pop, so a burst of rapid taps ends on exactly one
    // pending turnaround and the pill cannot be left stranded at the top of an
    // arc that nobody is coming back for.
    _popTimer = Timer(_kPopDwell, () {
      _popTimer = null;
      _grab.retarget(0, response: _kPopResponse, ratio: _kGrabRatio);
      _wake();
    });
    _wake();
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    _destinations = navDestinations(AppLocalizations.of(context));
    _rtl = Directionality.of(context) == TextDirection.rtl;
    _calm = MotionScope.of(context).calm;
    final profile = widget.profile ?? SettingsStore.instance.glass;
    final geo = profile.geometry;
    final margin = geo.of(kBarMargin);
    final shellPadding = EdgeInsets.symmetric(
      horizontal: geo.of(kShellPadH),
      vertical: geo.of(kShellPadV),
    );
    // `viewPadding`, NOT `padding`.
    //
    // `padding` is what is LEFT after ancestors consume it, so any `SafeArea`
    // above this widget zeroes it and the gap below collapses to the knob —
    // putting the bar 12pt off the screen edge, under the home indicator,
    // instead of clear of it. `viewPadding` reports the physical inset
    // regardless of who has already handled it, which is the question being
    // asked here: where is the hardware.
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    // The knob measured from the INDICATOR, not from the top of the inset.
    //
    // This has now been wrong twice in opposite directions. It started as
    // `bottom: kBarBottom` inside a `SafeArea`, so the two ADDED — 12pt of
    // float on top of a 34pt inset put the bar 46pt up. The fix was
    // `max(knob, inset)`, which is 34pt: better, still high, and worse in one
    // way, because the knob's whole range is at or above that floor so nothing
    // could bring the bar down. "There is more space under it than there
    // should be" is exactly what that geometry looks like.
    //
    // The mistake both times was treating the bottom inset as a keep-out zone.
    // It is not: it is generous padding around a ~5pt home indicator that sits
    // ~8pt off the edge, and Apple's own floating chrome sits inside it. What
    // has to be cleared is the INDICATOR, which [kIndicatorKeepOut] is, and the
    // knob then means what its hint has always said — how high the bar floats
    // above it. Hardware with no indicator has nothing to clear, so the knob is
    // the whole gap there, exactly as before.
    final barBottom =
        (safeBottom > 0 ? kIndicatorKeepOut : 0) + geo.of(kBarBottom);

    return Positioned(
      left: margin,
      right: margin,
      bottom: barBottom,
      // Bottom inset handled above; this is now top/left/right only so the
      // two cannot double up again.
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        // The app's own glass recipe rather than a hand-rolled ClipRRect +
        // BackdropFilter + Container, which is what this was and which had
        // drifted: it drew a flat 0.72 surface with no sheen while every other
        // floating surface in the app had one, and its solo BackdropFilter
        // could not join the shared rasterization pass that
        // BackdropFilter.grouped gives the rest.
        //
        // A capsule, reversing an earlier call to make it a rounded rectangle.
        // That call was right about the symptom — `circular(999)` on a 335x63
        // shell clamps into barrel ends — but treated it as a shape problem
        // when it was a height problem. Trimming the segment to 48pt puts the
        // shell at 60pt, where a true StadiumBorder is the iOS tab bar it was
        // always imitating.
        // Its own glass config, separate from every other surface's: this is
        // the one that sits over moving content for its whole life, so a
        // tuning that reads well here as a lens is usually too thin for a
        // composer or a header with text directly behind it.
        //
        // Three sibling layers rather than one glass with everything inside it,
        // because the swollen pill has to be able to leave the bar and anything
        // inside [LiquidGlass] is inside its capsule clip. So: the glass is
        // stretched to fill, the pill floats above it unclipped, and the row of
        // segments — the only child that is *not* positioned — is what gives
        // the whole stack its size, exactly as the glass's own child used to.
        // Paint order is unchanged from when all three were nested: backdrop,
        // then pill, then icons on top of it.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: LiquidGlass(
                shape: LiquidGlassShape.capsule,
                config: profile.nav,
                child: const SizedBox.expand(),
              ),
            ),
            // Inset to the row's box, so the indicator's geometry is measured
            // against the segments and not against the shell padding too.
            Positioned.fill(
              child: Padding(padding: shellPadding, child: _indicator(geo)),
            ),
            Padding(
              padding: shellPadding,
              // One listener for the whole bar, not one per segment: a drag has
              // to cross segment boundaries without the gesture ending, which
              // per-segment recognizers structurally cannot do.
              child: Listener(
                key: _barKey,
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: Row(
                  children: [
                    for (var i = 0; i < _destinations.length; i++)
                      _segment(theme, geo, _destinations[i], i),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The sliding accent pill.
  ///
  /// [IgnorePointer] because the bar's own [Listener] handles every pointer
  /// now; the pill is paint.
  Widget _indicator(GlassConfig geo) {
    final inset = geo.of(kIndicatorInset);
    // Outside the AnimatedBuilder: this measures the pill's *resting* box, which
    // does not change per frame, and a LayoutBuilder inside the builder would
    // put a layout callback on every frame of the swell to learn the same two
    // numbers. The constraints here are the row's, tight, courtesy of the
    // Positioned.fill in [build].
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final pillW = box.maxWidth / _count - inset * 2;
          final pillH = box.maxHeight;
          return AnimatedBuilder(
            animation: _frame,
            builder: (context, _) {
              final grab = _grab.value;
              final stretch = (_position.velocity.abs() * _kStretchPerVelocity)
                  .clamp(0.0, _kMaxStretch);
              final over = (_excess.abs() / _kFullSquash).clamp(0.0, 1.0);
              final squash = _kSquashAtWall * over;
              // Points first, factors second. Guarded because a zero-width slot
              // (a bar laid out at 0 during a transition) would otherwise divide
              // by zero and hand the Matrix4 a NaN, which paints nothing at all.
              final swell = _kGrabSwell * grab;
              final gx = pillW > 0 ? 1 + swell * 2 / pillW : 1.0;
              final gy = pillH > 0 ? 1 + swell * 2 / pillH : 1.0;
              return _placed(grab, gx, gy, stretch, squash, inset);
            },
          );
        },
      ),
    );
  }

  /// The positioned, transformed pill for one frame. Split out only to keep
  /// [_indicator]'s two nested builders readable.
  Widget _placed(
    double grab,
    double gx,
    double gy,
    double stretch,
    double squash,
    double inset,
  ) {
    return Align(
      // AlignmentDirectional, not Alignment: the Row below mirrors under
      // RTL — destination 0 renders on the right — but an absolute
      // alignment does not, so the indicator used to land on the mirrored
      // segment. Directional on both sides keeps them in step, and reads
      // the same in LTR.
      alignment: AlignmentDirectional(
        segmentAlignmentAt(_clampedPosition, _count),
        0,
      ),
      child: FractionallySizedBox(
        widthFactor: 1 / _count,
        heightFactor: 1,
        // The slot stays a full segment wide — that is what
        // segmentAlignmentAt positions, and what the tests measure
        // against — and only the painted pill is inset within it.
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Transform(
            alignment: Alignment.center,
            // The grab term differs per axis *so that the swell does not*:
            // gx and gy are the factors that add the same [_kGrabSwell] points
            // to a box that is wider than it is tall, about its centre, so the
            // pill lifts evenly wherever it is sitting. The other two terms are
            // the deliberately asymmetric ones: stretch along travel with a
            // squash across it, and the wall compression with a bulge across
            // it — volume, in both cases, is what sells this as a body of
            // liquid rather than a growing rectangle.
            transform: Matrix4.diagonal3Values(
              (gx + stretch) * (1 - squash),
              (gy - stretch * 0.55) * (1 + squash * 0.4),
              1,
            ),
            child: _Indicator(grab: grab.clamp(0.0, 1.0)),
          ),
        ),
      ),
    );
  }

  Widget _segment(AppTheme theme, GlassConfig geo, NavDest d, int i) {
    final iconSize = geo.of(kIconSize);
    return Expanded(
      child: FocusableTap(
        // Keyboard activation only — the Listener above owns pointers, and
        // FocusableTap deliberately registers no recognizer of its own, so the
        // two cannot fight.
        onTap: () => _commit(i),
        semanticLabel: d.label,
        selected: d.section == widget.active,
        // Matches the indicator behind it.
        shape: FocusRingShape.capsule,
        // The segment's *semantic* tap. It used to come free from the
        // per-segment GestureDetector; the bar-level Listener that replaced
        // that is invisible to assistive tech, because a VoiceOver activation
        // arrives as a SemanticsAction and never as a pointer at all. A
        // Semantics annotation, rather than another recognizer, is the whole
        // point: it restores the action without putting anything back in the
        // way of the drag. `pill_bottom_nav_gesture_test.dart` performs the
        // action to prove the node still carries it.
        child: Semantics(
          onTap: () => _commit(i),
          child: Padding(
            // Wider than the indicator's own inset, so the width a long label
            // ellipsizes at stays inside the painted pill rather than running
            // out to its edge.
            padding: EdgeInsets.symmetric(
              vertical: geo.of(kSegmentPadV),
              horizontal: geo.of(kIndicatorInset) + 6,
            ),
            child: AnimatedBuilder(
              animation: _frame,
              builder: (context, _) {
                // How much of the pill is currently over this segment. Driving
                // the colour off the pill's real position rather than off a
                // bool means the handover happens *as the pill arrives*, in
                // step with it. The two used to run on separate clocks — a
                // 220ms AnimatedDefaultTextStyle against the slide — which is
                // the other half of why switching tabs read as a cut.
                // Clamped, like the pill itself: pulling past the last segment
                // must not start dimming the destination the pill is sitting on.
                final cover = (1 - (_clampedPosition - i).abs()).clamp(
                  0.0,
                  1.0,
                );
                // Smoothstep: a linear ramp spends most of its time in the
                // muddy middle where both segments look half-selected.
                final t = cover * cover * (3 - 2 * cover);
                final color = Color.lerp(theme.inkSoft, theme.accent, t)!;
                return Transform.scale(
                  scale: 1 + _kContentGrow * _grab.value * t,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sized to the glyph, not past it. This was a 46pt-wide box
                      // around a 22pt icon, widened purely so a `right: 0` badge
                      // had somewhere to grow — which parked the badge 12pt clear
                      // of the icon it counts for, and padded 24pt of nothing
                      // into the middle of every segment.
                      SizedBox.square(
                        dimension: iconSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(d.icon, size: iconSize, color: color),
                            if ((widget.badges[d.section] ?? 0) > 0)
                              Positioned(
                                top: -6,
                                // Anchored by `left`, so the badge grows rightward
                                // out of the box. Anchoring by `right` — the
                                // obvious reading — pins its right edge and grows
                                // it LEFTWARD across the glyph instead: one digit
                                // covered the icon's right 6pt and "99+" covered
                                // 18 of its 22. There is ~28pt of slack either
                                // side of the content inside a segment, so the
                                // overflow has somewhere to go.
                                left: iconSize - 9,
                                // Sits on the accent-filled sliding indicator
                                // when this segment is the active one, so it has
                                // to invert there. Hardcoding `false` painted
                                // accent@0.16 on accent@0.16 and the badge
                                // vanished on the one segment most likely to
                                // carry it.
                                child: CountBadge(
                                  count: widget.badges[d.section]!,
                                  onAccent: t > 0.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: geo.of(kIconLabelGap)),
                      // Excluded from semantics because the segment already
                      // carries this exact string as its [FocusableTap] label,
                      // and the two merge into one node: every destination
                      // announced itself twice ("Discover, Discover, button").
                      // The badge above is deliberately not excluded — "Chat,
                      // 3" is worth saying.
                      //
                      // Still guarded: at four segments a 375pt phone leaves
                      // each label ~62pt, which fits every current destination,
                      // but a fifth one or a longer word should degrade rather
                      // than throw an overflow.
                      ExcludeSemantics(
                        child: Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'CupertinoSystemText',
                            fontSize: geo.of(kLabelSize),
                            fontWeight: FontWeight.lerp(
                              FontWeight.w500,
                              FontWeight.w600,
                              t,
                            ),
                            letterSpacing: -0.08,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The per-frame repaint signal. A bare [ChangeNotifier] with a public poke:
/// the springs are the state, this only says "they moved".
class _FrameNotifier extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// The painted selection pill. Its parent [FractionallySizedBox] is the full
/// segment, so a test measuring the slot cannot see whether the pill inside it
/// is inset or full-bleed — which is the whole difference between a selection
/// and a slab.
@visibleForTesting
const Key navIndicatorKey = Key('pill-nav-indicator');

/// The highlight behind the active segment: a neutral glass lozenge with a
/// light edge, the active icon and label carrying the accent.
///
/// It used to be an accent wash, which on a dark page is a navy pill — the
/// single most visible "dark blue" on the screen.
class _Indicator extends StatelessWidget {
  const _Indicator({required this.grab});

  /// 0 at rest, 1 fully held. Brightens the fill and its edge so the pill
  /// reads as *picked up* and not merely scaled — scale alone at this size is
  /// nearly invisible on a moving background.
  final double grab;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final light = theme.background.computeLuminance() > 0.5;
    return DecoratedBox(
      key: navIndicatorKey,
      decoration: ShapeDecoration(
        color: theme.ink.withValues(
          alpha: (light ? 0.07 : 0.12) + 0.06 * grab,
        ),
        shape: StadiumBorder(
          side: BorderSide(
            color: (light ? Colors.black : Colors.white).withValues(
              alpha: (light ? 0.06 : 0.14) + 0.12 * grab,
            ),
            width: 0.5,
          ),
        ),
        shadows: grab <= 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18 * grab),
                  blurRadius: 14 * grab,
                ),
              ],
      ),
    );
  }
}
