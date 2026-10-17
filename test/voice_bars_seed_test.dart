import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/pending_upload.dart';
import 'package:monkeyhub/widgets/audio_message.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';

/// A voice note's bars keep their shape from the uploading row to the
/// finished player: the flight lands on the uploading row's bars, and a
/// change of shape the moment the upload finishes would be a glitch right
/// after landing.
void main() {
  List<double> bars(ChatMessage m) => voiceWaveformHeights((voiceBarsSeedKey(m) ?? '').hashCode);

  ChatMessage optimistic() => ChatMessage(
        id: 'local_1700000000000',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'me',
        content: '',
        createdAt: DateTime(2026, 10, 17, 14),
        type: MessageType.audio,
        upload: PendingUpload(bytes: Uint8List(3), contentType: 'audio/mp4'),
      );

  // The server's row for it, echoing the optimistic id as its client id.
  ChatMessage live() => ChatMessage.fromJson({
        '_id': 'k57abc',
        'roomId': 'r1',
        'userId': 'u1',
        'content': '',
        'createdAt': 1700000000000,
        'type': 'audio',
        'mediaStorageId': 'kg2storage',
        'clientId': 'local_1700000000000',
      });

  test('the uploading row and the live row draw the same bars', () {
    final before = optimistic();
    final after = live();
    expect(after.clientId, before.id, reason: 'the echo carries the local id');
    expect(voiceBarsSeedKey(after), voiceBarsSeedKey(before));
    expect(bars(after), bars(before));
  });

  // Acked, the optimistic bubble stays up (still holding its upload) until
  // the live row replaces it (`pending_reconcile.dart`): all three agree.
  test('so does the optimistic row once acked, before the echo', () {
    final before = optimistic();
    final acked = optimistic()..serverId = 'k57abc';
    expect(bars(acked), bars(before));
    expect(bars(live()), bars(acked));
  });

  test('a note from before client ids keeps its storage-id shape', () {
    final old = ChatMessage.fromJson({
      '_id': 'k57old',
      'roomId': 'r1',
      'userId': 'u1',
      'content': '',
      'createdAt': 1600000000000,
      'type': 'audio',
      'mediaStorageId': 'kg2old',
    });
    expect(voiceBarsSeedKey(old), 'kg2old');
  });
}
