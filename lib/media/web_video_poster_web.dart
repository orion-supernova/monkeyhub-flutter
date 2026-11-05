import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

import 'blob_url_web.dart';

/// Grabs a still from in-memory video bytes in the browser.
///
/// Without one, a video posted from the web had nothing to show anywhere: no
/// rail card, no full-screen page, and so no way to open it at all.
class WebVideoPoster {
  const WebVideoPoster._();

  /// Same size and quality as `VideoPoster`, so a poster looks the same
  /// whichever device made it.
  static const _maxEdge = 640;
  static const _quality = 0.7;

  /// A JPEG frame from [bytes] (MIME [type]), or null when the browser cannot
  /// decode the clip. Never throws: a poster is an enhancement to a post that
  /// must go regardless.
  static Future<Uint8List?> fromBytes(Uint8List bytes, String type) async {
    final url = BlobUrl.create(bytes, type);
    if (url == null) return null;
    final video = web.document.createElement('video') as web.HTMLVideoElement
      ..muted = true
      ..playsInline = true
      ..preload = 'auto';
    try {
      video.src = url;
      await _next(video, 'loadeddata');
      // Frame zero is black on a surprising number of clips (fades, screen
      // recordings); half a second in is the same choice `VideoPoster` makes.
      final d = video.duration;
      final at = d.isFinite && d > 0 ? math.min(0.5, d / 2) : 0.0;
      if (at > 0) {
        video.currentTime = at;
        await _next(video, 'seeked');
      }
      final w = video.videoWidth;
      final h = video.videoHeight;
      if (w <= 0 || h <= 0) return null;
      final scale = math.min(1.0, _maxEdge / math.max(w, h));
      final cw = (w * scale).round();
      final ch = (h * scale).round();
      final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
        ..width = cw
        ..height = ch;
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(video, 0, 0, cw, ch);
      final done = Completer<web.Blob?>();
      canvas.toBlob(
        ((web.Blob? b) => done.complete(b)).toJS,
        'image/jpeg',
        _quality.toJS,
      );
      final blob = await done.future.timeout(const Duration(seconds: 5));
      if (blob == null) return null;
      final buffer = await blob.arrayBuffer().toDart;
      final out = buffer.toDart.asUint8List();
      return out.isEmpty ? null : out;
    } catch (e) {
      debugPrint('web poster failed: $e');
      return null;
    } finally {
      video.removeAttribute('src');
      video.load();
      BlobUrl.revoke(url);
    }
  }

  /// The next [type] event on [video], or an error if the clip cannot be
  /// decoded or takes too long to say so.
  static Future<void> _next(web.HTMLVideoElement video, String type) {
    final done = Completer<void>();
    late final JSFunction onOk;
    late final JSFunction onErr;
    void detach() {
      video.removeEventListener(type, onOk);
      video.removeEventListener('error', onErr);
    }

    onOk = ((web.Event _) {
      detach();
      if (!done.isCompleted) done.complete();
    }).toJS;
    onErr = ((web.Event _) {
      detach();
      if (!done.isCompleted) done.completeError(StateError('decode'));
    }).toJS;
    video.addEventListener(type, onOk);
    video.addEventListener('error', onErr);
    return done.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        detach();
        throw TimeoutException('video $type');
      },
    );
  }
}
