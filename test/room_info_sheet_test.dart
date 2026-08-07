import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/join_room_sheet.dart';

/// The sheet a public room row opens for a stranger is the one place that room
/// gets to describe itself in full. The rows are lists and cap what they show —
/// two lines of name, two of description, a pill where a sentence would go — so
/// everything they had to abbreviate has to survive here, uncapped.
void main() {
  const longName =
      'the ankara thursday coffee and long walks appreciation society';
  const longDescription =
      'we meet on thursdays at seven, usually at the place near the station, '
      'and we walk for an hour before anyone orders anything. newcomers are '
      'welcome and there is no obligation to say anything at all for the first '
      'few weeks — plenty of us did exactly that.';

  ChatRoom room({
    String name = longName,
    String? description = longDescription,
    bool hasPassword = false,
    Duration? lifetime,
  }) => ChatRoom(
    id: 'r1',
    name: name,
    description: description,
    createdBy: 'u1',
    createdAt: DateTime(2026, 3, 4),
    isPrivate: false,
    memberCount: 12,
    hasPassword: hasPassword,
    type: lifetime == null ? RoomType.regular : RoomType.secret,
    messageLifetime: lifetime,
  );

  // Nothing in the sheet fetches: these rooms carry no avatar, which is also
  // the case the glyph fallback exists for.
  final api = ChatApi(ConvexBackend.instance);

  /// Opens the sheet and settles it. [windowClass] picks which form of it —
  /// compact is the bottom sheet, expanded the desktop popover, and the two take
  /// different paths through `showAdaptiveSheet`.
  Future<void> open(
    WidgetTester tester,
    ChatRoom r, {
    WindowClass windowClass = WindowClass.compact,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    // Both scopes sit above [MaterialApp]: the sheet is a route on its
    // navigator, so anything below `home:` is out of its reach — which is how
    // the app itself wires them.
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: LayoutScope(
          windowClass: windowClass,
          width: size.width,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showJoinRoomSheet(context, r, api),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('prints the name and the description whole', (tester) async {
    await open(tester, room());
    // No line cap and no ellipsis: a name too long for the rows is exactly the
    // name someone opened this to read.
    final name = tester.widget<Text>(find.text(longName));
    expect(name.maxLines, isNull);
    expect(name.overflow, isNot(TextOverflow.ellipsis));

    final description = tester.widget<Text>(find.text(longDescription));
    expect(description.maxLines, isNull);
    expect(description.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('says what each of the row pills meant', (tester) async {
    await open(
      tester,
      room(hasPassword: true, lifetime: const Duration(minutes: 5)),
    );
    final l10n = AppLocalizationsEn();
    expect(find.text(l10n.roomInfoSheetDetailsLabel), findsOneWidget);
    // A padlock on a row says there is something to know; only the sentence
    // says what to do about it.
    expect(find.text(l10n.roomBadgeLockedTooltip), findsOneWidget);
    expect(find.text(l10n.roomBadgePublicTooltip), findsOneWidget);
    expect(find.text(l10n.roomBadgeEphemeralTooltip('5m')), findsOneWidget);
    expect(find.text(l10n.roomInfoSheetCreatedLabel), findsOneWidget);
  });

  testWidgets('a room that never described itself says so', (tester) async {
    await open(tester, room(description: null));
    expect(
      find.text(AppLocalizationsEn().roomInfoSheetNoDescription),
      findsOneWidget,
    );
  });

  testWidgets('keeps the join button reachable under a long description', (
    tester,
  ) async {
    // The room's own account of itself scrolls; the action never does. On a
    // short window this is the difference between a joinable room and a wall of
    // text with the button pushed off the bottom.
    await open(tester, room(), size: const Size(360, 560));
    expect(tester.takeException(), isNull);
    expect(find.text(AppLocalizationsEn().groupCallBannerJoinRoomButtonLabel),
        findsOneWidget);
  });

  testWidgets('the desktop popover form is bounded too', (tester) async {
    // That form hands its content unbounded height, where an unconstrained
    // scroll view inside it would throw rather than scroll.
    await open(
      tester,
      room(hasPassword: true),
      windowClass: WindowClass.expanded,
      size: const Size(1200, 800),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(longDescription), findsOneWidget);
  });
}
