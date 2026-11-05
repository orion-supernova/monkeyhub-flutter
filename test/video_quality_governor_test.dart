import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_stats_monitor.dart';
import 'package:monkeyhub/calls/video_quality_governor.dart';

CallQualitySnapshot snap({
  double? avail,
  double? out,
  String? limit,
  CallQuality quality = CallQuality.good,
}) =>
    CallQualitySnapshot(
      quality: quality,
      availableOutKbps: avail,
      outKbps: out,
      limitationReason: limit,
    );

void main() {
  final t0 = DateTime(2026, 11, 5, 12);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  group('isStrained', () {
    test('a link under 60% of the tier cap is strained', () {
      // 4K caps at 8 Mbps: 4.8 Mbps is the line.
      expect(
        VideoQualityGovernor.isStrained(
          snap(avail: 4000),
          VideoQualityTier.uhd4k,
        ),
        isTrue,
      );
      expect(
        VideoQualityGovernor.isStrained(
          snap(avail: 6000),
          VideoQualityTier.uhd4k,
        ),
        isFalse,
      );
    });

    test('a CPU-limited encoder is strained whatever the link', () {
      expect(
        VideoQualityGovernor.isStrained(
          snap(avail: 20000, limit: 'cpu'),
          VideoQualityTier.uhd4k,
        ),
        isTrue,
      );
    });

    test('bandwidth-limited and sending under half the cap', () {
      expect(
        VideoQualityGovernor.isStrained(
          snap(out: 900, limit: 'bandwidth'),
          VideoQualityTier.hd1080,
        ),
        isTrue,
      );
      expect(
        VideoQualityGovernor.isStrained(
          snap(out: 2000, limit: 'bandwidth'),
          VideoQualityTier.hd1080,
        ),
        isFalse,
      );
    });

    test('no stats is no strain', () {
      expect(
        VideoQualityGovernor.isStrained(snap(), VideoQualityTier.uhd4k),
        isFalse,
      );
    });
  });

  group('fittingTier', () {
    test('4K on a 2 Mbps link drops past 1080p to 720p', () {
      // 1080p needs 1.5 Mbps of 2.5; 2 Mbps carries it.
      expect(
        VideoQualityGovernor.fittingTier(
          snap(avail: 2000),
          VideoQualityTier.uhd4k,
        ),
        VideoQualityTier.hd1080,
      );
      expect(
        VideoQualityGovernor.fittingTier(
          snap(avail: 900),
          VideoQualityTier.uhd4k,
        ),
        VideoQualityTier.auto,
      );
    });

    test('one step down without an estimate, or for the CPU', () {
      expect(
        VideoQualityGovernor.fittingTier(snap(), VideoQualityTier.uhd4k),
        VideoQualityTier.hd1080,
      );
      expect(
        VideoQualityGovernor.fittingTier(
          snap(avail: 300, limit: 'cpu'),
          VideoQualityTier.uhd4k,
        ),
        VideoQualityTier.hd1080,
      );
    });
  });

  group('observe', () {
    test('ignores the warmup after a connect', () {
      final g = VideoQualityGovernor()..reset(t0);
      for (var s = 0; s < 14; s += 2) {
        expect(g.observe(snap(avail: 500), VideoQualityTier.uhd4k, at(s)),
            isNull);
      }
    });

    test('advises after five strained polls in a row', () {
      final g = VideoQualityGovernor()..reset(t0);
      VideoQualityAdvice? advice;
      var polls = 0;
      for (var s = 16; advice == null && s < 60; s += 2) {
        advice = g.observe(snap(avail: 500), VideoQualityTier.uhd4k, at(s));
        polls++;
      }
      expect(polls, 5);
      expect(
        advice,
        const VideoQualityAdvice(
          from: VideoQualityTier.uhd4k,
          to: VideoQualityTier.auto,
        ),
      );
    });

    test('one good poll starts the count over', () {
      final g = VideoQualityGovernor()..reset(t0);
      for (var s = 16; s < 24; s += 2) {
        expect(g.observe(snap(avail: 500), VideoQualityTier.hd1080, at(s)),
            isNull);
      }
      expect(g.observe(snap(avail: 5000), VideoQualityTier.hd1080, at(24)),
          isNull);
      for (var s = 26; s < 34; s += 2) {
        expect(g.observe(snap(avail: 500), VideoQualityTier.hd1080, at(s)),
            isNull);
      }
    });

    test('never advises below auto', () {
      final g = VideoQualityGovernor()..reset(t0);
      for (var s = 16; s < 60; s += 2) {
        expect(g.observe(snap(avail: 100), VideoQualityTier.auto, at(s)),
            isNull);
      }
    });

    test('after advice, the next one needs a fresh warmup and window', () {
      final g = VideoQualityGovernor()..reset(t0);
      VideoQualityAdvice? first;
      var s = 16;
      for (; first == null; s += 2) {
        first = g.observe(snap(avail: 500), VideoQualityTier.uhd4k, at(s));
      }
      // Straight after: still inside the new warmup.
      expect(g.observe(snap(avail: 500), VideoQualityTier.uhd4k, at(s)),
          isNull);
    });
  });
}
