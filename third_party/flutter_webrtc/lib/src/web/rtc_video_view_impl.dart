import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'package:dart_webrtc/dart_webrtc.dart';
import 'package:web/web.dart' as web;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'rtc_video_renderer_impl.dart';

class RTCVideoView extends StatefulWidget {
  RTCVideoView(
    this._renderer, {
    super.key,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    this.mirror = false,
    this.filterQuality = FilterQuality.low,
    this.placeholderBuilder,
  });

  final RTCVideoRenderer _renderer;
  final RTCVideoViewObjectFit objectFit;
  final bool mirror;
  final FilterQuality filterQuality;
  final WidgetBuilder? placeholderBuilder;

  @override
  RTCVideoViewState createState() => RTCVideoViewState();
}

class RTCVideoViewState extends State<RTCVideoView> {
  RTCVideoViewState();

  RTCVideoRenderer get videoRenderer => widget._renderer;

  // MONKEYHUB PATCH W4: follow the renderer the widget names.
  //
  // Upstream looked the <video> element up once, in initState, and never
  // again. A State outlives its widget's renderer whenever a parent swaps
  // which renderer one slot shows (the call screen's full-bleed slot goes
  // from the local camera to the peer when the peer's video lands, and a
  // PiP tap swaps the two): the slot kept copying frames from the first
  // renderer's element, so the web caller saw themselves in both tiles.
  // It also kept listening to the first renderer, never removed that
  // listener, and its frame loop outlived dispose(), decoding a frame per
  // video frame into images nobody disposed.
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    videoRenderer.addListener(_onRendererListener);
    videoRenderer.mirror = widget.mirror;
    videoRenderer.objectFit =
        widget.objectFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
            ? 'contain'
            : 'cover';
    videoElement = _lookUpElement();
    size = null;
    _startFrames();
  }

  web.HTMLVideoElement? _lookUpElement() =>
      web.document.getElementById("video_${videoRenderer.viewType}")
          as web.HTMLVideoElement?;

  void _onRendererListener() {
    if (mounted) setState(() {});
  }

  int? callbackID;

  /// Bumped per renderer attached and on dispose: a frame callback from an
  /// older loop stops instead of re-arming.
  int _loop = 0;

  bool _live(int loop) => mounted && loop == _loop;

  void _startFrames() {
    final element = videoElement;
    if (element != null) cancelFrame(element);
    _frame(++_loop);
  }

  void _request(web.HTMLVideoElement element, int loop) {
    if (!_live(loop)) return;
    callbackID = element.requestVideoFrameCallbackWithFallback(
        ((JSAny now, JSAny metadata) => _frame(loop)).toJS);
  }

  void cancelFrame(web.HTMLVideoElement element) {
    if (callbackID != null) {
      element.cancelVideoFrameCallbackWithFallback(callbackID!);
      callbackID = null;
    }
  }

  void _frame(int loop) {
    if (!_live(loop)) return;
    final web.HTMLVideoElement? element = videoElement ??= _lookUpElement();
    if (element != null) {
      // only capture frames if video is playing (optimization for RAF)
      if (element.readyState > 2) {
        capture(element, loop).then((_) => _request(element, loop));
      } else {
        _request(element, loop);
      }
    } else {
      // The renderer's element is not in the document yet (initialize()
      // still running): look again shortly.
      Future.delayed(Duration(milliseconds: 100)).then((_) => _frame(loop));
    }
  }

  ui.Image? capturedFrame;
  num? lastFrameTime;
  Future<void> capture(web.HTMLVideoElement element, int loop) async {
    if (lastFrameTime != element.currentTime) {
      lastFrameTime = element.currentTime;
      try {
        final ui.Image img = await ui_web.createImageFromTextureSource(element,
            width: element.videoWidth,
            height: element.videoHeight,
            transferOwnership: true);

        if (_live(loop)) {
          setState(() {
            capturedFrame?.dispose();
            capturedFrame = img;
          });
        } else {
          img.dispose();
        }
      } on web.DOMException catch (err) {
        lastFrameTime = null;
        if (err.name == 'InvalidStateError') {
          // We don't have enough data yet, continue on
        } else {
          rethrow;
        }
      }
    }
  }

  @override
  void dispose() {
    _loop++;
    videoRenderer.removeListener(_onRendererListener);
    if (videoElement != null) {
      cancelFrame(videoElement!);
    }
    capturedFrame?.dispose();
    capturedFrame = null;
    super.dispose();
  }

  Size? size;

  void updateElement() {
    if (videoElement != null && size != null) {
      videoElement!.width = size!.width.toInt();
      videoElement!.height = size!.height.toInt();
    }
  }

  @override
  void didUpdateWidget(RTCVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget._renderer, widget._renderer)) {
      oldWidget._renderer.removeListener(_onRendererListener);
      final old = videoElement;
      if (old != null) cancelFrame(old);
      // The last frame is the previous renderer's picture: drop it rather
      // than show the wrong feed until the new one's first frame lands.
      capturedFrame?.dispose();
      capturedFrame = null;
      lastFrameTime = null;
      _attach();
      return;
    }
    Timer(
        Duration(milliseconds: 10), () => videoRenderer.mirror = widget.mirror);
    videoRenderer.objectFit =
        widget.objectFit == RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
            ? 'contain'
            : 'cover';
  }

  web.HTMLVideoElement? videoElement;

  Widget buildVideoElementView() {
    if (useHtmlElementView) {
      return HtmlElementView(viewType: videoRenderer.viewType);
    } else {
      return LayoutBuilder(builder: (context, constraints) {
        if (videoElement != null && size != constraints.biggest) {
          size = constraints.biggest;
          updateElement();
        }

        return Stack(children: [
          if (capturedFrame != null)
            Positioned.fill(
                // MONKEYHUB PATCH W4: every video frame repaints this layer
                // alone, not whatever screen chrome shares its boundary.
                child: RepaintBoundary(
                    child: FittedBox(
                    fit: switch (widget.objectFit) {
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain =>
                        BoxFit.contain,
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover =>
                        BoxFit.cover,
                    },
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                        width: capturedFrame!.width.toDouble(),
                        height: capturedFrame!.height.toDouble(),
                        child: CustomPaint(
                            willChange: true,
                            painter: _ImageFlipPainter(
                              capturedFrame!,
                              widget.mirror,
                            ))))))
        ]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Center(
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: widget._renderer.renderVideo
                ? buildVideoElementView()
                : widget.placeholderBuilder?.call(context) ?? Container(),
          ),
        );
      },
    );
  }
}

typedef _VideoFrameRequestCallback = JSFunction;

extension _HTMLVideoElementRequestAnimationFrame on web.HTMLVideoElement {
  int requestVideoFrameCallbackWithFallback(
      _VideoFrameRequestCallback callback) {
    if (hasProperty('requestVideoFrameCallback'.toJS).toDart) {
      return requestVideoFrameCallback(callback);
    } else {
      return web.window.requestAnimationFrame((double num) {
        callback.callAsFunction(this, 0.toJS, 0.toJS);
      }.toJS);
    }
  }

  void cancelVideoFrameCallbackWithFallback(int callbackID) {
    if (hasProperty('requestVideoFrameCallback'.toJS).toDart) {
      cancelVideoFrameCallback(callbackID);
    } else {
      web.window.cancelAnimationFrame(callbackID);
    }
  }

  external int requestVideoFrameCallback(_VideoFrameRequestCallback callback);
  external void cancelVideoFrameCallback(int callbackID);
}

class _ImageFlipPainter extends CustomPainter {
  _ImageFlipPainter(this.image, this.flip);

  final ui.Image image;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    if (flip) {
      canvas.scale(-1, 1);
      canvas.drawImage(image, Offset(-size.width, 0),
          Paint()..filterQuality = ui.FilterQuality.high);
    } else {
      canvas.drawImage(
          image, Offset(0, 0), Paint()..filterQuality = ui.FilterQuality.high);
    }
  }

  // MONKEYHUB PATCH W4: upstream returned false, so a new frame reached
  // the screen only when something else repainted the same layer.
  @override
  bool shouldRepaint(_ImageFlipPainter oldDelegate) =>
      !identical(oldDelegate.image, image) || oldDelegate.flip != flip;
}
