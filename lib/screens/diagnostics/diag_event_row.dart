import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../diagnostics/diag_event.dart';
import '../../keyboard/focusable_tap.dart';
import '../../theme/theme_scope.dart';
import 'diag_collapse.dart';
import 'diag_palette.dart';
import 'json_highlight.dart';

/// One row of the timeline — a single event, or a collapsed run of them.
class DiagEventRow extends StatefulWidget {
  const DiagEventRow({super.key, required this.group, this.previous});

  final DiagGroup group;

  /// The event immediately before this group, for the Δ gutter.
  final DiagEvent? previous;

  @override
  State<DiagEventRow> createState() => _DiagEventRowState();
}

class _DiagEventRowState extends State<DiagEventRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final e = widget.group.first;
    // Two channels, doing two different jobs. The left rule is the CATEGORY,
    // so a scroll reads as bands of colour and you can find the layout events
    // among four hundred subscription ones without reading a word. Severity is
    // a background wash, and only for warn/error — if every row is emphasised
    // then none of them is.
    final colour = DiagPalette.cat(e.cat);
    final loud = DiagPalette.isLoud(e.sev);
    final sevColour = DiagPalette.severity(theme, e.sev);
    final prev = widget.previous;
    final delta = prev == null ? null : e.upMs - prev.upMs;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: FocusableTap(
        onTap: () => setState(() => _open = !_open),
        radius: theme.radiusSm,
        semanticLabel: '${e.cat.name} ${e.event}',
        child: GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: loud
                  ? sevColour.withValues(alpha: 0.10)
                  : theme.surfaceRaised,
              borderRadius: BorderRadius.circular(theme.radiusSm),
              border: Border(
                left: BorderSide(color: colour, width: loud ? 3 : 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The Δ gutter. A strobe is visible in this one column and
                    // nowhere else — a wall of 16ms values IS the finding.
                    SizedBox(
                      width: 52,
                      child: Text(
                        delta == null ? '—' : '+${delta}ms',
                        textAlign: TextAlign.right,
                        style: theme.monoTiny.copyWith(
                          color: (delta != null && delta < 50)
                              ? theme.danger
                              : theme.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (loud) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: sevColour,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                '${e.cat.name}/${e.event}',
                                style: theme.monoTiny.copyWith(color: colour),
                              ),
                              if (widget.group.collapsed) ...[
                                const SizedBox(width: 6),
                                _Badge(
                                  // The span is the diagnostic, not the count.
                                  text:
                                      '×${widget.group.count} over '
                                      '${(widget.group.spanMs / 1000).toStringAsFixed(1)}s',
                                  colour: theme.danger,
                                ),
                              ],
                              if (e.durationMs != null) ...[
                                const SizedBox(width: 6),
                                _Badge(
                                  text: '${e.durationMs}ms',
                                  colour: theme.inkMuted,
                                ),
                              ],
                            ],
                          ),
                          if (e.name != null)
                            Text(
                              e.name!,
                              style: theme.monoTiny.copyWith(color: theme.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (e.detail != null)
                            Text(
                              e.detail!,
                              style: theme.bodySoft,
                              maxLines: _open ? null : 2,
                              overflow: _open ? null : TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_open) _Detail(event: e, group: widget.group),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.event, required this.group});
  final DiagEvent event;
  final DiagGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'seq ${event.seq} · up ${event.upMs}ms · '
            '${DateTime.fromMillisecondsSinceEpoch(event.tsMs).toIso8601String()}'
            '${event.corrId != null ? ' · corr ${event.corrId}' : ''}'
            '${event.screen != null ? ' · ${event.screen}' : ''}',
            style: theme.monoTiny.copyWith(color: theme.inkMuted),
          ),
          if (group.collapsed)
            Text(
              'run: seq ${group.first.seq}–${group.last.seq}, '
              'up ${group.first.upMs}–${group.last.upMs}ms',
              style: theme.monoTiny.copyWith(color: theme.inkMuted),
            ),
          if (event.body != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
              child: SelectableText.rich(
                TextSpan(
                  children: highlightJson(event.prettyBody, theme),
                  style: theme.monoTiny,
                ),
              ),
            ),
            if (event.bodyTruncated)
              Text(
                'body truncated at capture',
                style: theme.monoTiny.copyWith(color: theme.danger),
              ),
          ],
          const SizedBox(height: 6),
          FocusableTap(
            onTap: () => _copy(context, event),
            radius: theme.radiusSm,
            semanticLabel: 'Copy event',
            child: GestureDetector(
              onTap: () => _copy(context, event),
              behavior: HitTestBehavior.opaque,
              child: Text(
                'copy event',
                style: theme.monoTiny.copyWith(color: theme.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _copy(BuildContext context, DiagEvent e) async {
    await Clipboard.setData(ClipboardData(text: e.toNdjsonLine()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Event copied')));
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.colour});
  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: theme.monoTiny.copyWith(color: colour)),
    );
  }
}
