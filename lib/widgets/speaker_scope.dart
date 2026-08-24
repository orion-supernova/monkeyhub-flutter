import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';
import '../theme/speaker_colors.dart';
import '../theme/theme_scope.dart';

// Re-exported so a screen that installs a scope needs one import rather than
// two: the assignment and the widget that carries it are the same idea.
export '../theme/speaker_colors.dart' show SpeakerSlots, SpeakerTint;

/// The colour each person in the surrounding room speaks in.
///
/// Inherited rather than threaded because the answer is wanted in a dozen
/// places that have nothing to do with each other — a sender name, a bubble
/// fill, an avatar ring, a reply tether pointing at someone else's message,
/// an @-mention naming a third person. Every one of those already knows the
/// user id it is about; none of them wants a colour parameter passed down
/// through six constructors to reach it.
///
/// Install one per transcript. It has to be re-installed at every surface
/// that renders bubbles outside the room's own tree — the thread overlay and
/// the lifted preview in the action menu both mount into the ROOT overlay,
/// where the room's scope is not an ancestor. A bubble that misses the scope
/// degrades to plain theme ink rather than misbehaving, but it also stops
/// matching the row it lifted off, which reads as a bug.
class SpeakerScope extends InheritedWidget {
  const SpeakerScope({
    super.key,
    required this.slots,
    required super.child,
  });

  final SpeakerSlots slots;

  /// The room's assignment, or [SpeakerSlots.none] outside one. Never null, so
  /// no caller has to branch on "am I in a room".
  static SpeakerSlots of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpeakerScope>()?.slots ??
      SpeakerSlots.none;

  /// The ink [userId]'s NAME is written in, or null to leave it in theme ink.
  ///
  /// Null covers every "no colour here" case at once: the feature is off, this
  /// is a DM, the id is the viewer's own, or the sender has left the room.
  static Color? inkOf(
    BuildContext context,
    String? userId, {
    required Color on,
  }) {
    final slot = _slotOf(context, userId, atLeast: SpeakerTint.name);
    if (slot == null) return null;
    return ThemeScope.of(context).speakerInk(slot, on: on);
  }

  /// The colour of a MARK belonging to [userId] — an avatar ring, a reply
  /// tether, the rail down a quote card. Louder than [inkOf]; see
  /// [SpeakerPalette.speakerMark].
  static Color? markOf(
    BuildContext context,
    String? userId, {
    required Color on,
  }) {
    final slot = _slotOf(context, userId, atLeast: SpeakerTint.name);
    if (slot == null) return null;
    return ThemeScope.of(context).speakerMark(slot, on: on);
  }

  /// [surface], washed with [userId]'s colour — null unless the reader has
  /// asked for the colour to reach into the bubbles themselves.
  ///
  /// This is the one lookup gated on [SpeakerTint.bubble]: it is the rung that
  /// changes what a message looks like rather than what its label looks like.
  static Color? washOf(
    BuildContext context,
    String? userId, {
    required Color surface,
  }) {
    final slot = _slotOf(context, userId, atLeast: SpeakerTint.bubble);
    if (slot == null) return null;
    return ThemeScope.of(context).speakerWash(slot, surface: surface);
  }

  /// The raw slot, gated on the reader's preference. Reading [SettingsStore]
  /// here rather than carrying the level on the scope keeps the two live
  /// wires apart: the scope changes when the ROSTER changes, the preference
  /// changes when the reader changes it, and every bubble is already inside an
  /// `AnimatedBuilder` on the store for the bubble-shape preference — so a
  /// change to either repaints without a third listener.
  static int? _slotOf(
    BuildContext context,
    String? userId, {
    required SpeakerTint atLeast,
  }) {
    if (userId == null || userId.isEmpty) return null;
    if (SettingsStore.instance.speakerTint.index < atLeast.index) return null;
    return of(context).slotOf(userId);
  }

  @override
  bool updateShouldNotify(SpeakerScope oldWidget) =>
      oldWidget.slots != slots;
}
