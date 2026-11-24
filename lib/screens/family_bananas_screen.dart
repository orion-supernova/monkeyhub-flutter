import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../family/banana_family_api.dart';
import '../family/banana_item_names.dart';
import '../family/banana_send_sheet.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart' show readableSlivers;
import '../widgets/app_toast.dart';
import '../widgets/ios_kit.dart';

/// Family > a child > Bananas: what this child may do with bananas, and a
/// way to send some. Everything here is the guardian's decision; the child
/// never sees this screen.
///
/// Reads once on open (rules, then history). No subscription: rules change
/// only through this screen, and the history is a glance, not a feed.
class FamilyBananasScreen extends StatefulWidget {
  const FamilyBananasScreen({
    super.key,
    required this.api,
    required this.guardianId,
    required this.child,
  });

  final ChatApi api;
  final String guardianId;
  final ChatUser child;

  @override
  State<FamilyBananasScreen> createState() => _FamilyBananasScreenState();
}

class _FamilyBananasScreenState extends State<FamilyBananasScreen> {
  BananaRules? _rules;
  List<BananaLedgerRow> _history = const [];
  bool _historyLoaded = false;

  static const _allowances = [0, 25, 50, 100];
  static const _autoYes = [0, 60, 120];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await BananaFamilyApi.rules(widget.guardianId, widget.child.id);
      if (mounted) setState(() => _rules = r);
    } catch (_) {
      if (mounted) setState(() => _rules ??= const BananaRules());
    }
    try {
      final h = await BananaFamilyApi.history(widget.guardianId, widget.child.id);
      if (mounted) {
        setState(() {
          _history = h;
          _historyLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _historyLoaded = true);
    }
  }

  /// Applies [next] at once and sends only what changed; a refusal puts the
  /// old rules back and says so.
  Future<void> _set(
    BananaRules next, {
    bool? ask,
    String? spend,
    int? allowance,
    int? autoYes,
  }) async {
    final before = _rules;
    setState(() => _rules = next);
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    try {
      await BananaFamilyApi.setRules(
        guardianId: widget.guardianId,
        childId: widget.child.id,
        ask: ask,
        spend: spend,
        allowancePerWeek: allowance,
        autoYesPerWeek: autoYes,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _rules = before);
      toast.show(loc.bananasErrGeneric);
    }
  }

  Future<void> _send() async {
    final name = widget.child.displayName;
    final amount = await showSendBananasSheet(context, childName: name);
    if (amount == null || !mounted) return;
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    try {
      await BananaFamilyApi.sendBananas(
        guardianId: widget.guardianId,
        childId: widget.child.id,
        amount: amount,
      );
      toast.show(loc.bananasSentToast(name, amount));
      await _load();
    } catch (e) {
      toast.show(e.toString().contains('NO_BANANAS')
          ? loc.bananasErrNoBananas
          : loc.bananasErrGeneric);
    }
  }

  String _ledgerTitle(AppLocalizations loc, BananaLedgerRow r) {
    final k = r.kind.toLowerCase();
    if (k.contains('gift')) return loc.bananasLedgerGift;
    if (k.contains('allowance')) return loc.bananasLedgerAllowance;
    final item = r.item;
    if (item != null && item.isNotEmpty && (k.contains('unlock') || k.contains('paid'))) {
      return loc.bananasLedgerUnlock(bananaItemName(loc, item));
    }
    return r.amount >= 0 ? loc.bananasLedgerEarned : loc.bananasLedgerSpent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final r = _rules;
    final name = widget.child.displayName;
    return IosPage(
      onRefresh: () {
        HapticFeedback.lightImpact();
        return _load();
      },
      title: loc.bananasTitle,
      slivers: r == null
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CupertinoActivityIndicator(color: theme.inkMuted),
                ),
              ),
            ]
          : readableSlivers(context, [
              GroupedSection(children: [
                GroupedRow(
                  icon: CupertinoIcons.gift_fill,
                  tone: TileTone.orange,
                  title: loc.bananasBalance,
                  value: loc.bananasPrice(r.balance),
                ),
                GroupedRow(
                  icon: CupertinoIcons.paperplane_fill,
                  tone: TileTone.green,
                  title: loc.bananasSendBananas,
                  onTap: _send,
                ),
              ]),
              GroupedSection(
                footer: loc.bananasAskingFooter(name),
                children: [
                  GroupedRow.toggle(
                    title: loc.bananasAsking,
                    value: r.ask,
                    onChanged: (v) => _set(r.copyWith(ask: v), ask: v),
                  ),
                ],
              ),
              GroupedSection(
                header: loc.bananasAllowance,
                footer: loc.bananasAllowanceFooter,
                children: [
                  for (final v in _allowances)
                    GroupedRow.choice(
                      title: v == 0 ? loc.bananasOff : loc.bananasAllowanceValue(v),
                      selected: r.allowancePerWeek == v,
                      onTap: () =>
                          _set(r.copyWith(allowancePerWeek: v), allowance: v),
                    ),
                ],
              ),
              GroupedSection(
                header: loc.bananasSpendHeader,
                footer: loc.bananasSpendFooter,
                children: [
                  for (final o in [
                    ('all', loc.bananasSpendAll),
                    ('lifelines', loc.bananasSpendLifelines),
                    ('none', loc.bananasSpendNone),
                  ])
                    GroupedRow.choice(
                      title: o.$2,
                      selected: r.spend == o.$1,
                      onTap: () => _set(r.copyWith(spend: o.$1), spend: o.$1),
                    ),
                ],
              ),
              GroupedSection(
                header: loc.bananasAutoYes,
                footer: loc.bananasAutoYesFooter,
                children: [
                  for (final v in _autoYes)
                    GroupedRow.choice(
                      title: v == 0 ? loc.bananasOff : loc.bananasAllowanceValue(v),
                      selected: r.autoYesPerWeek == v,
                      onTap: () => _set(r.copyWith(autoYesPerWeek: v), autoYes: v),
                    ),
                ],
              ),
              GroupedSection(
                header: loc.bananasHistory,
                children: [
                  if (!_historyLoaded)
                    GroupedRow(title: '…')
                  else if (_history.isEmpty)
                    GroupedRow(title: loc.bananasHistoryEmpty)
                  else
                    for (final h in _history)
                      GroupedRow(
                        title: _ledgerTitle(loc, h),
                        subtitle: MaterialLocalizations.of(context)
                            .formatShortDate(h.at),
                        value: h.amount >= 0 ? '+${h.amount}' : '${h.amount}',
                      ),
                ],
              ),
            ]),
    );
  }
}
