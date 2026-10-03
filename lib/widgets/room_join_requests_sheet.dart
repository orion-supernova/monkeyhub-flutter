import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../auth/auth_errors.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../invites/room_admin_errors.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/room_admin.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';
import 'user_avatar.dart';

/// The admin queue: people who redeemed the link on a room whose policy is
/// "admins approve each join".
///
/// They are NOT members while they sit here — they cannot read a message, see
/// the roster, or tell that the queue exists. That is the whole difference
/// between this and the open policy, and it is why the sheet shows the person's
/// handle and avatar and nothing else: an admin is deciding about a stranger,
/// and everything else this app knows about that stranger is theirs, not the
/// room's.
///
/// Resolves to true when at least one request was decided, so the caller can
/// refresh the member list it is sitting on.
Future<bool> showRoomJoinRequestsSheet(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
  required String roomId,
}) async {
  final changed = await showAdaptiveSheet<bool>(
    context,
    // Bounded by the top safe area. `ModalBottomSheetRoute` strips the top
    // inset from everything inside it, so a `SafeArea` in the content is a
    // silent no-op — this flag is the only hook that applies it, from the
    // route, where the padding still exists. Without it a tall sheet runs
    // under the notch.
    useSafeArea: true,
    builder: (_) => _JoinRequestsSheet(repo: repo, api: api, roomId: roomId),
  );
  return changed ?? false;
}

class _JoinRequestsSheet extends StatefulWidget {
  const _JoinRequestsSheet({
    required this.repo,
    required this.api,
    required this.roomId,
  });

  final ChatRepository repo;
  final ChatApi api;
  final String roomId;

  @override
  State<_JoinRequestsSheet> createState() => _JoinRequestsSheetState();
}

class _JoinRequestsSheetState extends State<_JoinRequestsSheet> {
  List<RoomJoinRequest> _requests = const [];
  bool _loading = true;
  final _deciding = <String>{};
  bool _anyDecided = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.repo.listJoinRequests(widget.roomId);
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _decide(RoomJoinRequest r, bool approve) async {
    if (_deciding.contains(r.requestId)) return;
    setState(() => _deciding.add(r.requestId));
    try {
      await widget.repo.decideJoinRequest(
        requestId: r.requestId,
        approve: approve,
      );
      if (!mounted) return;
      setState(() {
        _deciding.remove(r.requestId);
        // Removed rather than marked. Unlike the invite picker — where the
        // list is a roster you check afterwards — this is a work queue, and a
        // queue that keeps its finished items is one an admin has to re-read
        // every time to find what is left.
        _requests = _requests.where((x) => x.requestId != r.requestId).toList();
        _anyDecided = true;
      });
      if (_requests.isEmpty && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deciding.remove(r.requestId));
      final l10n = AppLocalizations.of(context);
      showAppToast(
        context,
        humanizeAuthError(
          e,
          l10n,
          fallback: l10n.roomAdminGenericError,
          overrides: roomAdminErrorMessages(l10n),
        ),
        tone: ToastTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_anyDecided);
      },
      child: SheetFrame(
        title: l10n.roomJoinRequestsTitle,
        leading: SheetCloseButton(
          onTap: () => Navigator.of(context).pop(_anyDecided),
        ),
        // One scroller for the whole sheet: the frame does not scroll, and
        // a long queue must never overflow it.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Text(
                  l10n.roomJoinRequestsBlurb,
                  style: theme.bodySoft.copyWith(color: theme.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (_requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    l10n.roomJoinRequestsEmpty,
                    style: theme.bodySoft,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                SheetRise(
                  child: SheetGroup(
                    children: [
                      for (final r in _requests)
                        _RequestRow(
                          key: ValueKey(r.requestId),
                          request: r,
                          api: widget.api,
                          busy: _deciding.contains(r.requestId),
                          onApprove: () => _decide(r, true),
                          onReject: () => _decide(r, false),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    super.key,
    required this.request,
    required this.api,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final RoomJoinRequest request;
  final ChatApi api;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          UserAvatar(user: request.user, size: 40, api: api),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.user.displayName,
                  style: theme.body.copyWith(fontSize: 17, color: theme.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${request.user.username}',
                  style: theme.bodySoft.copyWith(
                    fontSize: 13,
                    color: theme.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DecisionCapsules(
            busy: busy,
            approveLabel: l10n.joinRequestAllowIos,
            onApprove: onApprove,
            onReject: onReject,
          ),
        ],
      ),
    );
  }
}

/// The two answers on a pending request: a quiet Decline and a solid primary.
///
/// Decline is a neutral capsule with red text rather than a red outline —
/// an outlined pair read as two equal alarms. The primary is the outgoing-
/// bubble colour, the theme's tone for "white text sits on this". Shared with
/// the suggested-changes sheet so the two never answer differently.
class DecisionCapsules extends StatelessWidget {
  const DecisionCapsules({
    super.key,
    required this.busy,
    required this.approveLabel,
    required this.onApprove,
    required this.onReject,
  });

  final bool busy;
  final String approveLabel;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    if (busy) {
      return const SizedBox(
        width: 44,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Capsule(
          label: l10n.requestDeclineIos,
          fill: theme.ink.withValues(alpha: 0.09),
          ink: theme.danger,
          onTap: onReject,
        ),
        const SizedBox(width: 6),
        _Capsule(
          label: approveLabel,
          fill: theme.bubbleFill(isMine: true),
          ink: theme.accentInk,
          onTap: onApprove,
        ),
      ],
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      scale: 0.93,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.bodySoft.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: ink,
          ),
        ),
      ),
    );
  }
}
