import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/group_call_sheets.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// FocusableTap adds keyboard focus only — it registers NO gesture
/// recognizer, so every call control must wrap its child in a
/// GestureDetector to be tappable at all. This shipped broken once (call
/// tray + group start sheet completely dead to touch); these tests pin the
/// highest-traffic surface, the group start sheet, as actually tappable.
class _FakeGroupCallApi extends Fake implements GroupCallApi {}

class _FakeChatApi extends Fake implements ChatApi {}

class _RecordingGroupCallService extends GroupCallService {
  _RecordingGroupCallService() : super(api: _FakeGroupCallApi());

  final List<({String roomId, CallMediaKind kind, List<String>? inviteeIds})>
  started = [];

  @override
  Future<void> startCall({
    required String roomId,
    required CallMediaKind kind,
    List<String>? inviteeIds,
  }) async {
    started.add((roomId: roomId, kind: kind, inviteeIds: inviteeIds));
  }
}

void main() {
  late _RecordingGroupCallService service;

  Widget host() {
    service = _RecordingGroupCallService();
    // ThemeScope must sit ABOVE the MaterialApp: the sheet is pushed on the
    // root navigator, whose contexts don't descend from `home`.
    return ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => showStartGroupCallSheet(
                  context,
                  service: service,
                  api: _FakeChatApi(),
                  roomId: 'room1',
                  myUserId: 'me',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Start a call'), findsOneWidget);
  }

  testWidgets('tapping "Call everyone" starts a voice call for the room', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Call everyone'));
    await tester.pumpAndSettle();
    expect(service.started, hasLength(1));
    expect(service.started.single.roomId, 'room1');
    expect(service.started.single.kind, CallMediaKind.audio);
    expect(service.started.single.inviteeIds, isNull);
  });

  testWidgets('the Video segment responds and changes the started call kind', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Call everyone'));
    await tester.pumpAndSettle();
    expect(service.started.single.kind, CallMediaKind.video);
  });
}
