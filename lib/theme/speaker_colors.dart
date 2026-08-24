import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'app_theme.dart';

/// How far a speaker's colour reaches into a group transcript.
///
/// Three rungs rather than a switch because the two useful answers are not
/// "on" and "off". Colouring the NAME is what Discord and Slack do and is all
/// the signal you need while names are on screen — but a run of five messages
/// from one person prints the name once, and the four bubbles under it are
/// back to being anonymous. [bubble] is the rung that fixes that: the colour
/// carries into the bubble itself, so identity survives grouping.
enum SpeakerTint {
  /// Nobody is tinted. Everything reads in theme ink, exactly as it did
  /// before this file existed.
  off,

  /// The sender's name above the bubble, their avatar ring, and the reply
  /// chrome that quotes them.
  name,

  /// Everything [name] paints, plus a wash of the speaker's colour through
  /// the body of each of their bubbles.
  bubble,
}

/// How many colours a room hands out before it has to repeat one.
///
/// Twelve is where the hues below stop being tellable apart at a glance —
/// past it you are asking a reader to distinguish two teals, which is worse
/// than an honest repeat. Rooms bigger than twelve speakers wrap into a
/// second band (see [SpeakerSlots.forMembers]), which is the same bargain
/// every chat app that does this makes.
const int kSpeakerSlotCount = 12;

/// The hue wheel, in ascending order, spaced to stay distinguishable on both
/// a near-black and a cream background. Deliberately thin through the
/// yellow-green band (72 → 110), which is where a dark theme turns two
/// neighbouring hues into the same olive.
const List<double> _kHues = [
  4, // red
  22, // orange
  42, // amber
  72, // lime
  110, // green
  150, // spring
  175, // teal
  196, // cyan
  218, // azure
  250, // indigo
  282, // violet
  320, // magenta
];

/// Walks the wheel in fifths rather than in order, so slot 0 and slot 1 are
/// 150° apart instead of 18°. This matters because assignment probes
/// *forward* on a collision: two people who want the same colour end up in
/// adjacent SLOTS, and adjacent slots have to look nothing alike.
///
/// 5 and 12 are coprime, so the walk still visits all twelve hues.
const int _kHueStride = 5;

double _hueForSlot(int slot) =>
    _kHues[(slot * _kHueStride) % kSpeakerSlotCount];

/// One member, and the instant they joined the room.
///
/// [joinedAt] is a priority, not a display value: it decides who keeps their
/// preferred colour when two people want the same one. Zero for a backend
/// that predates the field, which degrades the whole room to id order — still
/// deterministic, still identical on every client, just no longer immune to a
/// new member reshuffling the room. See [SpeakerSlots.forMembers].
typedef SpeakerMember = ({String id, int joinedAt});

/// Which of the [kSpeakerSlotCount] colours each member of a room speaks in.
///
/// The assignment is a pure function of the roster, so it is the same on every
/// device, for every viewer, on every launch — nobody stores a colour and
/// nothing has to be agreed on. Two properties are worth stating plainly
/// because they are what the whole design is for:
///
///   * **Stable across launches.** A user's preferred slot is a hash of their
///     id, so absent a collision they are the same colour in every room they
///     are in, forever.
///   * **Stable across joins.** Collisions are resolved in join order, and a
///     new member is by definition last — so they take a free colour rather
///     than taking someone else's and cascading the room. The colours you
///     learned yesterday are the colours you see today.
@immutable
class SpeakerSlots {
  const SpeakerSlots._(this._slots);

  /// A room that hands out no colours: a DM, or a group with the feature off.
  /// Every lookup returns null, which every caller reads as "theme ink".
  static const SpeakerSlots none = SpeakerSlots._(<String, int>{});

  final Map<String, int> _slots;

  /// Assigns every member a slot.
  ///
  /// [exclude] is the viewer's own id. Leaving yourself out is not an
  /// optimisation — your bubbles are painted in the accent and sit on the
  /// other margin, and a second identity colour on top of that would be
  /// answering a question the layout already answered. It also frees a colour
  /// for someone who needs one.
  ///
  /// [pinned] is this reader's manual overrides for this room, subject id to
  /// slot. They are applied FIRST and absolutely — a pin is not a preference
  /// that loses to a hash — and the slots they occupy are then off-limits to
  /// everyone the room places automatically. Two pins on one slot is the
  /// reader's own doing and is honoured; nothing derived is ever pushed onto a
  /// pinned slot while a free one remains.
  ///
  /// Folding overrides in HERE rather than at lookup time is what keeps the
  /// read path free: a bubble asking for its speaker's colour does one map
  /// lookup whether or not anybody has ever opened the picker.
  factory SpeakerSlots.forMembers(
    Iterable<SpeakerMember> members, {
    String? exclude,
    Map<String, int> pinned = const <String, int>{},
  }) {
    final roster = [
      for (final m in members)
        if (m.id != exclude) m,
    ];
    if (roster.isEmpty) return none;
    // Join order first, id as the tiebreak — and as the whole ordering on a
    // backend that sends no `joinedAt`, where every member reads as 0.
    roster.sort((a, b) {
      final byTime = a.joinedAt.compareTo(b.joinedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });

    final out = <String, int>{};
    final taken = <int>{};
    // Pins first, so the automatic pass below sees their slots as occupied. A
    // pin naming somebody who has since left is dropped rather than holding a
    // colour shut for a person who can no longer speak — the server sweeps
    // those rows on departure, and this covers the window before that lands.
    if (pinned.isNotEmpty) {
      for (final m in roster) {
        final slot = pinned[m.id];
        if (slot == null) continue;
        final bounded = slot % kSpeakerSlotCount;
        out[m.id] = bounded;
        taken.add(bounded);
      }
    }
    for (final m in roster) {
      if (out.containsKey(m.id)) continue;
      // A band is one full pass over the wheel. Rooms with more than twelve
      // speakers start the wheel again rather than piling everyone left onto
      // one colour.
      if (taken.length == kSpeakerSlotCount) taken.clear();
      final preferred = speakerPreferredSlot(m.id);
      var slot = preferred;
      for (var k = 0; k < kSpeakerSlotCount; k++) {
        final candidate = (preferred + k) % kSpeakerSlotCount;
        if (!taken.contains(candidate)) {
          slot = candidate;
          break;
        }
      }
      taken.add(slot);
      out[m.id] = slot;
    }
    return SpeakerSlots._(out);
  }

  /// The slot [userId] speaks in, or null for the viewer themselves, a
  /// non-member (a former member whose messages are still in the transcript),
  /// or a room that hands out no colours.
  int? slotOf(String? userId) => userId == null ? null : _slots[userId];

  /// Everyone currently speaking in [slot].
  ///
  /// Normally one person, or nobody. More than one only where the reader has
  /// pinned two people onto the same colour, or where the room is past twelve
  /// speakers and has wrapped — which is exactly what the picker has to be able
  /// to say out loud before somebody makes it worse.
  List<String> holdersOf(int slot) => [
        for (final e in _slots.entries)
          if (e.value == slot) e.key,
      ];

  bool get isEmpty => _slots.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is SpeakerSlots && mapEquals(_slots, other._slots);

  @override
  int get hashCode => Object.hashAllUnordered(
        [for (final e in _slots.entries) Object.hash(e.key, e.value)],
      );
}

/// The slot a user would take if nobody else wanted it — FNV-1a over the id,
/// which spreads short Convex ids evenly and, being a pure function of the id
/// alone, is what makes one person's colour travel with them between rooms.
int speakerPreferredSlot(String userId) {
  var h = 0x811c9dc5;
  for (final c in userId.codeUnits) {
    h = (h ^ c) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h % kSpeakerSlotCount;
}

/// Speaker colours, derived from the active theme rather than authored nine
/// times over.
///
/// An extension for the same reason [BubbleGeometry] is one: every theme
/// *implements* [AppTheme], so a new member on the interface would land on
/// all of them as a compile error. Deriving also means a theme added tomorrow
/// gets speaker colours for free, and gets them in its own register — the
/// saturation comes from the theme's accent, so Vault Noir's speakers are as
/// muted as Vault Noir is and Cyberpunk's are as loud.
extension SpeakerPalette on AppTheme {
  /// The ink a speaker's name is written in: WCAG AA (4.5:1) against [on],
  /// because this is small text and it has to be *read*, not just noticed.
  Color speakerInk(int slot, {required Color on}) =>
      _speakerColor(this, slot, on: on, target: 4.5);

  /// The colour of a mark rather than a word — an avatar ring, a reply
  /// tether, a quote card's rail. 3:1, the floor for a non-text object, which
  /// leaves it more saturated than [speakerInk] and reading as *colour*.
  Color speakerMark(int slot, {required Color on}) =>
      _speakerColor(this, slot, on: on, target: 3.0);

  /// [surface], washed with enough of the speaker's colour to be recognisable
  /// and not enough to fight the text on top of it.
  ///
  /// The alpha is low on purpose. What has to survive is the ORDER of the
  /// wash against its neighbours — a reader tells two speakers apart by
  /// comparing two bubbles on screen, not by naming a colour — and body ink
  /// has to stay at full contrast over it. `speaker_colors_test.dart` asserts
  /// the second half of that on every theme.
  Color speakerWash(int slot, {required Color surface, double alpha = 0.13}) {
    final base = _opaque(this, surface);
    return Color.alphaBlend(
      speakerMark(slot, on: base).withValues(alpha: alpha),
      base,
    );
  }
}

/// Composites a translucent theme surface (Bio-Organic's is 70% opaque) over
/// the background it actually sits on, so contrast is measured against the
/// pixels a reader sees rather than against a colour nothing paints.
Color _opaque(AppTheme theme, Color on) =>
    on.a >= 1.0 ? on : Color.alphaBlend(on, theme.background);

/// Conditioned colours are pure functions of four small values and are asked
/// for once per bubble per frame, so they are memoised. Bounded by
/// (themes × slots × surfaces × two targets) — a few hundred entries at the
/// absolute worst, and in practice a couple of dozen.
final Map<int, Color> _conditioned = <int, Color>{};

Color _speakerColor(
  AppTheme theme,
  int slot, {
  required Color on,
  required double target,
}) {
  final base = _opaque(theme, on);
  // Keyed on the actual INPUTS, not on the theme's name: the accent is what
  // sets saturation below, and two Basic variants differ by nothing else this
  // function reads. Keying on `id` alone would be correct today and quietly
  // wrong the first time a theme changed its accent without changing its id.
  final key = Object.hash(slot % kSpeakerSlotCount, base.toARGB32(),
      theme.accent.toARGB32(), target);
  final hit = _conditioned[key];
  if (hit != null) return hit;

  // The theme's own accent sets how loud its speakers are. Floored at 0.45
  // because a theme with a near-grey accent would otherwise hand out twelve
  // shades of the same grey and differentiate nothing at all — which is the
  // one outcome this whole file exists to prevent.
  final saturation =
      HSLColor.fromColor(theme.accent).saturation.clamp(0.45, 0.95);
  final result = _condition(
    hue: _hueForSlot(slot % kSpeakerSlotCount),
    saturation: saturation,
    on: base,
    target: target,
  );
  _conditioned[key] = result;
  return result;
}

/// Walks lightness away from [on] until the hue clears [target] contrast.
///
/// Lightness rather than saturation because desaturating to gain contrast
/// throws away the only thing the colour is carrying. Sixteen steps of 0.03
/// spans the whole usable range, and every hue in [_kHues] clears 4.5:1 well
/// inside it on both a near-black and a cream ground.
Color _condition({
  required double hue,
  required double saturation,
  required Color on,
  required double target,
}) {
  final onDark = on.computeLuminance() < 0.5;
  // Start where the answer usually is, so the common case never loops.
  var lightness = onDark ? 0.62 : 0.42;
  final step = onDark ? 0.03 : -0.03;
  var color = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  for (var i = 0; i < 16 && speakerContrast(color, on) < target; i++) {
    lightness = (lightness + step).clamp(0.08, 0.97);
    color = HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  }
  return color;
}

/// WCAG relative-luminance contrast between two opaque colours.
///
/// Public because the tests that hold this file to its promises need the same
/// arithmetic the file used to make them.
@visibleForTesting
double speakerContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
