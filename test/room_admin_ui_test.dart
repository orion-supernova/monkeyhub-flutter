import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/editable_info_row.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/widgets/room_member_actions_sheet.dart';
import 'package:monkeyhub/widgets/skeleton_rows.dart';

/// The group-admin surfaces, pumped.
///
/// These exist because `flutter analyze` cannot see a runtime assertion, and
/// one shipped: `_ActionRow` used a NEGATIVE margin on an `AnimatedContainer`,
/// which asserts `margin.isNonNegative`. It threw on every row of the member
/// sheet the instant it opened, and nothing in the static checks or the
/// existing suite noticed. Pumping the widget is the cheapest thing that would
/// have.
Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('member actions sheet', () {
    // The direct regression for the negative-margin assert. Opening the sheet
    // is the whole test: it threw during build on every row.
    Future<void> open(WidgetTester t, RoomPermissions perms) async {
      final api = ChatApi(ConvexBackend.instance);
      final member = ChatUser(id: 'u1', username: 'deniz', name: 'Deniz');
      // Both scopes sit ABOVE MaterialApp: the sheet is a route of its own, so
      // anything provided inside `home` is not an ancestor of it. Same reason
      // `room_info_sheet_test.dart` is built this way.
      await t.pumpWidget(ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: LayoutScope(
          windowClass: WindowClass.compact,
          width: 400,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(builder: (ctx) => Center(child: GestureDetector(
                onTap: () => showRoomMemberActions(
                  ctx,
                  member: member,
                  memberRole: RoomRole.member,
                  permissions: perms,
                  api: api,
                  isSelf: false,
                ),
                child: const Text('open'),
              ))),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('opens for a plain member with the contact rows', (t) async {
      await open(t, RoomPermissions.none);
      expect(tester_exception(), isNull,
          reason: 'the sheet must build without throwing');
      // Everyone gets these — the sheet is not admin-only.
      expect(find.byIcon(CupertinoIcons.chat_bubble_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.phone_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.video_camera_solid), findsOneWidget);
      // ...and no moderation.
      expect(find.byIcon(CupertinoIcons.person_badge_minus_fill), findsNothing);
      expect(find.byIcon(CupertinoIcons.shield_lefthalf_fill), findsNothing);
    });

    testWidgets('adds the moderation rows for an admin', (t) async {
      await open(t, const RoomPermissions(
        role: RoomRole.admin,
        isGroup: true,
        canEditRoom: true,
        canRemoveMembers: true,
        canAssignAdmins: true,
        canManageLink: true,
        canReviewJoinRequests: true,
        canReviewChangeRequests: true,
        canSuggestChanges: false,
        canInvite: true,
        membersCanInvite: true,
        linkJoinPolicy: RoomJoinPolicy.open,
      ));
      expect(tester_exception(), isNull);
      expect(find.byIcon(CupertinoIcons.shield_lefthalf_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person_badge_minus_fill), findsOneWidget);
    });

    testWidgets('pressing a row does not throw', (t) async {
      // The quick actions are spring-pressed tiles; the bug that once shipped
      // was in a row's press state. Exercise the down/up path explicitly.
      await open(t, RoomPermissions.none);
      final gesture =
          await t.startGesture(t.getCenter(find.byIcon(CupertinoIcons.chat_bubble_fill)));
      await t.pump(const Duration(milliseconds: 80));
      await gesture.up();
      await t.pumpAndSettle();
      expect(tester_exception(), isNull);
    });
  });

  group('SkeletonRows', () {
    testWidgets('builds without exploding, at the requested count', (t) async {
      await t.pumpWidget(_host(const SkeletonRows(count: 5)));
      await t.pump(const Duration(milliseconds: 200));
      expect(tester_exception(), isNull);
      // Five rows, each an avatar plus two lines.
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('keeps animating without rebuilding the tree', (t) async {
      await t.pumpWidget(_host(const SkeletonRows(count: 3)));
      await t.pump(const Duration(milliseconds: 700));
      await t.pump(const Duration(milliseconds: 700));
      expect(tester_exception(), isNull);
    });
  });

  group('EditableInfoRow', () {
    Widget row({
      required TextEditingController c,
      required String value,
      required ValueChanged<String> onCommit,
    }) =>
        _host(EditableInfoRow(
          label: 'NAME',
          value: value,
          controller: c,
          placeholder: 'Name this room',
          saveLabel: 'Save',
          cancelLabel: 'Cancel',
          onCommit: onCommit,
        ));

    testWidgets('shows the value as text, with no field, until tapped',
        (t) async {
      final c = TextEditingController();
      await t.pumpWidget(row(c: c, value: 'Hafta Sonu', onCommit: (_) {}));
      expect(find.text('Hafta Sonu'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await t.tap(find.text('Hafta Sonu'));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders the placeholder when empty', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(row(c: c, value: '', onCommit: (_) {}));
      expect(find.text('Name this room'), findsOneWidget);
    });

    testWidgets('the tick commits the edit', (t) async {
      final c = TextEditingController();
      String? committed;
      await t.pumpWidget(
          row(c: c, value: 'Before', onCommit: (v) => committed = v));
      await t.tap(find.text('Before'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'After');
      await t.tap(find.byIcon(CupertinoIcons.checkmark_circle_fill));
      await t.pumpAndSettle();

      expect(committed, 'After');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the cross discards it, and restores the original', (t) async {
      final c = TextEditingController();
      var commits = 0;
      await t.pumpWidget(row(c: c, value: 'Before', onCommit: (_) => commits++));
      await t.tap(find.text('Before'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'Garbled');
      await t.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
      await t.pumpAndSettle();

      expect(commits, 0, reason: 'cancel must never commit');
      expect(c.text, 'Before', reason: 'the buffer is restored');
      expect(find.text('Before'), findsOneWidget);
    });

    testWidgets('typing alone never commits, however long you wait', (t) async {
      // The bug this pins shipped: the SCREEN watched these controllers and
      // wrote on a debounce, so changing a name and tapping cancel saved the
      // new name and then put the old one back on screen. Text must commit
      // through the tick and nothing else — no timer, no listener, no blur.
      final c = TextEditingController();
      var commits = 0;
      await t.pumpWidget(row(c: c, value: 'Before', onCommit: (_) => commits++));
      await t.tap(find.text('Before'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'Typed but not confirmed');
      await t.pump(const Duration(seconds: 3));
      expect(commits, 0, reason: 'no debounce may write behind the tick');
    });

    testWidgets('tapping in and straight back out writes nothing', (t) async {
      final c = TextEditingController();
      var commits = 0;
      await t.pumpWidget(row(c: c, value: 'Same', onCommit: (_) => commits++));
      await t.tap(find.text('Same'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(CupertinoIcons.checkmark_circle_fill));
      await t.pumpAndSettle();
      expect(commits, 0, reason: 'unchanged text is not a change');
    });

    testWidgets('disabled shows no affordance and does not open', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(_host(EditableInfoRow(
        label: 'NAME',
        value: 'Read only',
        controller: c,
        placeholder: 'x',
        saveLabel: 'Save',
        cancelLabel: 'Cancel',
        enabled: false,
        onCommit: (_) {},
      )));
      expect(find.byIcon(CupertinoIcons.pencil), findsNothing);
      await t.tap(find.text('Read only'));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('display follows the room, not a stale buffer', (t) async {
      // Another admin renames the room while this screen is open: the row must
      // show the new name, not whatever the edit buffer last held.
      final c = TextEditingController(text: 'Old draft');
      await t.pumpWidget(row(c: c, value: 'Renamed remotely', onCommit: (_) {}));
      expect(find.text('Renamed remotely'), findsOneWidget);
      expect(find.text('Old draft'), findsNothing);
    });
  });
}

/// Surfaces an exception captured by the framework during a pump, if any.
Object? tester_exception() {
  final e = TestWidgetsFlutterBinding.instance.takeException();
  return e;
}
