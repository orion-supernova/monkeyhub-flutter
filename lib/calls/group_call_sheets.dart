import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
import '../widgets/user_avatar.dart';
import 'call_models.dart';
import 'group_call_service.dart';

/// Entry point for starting a group call from a room header: bottom sheet
/// with voice/video choice and "call everyone" vs "choose people".
///
/// [initialKind] is which chip starts selected — the header's dedicated
/// video button opens the sheet already on video, so that tap isn't asked
/// twice. The chips stay, so the choice is still one tap away.
Future<void> showStartGroupCallSheet(
  BuildContext context, {
  required GroupCallService service,
  required ChatApi api,
  required String roomId,
  required String myUserId,
  CallMediaKind initialKind = CallMediaKind.audio,
}) async {
  var kind = initialKind;

  await showAdaptiveSheet<void>(
    context,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final l10n = AppLocalizations.of(sheetCtx);
          return SheetFrame(
            title: l10n.linkedAccountsScreenCallSheetTitle,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Voice or video as the shared segmented control — one
                // decision, two answers, the iOS shape for it.
                IosSegmentedControl<CallMediaKind>(
                  value: kind,
                  onChanged: (k) => setSheetState(() => kind = k),
                  segments: [
                    IosSegment(
                      value: CallMediaKind.audio,
                      icon: CupertinoIcons.phone_fill,
                      label: l10n.linkedAccountsScreenCallSheetVoiceLabel,
                    ),
                    IosSegment(
                      value: CallMediaKind.video,
                      icon: CupertinoIcons.video_camera_solid,
                      label: l10n.linkedAccountsScreenCallSheetVideoLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SheetGroup(
                  children: [
                    GroupedRow(
                      icon: CupertinoIcons.person_3_fill,
                      tone: TileTone.green,
                      title: l10n.linkedAccountsScreenCallSheetCallEveryoneTitle,
                      subtitle:
                          l10n.linkedAccountsScreenCallSheetCallEveryoneSubtitle,
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _startCall(context, service, roomId, kind, null);
                      },
                    ),
                    // Not the check glyph: that is the picker's "selected"
                    // mark one screen later, and here nothing is picked yet.
                    GroupedRow(
                      icon: CupertinoIcons.person_crop_circle_badge_plus,
                      tone: TileTone.blue,
                      title: l10n.linkedAccountsScreenCallSheetChoosePeopleTitle,
                      subtitle:
                          l10n.linkedAccountsScreenCallSheetChoosePeopleSubtitle,
                      onTap: () async {
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
                const SizedBox(height: 4),
              ],
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
            ? AppLocalizations.of(
                context,
              ).linkedAccountsScreenCallSheetCallFullError
            : AppLocalizations.of(
                context,
              ).linkedAccountsScreenCallSheetStartFailedError;
        showAppToast(context, msg);
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

  return showAdaptiveSheet<List<String>>(
    context,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          if (members == null) {
            api
                .getMembers(roomId, viewerUserId: myUserId)
                .then((list) {
                  if (!sheetCtx.mounted) return;
                  setSheetState(() {
                    members = list
                        .where((u) => u.id != myUserId)
                        .toList(growable: false);
                  });
                })
                .catchError((_) {
                  if (sheetCtx.mounted) setSheetState(() => members = const []);
                });
          }
          final list = members;
          final l10n = AppLocalizations.of(sheetCtx);
          final start = selected.isEmpty
              ? null
              : () => Navigator.of(sheetCtx)
                  .pop(selected.toList(growable: false));
          return SheetFrame(
            title: l10n.linkedAccountsScreenCallSheetInviteTitle,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (list == null)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else if (list.isEmpty)
                    EmptyLine(l10n.linkedAccountsScreenCallSheetNoOtherMembers)
                  else
                    // Messages-style picker: one grouped block that scrolls
                    // on its own, a check that springs in per person.
                    Flexible(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(groupedRadius(theme)),
                        child: ColoredBox(
                          color: sheetGroupFill(theme),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: list.length,
                            // The hairline starts at the text, as SheetGroup
                            // draws it under a PersonRow.
                            separatorBuilder: (_, _) => Padding(
                              padding: const EdgeInsets.only(
                                left: kPersonRowTextInset,
                              ),
                              child: Container(
                                height: 1 /
                                    MediaQuery.devicePixelRatioOf(sheetCtx),
                                color: theme.ink.withValues(alpha: 0.10),
                              ),
                            ),
                            itemBuilder: (_, i) {
                              final u = list[i];
                              final isOn = selected.contains(u.id);
                              void toggle() => setSheetState(() {
                                if (isOn) {
                                  selected.remove(u.id);
                                } else {
                                  selected.add(u.id);
                                }
                              });
                              return _PickRow(
                                user: u,
                                api: api,
                                on: isOn,
                                onTap: toggle,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  SheetActionButton(
                    label: selected.isEmpty
                        ? l10n.linkedAccountsScreenCallSheetSelectPeople
                        : l10n.linkedAccountsScreenCallSheetStartCallCount(
                            '${selected.length}',
                          ),
                    onTap: start,
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

/// One person in the call picker: face, name, and the shared selection
/// circle — the Messages "New Group" picker, on [PersonRow].
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.user,
    required this.api,
    required this.on,
    required this.onTap,
  });

  final ChatUser user;
  final ChatApi api;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PersonRow(
        avatar: UserAvatar(user: user, api: api, size: 40, showStatus: false),
        title: user.displayName,
        semanticLabel: user.displayName,
        trailing: SelectionCheck(picked: on),
        onTap: onTap,
      );
}
