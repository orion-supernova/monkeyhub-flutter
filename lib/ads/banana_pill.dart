import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../widgets/glass_buttons.dart';
import 'banana_glyph.dart';
import 'banana_sheet.dart';
import 'banana_wallet.dart';

/// The bananas in a tab's top bar: the drawn banana and the count, on the
/// app's glass pill. Pops when the count goes up, waves while today's free
/// banana is waiting, and opens the wallet ([showBananaWallet]).
///
/// Reads the wallet once when it appears (no subscription: the wallet only
/// changes through this player's own taps, and every one of those refreshes
/// [BananaWallet]).
class BananaPill extends StatefulWidget {
  const BananaPill({super.key, required this.userId});

  final String userId;

  @override
  State<BananaPill> createState() => _BananaPillState();
}

class _BananaPillState extends State<BananaPill> {
  final _wallet = BananaWallet.instance;
  late int _shown = _wallet.balance;
  int _pops = 0;

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_changed);
    _wallet.refresh(widget.userId);
  }

  @override
  void dispose() {
    _wallet.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (_wallet.balance > _shown) _pops++;
      _shown = _wallet.balance;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GlassPillButton(
      label: '${_wallet.balance}',
      semanticLabel: l10n.bananaBalance(_wallet.balance),
      glyph: BananaGlyph(
        size: 22,
        popKey: _pops,
        waving: _wallet.freeReady,
      ),
      onTap: () => showBananaWallet(context, userId: widget.userId),
    );
  }
}
