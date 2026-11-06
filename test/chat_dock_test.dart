import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/scheduled_message.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_bottom_inset.dart';
import 'package:monkeyhub/widgets/chat_dock.dart';
import 'package:monkeyhub/widgets/glass_pill.dart';
import 'package:monkeyhub/widgets/scheduled_pill.dart';

/// The bottom dock's lanes and the collision table in
/// `docs/design/swipe-up-fork.html#dock`.
///
/// The cards, the picker and the field are keyed stand-ins: the dock owns
/// ORDER, CAPACITY and COLLAPSE, none of which depend on what is inside them.
/// The scheduled pill is the real one because it is the only shelf item that
/// exists today.

const kFieldKey = ValueKey('field');
const kReplyKey = ValueKey('reply');
const kEditKey = ValueKey('edit');
const kMentionKey = ValueKey('mention');
const kBarKey = ValueKey('selection-bar');
const kDummyBarKey = ValueKey('dummy-huddle-bar');

Widget _box(Key key, double h, Color c, [String? label]) => Container(
      key: key,
      height: h,
      color: c,
      alignment: Alignment.center,
      child: label == null ? null : Text(label),
    );

ScheduledMessage _sm({bool pending = true, String? failedReason}) =>
    ScheduledMessage(
      id: 'sm1',
      roomId: 'r1',
      content: 'hello',
      sendAt: DateTime(2030, 1, 1, 18),
      createdAt: DateTime(2029, 12, 31, 9),
      pending: pending,
      failedReason: failedReason,
    );

/// The real scheduled pill, registered the way room_screen registers it.
DockShelfItem scheduledItem({int priority = DockShelfPriority.scheduled}) =>
    DockShelfItem(
      id: 'scheduled',
      priority: priority,
      expanded: (_) => ScheduledPill(scheduled: [_sm()], onTap: () {}),
      chip: (_) => DockShelfChip(
        icon: CupertinoIcons.clock,
        count: 1,
        semanticLabel: 'scheduled',
        onTap: () {},
      ),
    );

/// Stands in for a future huddle bar: a wide item that outranks everything.
DockShelfItem dummyHuddle() => DockShelfItem(
      id: 'huddle',
      priority: DockShelfPriority.huddle,
      expanded: (_) => Container(
        key: kDummyBarKey,
        height: 34,
        width: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Text('HUDDLE  3 here',
            style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 13)),
      ),
      chip: (_) => const SizedBox(height: 40, child: Text('H')),
    );

/// A dock on a 400pt-wide screen, anchored bottom like the room's.
Widget buildScene({
  bool reply = false,
  bool edit = false,
  bool mentionOpen = false,
  bool selection = false,
  bool recording = false,
  List<DockShelfItem> shelf = const [],
  ValueNotifier<double>? fade,
  ChatBottomInset? inset,
}) {
  Widget dock = ChatDock(
    dockFade: fade,
    mentionOpen: mentionOpen,
    recording: recording,
    shelf: shelf,
    edit: edit ? _box(kEditKey, 48, const Color(0xFFE0A030), 'EDIT') : null,
    reply: reply ? _box(kReplyKey, 48, const Color(0xFF3070E0), 'REPLY') : null,
    mention: mentionOpen
        ? _box(kMentionKey, 120, const Color(0xFF8040C0), 'MENTION')
        : null,
    field: _box(kFieldKey, 52, const Color(0xFF606060), 'FIELD'),
  );
  // Selection mode swaps the whole dock for the bar (room_screen does this
  // ternary around ChatDock, in both chat styles).
  if (selection) dock = _box(kBarKey, 52, const Color(0xFFC03030), 'SELECTED');
  if (inset != null) {
    dock = MeasureChatBottomInset(
      inset: inset,
      which: ChatChromeHeight.target,
      child: dock,
    );
  }
  return MediaQuery(
    data: const MediaQueryData(size: Size(400, 600)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(
          backgroundColor: const Color(0xFF101418),
          body: Align(alignment: Alignment.bottomCenter, child: dock),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('recording hides the shelf and the context lane, keeps the field',
      (t) async {
    await t.pumpWidget(
        buildScene(reply: true, shelf: [scheduledItem()], recording: true));
    expect(find.byType(ScheduledPill), findsNothing);
    expect(find.byKey(kReplyKey), findsNothing);
    expect(find.byKey(kFieldKey), findsOneWidget);
    // Recording ends: both come back.
    await t.pumpWidget(buildScene(reply: true, shelf: [scheduledItem()]));
    await t.pumpAndSettle();
    expect(find.byType(ScheduledPill), findsOneWidget);
    expect(find.byKey(kReplyKey), findsOneWidget);
  });

  double top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;
  double bottom(WidgetTester t, Finder f) => t.getBottomLeft(f).dy;

  testWidgets('reply card sits on the field; scheduled pill is above the card',
      (t) async {
    await t.pumpWidget(buildScene(reply: true, shelf: [scheduledItem()]));
    final pill = find.byType(ScheduledPill);
    expect(pill, findsOneWidget);
    // Top to bottom: pill, reply, field. The old bug put the pill last-but-one.
    expect(bottom(t, pill), lessThanOrEqualTo(top(t, find.byKey(kReplyKey))));
    expect(bottom(t, find.byKey(kReplyKey)),
        closeTo(top(t, find.byKey(kFieldKey)), 0.01));
  });

  testWidgets('shelf with two items: top takes the width, the other is a chip',
      (t) async {
    await t.pumpWidget(buildScene(shelf: [scheduledItem(), dummyHuddle()]));
    // Registration order does not matter: priority does.
    expect(find.byKey(kDummyBarKey), findsOneWidget);
    expect(find.byType(ScheduledPill), findsNothing);
    final chip = find.byType(DockShelfChip);
    expect(chip, findsOneWidget);
    expect(t.getSize(chip).width, greaterThanOrEqualTo(kDockChipWidth));
    expect(t.getSize(chip).width, lessThan(kDockChipWidth + 20));
    // Same row: the chip is right of the bar and they overlap vertically.
    expect(t.getTopLeft(chip).dx,
        greaterThan(t.getTopRight(find.byKey(kDummyBarKey)).dx));
    final row = t.getRect(find.byType(DockShelfChip));
    final bar = t.getRect(find.byKey(kDummyBarKey));
    expect(row.top < bar.bottom && bar.top < row.bottom, isTrue);
    // One row only: the shelf is exactly one slot tall.
    expect(
        t.getSize(find.byType(ChatDock)).height, kDockShelfHeight + 52);
  });

  testWidgets('a tall top item sizes the row; chips stay 44 wide, centred',
      (t) async {
    final tall = DockShelfItem(
      id: 'huddle',
      priority: DockShelfPriority.huddle,
      height: 86,
      expanded: (_) => const SizedBox(key: kDummyBarKey, height: 74, width: 240),
      chip: (_) => const SizedBox.shrink(),
    );
    await t.pumpWidget(buildScene(shelf: [scheduledItem(), tall]));
    expect(t.getSize(find.byType(ChatDock)).height, 86 + 52);
    final chip = t.getRect(find.byType(DockShelfChip));
    final bar = t.getRect(find.byKey(kDummyBarKey));
    expect(chip.center.dy, closeTo(bar.center.dy, 1.0));
    expect(chip.width, lessThan(kDockChipWidth + 20));
  });

  testWidgets('shelf with one item is exactly the old centred pill',
      (t) async {
    await t.pumpWidget(buildScene(shelf: [scheduledItem()]));
    expect(find.byType(DockShelfChip), findsNothing);
    expect(t.getSize(find.byType(ChatDock)).height, kDockShelfHeight + 52);
    expect(t.getCenter(find.byType(GlassPill)).dx, closeTo(t.getCenter(find.byType(ChatDock)).dx, 0.01));
  });

  testWidgets('mention picker open hides the shelf; closing brings it back',
      (t) async {
    await t.pumpWidget(buildScene(shelf: [scheduledItem()]));
    expect(find.byType(ScheduledPill), findsOneWidget);
    await t.pumpWidget(
        buildScene(mentionOpen: true, shelf: [scheduledItem()]));
    expect(find.byType(ScheduledPill), findsNothing);
    expect(find.byKey(kMentionKey), findsOneWidget);
    await t.pumpWidget(buildScene(shelf: [scheduledItem()]));
    expect(find.byType(ScheduledPill), findsOneWidget);
  });

  testWidgets('selection mode replaces the whole dock', (t) async {
    await t.pumpWidget(
        buildScene(selection: true, reply: true, shelf: [scheduledItem()]));
    expect(find.byKey(kBarKey), findsOneWidget);
    expect(find.byType(ChatDock), findsNothing);
    expect(find.byType(ScheduledPill), findsNothing);
    expect(find.byKey(kFieldKey), findsNothing);
  });

  testWidgets('edit wins over reply: the context lane holds one card',
      (t) async {
    await t.pumpWidget(buildScene(edit: true, reply: true));
    expect(find.byKey(kEditKey), findsOneWidget);
    expect(find.byKey(kReplyKey), findsNothing);
    expect(bottom(t, find.byKey(kEditKey)),
        closeTo(top(t, find.byKey(kFieldKey)), 0.01));
  });

  testWidgets('the measured box covers every lane', (t) async {
    final inset = ChatBottomInset();
    addTearDown(inset.dispose);
    await t.pumpWidget(
        buildScene(reply: true, shelf: [scheduledItem()], inset: inset));
    await t.pump();
    expect(inset.height, kDockShelfHeight + 48 + 52);
  });

  testWidgets('dockFade dims the dock, swaps glass for its still twin, and '
      'stops taps', (t) async {
    final fade = ValueNotifier<double>(1);
    addTearDown(fade.dispose);
    await t.pumpWidget(buildScene(shelf: [scheduledItem()], fade: fade));
    double opacity() =>
        t.widget<Opacity>(find.descendant(
            of: find.byType(ChatDock), matching: find.byType(Opacity))
            .first).opacity;
    expect(opacity(), 1);
    fade.value = 0.4;
    await t.pump();
    expect(opacity(), closeTo(0.4, 1e-9));
    expect(
        t
            .widget<IgnorePointer>(find
                .descendant(
                    of: find.byType(ChatDock),
                    matching: find.byType(IgnorePointer))
                .first)
            .ignoring,
        isTrue);
  });
}
