import 'package:flutter/material.dart';

import '../auth/auth_errors.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../invites/room_admin_errors.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/room_admin.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'sheet_surface.dart';
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
      // The sheet can be dragged away mid-queue; the caller still needs to know
      // whether anything changed so it can refresh the roster behind it.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_anyDecided);
      },
      child: SheetSurface(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.roomJoinRequestsTitle, style: theme.displaySmall),
              const SizedBox(height: 6),
              Text(l10n.roomJoinRequestsBlurb, style: theme.bodySoft),
              const SizedBox(height: 18),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.accent,
                      ),
                    ),
                  ),
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
                // Plain rows — see the note in the friend picker about not
                // nesting a scroller inside the sheet's own.
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          UserAvatar(user: request.user, size: 38, api: api),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.user.displayName, style: theme.body),
                Text('@${request.user.username}', style: theme.monoTiny),
              ],
            ),
          ),
          if (busy)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent),
            )
          else ...[
            _DecideButton(
              label: l10n.roomJoinRequestsReject,
              color: theme.danger,
              onTap: onReject,
            ),
            const SizedBox(width: 8),
            _DecideButton(
              label: l10n.roomJoinRequestsApprove,
              color: theme.accent,
              onTap: onApprove,
            ),
          ],
        ],
      ),
    );
  }
}

class _DecideButton extends StatelessWidget {
  const _DecideButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusSm,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.2),
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
          child: Text(label, style: theme.monoTiny.copyWith(color: color)),
        ),
      ),
    );
  }
}
