import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/ui_selection_store.dart';
import 'package:monkeyhub/invites/room_admin_errors.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/editable_info_row.dart';

/// The client half of "a member suggests, an admin decides".
///
/// The backend's own rules are exercised in
/// `backend/convex/roomChangeRequests.test.ts`. What that cannot see is the
/// three places this feature can go wrong on the device, none of which the
/// analyzer catches:
///
///   1. **A row that edits and a row that suggests look identical.** The only
///      thing distinguishing them is the note under the value, so the note has
///      to survive both states of [EditableInfoRow] — including the edit state,
///      which is exactly when somebody is about to act on it.
///   2. **The wire vocabulary.** `field` is three literals shared with
///      TypeScript, and a typo is a runtime refusal on a real phone, not a
///      compile error. So is the `focus` value the notification tap carries.
///   3. **Lenient parsing.** A server that grows a fourth field must degrade an
///      old client to "a change it cannot describe", never to a crash on
///      somebody else's queue.
void main() {
  group('the wire vocabulary', () {
    test('the three fields spell themselves the way the backend reads them', () {
      // Shared with `roomChangeRequests.ts` FIELD_* — a typo here is a
      // CHANGE_REQUEST_INVALID_FIELD on a device and nothing sooner.
      expect(RoomChangeField.avatar.wire, 'avatar');
      expect(RoomChangeField.name.wire, 'name');
      expect(RoomChangeField.description.wire, 'description');
    });

    test('an unknown field parses rather than throwing', () {
      expect(RoomChangeFieldWire.parse('wallpaper'), RoomChangeField.unknown);
      expect(RoomChangeFieldWire.parse(null), RoomChangeField.unknown);
      // And never travels back out as a field the server would accept.
      expect(RoomChangeField.unknown.wire, '');
    });

    test('a suggestion decodes both ends of the same row', () {
      final admin = RoomChangeRequest.fromJson({
        'requestId': 'r1',
        'field': 'name',
        'value': 'Trip 2026',
        'currentValue': 'the group',
        'createdAt': 1700000000000,
        'user': {'_id': 'u1', 'username': 'deniz', 'name': 'Deniz'},
      });
      expect(admin.field, RoomChangeField.name);
      expect(admin.value, 'Trip 2026');
      expect(admin.currentValue, 'the group');
      expect(admin.user?.username, 'deniz');

      // The author's own view carries neither the comparison nor the person.
      final mine = RoomChangeRequest.fromJson({
        'requestId': 'r2',
        'field': 'avatar',
        'storageId': 'kg2abc',
        'createdAt': 1700000000000,
      });
      expect(mine.field, RoomChangeField.avatar);
      expect(mine.storageId, 'kg2abc');
      expect(mine.user, isNull);
      expect(mine.currentValue, isNull);
    });
  });

  group('permissions decide which half of the feature is drawn', () {
    test('review and suggest arrive as complements, never both', () {
      final asAdmin = RoomPermissions.fromJson(const {
        'role': 'admin',
        'isGroup': true,
        'canEditRoom': true,
        'canReviewChangeRequests': true,
        'canSuggestChanges': false,
      });
      expect(asAdmin.canReviewChangeRequests, isTrue);
      expect(asAdmin.canSuggestChanges, isFalse);

      final asMember = RoomPermissions.fromJson(const {
        'role': 'member',
        'isGroup': true,
        'canEditRoom': false,
        'canReviewChangeRequests': false,
        'canSuggestChanges': true,
      });
      expect(asMember.canReviewChangeRequests, isFalse);
      expect(asMember.canSuggestChanges, isTrue);
    });

    test('a server too old to send the flags offers nothing', () {
      // The whole point of `RoomPermissions.none`'s posture: an absent answer
      // must never be read as a granted one.
      final old = RoomPermissions.fromJson(const {'role': 'admin', 'isGroup': true});
      expect(old.canReviewChangeRequests, isFalse);
      expect(old.canSuggestChanges, isFalse);
      expect(RoomPermissions.none.canReviewChangeRequests, isFalse);
      expect(RoomPermissions.none.canSuggestChanges, isFalse);
    });
  });

  group('the note that says where an edit goes', () {
    Widget host(Widget child) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        );

    Widget row({String? note}) => EditableInfoRow(
          label: 'NAME',
          value: 'the group',
          controller: TextEditingController(),
          placeholder: 'Name this',
          saveLabel: 'save',
          cancelLabel: 'cancel',
          note: note,
          onCommit: (_) {},
        );

    testWidgets('an ordinary row carries none', (t) async {
      await t.pumpWidget(host(row()));
      expect(find.text('an admin has to approve this'), findsNothing);
    });

    testWidgets('a suggester sees it before the tap', (t) async {
      await t.pumpWidget(host(row(note: 'an admin has to approve this')));
      expect(find.text('an admin has to approve this'), findsOneWidget);
    });

    testWidgets('and still sees it with the field open', (t) async {
      // The regression this guards: dropping the note in the edit state takes
      // it away at the exact moment somebody is acting on it, which is the
      // only moment it matters.
      await t.pumpWidget(host(row(note: 'an admin has to approve this')));
      await t.tap(find.text('the group'));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('an admin has to approve this'), findsOneWidget);
    });
  });

  group('the notification tap', () {
    // `data.focus`, carried by both native handlers beside the roomId, and the
    // one-shot it lands in. `app.dart` maps the string; the store routes it by
    // room. Neither half is visible to the analyzer.
    setUp(() => UiSelectionStore.instance.consumeRoomChangeReview('drain'));

    test('a request is consumed by the room it names', () {
      UiSelectionStore.instance.requestRoomChangeReview('room-a');
      expect(UiSelectionStore.instance.consumeRoomChangeReview('room-a'), isTrue);
      // One-shot: a screen rebuilding must not reopen the sheet.
      expect(UiSelectionStore.instance.consumeRoomChangeReview('room-a'), isFalse);
    });

    test('the wrong room clears it rather than carrying it forward', () {
      UiSelectionStore.instance.requestRoomChangeReview('room-a');
      expect(UiSelectionStore.instance.consumeRoomChangeReview('room-b'), isFalse);
      // Cleared on the miss too — the user opened a different room, so the
      // request has already been overtaken and must not ambush them later.
      expect(UiSelectionStore.instance.consumeRoomChangeReview('room-a'), isFalse);
    });

    test('the games and moment one-shots are untouched', () {
      UiSelectionStore.instance.requestRoomChangeReview('room-a');
      expect(UiSelectionStore.instance.gamesViewPending, isFalse);
      expect(UiSelectionStore.instance.momentIdPending, isNull);
      UiSelectionStore.instance.consumeRoomChangeReview('room-a');
    });

    test('every layer spells the focus value the same way', () {
      // Four files, three languages, and nothing but agreement. The literal
      // lives in app.dart; the two native handlers forward whatever arrives,
      // and the backend writes it.
      const focus = 'roomChanges';
      for (final path in const [
        'lib/app.dart',
        'backend/convex/notifications.ts',
      ]) {
        expect(
          File(path).readAsStringSync().contains(focus),
          isTrue,
          reason: '$path no longer mentions the focus value "$focus"',
        );
      }
    });
  });

  group('error wording', () {
    testWidgets('every suggestion refusal has a sentence of its own',
        (t) async {
      late AppLocalizations l10n;
      await t.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (ctx) {
          l10n = AppLocalizations.of(ctx);
          return const SizedBox();
        }),
      ));
      final map = roomAdminErrorMessages(l10n);
      // Every code `roomChangeRequests.ts` can throw, so none of them reaches
      // a user as a raw identifier.
      for (final code in const [
        'CHANGE_REQUEST_NOT_FOUND',
        'CHANGE_REQUEST_NOT_YOURS',
        'CHANGE_REQUEST_NO_CHANGE',
        'CHANGE_REQUEST_MISSING_VALUE',
        'CHANGE_REQUEST_INVALID_FIELD',
        // Re-checked at approval, so an admin can meet them on a name that was
        // free when it was suggested.
        'ROOM_NAME_REQUIRED',
        'ROOM_EXISTS',
      ]) {
        expect(map[code], isNotNull, reason: '$code has no wording');
        expect(map[code], isNot(contains('_')), reason: '$code reads as a code');
      }
      // And the prefix keeps them clear of the friend-request copy, which is
      // what `JOIN_REQUEST_NOT_FOUND` needs override precedence to escape.
      expect(map['CHANGE_REQUEST_NOT_FOUND'],
          isNot(equals(map['JOIN_REQUEST_NOT_FOUND'])));
    });
  });
}
