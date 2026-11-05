import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_stats_monitor.dart';
import 'package:monkeyhub/calls/video_quality_governor.dart';

import 'fakes/fake_webrtc.dart';

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

/// A camera track that says what size it captures at.
class _SizedTrack extends FakeMediaStreamTrack {
  _SizedTrack(this.width, this.height) : super(kind: 'video');
  int width;
  int height;
  @override
  Map<String, dynamic> getSettings() => {'width': width, 'height': height};
}

const _uhd = VideoQualityTier.uhd4k;
const _hd = VideoQualityTier.hd1080;
const _sd = VideoQualityTier.auto;

void main() {
  final t0 = DateTime(2026, 11, 5, 12);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  group('isStrained', () {
    test('a link under 60% of the cap is strained', () {
      // 4K caps at 8 Mbps: 4.8 Mbps is the line.
      expect(VideoQualityGovernor.isStrained(snap(avail: 4000), 8000), isTrue);
      expect(VideoQualityGovernor.isStrained(snap(avail: 6000), 8000), isFalse);
    });

    test('a CPU-limited encoder is strained whatever the link', () {
      expect(
        VideoQualityGovernor.isStrained(snap(avail: 20000, limit: 'cpu'), 8000),
        isTrue,
      );
    });

    test('bandwidth-limited and sending under half the cap', () {
      expect(
        VideoQualityGovernor.isStrained(
            snap(out: 900, limit: 'bandwidth'), 2500),
        isTrue,
      );
      expect(
        VideoQualityGovernor.isStrained(
            snap(out: 2000, limit: 'bandwidth'), 2500),
        isFalse,
      );
    });

    test('no stats is no strain', () {
      expect(VideoQualityGovernor.isStrained(snap(), 8000), isFalse);
    });
  });

  group('fittingTier', () {
    test('picks the highest tier the estimate carries', () {
      // 1080p needs 1.5 Mbps of its 2.5.
      expect(
        VideoQualityGovernor.fittingTier(snap(avail: 2000), _uhd, soloCapKbps),
        _hd,
      );
      expect(
        VideoQualityGovernor.fittingTier(snap(avail: 900), _uhd, soloCapKbps),
        _sd,
      );
    });

    test('one step down without an estimate, or for the CPU', () {
      expect(VideoQualityGovernor.fittingTier(snap(), _uhd, soloCapKbps), _hd);
      expect(
        VideoQualityGovernor.fittingTier(
            snap(avail: 300, limit: 'cpu'), _uhd, soloCapKbps),
        _hd,
      );
    });
  });

  group('observe', () {
    VideoQualityAdvice? feed(
      VideoQualityGovernor g,
      CallQualitySnapshot q,
      VideoQualityTier current, {
      required int from,
      required int until,
      VideoQualityTier ceiling = _uhd,
      bool allowUp = true,
    }) {
      for (var s = from; s < until; s += 2) {
        final a = g.observe(
          q,
          current: current,
          ceiling: ceiling,
          capKbpsOf: soloCapKbps,
          now: at(s),
          allowUp: allowUp,
        );
        if (a != null) return a;
      }
      return null;
    }

    test('ignores the warmup after a connect', () {
      final g = VideoQualityGovernor()..reset(t0);
      expect(feed(g, snap(avail: 500), _uhd, from: 0, until: 14), isNull);
    });

    test('steps down after five strained polls in a row', () {
      final g = VideoQualityGovernor()..reset(t0);
      expect(feed(g, snap(avail: 500), _uhd, from: 16, until: 24), isNull);
      expect(
        feed(g, snap(avail: 500), _uhd, from: 24, until: 26),
        const VideoQualityAdvice(from: _uhd, to: _sd),
      );
    });

    test('one good poll starts the count over', () {
      final g = VideoQualityGovernor()..reset(t0);
      expect(feed(g, snap(avail: 500), _hd, from: 16, until: 24), isNull);
      expect(feed(g, snap(avail: 5000), _hd, from: 24, until: 26), isNull);
      expect(feed(g, snap(avail: 500), _hd, from: 26, until: 34), isNull);
    });

    test('never steps below auto', () {
      final g = VideoQualityGovernor()..reset(t0);
      expect(
        feed(g, snap(avail: 100), _sd, from: 16, until: 200, ceiling: _sd),
        isNull,
      );
    });

    test('steps back up one tier after 30 s of calm', () {
      final g = VideoQualityGovernor()..reset(t0);
      // 15 calm polls past the warmup.
      expect(feed(g, snap(avail: 9000), _sd, from: 16, until: 44), isNull);
      expect(
        feed(g, snap(avail: 9000), _sd, from: 44, until: 46),
        const VideoQualityAdvice(from: _sd, to: _hd),
      );
    });

    test('never steps above the ceiling, or while held', () {
      final g = VideoQualityGovernor()..reset(t0);
      expect(
        feed(g, snap(avail: 9000), _hd, from: 16, until: 200, ceiling: _hd),
        isNull,
      );
      final h = VideoQualityGovernor()..reset(t0);
      expect(
        feed(h, snap(avail: 9000), _sd, from: 16, until: 200, allowUp: false),
        isNull,
      );
    });

    test('a probe that fails doubles the wait for the next', () {
      final g = VideoQualityGovernor()..reset(t0);
      final up = feed(g, snap(avail: 9000), _sd, from: 16, until: 200)!;
      expect(up.to, _hd);
      // The link can't hold 1080p: down again inside the probe window.
      final upAt = 46;
      final down =
          feed(g, snap(avail: 500), _hd, from: upAt + 16, until: upAt + 60)!;
      expect(down.down, isTrue);
      // Calm again: the next probe now needs 60 s, not 30.
      final base = upAt + 26;
      expect(
        feed(g, snap(avail: 9000), _sd, from: base + 16, until: base + 16 + 58),
        isNull,
      );
      expect(
        feed(g, snap(avail: 9000), _sd,
            from: base + 16 + 58, until: base + 16 + 62),
        isNotNull,
      );
    });
  });

  group('sendScaleFor', () {
    test('shrinks a bigger capture to the send tier', () {
      expect(sendScaleFor(2160, _sd), 3.0);
      expect(sendScaleFor(2160, _hd), 2.0);
      expect(sendScaleFor(1080, _sd), 1.5);
    });

    test('never scales up', () {
      expect(sendScaleFor(720, _hd), 1.0);
      expect(sendScaleFor(null, _hd), 1.0);
    });
  });

  group('CallQualityAdapter', () {
    late Map<String, FakeRtpSender> senders;
    late _SizedTrack track;
    late List<VideoQualityTier> recaptures;
    late bool auto;

    CallQualityAdapter make({VideoQualityTier saved = _uhd}) {
      senders = {'a': FakeRtpSender(), 'b': FakeRtpSender()};
      track = _SizedTrack(3840, 2160);
      recaptures = [];
      auto = true;
      return CallQualityAdapter(
        savedTier: () => saved,
        autoLower: () => auto,
        linkOf: (id) {
          final s = senders[id];
          return s == null ? null : (sender: s, capKbpsOf: soloCapKbps);
        },
        captureTrack: () => track,
        recaptureCamera: (tier) async {
          recaptures.add(tier);
          final h = switch (tier) { _sd => 720, _hd => 1080, _uhd => 2160 };
          track = _SizedTrack(h * 16 ~/ 9, h);
        },
      );
    }

    double? scaleOf(String id) =>
        senders[id]!.parameters.encodings?.first.scaleResolutionDownBy;
    int? capOf(String id) =>
        senders[id]!.parameters.encodings?.first.maxBitrate;

    /// Feeds [q] to link [id] every 2 s over [from, until).
    Future<void> poll(
      CallQualityAdapter a,
      String id,
      CallQualitySnapshot q, {
      required int from,
      required int until,
    }) async {
      for (var s = from; s < until; s += 2) {
        a.onPoll(id, q, at(s));
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a weak link shrinks the encoder, never restarts the camera',
        () async {
      final a = make()..connected('a', t0);
      await poll(a, 'a', snap(avail: 900), from: 16, until: 26);
      expect(scaleOf('a'), 3.0); // 2160p capture sent as 720p
      expect(capOf('a'), 1200000);
      expect(recaptures, isEmpty);
      expect(a.liveTier, _sd);
      expect(a.qualityNotice.value?.applied, isTrue);
    });

    test('and grows back when the link recovers', () async {
      final a = make()..connected('a', t0);
      await poll(a, 'a', snap(avail: 900), from: 16, until: 26);
      // Warmup after the step, then 30 s calm per step: 720p -> 1080p -> 4K.
      await poll(a, 'a', snap(avail: 20000), from: 26, until: 200);
      expect(scaleOf('a'), 1.0);
      expect(capOf('a'), 8000000);
      expect(a.liveTier, _uhd);
      expect(recaptures, isEmpty);
      expect(a.qualityNotice.value, isNull);
    });

    test('a CPU-limited phone also captures smaller', () async {
      final a = make()..connected('a', t0);
      await poll(a, 'a', snap(avail: 20000, limit: 'cpu'),
          from: 16, until: 26);
      expect(recaptures, [_hd]);
      // Re-captured at 1080p and sending 1080p: no shrink left.
      expect(scaleOf('a'), 1.0);
      expect(a.captureTier, _hd);
    });

    test('a link low for two minutes stops capturing what nobody gets',
        () async {
      final a = make()..connected('a', t0);
      await poll(a, 'a', snap(avail: 900), from: 16, until: 26);
      expect(recaptures, isEmpty);
      // Still weak (no up, no further down: already at 720p).
      await poll(a, 'a', snap(avail: 900), from: 26, until: 26 + 122);
      expect(recaptures, [_sd]);
    });

    test('in a group only the weak link drops, and the camera stays',
        () async {
      final a = make()
        ..connected('a', t0)
        ..connected('b', t0);
      for (var s = 16; s < 26 + 130; s += 2) {
        a.onPoll('a', snap(avail: 900), at(s));
        a.onPoll('b', snap(avail: 20000), at(s));
        await Future<void>.delayed(Duration.zero);
      }
      expect(scaleOf('a'), 3.0);
      expect(senders['b']!.parameters.encodings, isNull);
      expect(a.liveTier, _uhd);
      // b still takes 4K, so the shared camera keeps capturing it.
      expect(recaptures, isEmpty);
    });

    test('with auto-lowering off it offers, once, and changes nothing',
        () async {
      final a = make()..connected('a', t0);
      auto = false;
      await poll(a, 'a', snap(avail: 900), from: 16, until: 60);
      final n = a.qualityNotice.value!;
      expect(n.applied, isFalse);
      expect(n.from, _uhd);
      expect(n.to, _sd);
      expect(senders['a']!.parameters.encodings, isNull);
      a.dismissQualityNotice();
      await poll(a, 'a', snap(avail: 900), from: 60, until: 120);
      expect(a.qualityNotice.value, isNull);
    });

    test('taking the offer holds the lower tier for the call', () async {
      final a = make()..connected('a', t0);
      auto = false;
      await poll(a, 'a', snap(avail: 900), from: 16, until: 26);
      await a.lowerVideoQualityForCall(_hd);
      expect(scaleOf('a'), 2.0);
      auto = true;
      await poll(a, 'a', snap(avail: 20000), from: 26, until: 200);
      expect(a.liveTier, _hd);
    });

    test('auto tier: nothing to do, libwebrtc adapts by itself', () async {
      final a = make(saved: _sd)..connected('a', t0);
      await poll(a, 'a', snap(avail: 100), from: 16, until: 200);
      expect(senders['a']!.parameters.encodings, isNull);
      expect(a.qualityNotice.value, isNull);
    });
  });
}
