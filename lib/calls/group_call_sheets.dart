import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'call_models.dart';
import 'group_call_service.dart';

/// Entry point for starting a group call from a room header: bottom sheet
/// with voice/video choice and "call everyone" vs "choose people".
Future<void> showStartGroupCallSheet(
  BuildContext context, {
  required GroupCallService service,
  required ChatApi api,
  required String roomId,
  required String myUserId,
}) async {
  final theme = ThemeScope.of(context);
  var kind = CallMediaKind.audio;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Widget kindChip(CallMediaKind k, IconData icon, String label) {
            final selected = kind == k;
            return FocusableTap(
              onTap: () => setSheetState(() => kind = k),
              radius: 999,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.accent
                      : theme.ink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 16,
                        color: selected ? theme.background : theme.ink),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: theme.monoTiny.copyWith(
                        color: selected ? theme.background : theme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          Widget action(IconData icon, String title, String subtitle,
              VoidCallback onTap) {
            return FocusableTap(
              onTap: onTap,
              radius: 14,
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.ink.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: theme.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: theme.body
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: theme.monoTiny
                                  .copyWith(color: theme.inkMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.inkMuted, size: 18),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start a call', style: theme.displaySmall),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      kindChip(CallMediaKind.audio, Icons.call, 'VOICE'),
                      const SizedBox(width: 8),
                      kindChip(CallMediaKind.video, Icons.videocam, 'VIDEO'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  action(
                    Icons.groups,
                    'Call everyone',
                    'Ring all members of this room',
                    () {
                      Navigator.of(sheetCtx).pop();
                      _startCall(context, service, roomId, kind, null);
                    },
                  ),
                  action(
                    Icons.checklist,
                    'Choose people',
                    'Pick who to invite',
                    () async {
                      Navigator.of(sheetCtx).pop();
                      final picked = await _pickMembers(
                        context,
                        api: api,
                        roomId: roomId,
                        myUserId: myUserId,
                      );
                      if (picked == null || picked.isEmpty) return;
                      if (!context.mounted) return;
                      _startCall(context, service, roomId, kind, picked);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _startCall(
  BuildContext context,
  GroupCallService service,
  String roomId,
  CallMediaKind kind,
  List<String>? inviteeIds,
) {
  service
      .startCall(roomId: roomId, kind: kind, inviteeIds: inviteeIds)
      .catchError((e) {
    if (!context.mounted) return;
    final msg = e.toString().contains('CALL_FULL')
        ? 'That call is full (max 6 people)'
        : 'Could not start the call';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  });
}

/// Member multi-select. Returns the chosen userIds, or null on dismiss.
Future<List<String>?> _pickMembers(
  BuildContext context, {
  required ChatApi api,
  required String roomId,
  required String myUserId,
}) async {
  final theme = ThemeScope.of(context);
  List<ChatUser>? members;
  final selected = <String>{};

  return showModalBottomSheet<List<String>>(
    context: context,
    backgroundColor: theme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          if (members == null) {
            api.getMembers(roomId).then((list) {
              if (!sheetCtx.mounted) return;
              setSheetState(() {
                members = list
                    .where((u) => u.id != myUserId)
                    .toList(growable: false);
              });
            }).catchError((_) {
              if (sheetCtx.mounted) setSheetState(() => members = const []);
            });
          }
          final list = members;
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite to call', style: theme.displaySmall),
                  const SizedBox(height: 10),
                  if (list == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No other members here',
                          style: theme.body.copyWith(color: theme.inkMuted)),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final u = list[i];
                          final isOn = selected.contains(u.id);
                          return FocusableTap(
                            onTap: () => setSheetState(() {
                              if (isOn) {
                                selected.remove(u.id);
                              } else {
                                selected.add(u.id);
                              }
                            }),
                            radius: 12,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  UserAvatar(
                                      user: u,
                                      api: api,
                                      size: 36,
                                      showStatus: false),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(u.displayName,
                                        style: theme.body,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Icon(
                                    isOn
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isOn
                                        ? theme.accent
                                        : theme.inkMuted,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  FocusableTap(
                    onTap: selected.isEmpty
                        ? null
                        : () => Navigator.of(sheetCtx)
                            .pop(selected.toList(growable: false)),
                    radius: 14,
                    enabled: selected.isNotEmpty,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected.isEmpty
                            ? theme.ink.withValues(alpha: 0.08)
                            : theme.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          selected.isEmpty
                              ? 'Select people'
                              : 'Start call (${selected.length})',
                          style: theme.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected.isEmpty
                                ? theme.inkMuted
                                : theme.background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
