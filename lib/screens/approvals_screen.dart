import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/banana_glyph.dart';
import '../ads/banana_shop.dart';
import '../ads/banana_wallet.dart';
import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../family/banana_family_api.dart';
import '../family/banana_item_names.dart';
import '../family/banana_send_sheet.dart';
import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/family.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/ios_kit.dart';
import '../widgets/app_toast.dart';
import '../widgets/user_avatar.dart';

/// The parent's inbox: everything waiting on them, across every child.
///
/// The three item types are kept visually distinct rather than collapsed into
/// a generic "request", because the decision a parent is making is genuinely
/// different in each case — letting their own child reach out, letting a
/// stranger reach in, or letting them into a room full of people.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({
    super.key,
    required this.api,
    required this.guardianId,
    required this.family,
  });

  final ChatApi api;
  final String guardianId;
  final FamilyService family;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  List<QueueItem> _items = const [];
  bool _loading = true;

  /// Ids currently being decided, so a double-tap can't fire twice.
  final _deciding = <String>{};

  /// The queue, live.
  ///
  /// This screen read it once and never again, which made it wrong in three
  /// ordinary situations: a request arriving while a parent had it open, a
  /// co-parent deciding the same item from their own phone, and a child's
  /// request being withdrawn. All three already travel over the socket this
  /// app keeps open — see [ChatApi.subscribeGuardianQueue].
  Subscription? _sub;

  final _wallet = BananaWallet.instance;

  @override
  void initState() {
    super.initState();
    _wallet.addListener(_onWallet);
    // Read once so "Yes" can say up front whether it will need a pack.
    _wallet.refresh(widget.guardianId);
    _attach();
  }

  void _onWallet() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _wallet.removeListener(_onWallet);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _attach() async {
    try {
      final sub = await widget.api.subscribeGuardianQueue(
        guardianId: widget.guardianId,
        onItems: (items) {
          if (!mounted) return;
          setState(() {
            _items = items;
            _loading = false;
            // A decision that has landed is no longer in flight. Without this
            // an item the server has already dropped could leave its id stuck
            // in the set, and a re-raised request would open disabled.
            _deciding.removeWhere(
              (id) => !items.any((i) => i.id == id),
            );
          });
        },
        // Transient socket trouble. Keep whatever is on screen and let the
        // pull-to-refresh below be the way out — clearing the list here would
        // tell a parent they have nothing waiting, which is the one wrong
        // answer this screen must not give.
        onError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      );
      if (!mounted) {
        sub.cancel();
        return;
      }
      _sub = sub;
    } catch (_) {
      // Subscribing failed outright — fall back to the one-shot read so the
      // screen still works on a flaky connection.
      await _load();
    }
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.listGuardianQueue(widget.guardianId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(QueueItem item, bool approve) async {
    if (_deciding.contains(item.id)) return;
    if (item.relay == QueueRelay.banana) return; // see _decideBanana
    setState(() => _deciding.add(item.id));
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    try {
      // Three destinations, switched on the item's own [QueueItem.relay].
      // This used to be `isContact ? advance : decideApproval`, which meant any
      // new queue kind silently fell into the else branch and handed
      // `family:decideApproval` an id from a table it has never heard of.
      switch (item.relay) {
        case QueueRelay.contact:
          // Both contact directions go through the same relay mutation — the
          // backend works out whose hop it is from the row's stage.
          await widget.api.advanceContactRequest(
            friendshipId: item.id,
            guardianId: widget.guardianId,
            approve: approve,
          );
        case QueueRelay.roomGrant:
          await widget.api.decideApproval(
            approvalId: item.id,
            guardianId: widget.guardianId,
            approve: approve,
          );
        case QueueRelay.roomInvite:
          await widget.api.advanceRoomInvitation(
            invitationId: item.id,
            guardianId: widget.guardianId,
            approve: approve,
          );
        case QueueRelay.banana:
          break;
      }
      if (!mounted) return;
      // Optimistic, and kept even though the subscription will say the same
      // thing a moment later: the card should leave under the thumb, not after
      // a round trip. The live update is idempotent with it.
      setState(() => _items = _items.where((i) => i.id != item.id).toList());
      // Keep the badge in Settings honest.
      widget.family.refresh();
    } catch (e) {
      toast.show(_humanize(e, loc));
    } finally {
      if (mounted) setState(() => _deciding.remove(item.id));
    }
  }

  /// A child's banana request: `approve` (pays from this guardian's wallet),
  /// `gift` (bananas instead of the item) or `decline`.
  ///
  /// A short wallet is not an error to show: it opens the banana shop, and
  /// once bananas arrive the same approve is sent again, once. That is the
  /// "Yes · get bananas & unlock" button.
  Future<void> _decideBanana(QueueItem item, String action) async {
    if (_deciding.contains(item.id)) return;
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    final child = item.child.displayName;
    final name = bananaItemName(loc, item.bananaItem ?? '');
    int? amount;
    if (action == 'gift') {
      amount = await showSendBananasSheet(context, childName: child);
      if (amount == null || !mounted) return;
    }
    setState(() => _deciding.add(item.id));
    try {
      try {
        await _answer(item, action, amount);
      } catch (e) {
        if (action != 'approve' || !e.toString().contains('NO_BANANAS')) rethrow;
        if (!mounted) return;
        final before = _wallet.balance;
        await showBananaShop(context);
        await _wallet.refresh(widget.guardianId);
        if (!mounted || _wallet.balance <= before) return;
        await _answer(item, action, amount);
      }
      if (!mounted) return;
      setState(() => _items = _items.where((i) => i.id != item.id).toList());
      widget.family.refresh();
      _wallet.refresh(widget.guardianId);
      toast.show(switch (action) {
        'approve' => loc.bananasApprovedToast(child, name),
        'gift' => loc.bananasSentToast(child, amount ?? 0),
        _ => loc.bananasDeclinedToast(child),
      });
    } catch (e) {
      toast.show(_humanize(e, loc));
    } finally {
      if (mounted) setState(() => _deciding.remove(item.id));
    }
  }

  Future<void> _answer(QueueItem item, String action, int? amount) =>
      BananaFamilyApi.answer(
        guardianId: widget.guardianId,
        requestId: item.id,
        action: action,
        amount: amount,
      );

  String _humanize(Object e, AppLocalizations loc) {
    final s = e.toString();
    if (s.contains('NO_BANANAS')) return loc.bananasErrNoBananas;
    if (s.contains('ALREADY_ANSWERED')) return loc.bananasErrAnswered;
    if (s.contains('NOT_A_GUARDIAN')) {
      return loc.approvalsScreenErrorNotGuardian;
    }
    if (s.contains('REQUEST_NOT_FOUND') ||
        s.contains('REQUEST_NOT_PENDING_APPROVAL')) {
      return loc.approvalsScreenErrorAlreadyHandled;
    }
    return loc.approvalsScreenErrorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return IosPage(
      onRefresh: () {
        HapticFeedback.lightImpact();
        return _load();
      },
      title: loc.acctRowApprovals,
      slivers: _loading
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CupertinoActivityIndicator(color: theme.inkMuted),
                ),
              ),
            ]
          : _items.isEmpty
              ? [SliverFillRemaining(hasScrollBody: false, child: _EmptyState())]
              : readableSlivers(context, [
                  for (final item in _items)
                    if (item.type == QueueItemType.bananaRequest)
                      _BananaCard(
                        key: ValueKey(item.id),
                        item: item,
                        api: widget.api,
                        busy: _deciding.contains(item.id),
                        short: _wallet.loaded && _wallet.balance < item.bananaPrice,
                        balance: _wallet.balance,
                        onAnswer: (a) => _decideBanana(item, a),
                      )
                    else
                      _QueueCard(
                      key: ValueKey(item.id),
                      item: item,
                      api: widget.api,
                      busy: _deciding.contains(item.id),
                      onDecide: (ok) => _decide(item, ok),
                    ),
                ]),
  );
  }
}

/// Nothing waiting: the shared empty state, lifted a little off centre the
/// way iOS's ContentUnavailableView sits.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: EmptyState(
          icon: CupertinoIcons.checkmark_seal_fill,
          title: loc.apprEmptyTitle,
          message: loc.apprEmptySub,
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    super.key,
    required this.item,
    required this.api,
    required this.busy,
    required this.onDecide,
  });

  final QueueItem item;
  final ChatApi api;
  final bool busy;
  final ValueChanged<bool> onDecide;

  /// The one-line question the parent is actually answering.
  String _headline(AppLocalizations loc) {
    final child = item.child.displayName;
    switch (item.type) {
      case QueueItemType.contactOutgoing:
        return loc.approvalsScreenHeadlineContactOutgoing(
          child,
          item.other?.displayName ?? loc.approvalsScreenSomeoneLower,
        );
      case QueueItemType.contactIncoming:
        return loc.approvalsScreenHeadlineContactIncoming(
          child,
          item.other?.displayName ?? loc.approvalsScreenSomeoneCapital,
        );
      case QueueItemType.joinRoom:
        return loc.approvalsScreenHeadlineJoinRoom(
          child,
          item.room?.name ?? loc.approvalsScreenRoomFallback,
        );
      case QueueItemType.roomInviteOutgoing:
        return loc.approvalsScreenHeadlineRoomInviteOutgoing(
          child,
          item.other?.displayName ?? loc.approvalsScreenSomeoneLower,
          item.room?.name ?? loc.approvalsScreenRoomFallback,
        );
      case QueueItemType.roomInviteIncoming:
        return loc.approvalsScreenHeadlineRoomInviteIncoming(
          child,
          item.other?.displayName ?? loc.approvalsScreenSomeoneCapital,
          item.room?.name ?? loc.approvalsScreenRoomFallback,
        );
      case QueueItemType.bananaRequest:
        return '';
    }
  }

  /// The consequence, spelled out. A parent approving an inbound request is
  /// not making the two friends — the child still decides — and saying so
  /// avoids a nasty surprise.
  String _consequence(AppLocalizations loc) {
    switch (item.type) {
      case QueueItemType.contactOutgoing:
        return loc.approvalsScreenConsequenceContactOutgoing;
      case QueueItemType.contactIncoming:
        return loc.approvalsScreenConsequenceContactIncoming(_childName);
      case QueueItemType.joinRoom:
        return loc.approvalsScreenConsequenceJoinRoom;
      case QueueItemType.roomInviteOutgoing:
        return loc.approvalsScreenConsequenceRoomInviteOutgoing;
      // Says out loud that this one grants the room, because it does — unlike
      // every other incoming card here, a yes is not merely "let them ask".
      case QueueItemType.roomInviteIncoming:
        return loc.approvalsScreenConsequenceRoomInviteIncoming(_childName);
      case QueueItemType.bananaRequest:
        return '';
    }
  }

  String get _childName => item.child.displayName;

  IconData get _icon {
    switch (item.type) {
      case QueueItemType.contactOutgoing:
        return CupertinoIcons.person_badge_plus;
      case QueueItemType.contactIncoming:
        return CupertinoIcons.hand_raised;
      case QueueItemType.joinRoom:
        return CupertinoIcons.number;
      case QueueItemType.roomInviteOutgoing:
      case QueueItemType.roomInviteIncoming:
        return CupertinoIcons.person_3;
      case QueueItemType.bananaRequest:
        return CupertinoIcons.gift;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final subject = item.other;
    return InsetGroup(
      margin: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (subject != null)
                    UserAvatar(user: subject, size: 40, api: api)
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: quietFill(theme),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(_icon, size: 18, color: theme.accent),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headline(loc),
                          style: groupedTitleStyle(theme)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (subject != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            '@${subject.username}',
                            style: groupedSubtitleStyle(theme),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                // The child's own words, as a message bubble — it is one.
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: theme.ink.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    item.note,
                    style: groupedTitleStyle(theme),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                _consequence(loc),
                style: groupedFooterStyle(theme),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SheetActionButton(
                      label: loc.apprNotYet,
                      tonal: true,
                      onTap: busy ? null : () => onDecide(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Busy is a state of the button — same size, its own
                  // spinner — not a hand-built placeholder swapped in.
                  Expanded(
                    child: SheetActionButton(
                      label: loc.apprAllow,
                      busy: busy,
                      onTap: () => onDecide(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A child's ask for an unlock: who, what, how much, their sticker and note,
/// and the three answers. Same card shape as [_QueueCard] so the two kinds
/// share one queue without looking like two apps.
class _BananaCard extends StatelessWidget {
  const _BananaCard({
    super.key,
    required this.item,
    required this.api,
    required this.busy,
    required this.short,
    required this.balance,
    required this.onAnswer,
  });

  final QueueItem item;
  final ChatApi api;
  final bool busy;

  /// The guardian's wallet can't cover [QueueItem.bananaPrice]: "Yes" turns
  /// into "get bananas & unlock".
  final bool short;
  final int balance;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final id = item.bananaItem ?? '';
    final child = item.child.displayName;
    final sticker = item.sticker;
    return InsetGroup(
      margin: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(user: item.child, size: 40, api: api),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.bananasAskHeadline(child, bananaItemName(loc, id)),
                          style: groupedTitleStyle(theme)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const BananaGlyph(size: 14),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                [
                                  loc.bananasPrice(item.bananaPrice),
                                  bananaItemKind(loc, id),
                                ].where((e) => e.isNotEmpty).join(' · '),
                                style: groupedSubtitleStyle(theme),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (sticker != null && sticker.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(sticker, style: const TextStyle(fontSize: 30)),
                    ),
                ],
              ),
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: theme.ink.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(item.note, style: groupedTitleStyle(theme)),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                short
                    ? loc.bananasShortFooter(balance, child)
                    : loc.bananasYesFooter(child),
                style: groupedFooterStyle(theme),
              ),
              const SizedBox(height: 14),
              SheetActionButton(
                label: short ? loc.bananasYesGetBananas : loc.bananasYes,
                busy: busy,
                onTap: () => onAnswer('approve'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SheetActionButton(
                      label: loc.bananasSendBananas,
                      tonal: true,
                      onTap: busy ? null : () => onAnswer('gift'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SheetActionButton(
                      label: loc.bananasNotNow,
                      tonal: true,
                      onTap: busy ? null : () => onAnswer('decline'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
