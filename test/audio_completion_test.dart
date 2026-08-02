import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/audio_message.dart';

/// What this pins: what a voice note looks like once it has finished.
///
/// `just_audio` does NOT clear `playing` when a track ends. It emits
/// `PlayerState(playing: true, processingState: completed)` and stays there.
/// Believing that flag produced three symptoms from one cause:
///
///  1. a finished note kept showing the PAUSE glyph, as though still playing;
///  2. the tap handler read the same flag, took its `pause()` branch, and so
///     the first tap after a note ended did nothing — replaying took two taps;
///  3. the scrubber stopped short, because the position stream's last emission
///     lands a tick under the duration and then goes quiet, leaving the bar at
///     ~97% and the readout saying `0:41 / 0:42`.
///
/// All three are the same question — "is `completed` or `playing` the
/// authority?" — which is why this is one pure function and not three fixes.
void main() {
  const total = Duration(seconds: 42);

  group('while playing', () {
    test('reports playing and a real position', () {
      final d = audioDisplayFor(
        rawPlaying: true,
        completed: false,
        position: const Duration(seconds: 21),
        total: total,
      );
      expect(d.playing, isTrue);
      expect(d.progress, closeTo(0.5, 0.001));
      expect(d.elapsed, const Duration(seconds: 21));
    });

    test('paused mid-way holds its place', () {
      final d = audioDisplayFor(
        rawPlaying: false,
        completed: false,
        position: const Duration(seconds: 21),
        total: total,
      );
      expect(d.playing, isFalse);
      expect(d.progress, closeTo(0.5, 0.001));
    });
  });

  group('once finished', () {
    /// The exact state `just_audio` leaves behind: still flagged playing, and
    /// a position a tick short of the end.
    AudioDisplay finished() => audioDisplayFor(
      rawPlaying: true,
      completed: true,
      position: const Duration(seconds: 41, milliseconds: 700),
      total: total,
    );

    test('is not playing, whatever the raw flag says', () {
      expect(
        finished().playing,
        isFalse,
        reason:
            'this is what drew a pause button on a stopped note, and '
            'what sent the tap handler down its pause() branch so replaying '
            'took two taps',
      );
    });

    test('the bar arrives at the end', () {
      expect(
        finished().progress,
        1.0,
        reason:
            'the position stream stops short, so a computed progress '
            'rests at ~97% — a bar that visibly never finishes',
      );
    });

    test('the readout shows the full duration, not the last tick', () {
      expect(
        finished().elapsed,
        total,
        reason:
            'otherwise a finished note reads "0:41 / 0:42" and looks '
            'like it stopped early',
      );
    });
  });

  group('degenerate inputs', () {
    test('an unknown duration is 0 progress, not a divide by zero', () {
      final d = audioDisplayFor(
        rawPlaying: false,
        completed: false,
        position: Duration.zero,
        total: Duration.zero,
      );
      expect(d.progress, 0.0);
    });

    test('a position past the end is clamped', () {
      // Some platforms overshoot on the final tick.
      final d = audioDisplayFor(
        rawPlaying: true,
        completed: false,
        position: const Duration(seconds: 45),
        total: total,
      );
      expect(d.progress, 1.0);
    });

    test('completed wins even with a zero duration', () {
      final d = audioDisplayFor(
        rawPlaying: true,
        completed: true,
        position: Duration.zero,
        total: Duration.zero,
      );
      expect(d.playing, isFalse);
      expect(d.progress, 1.0);
    });
  });
}
