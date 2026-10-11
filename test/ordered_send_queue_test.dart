import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/ordered_send_queue.dart';

/// Photos go up in parallel and land in the order they were picked: the other
/// side's album must match the sender's preview, whichever upload wins.
void main() {
  test('posts land in send order when uploads finish out of order', () async {
    final q = OrderedSendQueue(slots: 3);
    final uploads = [Completer<bool>(), Completer<bool>(), Completer<bool>()];
    final posted = <int>[];
    final done = [
      for (var i = 0; i < 3; i++)
        q.add(
          upload: () => uploads[i].future,
          post: () async => posted.add(i),
        ),
    ];
    uploads[2].complete(true);
    uploads[1].complete(true);
    await pumpEventQueue();
    expect(posted, isEmpty, reason: 'nothing posts ahead of the first photo');
    uploads[0].complete(true);
    await Future.wait(done);
    expect(posted, [0, 1, 2]);
  });

  test('uploads overlap, up to the slot count', () async {
    final q = OrderedSendQueue(slots: 2);
    var running = 0, peak = 0;
    final gates = [for (var i = 0; i < 5; i++) Completer<void>()];
    final done = [
      for (var i = 0; i < 5; i++)
        q.add(
          upload: () async {
            running++;
            peak = peak < running ? running : peak;
            await gates[i].future;
            running--;
            return true;
          },
          post: () async {},
        ),
    ];
    await pumpEventQueue();
    expect(running, 2);
    for (final g in gates) {
      g.complete();
      await pumpEventQueue();
    }
    await Future.wait(done);
    expect(peak, 2);
  });

  test('a failed upload skips its post and holds nothing up', () async {
    final q = OrderedSendQueue();
    final posted = <int>[];
    await Future.wait([
      q.add(upload: () async => true, post: () async => posted.add(0)),
      q.add(upload: () async => false, post: () async => posted.add(1)),
      q.add(upload: () async => throw StateError('bug'),
          post: () async => posted.add(2)),
      q.add(upload: () async => true, post: () async => posted.add(3)),
    ]);
    expect(posted, [0, 3]);
  });
}
