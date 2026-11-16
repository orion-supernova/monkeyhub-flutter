import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../media/file_url_cache.dart';
import '../media/storage/media_image_cache.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import 'chat_list_row.dart' show monogramGradient;

/// The marker on a full-screen location map: the sharer's face in a ring, a
/// name label above it, and a small dot at the exact point underneath.
///
/// Drawn here once, as a PNG, and handed to whichever map is showing it
/// (MapKit and Google take it as an annotation image; OpenFreeMap shows it as
/// a widget), so the person looks the same on every engine and the label is
/// set in the app's own type rather than each map's callout style.
class LocationPinImage {
  const LocationPinImage(this.png, this.scale, this.anchorY, this.size);

  final Uint8List png;

  /// Device pixels per point the PNG was drawn at.
  final double scale;

  /// Where the coordinate sits, as a fraction of the image's height (the
  /// centre of the dot). Horizontally it is always the middle.
  final double anchorY;

  /// Size in points.
  final Size size;

  static const double _avatar = 52;
  static const double _ringWidth = 3;
  static const double _labelHeight = 30;
  static const double _tail = 7;
  static const double _gap = 6;
  static const double _dot = 7;

  static Future<LocationPinImage?> render({
    required AppTheme theme,
    required String label,
    required ChatUser? user,
    required ChatApi? api,
    required Color ring,
    required double scale,
  }) async {
    try {
      final face = await _face(user, api);
      final dark = theme.background.computeLuminance() < 0.4;

      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: dark ? const Color(0xFFFFFFFF) : const Color(0xFF111111),
            letterSpacing: -0.1,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 220);

      final labelW = text.width + 24;
      final width = labelW > _avatar + 16 ? labelW : _avatar + 16;
      final avatarTop = _labelHeight + _tail + _gap;
      final dotCentre = avatarTop + _avatar + _gap + _dot / 2;
      final height = dotCentre + _dot / 2 + 4; // Room for the dot's shadow.
      final size = Size(width, height);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(scale);
      final cx = width / 2;
      final shadow = Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      // Label pill with a tail pointing at the face.
      final pillFill = dark ? const Color(0xF22A2A2E) : const Color(0xF7FFFFFF);
      final pill = RRect.fromRectAndRadius(
        Rect.fromLTWH((width - labelW) / 2, 0, labelW, _labelHeight),
        const Radius.circular(_labelHeight / 2),
      );
      final tail = Path()
        ..moveTo(cx - 7, _labelHeight - 1)
        ..lineTo(cx, _labelHeight + _tail)
        ..lineTo(cx + 7, _labelHeight - 1)
        ..close();
      canvas.drawRRect(pill.shift(const Offset(0, 1.5)), shadow);
      canvas.drawRRect(pill, Paint()..color = pillFill);
      canvas.drawPath(tail, Paint()..color = pillFill);
      text.paint(
        canvas,
        Offset(cx - text.width / 2, (_labelHeight - text.height) / 2),
      );

      // Face: ring, a hairline of surface, then the picture or monogram.
      final faceCentre = Offset(cx, avatarTop + _avatar / 2);
      canvas.drawCircle(faceCentre.translate(0, 2), _avatar / 2, shadow);
      canvas.drawCircle(faceCentre, _avatar / 2, Paint()..color = ring);
      canvas.drawCircle(
        faceCentre,
        _avatar / 2 - _ringWidth,
        Paint()..color = theme.surface,
      );
      final inner = _avatar / 2 - _ringWidth - 1.5;
      final faceRect = Rect.fromCircle(center: faceCentre, radius: inner);
      canvas.save();
      canvas.clipPath(Path()..addOval(faceRect));
      if (face != null) {
        paintImage(
          canvas: canvas,
          rect: faceRect,
          image: face,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        );
      } else {
        canvas.drawRect(
          faceRect,
          Paint()
            ..shader = monogramGradient(
              theme,
              _seed(user?.id ?? label),
            ).createShader(faceRect),
        );
        final initial = TextPainter(
          text: TextSpan(
            text: user?.displayInitial ??
                (label.isEmpty ? '?' : label.characters.first.toUpperCase()),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFFFFF),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        initial.paint(
          canvas,
          faceCentre - Offset(initial.width / 2, initial.height / 2),
        );
      }
      canvas.restore();

      // The exact point.
      final dot = Offset(cx, dotCentre);
      canvas.drawCircle(dot, _dot / 2 + 1.5, Paint()..color = theme.surface);
      canvas.drawCircle(dot, _dot / 2, Paint()..color = ring);

      final image = await recorder.endRecording().toImage(
        (width * scale).ceil(),
        (height * scale).ceil(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return null;
      return LocationPinImage(
        bytes.buffer.asUint8List(),
        scale,
        dotCentre / height,
        size,
      );
    } catch (_) {
      return null;
    }
  }

  static int _seed(String id) {
    var hash = 0;
    for (final c in id.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return hash;
  }

  /// The avatar picture through the same URL cache and disk cache the
  /// avatars in the chat already filled, so this is normally instant.
  static Future<ui.Image?> _face(ChatUser? user, ChatApi? api) async {
    final id = user?.avatarStorageId;
    if (id == null || id.isEmpty || api == null) return null;
    final url = await FileUrlCache.instance.resolve(id, () => api.getFileUrl(id));
    if (url == null) return null;
    final provider = CachedNetworkImageProvider(
      url,
      cacheManager: MediaImageCache.manager,
    );
    final done = Completer<ui.Image?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!done.isCompleted) done.complete(info.image.clone());
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!done.isCompleted) done.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return done.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        stream.removeListener(listener);
        return null;
      },
    );
  }
}
