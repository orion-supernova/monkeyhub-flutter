import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../expressions/expression_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/expression_item.dart';
import '../adaptive_sheet.dart';
import '../app_toast.dart';
import '../../theme/motion.dart';
import '../ios_kit.dart' show GroupedRow, TileTone;
import '../sheet_kit.dart' show SheetFrame, SheetGroup;
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
    return SheetFrame(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final pack = store.packOf(item.stickerId);
          final starred = store.isFavorite(item);
          final mine = pack?.personal ?? false;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              // The sticker pops in on a spring — it is the subject of the
              // sheet, so it arrives like one.
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1),
                  duration: MotionScope.of(context)
                      .d(const Duration(milliseconds: 520)),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: _preview(context),
                ),
              ),
              const SizedBox(height: 12),
              if (pack != null) ...[
                Text(
                  pack.title,
                  textAlign: TextAlign.center,
                  style: theme.bodyEmph.copyWith(color: theme.ink),
                ),
                if (pack.author != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.expressionPackCredit(
                          pack.author!, pack.license ?? ''),
                      style: theme.bodySoft.copyWith(
                        fontSize: 13,
                        color: theme.inkMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ] else if (item.source == ExpressionSource.klipy)
                const Center(child: KlipyAttribution()),
              const SizedBox(height: 18),
              SheetGroup(
                children: [
                  GroupedRow(
                    icon: starred
                        ? CupertinoIcons.star_slash_fill
                        : CupertinoIcons.star_fill,
                    tone: TileTone.orange,
                    title: starred
                        ? l10n.expressionUnfavorite
                        : l10n.expressionFavorite,
                    chevron: false,
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
                    GroupedRow(
                      icon: CupertinoIcons.plus_app_fill,
                      tone: TileTone.blue,
                      title: l10n.expressionAddPackFromSticker(pack.title),
                      chevron: false,
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
                    GroupedRow(
                      icon: CupertinoIcons.flag_fill,
                      tone: TileTone.gray,
                      title: l10n.expressionReport,
                      chevron: false,
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
                    GroupedRow(
                      icon: CupertinoIcons.trash_fill,
                      title: l10n.expressionDeleteSticker,
                      destructive: true,
                      chevron: false,
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
              ),
            ],
          );
        },
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
