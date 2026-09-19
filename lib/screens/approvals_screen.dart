import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/family.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
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

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void dispose() {
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

  String _humanize(Object e, AppLocalizations loc) {
    final s = e.toString();
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.arrow_back,
                            size: 20, color: theme.inkSoft),
                      ),
                      const SizedBox(width: 14),
                      Text(loc.approvalsScreenTitle,
                          style: theme.label.copyWith(letterSpacing: 2.8)),
                      const SizedBox(width: 10),
                      if (_items.isNotEmpty)
                        Text('${_items.length}', style: theme.monoTiny),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                              color: theme.accent, strokeWidth: 2),
                        )
                      : _items.isEmpty
                          ? _EmptyState()
                          : RefreshIndicator(
                              color: theme.accent,
                              onRefresh: () {
                                HapticFeedback.lightImpact();
                                return _load();
                              },
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  edgeToEdgeBottom(context, 40),
                                ),
                                itemCount: _items.length,
                                itemBuilder: (_, i) => _QueueCard(
                                  item: _items[i],
                                  api: widget.api,
                                  busy: _deciding.contains(_items[i].id),
                                  onDecide: (ok) => _decide(_items[i], ok),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 34, color: theme.inkMuted),
          const SizedBox(height: 14),
          Text(loc.approvalsScreenEmptyTitle, style: theme.displaySmall),
          const SizedBox(height: 6),
          Text(loc.approvalsScreenEmptySubtitle, style: theme.bodySoft),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
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
    }
  }

  String get _childName => item.child.displayName;

  IconData get _icon {
    switch (item.type) {
      case QueueItemType.contactOutgoing:
        return Icons.person_add_alt;
      case QueueItemType.contactIncoming:
        return Icons.waving_hand_outlined;
      case QueueItemType.joinRoom:
        return Icons.tag;
      case QueueItemType.roomInviteOutgoing:
      case QueueItemType.roomInviteIncoming:
        return Icons.group_add_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final subject = item.other;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (subject != null)
                UserAvatar(user: subject, size: 38, api: api)
              else
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.accentSoft,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_icon, size: 16, color: theme.accent),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_headline(loc), style: theme.displaySmall),
                    if (subject != null) ...[
                      const SizedBox(height: 2),
                      Text('@${subject.username}',
                          style: theme.mono.copyWith(color: theme.inkMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                border: Border(
                  left: BorderSide(color: theme.accent, width: 2),
                ),
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              child: Text('“${item.note}”', style: theme.bodySoft),
            ),
          ],
          const SizedBox(height: 10),
          Text(_consequence(loc), style: theme.bodySoft),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Btn(
                  label: loc.approvalsScreenNotYetButton,
                  filled: false,
                  onTap: busy ? null : () => onDecide(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Btn(
                  label: loc.approvalsScreenAllowButton,
                  filled: true,
                  busy: busy,
                  onTap: busy ? null : () => onDecide(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.filled,
    required this.onTap,
    this.busy = false,
  });
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (busy ? theme.accentSoft : theme.accent)
              : Colors.transparent,
          border: filled ? null : Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: busy
            ? SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.accentInk,
                ),
              )
            : Text(
                label,
                style: theme.label.copyWith(
                  color: filled ? theme.accentInk : theme.inkSoft,
                  letterSpacing: 2.2,
                ),
              ),
      ),
    );
  }
}
