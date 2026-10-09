import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/settings_store.dart';
import '../../expressions/expression_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/expression_item.dart';
import '../../theme/theme_scope.dart';
import '../jumbo_emoji.dart';
import 'expression_media.dart';
import '../desktop_scroll.dart';

/// The strip of matching stickers that appears above the composer when what
/// has been typed is a single emoji — Telegram's and Signal's "sticker
/// suggestions".
///
/// Listens to the composer itself, so the host does not rebuild on every
/// keystroke; it is zero-height whenever there is nothing to suggest, which is
/// nearly always.
class StickerSuggestions extends StatelessWidget {
  const StickerSuggestions({
    super.key,
    required this.composer,
    required this.onSend,
  });

  final TextEditingController composer;

  /// Sends the chosen sticker. The host clears the composer — the emoji that
  /// summoned the strip has been answered.
  final ValueChanged<ExpressionItem> onSend;

  /// Everything standing for [emoji]: the user's recent and starred stickers
  /// first (they are the ones they reach for), then every pack's matches.
  static List<ExpressionItem> suggestionsFor(String emoji) {
    final store = ExpressionStore.instance;
    String bare(String s) => s.replaceAll('️', '').trim();
    final want = bare(emoji);
    final out = <ExpressionItem>[];
    void add(ExpressionItem i) {
      if (!out.any((o) => o.sameAs(i))) out.add(i);
    }

    final outside = store.canUseOutsideMedia;
    for (final i in [...store.recents, ...store.favorites]) {
      if (!i.isSticker || i.source == ExpressionSource.klipy) continue;
      if (!outside && i.source != ExpressionSource.pack) continue;
      if (bare(i.title ?? '') == want) add(i);
    }
    for (final s in store.stickersFor(emoji)) {
      add(s.toItem());
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [composer, ExpressionStore.instance, SettingsStore.instance]),
      builder: (context, _) {
        if (!SettingsStore.instance.stickerSuggestions) {
          return const SizedBox.shrink();
        }
        final run = jumboEmojiRun(composer.text.trim());
        if (run == null || run.length != 1) return const SizedBox.shrink();
        final items = suggestionsFor(run.first);
        if (items.isEmpty) return const SizedBox.shrink();
        return _Strip(items: items, onSend: onSend);
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.items, required this.onSend});

  final List<ExpressionItem> items;
  final ValueChanged<ExpressionItem> onSend;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final autoplay = expressionsAutoplay(context);
    return Semantics(
      container: true,
      label: l10n.expressionSuggestionsLabel,
      child: Container(
        height: 76,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        decoration: BoxDecoration(
          color: theme.surfaceRaised,
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(color: theme.divider),
        ),
        child: HorizontalWheelScroll(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final item = items[i];
              return Semantics(
                button: true,
                label: item.title,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSend(item);
                  },
                  child: StickerArt(
                    item: item,
                    size: 64,
                    api: ExpressionStore.instance.api,
                    url: _urlFor(item),
                    play: autoplay,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// A pack sticker's URL, when its pack is loaded — saves resolving it again.
  static String? _urlFor(ExpressionItem item) {
    for (final p in ExpressionStore.instance.catalog) {
      for (final s in p.stickers) {
        if (s.id == item.stickerId) return s.url;
      }
    }
    return null;
  }
}
