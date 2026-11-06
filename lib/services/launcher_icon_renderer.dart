import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/brand_icon_canvas.dart';
import '../widgets/monkey_collection.dart';
import 'launcher_icon_names.dart';

/// The silhouette a desktop OS expects of an app icon.
enum DesktopIconShape {
  /// Apple's macOS icon: a continuous-corner rounded square inset on a
  /// transparent canvas, with a soft drop shadow. An image given to
  /// `NSApp.applicationIconImage` is shown exactly as drawn (only asset-catalog
  /// icons get the system's mask), so the shape has to be baked in.
  macSquircle,

  /// Full-bleed square, as the Windows .ico and the Linux icon already ship.
  square,
}

/// Draws the icon behind a launcher-icon name as PNG bytes, at runtime.
///
/// The art is the very widget the picker tile and `test/generate_launcher_icons.dart`
/// use ([BrandIconCanvas] per theme, [MonkeyIconCanvas] for the Monkey
/// Collection), so what a desktop shows is what the picker showed. Desktop
/// platforms have no per-icon asset to switch to, which is why this exists:
/// nothing extra is shipped, the chosen art is rendered when it is chosen.
class LauncherIconRenderer {
  LauncherIconRenderer._();

  // Apple's macOS icon template on a 1024 canvas: an 824 body, 100 of margin
  // each side, corner radius ~22.4% of the body, shadow 12 down.
  static const double _macBody = 824 / 1024;
  static const double _macRadius = 0.2237;

  /// The theme whose icon carries platform name [iconName], or null when it is
  /// not a theme icon. Borrowing themes (see [kBorrowedIconThemeIds]) resolve
  /// to their owner because only the owner has art of its own.
  static AppTheme? themeForIconName(String iconName) {
    for (final t in ThemeController.all) {
      if (kBorrowedIconThemeIds.contains(t.id)) continue;
      if (launcherIconNameForThemeId(t.id) == iconName) return t;
    }
    return null;
  }

  /// Whether [iconName] has art to draw.
  static bool canRender(String iconName) =>
      monkeyCollectionIds.contains(iconName) ||
      themeForIconName(iconName) != null;

  /// The edge-to-edge art for [iconName] at [size] logical pixels, or null.
  static Widget? artFor(String iconName, double size) {
    final variant = monkeyVariantById(iconName);
    if (variant != null) return MonkeyIconCanvas(variant: variant, size: size);
    final theme = themeForIconName(iconName);
    if (theme != null) return BrandIconCanvas(theme: theme, size: size);
    return null;
  }

  /// Renders [iconName] as a [px] x [px] PNG in [shape], or null when the name
  /// has no art or rendering failed. Never throws.
  static Future<Uint8List?> renderPng(
    String iconName, {
    required int px,
    required DesktopIconShape shape,
  }) async {
    try {
      final bodyPx = shape == DesktopIconShape.macSquircle
          ? (px * _macBody).roundToDouble()
          : px.toDouble();
      final art = artFor(iconName, bodyPx);
      if (art == null) return null;
      final image = await _renderWidget(art, bodyPx.toInt());
      try {
        return await _compose(image, px, shape);
      } finally {
        image.dispose();
      }
    } catch (e, st) {
      debugPrint('[launcher_icon] render failed for $iconName: $e\n$st');
      return null;
    }
  }

  /// Scales PNG bytes to [px] x [px] (for the extra sizes Linux wants).
  static Future<Uint8List?> resizePng(Uint8List png, int px) async {
    try {
      final codec = await ui.instantiateImageCodec(
        png,
        targetWidth: px,
        targetHeight: px,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[launcher_icon] resize failed: $e');
      return null;
    }
  }

  static Future<Uint8List> _compose(
    ui.Image art,
    int px,
    DesktopIconShape shape,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final src = Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.high;
    if (shape == DesktopIconShape.macSquircle) {
      final body = art.width.toDouble();
      final inset = (px - body) / 2;
      final rect = Rect.fromLTWH(inset, inset, body, body);
      final body2 = RSuperellipse.fromRectAndRadius(
        rect,
        Radius.circular(body * _macRadius),
      );
      canvas.drawRSuperellipse(
        body2.shift(Offset(0, px * 12 / 1024)),
        Paint()
          ..color = const Color(0x47000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, px * 11 / 1024),
      );
      canvas.save();
      canvas.clipRSuperellipse(body2);
      canvas.drawImageRect(art, src, rect, paint);
      canvas.restore();
    } else {
      canvas.drawImageRect(
        art,
        src,
        Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
        paint,
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(px, px);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  /// Lays out and paints [art] in a detached render tree and returns the
  /// pixels. Detached because the picker may not be on screen (the icon is
  /// applied at launch) and the art must not flash into the live UI.
  ///
  /// Two passes: the first lets async assets (images, the bundled Google Fonts
  /// faces) load; the second remounts the tree so text laid out in a fallback
  /// face while the real one loaded is laid out again.
  static Future<ui.Image> _renderWidget(Widget art, int size) async {
    final logical = size.toDouble();
    final boundary = RenderRepaintBoundary();
    final view = ui.PlatformDispatcher.instance.implicitView ??
        ui.PlatformDispatcher.instance.views.first;
    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(Size(logical, logical)),
        physicalConstraints: BoxConstraints.tight(Size(logical, logical)),
        devicePixelRatio: 1.0,
      ),
      child: boundary,
    );
    final pipeline = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final buildOwner = BuildOwner(focusManager: FocusManager());

    Widget wrap(Widget child, Key key) => KeyedSubtree(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(size: Size(logical, logical)),
              child: Theme(
                data: ThemeData(),
                // Transparent Material + a style: text outside a Scaffold
                // would otherwise draw Flutter's yellow debug underline.
                child: Material(
                  type: MaterialType.transparency,
                  child: DefaultTextStyle(
                    style: const TextStyle(decoration: TextDecoration.none),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );

    late RenderObjectToWidgetElement<RenderBox> element;
    void pump() {
      buildOwner.buildScope(element);
      buildOwner.finalizeTree();
      pipeline.flushLayout();
      pipeline.flushCompositingBits();
      pipeline.flushPaint();
    }

    final adapter = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: wrap(art, UniqueKey()),
    );
    element = adapter.attachToRenderTree(buildOwner);
    try {
      for (var i = 0; i < 6; i++) {
        pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: wrap(art, UniqueKey()),
      ).attachToRenderTree(buildOwner, element);
      for (var i = 0; i < 2; i++) {
        pump();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      pump();
      return await boundary.toImage(pixelRatio: 1.0);
    } finally {
      RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: null,
      ).attachToRenderTree(buildOwner, element);
      buildOwner.buildScope(element);
      buildOwner.finalizeTree();
      pipeline.rootNode = null;
      renderView.dispose();
    }
  }
}
