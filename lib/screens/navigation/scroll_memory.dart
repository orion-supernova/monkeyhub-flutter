import 'package:flutter/widgets.dart';

/// Remembers where a section was scrolled to, across the rebuild a tab switch
/// causes — and restores it CLAMPED, so the restore cannot overshoot.
///
/// `home_shell._section()` builds a brand-new widget every time the tab
/// changes, and `SectionSwitcher` is built to discard the outgoing one, so each
/// section's State is destroyed and recreated on every switch. Scroll position
/// survived only through `PageStorageKey`, and that is where the bounce came
/// from:
///
///   1. `ScrollPosition.restoreScrollOffset` applies the saved pixels before
///      the content has been laid out, so nothing yet knows the extent.
///   2. `applyContentDimensions` then finds the offset out of range and calls
///      `goBallistic` to fix it.
///   3. Under bouncing physics, "fix it" is an ANIMATION — the little settle
///      you see when returning to a list you had scrolled to the bottom of.
///
/// Any change in content height between the two mounts is enough to trigger it,
/// and there are plenty: a room arriving, a header measuring differently, or a
/// padding change like the safe-area one that made this visible in the first
/// place.
///
/// So: turn Flutter's restore off (`keepScrollOffset: false` on the
/// controller), keep the offset here instead, and re-apply it with `jumpTo`
/// AFTER layout, clamped to the extent that actually exists. A jump has no
/// ballistic phase, so there is nothing to animate.
///
/// The trade, chosen deliberately: position stays APPROXIMATE. If the content
/// got shorter, you land at the new bottom rather than where you were. That is
/// the same answer the old code reached — it just arrives without the wobble.
///
/// Exact restoration needs the section's State to survive the switch
/// (`IndexedStack` or a keep-alive), which is a bigger change: it would keep
/// all four trees resident and needs a refresh-on-visible hook so Discover
/// does not go stale.
class ScrollMemory {
  ScrollMemory._();

  /// Offsets by section key. Static because the State that owns the scroller
  /// is exactly what does NOT survive — anything instance-scoped would be
  /// thrown away with it.
  ///
  /// Four entries at most, one per section, so it never needs eviction.
  static final Map<String, double> _offsets = <String, double>{};

  /// A controller that does not participate in `PageStorage` restoration.
  ///
  /// Without this the framework restores too, un-clamped, and the bounce comes
  /// straight back — the two mechanisms would be fighting over the same
  /// position.
  static ScrollController controller() =>
      ScrollController(keepScrollOffset: false);

  /// Wire a section's scroller up: restores the last offset, and keeps
  /// recording the current one from here on.
  ///
  /// Call from `initState`.
  ///
  /// **Recording continuously, not saving in `dispose`.** The first version
  /// saved on dispose and lost the position every single time, because by then
  /// the controller has no clients: `SectionSwitcher` removes the outgoing
  /// section from the tree to cross-fade it, and `hasClients` goes false at
  /// removal — well before `State.dispose` runs. The save read nothing, wrote
  /// nothing, and reported nothing.
  ///
  /// A listener sidesteps the whole question of when teardown happens: the
  /// offset on record is always the last one the user actually scrolled to.
  /// The cost is a map write per scroll notification, which is a rounding
  /// error next to the layout those notifications accompany.
  static void attach(String key, ScrollController c) {
    restore(key, c);
    c.addListener(() {
      if (c.hasClients) _offsets[key] = c.position.pixels;
    });
  }

  /// Overwrites what a section has on record.
  ///
  /// The listener [attach] installs covers every ordinary scroll, because
  /// every ordinary scroll notifies. A [ScrollPosition.correctBy] — the
  /// layout-level offset fix, used on the chat list when the pull-reveal
  /// panel is dropped out from above the viewport — deliberately notifies
  /// nobody, and would otherwise leave the record pointing at an offset
  /// measured against content that no longer exists.
  static void record(String key, double pixels) => _offsets[key] = pixels;

  /// Applies the remembered offset after the first layout, so there is a real
  /// extent to clamp against.
  static void restore(String key, ScrollController c) {
    final saved = _offsets[key];
    if (saved == null || saved <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!c.hasClients) return;
      final p = c.position;
      final target = saved.clamp(p.minScrollExtent, p.maxScrollExtent);
      // Already there — a jump would be a no-op that still notifies listeners,
      // and several of these sections drive chrome off scroll notifications.
      if ((p.pixels - target).abs() < 0.5) return;
      c.jumpTo(target);
    });
  }
}
