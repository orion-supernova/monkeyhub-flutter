// Real location transcript cards, including the live/finished distinction.
// flutter test test/design_preview/location_bubbles_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/widgets/location_bubble.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';

import 'preview_kit.dart';

final _now = DateTime(2026, 10, 4, 16, 0);

ChatMessage _location(MessageType type, {bool ended = false}) => ChatMessage(
  id: 'location-${type.name}-$ended',
  roomId: 'preview-room',
  senderId: 'ece',
  senderName: 'Ece',
  content: '',
  type: type,
  createdAt: _now,
  latitude: 41.0138,
  longitude: 28.9497,
  locationAccuracyM: 15,
  liveExpiresAt: type == MessageType.liveLocation
      ? _now.add(const Duration(hours: 1))
      : null,
  liveUpdatedAt: _now,
  liveEndedAt: ended ? _now.subtract(const Duration(minutes: 4)) : null,
);

Widget _card(AppTheme theme, MessageType type, {bool ended = false}) =>
    LocationBubble(
      theme: theme,
      message: _location(type, ended: ended),
      isMine: ended,
      width: 285,
      radius: BorderRadius.circular(22),
      clock: () => _now,
      publishing: type == MessageType.liveLocation && !ended,
      onStopSharing: type == MessageType.liveLocation && !ended
          ? () async {}
          : null,
      stamp: MessageStamp(
        createdAt: _now,
        status: MessageStatus.sent,
        tone: StampTone.onMedia,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPreviewFonts);
  for (final theme in [
    BasicTheme.midnight(),
    BasicTheme.daylight(),
    BasicTheme.rose(),
  ]) {
    testWidgets('location cards ${theme.id}', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          Scaffold(
            backgroundColor: theme.background,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shared places', style: theme.displaySmall),
                    const SizedBox(height: 18),
                    _card(theme, MessageType.location),
                    const SizedBox(height: 18),
                    _card(theme, MessageType.liveLocation),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _card(
                        theme,
                        MessageType.liveLocation,
                        ended: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        'location_bubbles_${theme.id}.png',
        size: const Size(393, 1100),
        settle: const Duration(milliseconds: 250),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
