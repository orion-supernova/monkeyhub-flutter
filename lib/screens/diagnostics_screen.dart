import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../diagnostics/diag_buffer.dart';
import '../diagnostics/diag_event.dart';
import '../diagnostics/diag_export.dart';
import '../diagnostics/diag_gate.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import 'diagnostics/diag_collapse.dart';
import 'diagnostics/diag_event_row.dart';
import 'diagnostics/diag_filter_sheet.dart';

/// The captured timeline.
///
/// English-only, and legitimately so: it is reachable only from a gesture that
/// does nothing at all unless the backend has unlocked this specific device, so
/// no string here is ever visible to an ordinary user and none of it belongs in
/// the twelve ARB files.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  // Created here and disposed below. The reference implementation builds one
  // inside `build` and never disposes it, leaking a controller per rebuild.
  final ScrollController _scroll = ScrollController();

  DiagFilter _filter = const DiagFilter();
  bool _follow = true;
  bool _busy = false;

  /// Rebuild ticker. The viewer listens to a REVISION COUNTER, never to the
  /// event list: during the burst this screen exists to capture, events arrive
  /// faster than a phone can lay out three thousand rows, and rebuilding per
  /// event would make the diagnostics screen its own performance bug.
  Timer? _tick;
  int _seenRevision = -1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // 4 Hz is fast enough to read as live and slow enough to be free.
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final rev = DiagBuffer.instance.revision.value;
      if (rev != _seenRevision && mounted) {
        setState(() => _seenRevision = rev);
        if (_follow) _jumpToEnd();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // Scrolling up means the user is reading something; following would yank it
    // away under them. Re-engage only when they return to the bottom.
    final atBottom = _scroll.offset >= _scroll.position.maxScrollExtent - 40;
    if (atBottom != _follow && mounted) setState(() => _follow = atBottom);
  }

  void _jumpToEnd() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  List<DiagEvent> get _events =>
      DiagBuffer.instance.snapshot().where(_filter.matches).toList();

  Future<void> _shareLog({Rect? origin}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await DiagBuffer.instance.flush();
      final events = DiagBuffer.instance.snapshot();
      final text = await DiagExport.build(
        events: events,
        dropped: DiagBuffer.instance.dropped,
      );
      await DiagExport.share(
        text: text,
        label: DiagGate.instance.label ?? 'device',
        origin: origin,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copySummary() async {
    final text = await DiagExport.summary(
      events: DiagBuffer.instance.snapshot(),
      dropped: DiagBuffer.instance.dropped,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Summary copied')));
  }

  Future<void> _openFilter() async {
    final next = await DiagFilterSheet.show(context, _filter);
    if (next != null && mounted) setState(() => _filter = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final events = _events;
    final groups = collapseEvents(events, enabled: _filter.collapse);
    final buf = DiagBuffer.instance;

    return Scaffold(
      backgroundColor: theme.surface,
      // Deliberately a flat surface rather than `theme.backgroundLayer` — the
      // themed backdrops include shader and gradient layers, and several of
      // them are themselves suspects for the strobe this screen exists to
      // diagnose. The screen you debug a flicker with must not be able to
      // flicker.
      body: SafeArea(
        child: AdaptivePageBody(
          child: Column(
            children: [
              _Header(
                total: buf.length,
                shown: events.length,
                dropped: buf.dropped,
                following: _follow,
                busy: _busy,
                onFilter: _openFilter,
                onShare: _shareLog,
                onCopy: _copySummary,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: groups.isEmpty
                    ? Center(
                        child: Text(
                          buf.length == 0
                              ? 'Nothing captured yet.'
                              : 'No events match the filter.',
                          style: theme.bodySoft,
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                        itemCount: groups.length,
                        itemBuilder: (context, i) => DiagEventRow(
                          group: groups[i],
                          previous: i == 0 ? null : groups[i - 1].last,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.shown,
    required this.dropped,
    required this.following,
    required this.busy,
    required this.onFilter,
    required this.onShare,
    required this.onCopy,
    required this.onClose,
  });

  final int total;
  final int shown;
  final int dropped;
  final bool following;
  final bool busy;
  final VoidCallback onFilter;
  final void Function({Rect? origin}) onShare;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        border: Border(bottom: BorderSide(color: theme.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('DIAGNOSTICS', style: theme.label),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$shown/$total'
                  '${dropped > 0 ? ' · $dropped dropped' : ''}'
                  '${following ? '' : ' · paused'}',
                  style: theme.monoTiny.copyWith(
                    // A non-zero dropped count means the log starts mid-story,
                    // which changes how you read everything above it.
                    color: dropped > 0 ? theme.danger : theme.inkMuted,
                  ),
                ),
              ),
              _Action(
                icon: Icons.filter_list,
                label: 'Filter',
                onTap: onFilter,
              ),
              _Action(
                icon: Icons.copy_all_outlined,
                label: 'Copy summary',
                onTap: onCopy,
              ),
              _ShareAction(busy: busy, onShare: onShare),
              _Action(icon: Icons.close, label: 'Close', onTap: onClose),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // BOTH wrappers, per FocusableTap's doc comment: it binds Enter/Space and
    // the semantics but registers no gesture recognizer, so the bare detector
    // is what makes this answer a touch at all.
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.circle,
      semanticLabel: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: 18, color: theme.inkSoft),
        ),
      ),
    );
  }
}

/// Share needs the button's global rect for iPad/macOS popover anchoring, so it
/// cannot use the plain [_Action] shape.
class _ShareAction extends StatelessWidget {
  const _ShareAction({required this.busy, required this.onShare});
  final bool busy;
  final void Function({Rect? origin}) onShare;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Builder(
      builder: (context) {
        void go() {
          final box = context.findRenderObject() as RenderBox?;
          final origin = box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size;
          onShare(origin: origin);
        }

        return FocusableTap(
          onTap: busy ? null : go,
          shape: FocusRingShape.circle,
          semanticLabel: 'Share log',
          child: GestureDetector(
            onTap: busy ? null : go,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.accent,
                      ),
                    )
                  : Icon(Icons.ios_share, size: 18, color: theme.accent),
            ),
          ),
        );
      },
    );
  }
}
