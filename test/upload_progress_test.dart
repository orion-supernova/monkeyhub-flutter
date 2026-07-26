import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/upload_service.dart';

/// The body-streaming half of [UploadService], with no socket involved.
///
/// The interesting property is a negative one that cannot be seen from the
/// outside: the counter has to track the *wire*, not the loop that fed it.
/// `http.StreamedRequest` — the obvious choice — hands you an `EventSink` with no
/// backpressure, so pushing chunks into it reports 100% the instant the push loop
/// finishes however slow the network is. A lazy stream is piped with `addStream`,
/// which pauses the generator whenever the socket's sink is full, so the count
/// means something. What can be pinned here is that the stream is complete, in
/// order, correctly counted, and correctly declared.
void main() {
  Uint8List bytesOf(int n) =>
      Uint8List.fromList(List<int>.generate(n, (i) => i % 251));

  test('declares Content-Length rather than falling back to chunked', () {
    // Without this dart:io switches to chunked transfer-encoding, and nobody has
    // verified Convex's upload endpoint accepts that body shape.
    final req = ProgressRequest(Uri.parse('https://x/y'), bytesOf(1234), null);
    expect(req.contentLength, 1234);
  });

  test('yields every byte, in order', () async {
    final source = bytesOf(ProgressRequest.chunkSize * 2 + 17);
    final req = ProgressRequest(Uri.parse('https://x/y'), source, null);

    final out = await req.finalize().toBytes();

    expect(out.length, source.length);
    expect(out, source);
  });

  test('reports cumulative counts that rise once and land on the total',
      () async {
    final source = bytesOf(ProgressRequest.chunkSize * 3 + 5);
    final seen = <int>[];
    final req = ProgressRequest(Uri.parse('https://x/y'), source, seen.add);

    await req.finalize().toBytes();

    expect(seen, isNotEmpty);
    expect(seen.last, source.length);
    // Cumulative, so strictly increasing — a counter that ever went backwards
    // would make the arc jump.
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThan(seen[i - 1]));
    }
    // One report per chunk, and the last chunk is the short remainder.
    expect(seen.length, 4);
    expect(seen.first, ProgressRequest.chunkSize);
  });

  test('a body smaller than one chunk reports exactly once', () async {
    final seen = <int>[];
    final req = ProgressRequest(Uri.parse('https://x/y'), bytesOf(10), seen.add);

    await req.finalize().toBytes();

    expect(seen, [10]);
  });

  test('an empty body still reports, so nothing waits on an arc that never fills',
      () async {
    final seen = <int>[];
    final req = ProgressRequest(
      Uri.parse('https://x/y'),
      Uint8List(0),
      seen.add,
    );

    final out = await req.finalize().toBytes();

    expect(out, isEmpty);
    expect(seen, [0]);
  });

  test('a cancelled task reports itself as cancelled', () {
    final task = UploadTask();
    expect(task.cancelled, isFalse);
    task.cancel();
    expect(task.cancelled, isTrue);
    // Idempotent: the repository cancels on discard and again on dispose.
    task.cancel();
    expect(task.cancelled, isTrue);
  });
}
