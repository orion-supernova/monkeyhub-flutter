import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../call_pip.dart';

/// What the app shows while Android has it in the system Picture in
/// Picture window: the call's one picture, full-bleed, or the name card
/// while that picture is off. Nothing to tap; PiP windows take no touches
/// beyond the system's own expand and close.
///
/// Android shrinks the whole activity into the window, so without this the
/// window would hold a scaled-down copy of whatever screen was up (the call
/// screen's buttons, a chat). Sits over every route at the app root and
/// costs nothing outside PiP: one listenable, an empty box.
///
/// The renderer exists only while the window does. It is created on the
/// way in and disposed on the way out, so a call that never leaves the app
/// never pays for a second decoder sink.
class SystemPipView extends StatefulWidget {
  const SystemPipView({super.key, CallPip? pip}) : _pip = pip;

  final CallPip? _pip;

  @override
  State<SystemPipView> createState() => _SystemPipViewState();
}

class _SystemPipViewState extends State<SystemPipView> {
  CallPip get _pip => widget._pip ?? CallPip.instance;

  RTCVideoRenderer? _renderer;
  bool _rendererReady = false;
  MediaStream? _bound;

  @override
  void initState() {
    super.initState();
    _pip.inPip.addListener(_sync);
    _pip.spec.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    _pip.inPip.removeListener(_sync);
    _pip.spec.removeListener(_sync);
    _release();
    super.dispose();
  }

  /// The stream the window should be showing right now, if any.
  MediaStream? get _wanted {
    if (!_pip.inPip.value) return null;
    final spec = _pip.spec.value;
    if (spec == null || spec.videoOff || spec.trackId == null) return null;
    return spec.stream;
  }

  void _sync() {
    if (!mounted) return;
    final want = _wanted;
    if (want == null) {
      // Out of PiP: let go entirely. Still in PiP with no picture: keep the
      // renderer for the picture's return, just unbind it.
      if (!_pip.inPip.value) {
        _release();
      } else if (_bound != null) {
        _bound = null;
        _renderer?.srcObject = null;
      }
    } else if (!identical(want, _bound)) {
      _bind(want);
    }
    setState(() {});
  }

  Future<void> _bind(MediaStream stream) async {
    _bound = stream;
    var r = _renderer;
    if (r == null) {
      r = RTCVideoRenderer();
      _renderer = r;
      _rendererReady = false;
      try {
        await r.initialize();
      } catch (e) {
        debugPrint('SystemPipView.initialize: $e');
        return;
      }
      if (!identical(_renderer, r)) {
        await r.dispose();
        return;
      }
      _rendererReady = true;
    }
    if (!identical(_bound, stream)) return;
    r.srcObject = stream;
    if (mounted) setState(() {});
  }

  void _release() {
    final r = _renderer;
    _renderer = null;
    _rendererReady = false;
    _bound = null;
    if (r != null) {
      r.srcObject = null;
      r.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_pip.inPip.value) return const SizedBox.shrink();
    final spec = _pip.spec.value;
    final r = _renderer;
    final showVideo = _wanted != null && r != null && _rendererReady;
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: const Color(0xFF0E0F12),
          child: showVideo
              ? RTCVideoView(
                  r,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : _NameCard(title: spec?.title ?? ''),
        ),
      ),
    );
  }
}

class _NameCard extends StatelessWidget {
  const _NameCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = title.trim();
    final initial = t.isEmpty ? '' : t.characters.first.toUpperCase();
    return LayoutBuilder(
      builder: (context, box) {
        final d = (box.biggest.shortestSide * 0.42).clamp(24.0, 96.0);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: d,
                  height: d,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2A2C33),
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: d * 0.42,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (t.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
