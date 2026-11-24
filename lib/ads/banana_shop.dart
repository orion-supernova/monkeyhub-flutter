import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../games/catalog.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/link_opener.dart';
import '../theme/theme_scope.dart';
import '../update/update_destination.dart' show kDownloadPageUrl;
import '../widgets/action_buttons.dart' show SheetActionButton;
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/sheet_drag.dart' show SheetScrollBody;
import '../widgets/sheet_kit.dart' show SheetFrame;
import 'banana_sheet.dart' show showBananaWallet;
import 'banana_store.dart';
import 'banana_wallet.dart';
import 'unlock_sheet.dart';

/// The Banana Shop: packs of bananas for sale (where the platform has a
/// store and the account is not a child's), the other ways to earn them, and
/// everything that bananas unlock, each row opening [showUnlockSheet].
///
/// Design: docs/design/bananas-and-unlocks.html, Screens.
Future<void> showBananaShop(BuildContext context) {
  final wallet = BananaWallet.instance;
  final userId = wallet.userId;
  if (userId != null) unawaited(wallet.refresh(userId));
  final l10n = AppLocalizations.of(context);
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => SheetFrame(
      title: l10n.bananasShopTitle,
      showClose: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      // The unlock list runs well past one screen: it scrolls, and a pull
      // from the top still drags the sheet closed.
      child: const SheetScrollBody(child: _ShopPanel()),
    ),
  );
}

class _ShopPanel extends StatefulWidget {
  const _ShopPanel();

  @override
  State<_ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<_ShopPanel> {
  final _wallet = BananaWallet.instance;
  final _store = BananaStore.instance;
  List<BananaPack>? _packs;
  String? _buying;

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_changed);
    if (_store.available) unawaited(_loadPacks());
  }

  @override
  void dispose() {
    _wallet.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPacks() async {
    final packs = await _store.packs();
    if (mounted) setState(() => _packs = packs);
  }

  Future<void> _buy(BananaPack pack) async {
    final userId = _wallet.userId;
    if (userId == null || _buying != null) return;
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    setState(() => _buying = pack.id);
    try {
      final gained = await _store.buy(userId, pack);
      if (!mounted) return;
      if (gained > 0) {
        HapticFeedback.heavyImpact();
        toast.show(l10n.bananaGot(gained));
      } else if (!_store.lastCancelled) {
        toast.show(l10n.bananasShopLate);
      }
    } catch (_) {
      toast.show(l10n.bananasShopFailed);
    }
    if (mounted) setState(() => _buying = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final w = _wallet;
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: theme.body,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Text(
              l10n.bananaBalance(w.balance),
              textAlign: TextAlign.center,
              style: theme.displaySmall.copyWith(color: theme.ink),
            ),
            const SizedBox(height: 18),
            _SectionLabel(l10n.bananasShopPacks),
            ..._packSection(context),
            const SizedBox(height: 20),
            _SectionLabel(l10n.bananasShopEarn),
            _LinkRow(
              glyph: '\u{1F34C}',
              title: l10n.bananasShopEarnRow,
              onTap: () {
                final id = w.userId;
                if (id != null) showBananaWallet(context, userId: id);
              },
            ),
            const SizedBox(height: 20),
            _SectionLabel(l10n.bananasShopUnlocks),
            ..._unlocks(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _packSection(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    if (_wallet.childAccount) {
      return [_Note(l10n.bananasShopChild)];
    }
    if (!_store.available) {
      return [
        _Note(l10n.bananasShopAppOnly),
        const SizedBox(height: 10),
        SheetActionButton(
          label: l10n.appOnlyGetApp,
          tonal: true,
          onTap: () => LinkOpener.openExternal(kDownloadPageUrl),
        ),
      ];
    }
    final packs = _packs;
    if (packs == null) {
      return [
        const SizedBox(height: 24),
        const Center(child: CupertinoActivityIndicator()),
        const SizedBox(height: 24),
      ];
    }
    if (packs.isEmpty) return [_Note(l10n.bananasShopNoPacks)];
    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: [
          for (final p in packs)
            _PackCard(
              pack: p,
              doubled: _wallet.firstPackBonus,
              busy: _buying == p.id,
              onTap: _buying == null ? () => _buy(p) : null,
            ),
        ],
      ),
      if (_wallet.firstPackBonus) ...[
        const SizedBox(height: 8),
        Text(
          l10n.bananasShopFirstDouble,
          textAlign: TextAlign.center,
          style: theme.caption.copyWith(color: theme.accent),
        ),
      ],
    ];
  }

  List<Widget> _unlocks(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = <(String, CatalogKind)>[
      (l10n.bananasGroupFighters, CatalogKind.fighter),
      (l10n.bananasGroupStages, CatalogKind.stage),
      (l10n.bananasGroupLooks, CatalogKind.look),
      (l10n.bananasGroupGames, CatalogKind.game),
      (l10n.bananasGroupBundles, CatalogKind.bundle),
    ];
    final out = <Widget>[];
    for (final (title, kind) in groups) {
      final items = [
        for (final i in kCatalog)
          if (i.kind == kind) i,
      ];
      final owned = items.where((i) => _wallet.ownsItem(i.id)).length;
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ThemeScope.of(context).bodyEmph.copyWith(
                    color: ThemeScope.of(context).ink,
                  ),
                ),
              ),
              Text(
                l10n.bananasShopOwnedCount(owned, items.length),
                style: ThemeScope.of(context).caption.copyWith(
                  color: ThemeScope.of(context).inkMuted,
                ),
              ),
            ],
          ),
        ),
      );
      for (final i in items) {
        final has = _wallet.ownsItem(i.id);
        out.add(
          _LinkRow(
            glyph: unlockItemEmoji(i.id),
            title: unlockItemName(l10n, i.id),
            trailing: has
                ? l10n.bananasShopOwned
                : '\u{1F34C} ${_wallet.priceOf(i.id)}',
            muted: has,
            onTap: () => showUnlockSheet(context, i.id),
          ),
        );
      }
    }
    return out;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.label.copyWith(color: theme.inkMuted),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.caption.copyWith(color: theme.inkMuted),
    );
  }
}

/// A tappable row: glyph, title, optional trailing price or state.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.glyph,
    required this.title,
    required this.onTap,
    this.trailing,
    this.muted = false,
  });

  final String glyph;
  final String title;
  final String? trailing;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                glyph,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: 22, height: 1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.body.copyWith(
                  color: muted ? theme.inkMuted : theme.ink,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: theme.bodyEmph.copyWith(
                  color: muted ? theme.inkMuted : theme.ink,
                ),
              )
            else
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: theme.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// One pack on sale.
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.doubled,
    required this.busy,
    required this.onTap,
  });

  final BananaPack pack;
  final bool doubled;
  final bool busy;
  final VoidCallback? onTap;

  String _name(AppLocalizations l10n) => switch (pack.id) {
    'handful' => l10n.bananasPackHandful,
    'basket' => l10n.bananasPackBasket,
    'crate' => l10n.bananasPackCrate,
    'tree' => l10n.bananasPackTree,
    _ => l10n.bananasPackJungle,
  };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      radius: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PackIcon(id: pack.id),
                    const SizedBox(height: 6),
                    Text(
                      _name(l10n),
                      style: theme.bodyEmph.copyWith(color: theme.ink),
                    ),
                    Text(
                      '\u{1F34C} ${doubled ? pack.bananas * 2 : pack.bananas}',
                      style: theme.caption.copyWith(color: theme.inkSoft),
                    ),
                    const SizedBox(height: 4),
                    busy
                        ? const CupertinoActivityIndicator()
                        : Text(
                            pack.priceString,
                            style: theme.bodyEmph.copyWith(color: theme.accent),
                          ),
                  ],
                ),
              ),
            ),
          ),
          if (doubled)
            Positioned(
              top: -6,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.bananasShopRibbon,
                  style: theme.caption.copyWith(
                    color: theme.accentInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A pack's picture. The Basket is a composite: three bananas fanned in a
/// basket, peeking above the rim.
class PackIcon extends StatelessWidget {
  const PackIcon({super.key, required this.id, this.size = 40});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    TextStyle style(double f) =>
        TextStyle(fontSize: size * f, height: 1);
    Widget glyph(String g, [double f = 1]) => Text(
      g,
      textScaler: TextScaler.noScaling,
      style: style(f),
    );
    if (id == 'basket') {
      return SizedBox(
        width: size * 1.3,
        height: size,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Bananas first, so the basket's rim hides their lower halves.
            Positioned(
              left: size * 0.10,
              top: size * 0.02,
              child: Transform.rotate(angle: -0.5, child: glyph('\u{1F34C}', 0.62)),
            ),
            Positioned(
              right: size * 0.10,
              top: size * 0.02,
              child: Transform.rotate(angle: 0.5, child: glyph('\u{1F34C}', 0.62)),
            ),
            Positioned(
              top: -size * 0.04,
              child: glyph('\u{1F34C}', 0.7),
            ),
            Positioned(bottom: -size * 0.04, child: glyph('\u{1F9FA}', 0.86)),
          ],
        ),
      );
    }
    final g = switch (id) {
      'handful' => '\u{1F34C}',
      'crate' => '\u{1F4E6}',
      'tree' => '\u{1F334}',
      _ => '\u{1F98D}',
    };
    return SizedBox(
      width: size * 1.3,
      height: size,
      child: Center(child: glyph(g, 0.9)),
    );
  }
}
