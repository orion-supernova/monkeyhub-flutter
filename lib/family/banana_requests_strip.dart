import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/banana_glyph.dart';
import '../ads/banana_wallet.dart';
import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/action_buttons.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/sheet_kit.dart' show SheetFrame;
import 'banana_family_api.dart';
import 'banana_item_names.dart';

/// "Waiting for a grown-up": the signed-in child's open banana requests, each
/// with a Take back action. Renders nothing when there are none, so it can be
/// mounted unconditionally (the banana wallet sheet is the intended home).
///
/// One `bananaRequests:mine` read when it appears, and again after a
/// withdrawal. No subscription: an answer arrives by push, and the wallet
/// refresh that follows it is what changes the child's screen.
class BananaRequestsStrip extends StatefulWidget {
  const BananaRequestsStrip({super.key, required this.userId});

  final String userId;

  @override
  State<BananaRequestsStrip> createState() => _BananaRequestsStripState();
}

class _BananaRequestsStripState extends State<BananaRequestsStrip> {
  List<OpenBananaRequest> _open = const [];
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await BananaFamilyApi.mine(widget.userId);
      if (mounted) setState(() => _open = rows.where((r) => r.status == 'open').toList());
    } catch (_) {
      // Not a child, or offline: the strip simply stays hidden.
    }
  }

  Future<void> _withdraw(OpenBananaRequest r) async {
    if (!_busy.add(r.id)) return;
    HapticFeedback.lightImpact();
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    try {
      await BananaFamilyApi.withdraw(widget.userId, r.id);
      if (mounted) setState(() => _open = _open.where((o) => o.id != r.id).toList());
    } catch (_) {
      toast.show(loc.bananasErrGeneric);
    } finally {
      _busy.remove(r.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_open.isEmpty) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.bananasWaitingTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            for (final r in _open)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: theme.ink.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const BananaGlyph(size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${bananaItemName(loc, r.item)} · ${r.price}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.ink,
                          ),
                        ),
                      ),
                      FocusableTap(
                        onTap: _busy.contains(r.id) ? null : () => _withdraw(r),
                        radius: 14,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Text(
                            loc.bananasWithdraw,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What a banana-answer push carries. Defined here so the backend can match
/// it: `data.type == "bananaRequest"`, plus `requestId`, `item` (catalog id),
/// `status` (`approved` or `gifted`), `guardianId` and `guardianName`.
class BananaAnswerPush {
  const BananaAnswerPush({
    required this.item,
    required this.status,
    required this.guardianId,
    required this.guardianName,
  });

  final String item;
  final String status;
  final String guardianId;
  final String guardianName;

  bool get gifted => status == 'gifted';

  static BananaAnswerPush? fromData(Map<dynamic, dynamic> data) {
    final status = data['status']?.toString() ?? '';
    // A decline is a quiet text push; only a yes or a gift is a moment.
    if (status != 'approved' && status != 'gifted') return null;
    return BananaAnswerPush(
      item: data['item']?.toString() ?? '',
      status: status,
      guardianId: data['guardianId']?.toString() ?? '',
      guardianName: data['guardianName']?.toString() ?? '',
    );
  }
}

/// A tap on a banana-answer push: refreshes the wallet (so the unlock is
/// there on this device), then the celebration. [onPlay] runs when the child
/// taps "Play now" (the sheet has closed by then); null just closes.
Future<void> showBananaAnswerCelebration(
  BuildContext context, {
  required ChatApi api,
  required String userId,
  required BananaAnswerPush push,
  VoidCallback? onPlay,
}) async {
  unawaited(BananaWallet.instance.refresh(userId));
  final playNow = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _Celebration(api: api, userId: userId, push: push),
  );
  if (playNow == true) onPlay?.call();
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.api, required this.userId, required this.push});
  final ChatApi api;
  final String userId;
  final BananaAnswerPush push;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> {
  bool _thanked = false;
  bool _sending = false;

  /// The thank-you is a real message in the DM with that grown-up, through the
  /// ordinary send path, so it shows up in both chat lists.
  Future<void> _thank() async {
    final guardianId = widget.push.guardianId;
    if (_sending || _thanked || guardianId.isEmpty) return;
    setState(() => _sending = true);
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    try {
      final room = await widget.api.getOrCreateDM(
        userId: widget.userId,
        friendId: guardianId,
      );
      await widget.api.sendMessage(
        roomId: room,
        userId: widget.userId,
        content: loc.bananasThanksMessage,
      );
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _thanked = true);
      toast.show(loc.bananasThanksSent);
    } catch (_) {
      toast.show(loc.bananasErrGeneric);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final p = widget.push;
    final who = p.guardianName.isEmpty ? loc.bananasGrownUp : p.guardianName;
    return SheetFrame(
      showClose: true,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: BananaGlyph(size: 64, popKey: 1)),
            const SizedBox(height: 14),
            Text(
              p.gifted ? loc.bananasGiftTitle(who) : loc.bananasYesTitle(who),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              p.gifted
                  ? loc.bananasGiftBody
                  : loc.bananasYesBody(bananaItemName(loc, p.item)),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: theme.inkMuted),
            ),
            const SizedBox(height: 22),
            SheetActionButton(
              label: loc.bananasPlayNow,
              onTap: () => Navigator.of(context).pop(true),
            ),
            if (p.guardianId.isNotEmpty) ...[
              const SizedBox(height: 8),
              SheetActionButton(
                label: loc.bananasThanks,
                tonal: true,
                busy: _sending,
                onTap: _thanked ? null : _thank,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
