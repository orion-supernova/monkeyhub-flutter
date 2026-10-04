import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
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
import 'remote_image.dart';
import 'room_join_requests_sheet.dart' show DecisionCapsules;
import 'sheet_kit.dart';
import 'user_avatar.dart';

/// The admin queue for suggested changes to the group's name, description and
/// picture — `roomChangeRequests.ts`.
///
/// Every row shows the room as it is BESIDE what is being proposed, because
/// that is the whole decision. "Trip 2026" on its own is not something anybody
/// can rule on; "the group → Trip 2026" is. The pair arrives together in one
/// query rather than being assembled here from the room the sheet is sitting
/// on, so the two halves cannot disagree for a frame after somebody else's
/// edit lands.
///
/// Resolves to true when at least one suggestion was decided, so the caller
/// can refresh the room it is sitting on — an approval changes the name behind
/// this sheet.
Future<bool> showRoomChangeRequestsSheet(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
  required String roomId,
}) async {
  final changed = await showAdaptiveSheet<bool>(
    context,
    // See the join-requests sheet: `ModalBottomSheetRoute` strips the top
    // inset from its content, so this flag on the ROUTE is the only thing that
    // keeps a tall sheet clear of the notch.
    useSafeArea: true,
    builder: (_) => _ChangeRequestsSheet(repo: repo, api: api, roomId: roomId),
  );
  return changed ?? false;
}

class _ChangeRequestsSheet extends StatefulWidget {
  const _ChangeRequestsSheet({
    required this.repo,
    required this.api,
    required this.roomId,
  });

  final ChatRepository repo;
  final ChatApi api;
  final String roomId;

  @override
  State<_ChangeRequestsSheet> createState() => _ChangeRequestsSheetState();
}

class _ChangeRequestsSheetState extends State<_ChangeRequestsSheet> {
  List<RoomChangeRequest> _requests = const [];
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
      final list = await widget.repo.listRoomChangeRequests(widget.roomId);
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

  Future<void> _decide(RoomChangeRequest r, bool approve) async {
    if (_deciding.contains(r.requestId)) return;
    setState(() => _deciding.add(r.requestId));
    try {
      await widget.repo.decideRoomChange(
        requestId: r.requestId,
        approve: approve,
      );
      if (!mounted) return;
      setState(() {
        _deciding.remove(r.requestId);
        // Removed rather than marked — this is a work queue, and one that
        // keeps its finished items is one an admin has to re-read every time
        // to find what is left. Same call the join-request queue makes.
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
      // A refusal usually means the row moved under us — another admin
      // answered it, or the name was taken since it was suggested. Re-read
      // rather than leaving a row that will refuse again on every tap.
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      // Draggable away mid-queue; the caller still needs to know whether
      // anything changed so it can refresh the room behind it.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_anyDecided);
      },
      child: SheetFrame(
        title: l10n.roomChangeRequestsTitle,
        onClose: () => Navigator.of(context).pop(_anyDecided),
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
                  l10n.roomChangeRequestsBlurb,
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
                    l10n.roomChangeRequestsEmpty,
                    style: theme.bodySoft,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                // Plain rows — see the note in the friend picker about not
                // nesting a scroller inside the sheet's own.
                // One card per suggestion: each is a decision with a
                // before/after to read, not a row in a list.
                for (var i = 0; i < _requests.length; i++)
                  Padding(
                    key: ValueKey(_requests[i].requestId),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SheetRise(
                      index: i,
                      child: SheetGroup(
                        children: [
                          _RequestRow(
                            request: _requests[i],
                            api: widget.api,
                            busy: _deciding.contains(_requests[i].requestId),
                            onApprove: () => _decide(_requests[i], true),
                            onReject: () => _decide(_requests[i], false),
                          ),
                        ],
                      ),
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
    required this.request,
    required this.api,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final RoomChangeRequest request;
  final ChatApi api;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _heading(AppLocalizations l10n) {
    switch (request.field) {
      case RoomChangeField.avatar:
        return l10n.roomChangeRequestsPhotoLabel;
      case RoomChangeField.name:
        return l10n.roomChangeRequestsNameLabel;
      case RoomChangeField.description:
        return l10n.roomChangeRequestsDescriptionLabel;
      case RoomChangeField.unknown:
        // A field a newer server grew. The row still says who asked and can
        // still be answered — an admin left unable to clear their own queue
        // because they have not updated yet is the worse failure.
        return l10n.roomChangeRequestsUnknownLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final who = request.user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (who != null) ...[
                UserAvatar(user: who, size: 26, api: api),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  who == null
                      ? _heading(l10n)
                      : l10n.roomChangeRequestsSuggestedBy(who.displayName),
                  style: theme.bodySoft.copyWith(
                    fontSize: 13,
                    color: theme.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _heading(l10n),
            style: theme.bodyEmph.copyWith(fontSize: 17, color: theme.ink),
          ),
          const SizedBox(height: 8),
          if (request.field == RoomChangeField.avatar)
            _PhotoComparison(request: request, api: api)
          else
            _TextComparison(request: request),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: DecisionCapsules(
              busy: busy,
              approveLabel: l10n.changeRequestUseIos,
              onApprove: onApprove,
              onReject: onReject,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoComparison extends StatelessWidget {
  const _PhotoComparison({required this.request, required this.api});

  final RoomChangeRequest request;
  final ChatApi api;

  static const _size = 62.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        _well(theme, request.currentStorageId),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(CupertinoIcons.arrow_right, size: 16, color: theme.inkMuted),
        ),
        _well(theme, request.storageId),
      ],
    );
  }

  Widget _well(AppTheme theme, String? storageId) {
    final has = storageId != null && storageId.isNotEmpty;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: theme.ink.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? RemoteImage(
              storageId: storageId,
              api: api,
              width: _size,
              height: _size,
              borderRadius: BorderRadius.circular(_size),
            )
          : Center(child: Icon(CupertinoIcons.number, size: 22, color: theme.inkMuted)),
    );
  }
}

/// The room's current text over the proposed text.
///
/// Stacked rather than side by side: a description runs to several lines and
/// two columns of wrapped prose is unreadable at sheet width. The current
/// value is struck through and muted, so which of the two is the proposal is
/// legible without reading either.
class _TextComparison extends StatelessWidget {
  const _TextComparison({required this.request});

  final RoomChangeRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = (request.currentValue ?? '').trim();
    final proposed = (request.value ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current.isNotEmpty) ...[
          Text(
            current,
            style: theme.bodySoft.copyWith(
              color: theme.inkMuted,
              decoration: TextDecoration.lineThrough,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          // An empty proposal on a description is a real one — "take it off" —
          // and rendering it as blank space would make the row look broken and
          // the decision unanswerable.
          proposed.isEmpty ? l10n.roomChangeRequestsClearedValue : proposed,
          style: proposed.isEmpty
              ? theme.body.copyWith(
                  color: theme.inkMuted,
                  fontStyle: FontStyle.italic,
                )
              : theme.body,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
