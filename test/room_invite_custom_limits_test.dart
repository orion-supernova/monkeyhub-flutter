import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/number_stepper.dart';
import 'package:monkeyhub/widgets/room_invite_sheet.dart';

/// The invite link's two limits, past the presets.
///
/// The chips cover "for tonight, for a week, for good". What they cannot cover
/// is the admin who wants the link to last through a three-day trip, or to let
/// in exactly the twelve people on the guest list — so each row ends in
/// Custom, and Custom is a stepper. What is pinned here is the part a wrong
/// guess would ship silently: the number the SERVER is sent.
class _FakeRepo extends ChangeNotifier implements ChatRepository {
  Duration? sentExpiry;
  int? sentMaxUses;
  int rotations = 0;

  @override
  Future<RoomInviteLink?> roomInviteLink(String roomId) async => null;

  @override
  Future<RoomInviteLink?> rotateRoomInviteLink(
    String roomId, {
    Duration? expiresIn,
    int? maxUses,
  }) async {
    rotations++;
    sentExpiry = expiresIn;
    sentMaxUses = maxUses;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _perms = RoomPermissions(
  role: RoomRole.owner,
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
);

Widget _host(Widget child) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('NumberStepper', () {
    Future<List<int>> pumpStepper(
      WidgetTester t, {
      int value = 5,
      int min = 1,
      int max = 10,
    }) async {
      final changes = <int>[];
      await t.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) => NumberStepper(
          value: value,
          min: min,
          max: max,
          increaseLabel: 'Increase',
          decreaseLabel: 'Decrease',
          semanticsLabel: 'Uses',
          onChanged: (v) => setState(() {
            value = v;
            changes.add(v);
          }),
        ),
      )));
      return changes;
    }

    testWidgets('a tap moves one step each way', (t) async {
      final changes = await pumpStepper(t);
      await t.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await t.pump();
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await t.pump();
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await t.pump();
      expect(changes, [6, 5, 4]);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('it stops at the bounds instead of wrapping', (t) async {
      final changes = await pumpStepper(t, value: 1, min: 1, max: 2);
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await t.pump();
      expect(changes, isEmpty);
      await t.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await t.pump();
      await t.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await t.pump();
      expect(changes, [2]);
    });

    testWidgets('holding runs, gathers speed, and stops at the end', (t) async {
      final changes = await pumpStepper(t, value: 1, min: 1, max: 1000);
      final gesture = await t.startGesture(
        t.getCenter(find.byIcon(Icons.keyboard_arrow_up_rounded)),
      );
      // Past the long-press threshold and a few seconds of repeats.
      for (var i = 0; i < 80; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await t.pump();

      expect(changes.last, 1000, reason: 'a held arrow reaches the far end');
      expect(changes.length, lessThan(80),
          reason: 'by bigger steps, not a thousand single ones');
      // Every change went up, and never overshot.
      for (var i = 1; i < changes.length; i++) {
        expect(changes[i], greaterThan(changes[i - 1]));
      }
    });

    testWidgets('a screen reader adjusts it as one control', (t) async {
      final handle = t.ensureSemantics();
      final changes = await pumpStepper(t);
      final node = t.getSemantics(find.byType(NumberStepper));
      expect(node.value, '5');
      expect(node.increasedValue, '6');
      expect(node.decreasedValue, '4');
      t.binding.pipelineOwner.semanticsOwner!
          .performAction(node.id, SemanticsAction.increase);
      await t.pump();
      expect(changes, [6]);
      handle.dispose();
    });
  });

  group('custom invite limits', () {
    Future<_FakeRepo> openSheet(WidgetTester t) async {
      t.view.physicalSize = const Size(430, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // Creating a link awaits a haptic, and an unanswered platform call would
      // leave the sheet busy — and its button dead — for the rest of the test.
      t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(() => t.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final repo = _FakeRepo();
      await t.pumpWidget(_host(Builder(
        builder: (context) => TextButton(
          onPressed: () => showRoomInviteSheet(
            context,
            repo: repo,
            roomId: 'r1',
            permissions: _perms,
          ),
          child: const Text('open'),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return repo;
    }

    Finder upIn(int index) =>
        find.byIcon(Icons.keyboard_arrow_up_rounded).at(index);

    /// Lets the "link created" toast finish, so no timer outlives the test.
    Future<void> settleToast(WidgetTester t) async {
      await t.pump(const Duration(seconds: 8));
      await t.pumpAndSettle();
    }

    testWidgets('a custom expiry is sent as exactly what was dialled',
        (t) async {
      final repo = await openSheet(t);

      // Seeded from the preset it replaces: a day opens on one day.
      await t.tap(find.text('1d'));
      await t.pump();
      await t.tap(find.text('Custom').first);
      await t.pumpAndSettle();
      expect(find.text('1 day'), findsOneWidget);

      await t.tap(upIn(0));
      await t.pump();
      await t.tap(upIn(0));
      await t.pump();
      expect(find.text('3 days'), findsOneWidget);

      await t.tap(find.text('CREATE LINK'));
      await t.pumpAndSettle();
      expect(repo.sentExpiry, const Duration(days: 3));
      expect(repo.sentMaxUses, isNull);
      await settleToast(t);
    });

    testWidgets('switching unit keeps the span, never shortening it',
        (t) async {
      final repo = await openSheet(t);
      await t.tap(find.text('Custom').first);
      await t.pumpAndSettle();
      // Default custom expiry: 3 days, which in hours is exactly the 72h
      // ceiling.
      await t.tap(find.text('Hours'));
      await t.pumpAndSettle();
      expect(find.text('72 hours'), findsOneWidget);

      // 71 hours back in days rounds UP to 3: an expiry must never come early.
      await t.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await t.pump();
      await t.tap(find.text('Days'));
      await t.pumpAndSettle();
      expect(find.text('3 days'), findsOneWidget);

      await t.tap(find.text('CREATE LINK'));
      await t.pumpAndSettle();
      expect(repo.sentExpiry, const Duration(days: 3));
      await settleToast(t);
    });

    testWidgets('a custom use count is sent, and a preset tap replaces it',
        (t) async {
      final repo = await openSheet(t);
      await t.tap(find.text('10'));
      await t.pump();
      await t.tap(find.text('Custom').last);
      await t.pumpAndSettle();
      expect(find.text('10 uses'), findsOneWidget);

      await t.tap(upIn(0));
      await t.pump();
      await t.tap(upIn(0));
      await t.pump();
      expect(find.text('12 uses'), findsOneWidget);

      await t.tap(find.text('CREATE LINK'));
      await t.pumpAndSettle();
      expect(repo.sentMaxUses, 12);
      expect(repo.rotations, 1);

      // A preset closes Custom and wins — the stepper's value is not sent.
      // (The fake hands back no link, so the sheet stays on CREATE; let the
      // first creation's toast clear off the button before pressing it again.)
      await settleToast(t);
      await t.tap(find.text('25'));
      await t.pumpAndSettle();
      expect(find.text('12 uses'), findsNothing);
      await t.tap(find.text('CREATE LINK'));
      await t.pumpAndSettle();
      expect(repo.rotations, 2);
      expect(repo.sentMaxUses, 25);
      await settleToast(t);
    });
  });
}
