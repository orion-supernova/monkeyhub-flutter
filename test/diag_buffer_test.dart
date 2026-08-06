import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/diagnostics/diag_buffer.dart';
import 'package:monkeyhub/diagnostics/diag_event.dart';

/// Bounds and crash-survival for the diagnostics ring.
///
/// Both properties are the kind that look fine in manual testing and fail on
/// the one device you cannot reach: an unbounded buffer only hurts during the
/// burst you were trying to capture, and a persistence format that cannot
/// tolerate a torn write only fails when the process dies — which is exactly
/// the log somebody wanted.
void main() {
  final buf = DiagBuffer.instance;

  setUp(buf.resetForTest);

  DiagEvent add({String? body, String? detail}) => buf.add(
    cat: DiagCat.api,
    sev: DiagSev.debug,
    event: 'query',
    name: 'users:heartbeat',
    body: body,
    detail: detail,
  );

  group('count cap', () {
    test('holds maxEvents and counts everything it dropped', () {
      for (var i = 0; i < DiagBuffer.maxEvents + 2000; i++) {
        add(detail: 'e$i');
      }
      expect(buf.length, DiagBuffer.maxEvents);
      expect(buf.dropped, 2000);
    });

    test('keeps the NEWEST events, since those explain what just happened', () {
      for (var i = 0; i < DiagBuffer.maxEvents + 10; i++) {
        add(detail: 'e$i');
      }
      final last = buf.snapshot().last;
      expect(last.detail, 'e${DiagBuffer.maxEvents + 9}');
    });

    test('seq keeps increasing across evictions', () {
      // Eviction must not renumber: seq is the identity that correlates a
      // request with the result that arrives after the request itself was
      // evicted.
      for (var i = 0; i < DiagBuffer.maxEvents + 50; i++) {
        add(detail: 'e$i');
      }
      final snap = buf.snapshot();
      for (var i = 1; i < snap.length; i++) {
        expect(snap[i].seq, greaterThan(snap[i - 1].seq));
      }
      expect(snap.first.seq, greaterThan(1));
    });
  });

  group('byte cap', () {
    test('a few huge bodies evict long before the count cap is reached', () {
      // The reason a count cap alone is not a memory bound: one Convex page can
      // be most of a megabyte, so 3000 events could be hundreds of MB.
      final big = 'x' * DiagBuffer.maxBodyChars;
      for (var i = 0; i < 4000; i++) {
        add(body: big);
      }
      expect(buf.length, lessThan(DiagBuffer.maxEvents));
      expect(buf.bytes, lessThanOrEqualTo(DiagBuffer.maxBytes));
      expect(buf.dropped, greaterThan(0));
    });

    test('accounting returns to zero after clear', () {
      for (var i = 0; i < 100; i++) {
        add(body: 'y' * 500);
      }
      expect(buf.bytes, greaterThan(0));
      buf.clear();
      expect(buf.bytes, 0);
      expect(buf.length, 0);
    });
  });

  group('body truncation', () {
    test('oversized bodies are cut at write time and marked', () {
      final e = add(body: 'z' * (DiagBuffer.maxBodyChars + 5000));
      expect(e.bodyTruncated, isTrue);
      expect(e.body!.length, lessThan(DiagBuffer.maxBodyChars + 100));
      expect(e.body, contains('truncated'));
    });

    test('bodies under the limit are untouched', () {
      final e = add(body: 'short');
      expect(e.bodyTruncated, isFalse);
      expect(e.body, 'short');
    });
  });

  group('NDJSON', () {
    test('round-trips every field', () {
      final e = buf.add(
        cat: DiagCat.connection,
        sev: DiagSev.warn,
        event: 'phase',
        name: 'health',
        corrId: '7',
        durationMs: 42,
        ok: false,
        detail: 'online -> stalled',
        body: '{"a":1}',
      );
      final back = DiagEvent.parseNdjson(e.toNdjsonLine()).single;
      expect(back.seq, e.seq);
      expect(back.cat, DiagCat.connection);
      expect(back.sev, DiagSev.warn);
      expect(back.event, 'phase');
      expect(back.name, 'health');
      expect(back.corrId, '7');
      expect(back.durationMs, 42);
      expect(back.ok, isFalse);
      expect(back.detail, 'online -> stalled');
      expect(back.body, '{"a":1}');
    });

    test('a torn final line still yields every complete line before it', () {
      // The whole reason the on-disk format is NDJSON rather than a JSON array.
      // A process killed mid-write leaves a half line; a truncated array is
      // simply unparseable, and you lose the entire session.
      final good = [
        for (var i = 0; i < 5; i++) add(detail: 'e$i').toNdjsonLine(),
      ].join();
      final torn = '$good{"s":99,"t":1,"u":1,"c":"api","v":"debug","e":"qu';

      final parsed = DiagEvent.parseNdjson(torn);
      expect(parsed.length, 5);
      expect(parsed.last.detail, 'e4');
    });

    test('a line with an unknown enum value is skipped, not fatal', () {
      const bad = '{"s":1,"t":1,"u":1,"c":"notACategory","v":"debug","e":"x"}\n';
      final ok = add(detail: 'fine').toNdjsonLine();
      final parsed = DiagEvent.parseNdjson('$bad$ok');
      expect(parsed.length, 1);
      expect(parsed.single.detail, 'fine');
    });

    test('garbage between good lines is skipped', () {
      final a = add(detail: 'a').toNdjsonLine();
      final b = add(detail: 'b').toNdjsonLine();
      final parsed = DiagEvent.parseNdjson('${a}not json at all\n$b');
      expect(parsed.map((e) => e.detail), ['a', 'b']);
    });
  });

  group('revision counter', () {
    test('bumps on add and on clear so the viewer can rebuild off it', () {
      final before = buf.revision.value;
      add(detail: 'x');
      expect(buf.revision.value, greaterThan(before));
      final afterAdd = buf.revision.value;
      buf.clear();
      expect(buf.revision.value, greaterThan(afterAdd));
    });
  });

  group('pretty body', () {
    test('pretty-prints JSON once and passes non-JSON through unchanged', () {
      final json = add(body: '{"b":2,"a":1}');
      expect(json.prettyBody, contains('\n'));
      // Cached: the same instance must not re-parse per read.
      expect(identical(json.prettyBody, json.prettyBody), isTrue);

      final plain = add(body: 'ConnectionHealth: not json');
      expect(plain.prettyBody, 'ConnectionHealth: not json');
    });
  });
}
