// Round-3 design spec renders: the CURRENT state of every transient status
// surface (toasts, connection banner, call pills, companion strip, small
// pills) and every chat attachment (poll / quiz / checklist / event bubbles,
// their compose sheets and respondent sheet, location / file / audio / link
// bubbles, the attachment menu and the schedule / location sheets).
//
//   flutter test test/design_preview/round3_spec_preview.dart
//
// Output: build/design_preview/r3_<what>_<theme>[_trx13].png. Not a test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/connection_health.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/companions/companion.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_interaction.dart';
import 'package:monkeyhub/models/scheduled_message.dart';
import 'package:monkeyhub/screens/interaction_compose_sheet.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/app_toast.dart';
import 'package:monkeyhub/widgets/approval_gate.dart';
import 'package:monkeyhub/widgets/attachment_menu.dart';
import 'package:monkeyhub/widgets/companion_strip.dart';
import 'package:monkeyhub/widgets/connection_banner.dart';
import 'package:monkeyhub/widgets/interaction_bubble.dart';
import 'package:monkeyhub/widgets/interaction_respondents_sheet.dart';
import 'package:monkeyhub/widgets/location_share_sheet.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/recovery_banner.dart';
import 'package:monkeyhub/widgets/schedule_message_sheet.dart';
import 'package:monkeyhub/widgets/scheduled_pill.dart';
import 'package:monkeyhub/widgets/ios_kit.dart' show RowSwitch;
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

final _api = ChatApi(ConvexBackend.instance);
final _day = DateTime(2026, 10, 2, 21, 0);
final _ece = ChatUser(id: 'ece', username: 'ece', name: 'Ece');

class _Health extends ChangeNotifier implements ConnectionHealth {
  _Health(this.phase, {this.isRetrying = false});
  @override
  final ConnectionPhase phase;
  @override
  final bool isRetrying;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RespApi extends Fake implements ChatApi {
  @override
  Future<List<InteractionRespondentDetail>> interactionRespondents({
    required String messageId,
    required String userId,
  }) async => [
        for (final (i, n) in ['Ece', 'Deniz Kaya', 'Arda', 'Zeynep', 'Kerem', 'Mom'].indexed)
          InteractionRespondentDetail(
            userId: 'u$i',
            name: n,
            choiceId: i.isEven ? '0' : '1',
            at: _day.add(Duration(minutes: i * 3)),
          ),
      ];
}

// ── fixtures ──────────────────────────────────────────────────────────────

int _n = 0;
ChatMessage _msg(String from, MessageType type, String content, {int min = 0}) => ChatMessage(
      id: 'm${_n++}',
      roomId: 'r',
      senderId: from,
      senderName: from == 'me' ? 'Murat' : 'Ece',
      content: content,
      createdAt: _day.add(Duration(minutes: min)),
      type: type,
    );

InteractionChoice _c(String id, String label, int count, [List<String> who = const []]) =>
    InteractionChoice(
      id: id,
      label: label,
      count: count,
      respondents: [
        for (final n in who) InteractionRespondent(userId: n, name: n, at: _day),
      ],
    );

MessageInteraction _it(
  ChatMessage m, {
  required List<InteractionChoice> choices,
  int respondents = 0,
  List<String> mine = const [],
  bool multiple = false,
  bool anonymous = false,
  bool quiz = false,
  String? correct,
  String? explanation,
  DateTime? closedAt,
  DateTime? startsAt,
  DateTime? endsAt,
  String? place,
  String createdBy = 'ece',
}) =>
    MessageInteraction(
      messageId: m.id,
      kind: m.type,
      createdBy: createdBy,
      createdAt: m.createdAt,
      choices: choices,
      respondentCount: respondents,
      myChoiceIds: mine,
      multiple: multiple,
      anonymous: anonymous,
      quiz: quiz,
      correctChoiceId: correct,
      explanation: explanation,
      closedAt: closedAt,
      startsAt: startsAt,
      endsAt: endsAt,
      place: place,
    );

final _actions = InteractionActions(
  onRespond: (_, _) {},
  onRetract: (_) {},
  onClose: (_) {},
  onAddItem: (_, _) {},
  onRemoveItem: (_, _) {},
  onShowRespondents: (_) {},
);

/// (message, interaction) pairs for one transcript page.
List<(ChatMessage, MessageInteraction?)> _polls() {
  final a = _msg('ece', MessageType.poll, 'Where should we eat on Saturday?');
  final b = _msg('me', MessageType.poll, 'Which days work for the trip?', min: 2);
  final c = _msg('ece', MessageType.poll, 'What is the capital of Australia?', min: 4);
  final d = _msg('ece', MessageType.poll, 'Best movie of the year?', min: 6);
  return [
    (_msg('ece', MessageType.text, 'ok voting time', min: 0), null),
    (
      a,
      _it(a, choices: [
        _c('0', 'The Italian place on the corner', 3, ['Deniz', 'Arda']),
        _c('1', 'Sushi', 1, ['Zeynep']),
        _c('2', 'Burgers', 0),
      ], respondents: 4),
    ),
    (
      b,
      _it(b, createdBy: 'me', multiple: true, mine: ['0', '2'], choices: [
        _c('0', 'Friday', 4, ['Ece', 'Murat']),
        _c('1', 'Saturday', 2, ['Deniz']),
        _c('2', 'Sunday', 5, ['Arda', 'Murat']),
      ], respondents: 6),
    ),
    (
      c,
      _it(c, quiz: true, mine: ['0'], correct: '1',
          explanation: 'Canberra was purpose-built as a compromise.',
          choices: [
            _c('0', 'Sydney', 2, ['Murat']),
            _c('1', 'Canberra', 3, ['Deniz']),
            _c('2', 'Melbourne', 1),
          ], respondents: 6),
    ),
    (
      d,
      _it(d, anonymous: true, closedAt: _day, choices: [
        _c('0', 'Dune Part Two', 7),
        _c('1', 'Challengers', 4),
      ], respondents: 11),
    ),
  ];
}

List<(ChatMessage, MessageInteraction?)> _lists() {
  final a = _msg('me', MessageType.checklist, 'Trip packing list');
  final b = _msg('ece', MessageType.event, 'Board game night', min: 3);
  final p = _msg('ece', MessageType.event, 'Kerem’s birthday dinner', min: 5);
  final s = _msg('ece', MessageType.poll, 'Pizza or curry tonight?', min: 7);
  return [
    (
      a,
      _it(a, createdBy: 'me', mine: ['0'], choices: [
        _c('0', 'Tent', 1, ['Murat']),
        _c('1', 'Sleeping bags', 1, ['Ece']),
        _c('2', 'Camping stove and gas', 0),
        _c('3', 'Sunscreen', 0),
      ], respondents: 2),
    ),
    (
      b,
      _it(b, mine: ['going'], startsAt: DateTime(2026, 10, 9, 19, 30),
          endsAt: DateTime(2026, 10, 9, 23, 0), place: 'Deniz’s flat, Moda',
          choices: [
            _c('going', 'going', 3, ['Murat', 'Deniz']),
            _c('maybe', 'maybe', 1, ['Arda']),
            _c('no', 'no', 0),
          ], respondents: 4),
    ),
    (
      p,
      _it(p, startsAt: DateTime(2026, 9, 20, 20, 0), choices: [
        _c('going', 'going', 5),
        _c('maybe', 'maybe', 0),
        _c('no', 'no', 1),
      ], respondents: 6),
    ),
    // Body not landed yet.
    (s, null),
  ];
}

List<ChatMessage> _media() {
  final loc = _msg('ece', MessageType.location, '')
    ..latitude = 41.0082
    ..longitude = 28.9784
    ..locationAccuracyM = 12;
  final live = _msg('me', MessageType.liveLocation, '', min: 1)
    ..latitude = 41.02
    ..longitude = 29.0
    ..liveExpiresAt = _day.add(const Duration(hours: 1));
  final file = ChatMessage(
    id: 'f1',
    roomId: 'r',
    senderId: 'ece',
    senderName: 'Ece',
    content: '',
    createdAt: _day.add(const Duration(minutes: 2)),
    type: MessageType.file,
    mediaStorageId: 'st1',
    fileName: 'Istanbul trip itinerary final v3.pdf',
    fileSize: 2400000,
    mimeType: 'application/pdf',
  );
  final myFile = ChatMessage(
    id: 'f2',
    roomId: 'r',
    senderId: 'me',
    senderName: 'Murat',
    content: '',
    createdAt: _day.add(const Duration(minutes: 3)),
    type: MessageType.file,
    mediaStorageId: 'st2',
    fileName: 'budget.xlsx',
    fileSize: 48000,
  );
  final audio = ChatMessage(
    id: 'a1',
    roomId: 'r',
    senderId: 'ece',
    senderName: 'Ece',
    content: '',
    createdAt: _day.add(const Duration(minutes: 4)),
    type: MessageType.audio,
    mediaStorageId: 'st3',
    mediaDurationMs: 14000,
  );
  final myAudio = ChatMessage(
    id: 'a2',
    roomId: 'r',
    senderId: 'me',
    senderName: 'Murat',
    content: '',
    createdAt: _day.add(const Duration(minutes: 5)),
    type: MessageType.audio,
    mediaStorageId: 'st4',
    mediaDurationMs: 42000,
  );
  final link = _msg('ece', MessageType.url, 'look https://www.apple.com/newsroom/', min: 6);
  final myLink = _msg('me', MessageType.url, 'https://github.com/flutter/flutter', min: 7);
  return [loc, live, file, myFile, audio, myAudio, link, myLink];
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.rows});
  final List<(ChatMessage, MessageInteraction?)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        theme.backgroundLayer(context),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 70, 16, 40),
          children: [
            for (var i = 0; i < rows.length; i++)
              MessageBubble(
                message: rows[i].$1,
                interaction: rows[i].$2,
                interactionActions: _actions,
                now: _day.add(const Duration(minutes: 20)),
                currentUserId: 'me',
                api: _api,
                author: rows[i].$1.senderId == 'me' ? null : _ece,
                showAvatarSlot: false,
                seenByOthers: true,
                deliveredToOthers: true,
              ),
          ],
        ),
      ]),
    );
  }
}

// ── hosts ─────────────────────────────────────────────────────────────────

class _Page extends StatefulWidget {
  const _Page({this.open, this.child});
  final void Function(BuildContext context)? open;
  final Widget? child;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    final open = widget.open;
    if (open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => open(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: widget.child ??
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 0),
            children: [
              Text('Settings', style: theme.displayLarge),
              for (var i = 0; i < 9; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    CircleAvatar(radius: 26, backgroundColor: theme.surfaceRaised),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Row $i', style: theme.bodyEmph)),
                  ]),
                ),
            ],
          ),
    );
  }
}

/// Every persistent / transient top-of-screen strip, stacked.
class _Bits extends StatelessWidget {
  const _Bits();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
        children: [
          ConnectionBanner(health: _Health(ConnectionPhase.reconnecting)),
          ConnectionBanner(health: _Health(ConnectionPhase.stalled)),
          ConnectionBanner(health: _Health(ConnectionPhase.stalled, isRetrying: true)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: CallStatusBanner(
              onTap: () {},
              icon: CallGlyphs.voice,
              title: l10n.activeCallPillCallWith('Ece'),
              meta: Text(l10n.activeCallPillOnDevice('iPad')),
              actions: [
                CallBannerAction(
                  icon: CallGlyphs.moveHere,
                  label: l10n.activeCallPillMoveHereLabel,
                  semanticLabel: l10n.activeCallPillMoveHereSemanticLabel,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: CallStatusBanner(
              icon: CallGlyphs.voice,
              title: 'Weekend Crew',
              meta: const Text('12:04'),
              actions: [
                CallBannerAction(
                  icon: CallGlyphs.back,
                  label: l10n.inCallPillReturn,
                  semanticLabel: l10n.inCallPillReturn,
                  onTap: () {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: CallStatusBanner(
              tone: CallBannerTone.neutral,
              icon: CallGlyphs.voice,
              title: 'Group call in progress',
              meta: const Text('Ece, Deniz +2'),
              actions: [
                CallBannerAction(
                  icon: CallGlyphs.voice,
                  label: 'Join',
                  semanticLabel: 'Join',
                  prominent: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
          CompanionStrip(
            visible: true,
            companion: Companion.sebastian,
            message: 'Downloading Sebastian · 412 MB of 1.2 GB',
            detail: '34%',
            progress: 0.34,
            actionLabel: 'Pause',
            onAction: () {},
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RecoveryPhraseBanner(onTap: () {}),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [WaitingPill(), Spacer()]),
          ),
          const SizedBox(height: 10),
          Center(
            child: ScheduledPill(
              scheduled: [
                ScheduledMessage(
                  id: 's1',
                  roomId: 'r',
                  content: 'happy birthday!',
                  sendAt: _day.add(const Duration(hours: 3)),
                  createdAt: _day,
                ),
                ScheduledMessage(
                  id: 's2',
                  roomId: 'r',
                  content: 'reminder',
                  sendAt: _day.add(const Duration(days: 1)),
                  createdAt: _day,
                ),
              ],
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ── scenes ────────────────────────────────────────────────────────────────

typedef _Scene = ({Widget Function() build, Future<void> Function(WidgetTester)? act, Size size});

const _tall = Size(393, 1700);

final Map<String, _Scene> _scenes = {
  // status
  'st_bits': (build: () => const _Bits(), act: null, size: kIphone16Pro),
  'st_toast_neutral': (
    build: () => _Page(open: (c) => AppToast.of(c).show('Pinned to the top', duration: const Duration(seconds: 30))),
    act: null,
    size: kIphone16Pro,
  ),
  'st_toast_taps': (
    build: () => _Page(
        open: (c) => AppToast.of(c).show(
            AppLocalizations.of(c).settingsScreenDiagnosticsCountdown(2),
            duration: const Duration(seconds: 30))),
    act: null,
    size: kIphone16Pro,
  ),
  'st_toast_success': (
    build: () => _Page(open: (c) => AppToast.of(c).show(AppLocalizations.of(c).roomScreenCopiedSnack, tone: ToastTone.success, duration: const Duration(seconds: 30))),
    act: null,
    size: kIphone16Pro,
  ),
  'st_toast_error': (
    build: () => _Page(
        open: (c) => AppToast.of(c).show(AppLocalizations.of(c).settingsScreenUpdateErrorSnackbar, tone: ToastTone.danger, duration: const Duration(seconds: 30))),
    act: null,
    size: kIphone16Pro,
  ),
  'st_toast_action': (
    build: () => _Page(
        open: (c) => AppToast.of(c).show(
              AppLocalizations.of(c).roomScreenTranslateRoomOffer,
              actionLabel: AppLocalizations.of(c).roomScreenTranslateRoomOfferAction,
              onAction: () {},
              duration: const Duration(seconds: 30),
            )),
    act: null,
    size: kIphone16Pro,
  ),
  // bubbles
  'bb_polls': (build: () => _Transcript(rows: _polls()), act: null, size: _tall),
  'bb_lists': (build: () => _Transcript(rows: _lists()), act: null, size: _tall),
  'bb_media': (
    build: () => _Transcript(rows: [for (final m in _media()) (m, null)]),
    act: null,
    size: _tall,
  ),
  // sheets
  'sh_attach': (build: () => _Page(open: (c) => showAttachmentMenu(c)), act: null, size: kIphone16Pro),
  'sh_poll': (
    build: () => _Page(open: (c) => showInteractionComposeSheet(c, kind: MessageType.poll)),
    act: null,
    size: kIphone16Pro,
  ),
  'sh_quiz': (
    build: () => _Page(open: (c) => showInteractionComposeSheet(c, kind: MessageType.poll)),
    act: (t) async {
      final switches = find.byType(RowSwitch);
      await t.ensureVisible(switches.at(2));
      await t.pump();
      await t.tap(switches.at(2), warnIfMissed: false);
    },
    size: kIphone16Pro,
  ),
  'sh_checklist': (
    build: () => _Page(open: (c) => showInteractionComposeSheet(c, kind: MessageType.checklist)),
    act: null,
    size: kIphone16Pro,
  ),
  'sh_event': (
    build: () => _Page(open: (c) => showInteractionComposeSheet(c, kind: MessageType.event)),
    act: null,
    size: kIphone16Pro,
  ),
  'sh_event_picker': (
    build: () => _Page(open: (c) => showInteractionComposeSheet(c, kind: MessageType.event)),
    act: (t) async {
      final l10n = AppLocalizations.of(t.element(find.byType(Scaffold).first));
      await t.tap(find.text(l10n.interactionComposePickStart), warnIfMissed: false);
    },
    size: kIphone16Pro,
  ),
  'sh_respondents': (
    build: () {
      final m = _msg('ece', MessageType.poll, 'Where should we eat?');
      final it = _it(m, choices: [_c('0', 'Italian', 3), _c('1', 'Sushi', 3)], respondents: 6);
      return _Page(
        open: (c) => showInteractionRespondentsSheet(
          c,
          api: _RespApi(),
          messageId: m.id,
          currentUserId: 'me',
          interaction: it,
          resolveUser: (_) => null,
          onOpenProfile: (_) {},
        ),
      );
    },
    act: null,
    size: kIphone16Pro,
  ),
  'sh_schedule': (
    build: () => _Page(open: (c) => showScheduleMessageSheet(c, preview: 'happy birthday!', queuedCount: 2)),
    act: null,
    size: kIphone16Pro,
  ),
  'sh_location': (build: () => _Page(open: (c) => showLocationShareSheet(c)), act: null, size: kIphone16Pro),
};

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AppToast.hide);

  const themes = ['basic', 'basic_daylight', 'risograph_pop'];
  const variants = <String, ({Locale locale, double scale})>{
    '': (locale: Locale('en'), scale: 1.0),
    '_trx13': (locale: Locale('tr'), scale: 1.3),
  };
  final only = const String.fromEnvironment('R3');

  for (final id in themes) {
    for (final e in _scenes.entries) {
      if (only.isNotEmpty && !e.key.startsWith(only)) continue;
      for (final v in variants.entries) {
        if (v.key.isNotEmpty && id != 'basic') continue;
        testWidgets('r3 ${e.key} $id${v.key}', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = v.value.scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final act = e.value.act;
          await snap(
            tester,
            previewApp(ThemeController.byId(id), e.value.build(), locale: v.value.locale),
            'r3_${e.key}_$id${v.key}.png',
            size: e.value.size,
            act: act == null
                ? (e.key.startsWith('bb') ? null : () async {})
                : () async {
                    for (var i = 0; i < 60; i++) {
                      await tester.pump(const Duration(milliseconds: 16));
                    }
                    await act(tester);
                  },
          );
        });
      }
    }
  }
}
