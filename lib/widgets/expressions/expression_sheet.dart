import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../expressions/expression_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/expression_item.dart';
import '../adaptive_sheet.dart';
import '../app_toast.dart';
import '../destructive_sheet.dart' show SheetGrabber;
import '../../theme/theme_scope.dart';
import 'expression_media.dart';
import 'klipy_attribution.dart';

/// Marks a subtree where [showExpressionSheet] must not push a sheet.
///
/// The thread overlay lives in a root `OverlayEntry`, and a modal route pushed
/// from inside it lands UNDER it — an invisible sheet that still eats the next
/// tap. The overlay wraps itself in this with `enabled: false`; everywhere
/// else (no scope at all) sheets are fine.
class ExpressionSheetScope extends InheritedWidget {
  const ExpressionSheetScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool enabledFor(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ExpressionSheetScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(ExpressionSheetScope old) => old.enabled != enabled;
}

/// Where a sheet cannot open, a hold still does the one thing people most want
/// from it: star the item, with a haptic to say it happened.
Future<void> _quickFavorite(BuildContext context, ExpressionItem item) async {
  HapticFeedback.mediumImpact();
  final l10n = AppLocalizations.of(context);
  final toast = AppToast.of(context);
  try {
    final starred = await ExpressionStore.instance.toggleFavorite(item);
    toast.show(starred ? l10n.expressionFavorited : l10n.expressionUnfavorited);
  } catch (_) {
    toast.show(l10n.expressionActionFailed, tone: ToastTone.danger);
  }
}

/// The sheet a tapped sticker (or a long-pressed picker tile) opens: the art
/// large, a star, where it came from, and — for KLIPY items — a way to report
/// it and the "Powered by KLIPY" mark.
///
/// Also the only place a personal sticker can be deleted, from its owner's
/// long-press in the picker.
Future<void> showExpressionSheet(BuildContext context, ExpressionItem item) {
  if (!ExpressionSheetScope.enabledFor(context)) {
    return _quickFavorite(context, item);
  }
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _ExpressionSheet(item: item),
  );
}

class _ExpressionSheet extends StatelessWidget {
  const _ExpressionSheet({required this.item});

  final ExpressionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = ExpressionStore.instance;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottomInset),
        child: DefaultTextStyle(
          style: theme.body.copyWith(
            color: theme.ink,
            decoration: TextDecoration.none,
          ),
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final pack = store.packOf(item.stickerId);
              final starred = store.isFavorite(item);
              final mine = pack?.personal ?? false;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetGrabber(),
                  const SizedBox(height: 8),
                  _preview(context),
                  const SizedBox(height: 12),
                  if (pack != null) ...[
                    Text(pack.title, style: theme.bodyEmph),
                    if (pack.author != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l10n.expressionPackCredit(
                              pack.author!, pack.license ?? ''),
                          style: theme.caption.copyWith(color: theme.inkMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ] else if (item.source == ExpressionSource.klipy)
                    const KlipyAttribution(),
                  const SizedBox(height: 16),
                  _Action(
                    icon: starred ? Icons.star_rounded : Icons.star_outline_rounded,
                    label: starred
                        ? l10n.expressionUnfavorite
                        : l10n.expressionFavorite,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      try {
                        await store.toggleFavorite(item);
                      } catch (_) {
                        if (context.mounted) {
                          showAppToast(context, l10n.expressionActionFailed,
                              tone: ToastTone.danger);
                        }
                      }
                    },
                  ),
                  // A sticker from a pack the viewer has not added — usually
                  // one somebody else sent — offers the whole pack. How
                  // stickers travel between people.
                  if (pack != null &&
                      !pack.personal &&
                      !store.isInstalled(pack.id))
                    _Action(
                      icon: Icons.add_circle_outline_rounded,
                      label: l10n.expressionAddPackFromSticker(pack.title),
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final toast = AppToast.of(context);
                        try {
                          await store.setInstalled(pack, true);
                          toast.show(
                            l10n.expressionPackAddedToast(pack.title),
                            tone: ToastTone.success,
                          );
                        } catch (_) {
                          toast.show(l10n.expressionActionFailed,
                              tone: ToastTone.danger);
                        }
                      },
                    ),
                  if (item.source == ExpressionSource.klipy &&
                      item.ref != null &&
                      store.klipy != null)
                    _Action(
                      icon: Icons.flag_outlined,
                      label: l10n.expressionReport,
                      onTap: () async {
                        final klipy = store.klipy!;
                        final toast = AppToast.of(context);
                        Navigator.of(context).pop();
                        try {
                          await klipy.report(item.kind, item.ref!, 'inappropriate');
                          toast.show(l10n.expressionReported,
                              tone: ToastTone.success);
                        } catch (_) {
                          toast.show(l10n.expressionActionFailed,
                              tone: ToastTone.danger);
                        }
                      },
                    ),
                  if (mine && item.stickerId != null)
                    _Action(
                      icon: Icons.delete_outline_rounded,
                      label: l10n.expressionDeleteSticker,
                      danger: true,
                      onTap: () async {
                        final toast = AppToast.of(context);
                        Navigator.of(context).pop();
                        try {
                          await store.deletePersonalSticker(item.stickerId!);
                        } catch (_) {
                          toast.show(l10n.expressionActionFailed,
                              tone: ToastTone.danger);
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    if (item.isSticker) {
      return StickerArt(
        item: item,
        size: 170,
        api: ExpressionStore.instance.api,
      );
    }
    final url = item.url;
    const w = 260.0;
    final h = w / item.aspectRatio.clamp(0.6, 2.2);
    return url == null
        ? const SizedBox.shrink()
        : KlipyImage(url: url, width: w, height: h, semanticLabel: item.title);
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = danger ? theme.danger : theme.ink;
    // FocusableTap + a bare GestureDetector, never InkWell — this app renders
    // no ink anywhere.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: theme.body.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
