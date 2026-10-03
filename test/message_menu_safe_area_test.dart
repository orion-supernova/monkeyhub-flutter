import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_surface.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/widgets/reaction_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this pins: on a phone with a Dynamic Island, with the keyboard up, the
/// long-press menu and the full emoji picker both lay out INSIDE the band
/// between the island and the top of the keyboard.
///
/// Both used to read a MediaQuery that somebody else had already spent:
/// * the menu is a ROOT-OVERLAY entry but was handed `MediaQuery.paddingOf` from
///   the tapped bubble's context — and the classic chat style wraps the room in
///   a `SafeArea`, which consumes the top padding (and `viewPadding.top` with
///   it). The menu believed the screen started at y=0.
/// * the picker is a bottom-sheet route, and `ModalBottomSheetRoute.buildPage`
///   wraps its content in `MediaQuery.removePadding(removeTop: true)` — so from
///   inside the sheet the island does not exist either, and a `SafeArea` added
///   in there would be a silent no-op.
///
/// Hence the shape of these tests: the geometry is injected with a `MediaQuery`
/// wrapping `MaterialApp` (the root overlay and the sheet route both live under
/// it) rather than faked on `tester.view` — reading a view directly is exactly
/// the escape hatch this fix removed, and a test that used one could not tell
/// whether the widget honoured its own MediaQuery.
void main() {
  // iPhone 15 Pro in points, and the insets it reports.
  const screen = Size(393, 852);
  const islandTop = 59.0;
  const homeIndicator = 34.0;
  const keyboard = 336.0;

  // The row set every menu in this file opens with: someone else's ordinary
  // message — REPLY / FORWARD / COPY / PIN / SELECT / VIEW PROFILE / REPORT,
  // the same seven rows the flat booleans used to produce.
  final caps = MessageCapabilities.none.copyWith(
    canReply: true,
    canForward: true,
    canCopy: true,
    canPin: true,
    canSelect: true,
    canViewProfile: true,
    canReport: true,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Bounded stand-in for `pumpAndSettle`. This menu re-fits its geometry in
  /// post-frame callbacks, where `pumpAndSettle` can spin instead of failing;
  /// non-convergence has to be a red test, not a hung one.
  Future<void> settle(WidgetTester tester, {int maxFrames = 200}) async {
    for (var i = 0; i < maxFrames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.binding.hasScheduledFrame) return;
    }
    fail('layout never converged within $maxFrames frames');
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int maxFrames = 200,
  }) async {
    for (var i = 0; i < maxFrames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (finder.evaluate().isNotEmpty) {
        await settle(tester);
        return;
      }
    }
    fail('never appeared within $maxFrames frames: $finder');
  }

  /// The room, roughly: a `Scaffold` whose body is inside a `SafeArea` (the
  /// classic chat style) with a bubble pinned to the top of the transcript —
  /// the worst case, because it is the bubble closest to the island.
  ///
  /// `ThemeScope` above `MaterialApp`, as app.dart wires it: the menu inserts
  /// into the ROOT overlay, so a scope nested under `home` would not be an
  /// ancestor of the thing that has to read it.
  Widget host({
    required GlobalKey anchor,
    required VoidCallback onTap,
    required EdgeInsets viewPadding,
    required EdgeInsets padding,
    required EdgeInsets viewInsets,
  }) {
    return ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewPadding: viewPadding,
            padding: padding,
            viewInsets: viewInsets,
          ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: SizedBox(key: anchor, width: 220, height: 60),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The glass card that holds [text] — the reaction pill for an emoji, the
  /// action list for a row label.
  Rect cardAround(WidgetTester tester, String text) => tester.getRect(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(GlassSurface),
            )
            .first,
      );

  Future<void> openMenu(WidgetTester tester, GlobalKey anchor) async {
    await tester.tap(find.byKey(anchor), warnIfMissed: false);
    await pumpUntil(tester, find.text('REPLY'));
  }

  /// Everything the menu shows has to be inside the band, not just its box:
  /// the pill and the list are positioned separately and only agree because
  /// they are clamped as a unit.
  void expectMenuInBand(
    WidgetTester tester, {
    required double bandTop,
    required double bandBottom,
  }) {
    final pill = cardAround(tester, '👍');
    final list = cardAround(tester, 'REPLY');
    expect(pill.top, greaterThanOrEqualTo(bandTop - 0.5),
        reason: 'the reaction pill is under the island');
    expect(pill.bottom, lessThanOrEqualTo(bandBottom + 0.5),
        reason: 'the reaction pill is under the keyboard');
    expect(list.top, greaterThanOrEqualTo(bandTop - 0.5),
        reason: 'the action list is under the island');
    expect(list.bottom, lessThanOrEqualTo(bandBottom + 0.5),
        reason: 'the action list is under the keyboard');
    // Not two boxes stacked on the same pixels: clamping them separately is
    // what used to put the list on top of the quick reactions.
    expect(pill.bottom, lessThanOrEqualTo(list.top + 0.5));
  }

  testWidgets(
      'island + keyboard: the menu and the emoji picker stay inside the band',
      (tester) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final anchor = GlobalKey();
    late BuildContext roomContext;
    String? pickedEmoji;

    await tester.pumpWidget(host(
      anchor: anchor,
      // padding.bottom is zero, not 34: iOS folds the home indicator into the
      // keyboard once the keys cover it, and a menu that added the two would
      // hold itself 34pt off a keyboard it is already clear of.
      viewPadding: const EdgeInsets.only(top: islandTop, bottom: homeIndicator),
      padding: const EdgeInsets.only(top: islandTop),
      viewInsets: const EdgeInsets.only(bottom: keyboard),
      onTap: () async {
        final result = await showMessageActionMenu(
          context: roomContext,
          anchorKey: anchor,
          bubbleBuilder: (_) => const SizedBox(width: 220, height: 60),
          isMine: false,
          capabilities: caps,
        );
        if (result?.openFullReactionPicker ?? false) {
          pickedEmoji = await showReactionPicker(roomContext);
        }
      },
    ));
    roomContext = tester.element(find.byKey(anchor));

    await openMenu(tester, anchor);
    expect(tester.takeException(), isNull);

    const bandTop = islandTop;
    const bandBottom = 852.0 - keyboard;
    expectMenuInBand(tester, bandTop: bandTop, bandBottom: bandBottom);

    // Now the other half: `+` swaps the pill for the full picker, which is a
    // bottom-sheet route and therefore reads a DIFFERENT MediaQuery than the
    // menu just did — one with the top padding already removed.
    await tester.tap(find.byIcon(CupertinoIcons.plus), warnIfMissed: false);
    await pumpUntil(tester, find.byType(EmojiPicker));

    // The SHEET's own top edge, not just the grid's: the panel's rounded top,
    // its drag handle and its REACT title are the first things the island eats,
    // and a grid that happens to start a few points lower is not the fix.
    final sheet = tester.getRect(find.byType(ReactionPickerSheet));
    expect(sheet.top, greaterThanOrEqualTo(bandTop - 0.5),
        reason: 'the picker sheet is drawn under the Dynamic Island');
    expect(tester.getRect(find.text('React')).top,
        greaterThanOrEqualTo(bandTop - 0.5));

    final grid = tester.getRect(find.byType(EmojiPicker));
    expect(grid.top, greaterThanOrEqualTo(bandTop - 0.5),
        reason: 'the emoji grid is under the Dynamic Island');
    expect(grid.bottom, lessThanOrEqualTo(bandBottom + 0.5),
        reason: 'the emoji grid runs under the keyboard');
    expect(grid.height, greaterThan(0),
        reason: 'a picker clamped to nothing is not a fix');
    expect(tester.takeException(), isNull);
    expect(pickedEmoji, isNull);
  });

  testWidgets('island, no keyboard: the band runs to the home indicator',
      (tester) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final anchor = GlobalKey();
    late BuildContext roomContext;

    await tester.pumpWidget(host(
      anchor: anchor,
      viewPadding: const EdgeInsets.only(top: islandTop, bottom: homeIndicator),
      padding: const EdgeInsets.only(top: islandTop, bottom: homeIndicator),
      viewInsets: EdgeInsets.zero,
      onTap: () async {
        final result = await showMessageActionMenu(
          context: roomContext,
          anchorKey: anchor,
          bubbleBuilder: (_) => const SizedBox(width: 220, height: 60),
          isMine: false,
          capabilities: caps,
        );
        if (result?.openFullReactionPicker ?? false) {
          await showReactionPicker(roomContext);
        }
      },
    ));
    roomContext = tester.element(find.byKey(anchor));

    await openMenu(tester, anchor);
    expectMenuInBand(
      tester,
      bandTop: islandTop,
      bandBottom: 852.0 - homeIndicator,
    );

    await tester.tap(find.byIcon(CupertinoIcons.plus), warnIfMissed: false);
    await pumpUntil(tester, find.byType(EmojiPicker));

    expect(tester.getRect(find.byType(ReactionPickerSheet)).top,
        greaterThanOrEqualTo(islandTop - 0.5));
    final grid = tester.getRect(find.byType(EmojiPicker));
    expect(grid.top, greaterThanOrEqualTo(islandTop - 0.5));
    expect(grid.bottom, lessThanOrEqualTo(852.0));
    // With the keyboard away the picker gets more room than it did with the
    // keys up — the clamp is a response to the insets, not a permanent cap.
    expect(grid.height, greaterThan(360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the keyboard coming up under an open menu re-fits it',
      (tester) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final anchor = GlobalKey();
    late BuildContext roomContext;
    var insets = EdgeInsets.zero;
    late StateSetter setInsets;

    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: StatefulBuilder(
          builder: (context, setState) {
            setInsets = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewPadding: const EdgeInsets.only(
                  top: islandTop,
                  bottom: homeIndicator,
                ),
                padding: EdgeInsets.only(
                  top: islandTop,
                  bottom: insets.bottom > 0 ? 0 : homeIndicator,
                ),
                viewInsets: insets,
              ),
              child: MaterialApp(
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SafeArea(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Builder(
                        builder: (ctx) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            roomContext = ctx;
                            showMessageActionMenu(
                              context: roomContext,
                              anchorKey: anchor,
                              bubbleBuilder: (_) =>
                                  const SizedBox(width: 220, height: 60),
                              isMine: false,
                              capabilities: caps,
                            );
                          },
                          child: SizedBox(key: anchor, width: 220, height: 60),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await openMenu(tester, anchor);
    expectMenuInBand(
      tester,
      bandTop: islandTop,
      bandBottom: 852.0 - homeIndicator,
    );

    // The keys arrive under a menu that is already up. Nothing re-invokes
    // `showMessageActionMenu`, so the only thing that can save this is the
    // overlay depending on the MediaQuery rather than a snapshot of it.
    for (final step in [80.0, 200.0, keyboard]) {
      setInsets(() => insets = EdgeInsets.only(bottom: step));
      await settle(tester);
      expectMenuInBand(
        tester,
        bandTop: islandTop,
        bandBottom: 852.0 - step,
      );
    }

    // And back down again.
    setInsets(() => insets = EdgeInsets.zero);
    await settle(tester);
    expectMenuInBand(
      tester,
      bandTop: islandTop,
      bandBottom: 852.0 - homeIndicator,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape: the menu clears the sensor housing on the side',
      (tester) async {
    // Rotated, the island is a side inset rather than a top one, and the
    // keyboard is a much larger share of a much shorter viewport.
    tester.view
      ..physicalSize = const Size(852, 393)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final anchor = GlobalKey();
    late BuildContext roomContext;

    await tester.pumpWidget(host(
      anchor: anchor,
      viewPadding: const EdgeInsets.only(left: islandTop, right: islandTop, bottom: 21),
      padding: const EdgeInsets.only(left: islandTop, right: islandTop),
      viewInsets: const EdgeInsets.only(bottom: 190),
      onTap: () async => showMessageActionMenu(
        context: roomContext,
        anchorKey: anchor,
        bubbleBuilder: (_) => const SizedBox(width: 220, height: 60),
        isMine: false,
        capabilities: caps,
      ),
    ));
    roomContext = tester.element(find.byKey(anchor));

    await openMenu(tester, anchor);
    expect(tester.takeException(), isNull);

    expectMenuInBand(tester, bandTop: 0, bandBottom: 393.0 - 190.0);
    for (final rect in [cardAround(tester, '👍'), cardAround(tester, 'REPLY')]) {
      expect(rect.left, greaterThanOrEqualTo(islandTop - 0.5),
          reason: 'a leading edge under the sensor housing');
      expect(rect.right, lessThanOrEqualTo(852.0 - islandTop + 0.5));
    }

    // 203pt of band, and the list wants ~348: it has to scroll rather than
    // shrink its rows or run off the edge.
    expect(find.byType(RawScrollbar), findsOneWidget);
  });
}
