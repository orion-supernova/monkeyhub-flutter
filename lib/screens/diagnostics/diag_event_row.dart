import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../diagnostics/diag_event.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/ios_kit.dart'
    show groupedFill, groupedMetaStyle, groupedRadius, groupedSubtitleStyle;
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
    final l10n = AppLocalizations.of(context);
    final e = widget.group.first;
    final catName = diagCategoryLabel(l10n, e.cat);
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
        semanticLabel: '$catName ${e.event}',
        child: GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 7, 10, 8),
            decoration: BoxDecoration(
              color: loud
                  ? Color.alphaBlend(
                      sevColour.withValues(alpha: 0.10),
                      groupedFill(theme),
                    )
                  : groupedFill(theme),
              // The grouped plates' corner, so a log row and a settings row
              // read as the same material.
              borderRadius: BorderRadius.circular(groupedRadius(theme) * 0.6),
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
                    // Mono, and only here and in the payload: these are the
                    // two columns read as numbers lined up, not as words.
                    SizedBox(
                      width: 58,
                      child: Padding(
                        // Sits on the event name's baseline, not its cap.
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          delta == null ? '—' : '+${delta}ms',
                          textAlign: TextAlign.right,
                          style: _mono(theme, 13).copyWith(
                            color: (delta != null && delta < 50)
                                ? theme.danger
                                : theme.inkMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (loud) ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: sevColour,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              // The event in the body face, the category as a
                              // small label in its own hue in front of it —
                              // the same hue as the rule on the left, so the
                              // two read as one thing.
                              Flexible(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$catName  ',
                                        style: groupedMetaStyle(theme).copyWith(
                                          color: colour,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: e.event,
                                        style: theme.body.copyWith(
                                          fontSize: 15,
                                          height: 1.3,
                                          fontWeight: FontWeight.w500,
                                          color: theme.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.group.collapsed) ...[
                                const SizedBox(width: 6),
                                _Badge(
                                  // The span is the diagnostic, not the count.
                                  text: l10n.diagRepeatSpan(
                                    widget.group.count,
                                    (widget.group.spanMs / 1000)
                                        .toStringAsFixed(1),
                                  ),
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
                          // A function or route name — an identifier, so mono.
                          if (e.name != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                e.name!,
                                style: _mono(theme, 13).copyWith(
                                  color: theme.inkSoft,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (e.detail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                e.detail!,
                                style: groupedSubtitleStyle(theme),
                                maxLines: _open ? null : 2,
                                overflow: _open ? null : TextOverflow.ellipsis,
                              ),
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 68),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'seq ${event.seq} · up ${event.upMs}ms · '
            '${DateTime.fromMillisecondsSinceEpoch(event.tsMs).toIso8601String()}'
            '${event.corrId != null ? ' · corr ${event.corrId}' : ''}'
            '${event.screen != null ? ' · ${event.screen}' : ''}',
            style: _mono(theme, 13).copyWith(color: theme.inkMuted),
          ),
          if (group.collapsed)
            Text(
              'run: seq ${group.first.seq}–${group.last.seq}, '
              'up ${group.first.upMs}–${group.last.upMs}ms',
              style: _mono(theme, 13).copyWith(color: theme.inkMuted),
            ),
          if (event.body != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
              child: SelectableText.rich(
                TextSpan(
                  children: highlightJson(event.prettyBody, theme),
                  style: _mono(theme, 13).copyWith(height: 1.4),
                ),
              ),
            ),
            if (event.bodyTruncated)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.diagBodyTruncated,
                  style: groupedMetaStyle(theme).copyWith(color: theme.danger),
                ),
              ),
          ],
          const SizedBox(height: 4),
          FocusableTap(
            onTap: () => _copy(context, event),
            radius: theme.radiusSm,
            semanticLabel: l10n.diagCopyEvent,
            child: GestureDetector(
              onTap: () => _copy(context, event),
              behavior: HitTestBehavior.opaque,
              // A 36pt-tall strip, not just the word: this is a thumb target.
              child: Container(
                height: 36,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.doc_on_doc,
                      size: 15,
                      color: theme.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.diagCopyEvent,
                      style: theme.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.accent,
                      ),
                    ),
                  ],
                ),
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
    showAppToast(
      context,
      AppLocalizations.of(context).diagEventCopied,
      tone: ToastTone.success,
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: groupedMetaStyle(theme).copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: colour,
        ),
      ),
    );
  }
}

/// The theme's mono face at an explicit size. Mono is for what is read as
/// code or as a column of numbers — the Δ gutter, identifiers, payloads,
/// timestamps — and nothing else on this screen.
TextStyle _mono(AppTheme theme, double size) =>
    theme.mono.copyWith(fontSize: size, height: 1.3);
