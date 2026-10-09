import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/file_meta.dart';
import 'package:monkeyhub/media/video_shrink.dart';

/// What this pins: **one size rule for every video, per video.**
///
///  * At or under the cap a video is sent as it is, whatever else is going.
///  * Over it, it is compressed where the platform can, refused where not.
void main() {
  const cap = kMaxFileUploadBytes;

  test('at or under the cap goes as it is', () {
    expect(videoFateFor(5 * 1024 * 1024), VideoFate.asIs);
    expect(videoFateFor(cap), VideoFate.asIs);
    expect(videoFateFor(cap, canShrink: false), VideoFate.asIs);
  });

  test('over the cap is compressed where it can be, refused where not', () {
    expect(videoFateFor(cap + 1), VideoFate.shrink);
    expect(videoFateFor(cap + 1, canShrink: false), VideoFate.refuse);
  });

  test('five 5 MB clips are five clips under the cap', () {
    final fates = [for (var i = 0; i < 5; i++) videoFateFor(5 * 1024 * 1024)];
    expect(fates, everyElement(VideoFate.asIs));
  });

  test('content type follows the container', () {
    expect(videoContentTypeFor('/a/IMG_0001.MOV'), 'video/quicktime');
    expect(videoContentTypeFor('/a/clip.mp4'), 'video/mp4');
    expect(videoContentTypeFor('/a/clip.m4v'), 'video/x-m4v');
    expect(videoContentTypeFor('/a/clip.webm'), 'video/webm');
    expect(videoContentTypeFor('/a/REC_123'), 'video/mp4');
  });
}
