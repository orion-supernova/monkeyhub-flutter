import 'dart:typed_data';

/// Off-web stub. Native platforms extract posters from a file path with
/// `VideoPoster`; see `web_video_poster.dart`.
class WebVideoPoster {
  const WebVideoPoster._();

  static Future<Uint8List?> fromBytes(Uint8List bytes, String type) async =>
      null;
}
