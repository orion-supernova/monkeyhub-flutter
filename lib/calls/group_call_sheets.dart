import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoIcons,
        CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
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
  final theme = ThemeScope.of(context);
  var kind = initialKind;

  await showAdaptiveSheet<void>(
    context,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final l10n = AppLocalizations.of(sheetCtx);
          return SheetFrame(
            title: l10n.linkedAccountsScreenCallSheetTitle,
            leading: const SheetCloseButton(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Voice or video as a native segmented control — one
                // decision, two answers, the iOS shape for it.
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<CallMediaKind>(
                    groupValue: kind,
                    backgroundColor: theme.ink.withValues(alpha: 0.08),
                    thumbColor: theme.isLight
                        ? Colors.white
                        : Color.alphaBlend(
                            theme.ink.withValues(alpha: 0.12),
                            theme.surfaceRaised,
                          ),
                    onValueChanged: (k) {
                      if (k == null) return;
                      HapticFeedback.selectionClick();
                      setSheetState(() => kind = k);
                    },
                    children: {
                      for (final (k, icon, label) in [
                        (
                          CallMediaKind.audio,
                          CupertinoIcons.phone_fill,
                          l10n.linkedAccountsScreenCallSheetVoiceLabel,
                        ),
                        (
                          CallMediaKind.video,
                          CupertinoIcons.video_camera_solid,
                          l10n.linkedAccountsScreenCallSheetVideoLabel,
                        ),
                      ])
                        k: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: kind == k ? theme.ink : theme.inkSoft,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                sentenceCaseOf(sheetCtx, label),
                                style: theme.body.copyWith(
                                  fontSize: 14,
                                  fontWeight: kind == k
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: kind == k ? theme.ink : theme.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                    },
                  ),
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
                    GroupedRow(
                      icon: CupertinoIcons.checkmark_circle_fill,
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
            leading: const SheetCloseButton(),
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
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.linkedAccountsScreenCallSheetNoOtherMembers,
                        style: theme.body.copyWith(color: theme.inkMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
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
                            separatorBuilder: (_, _) => Padding(
                              padding: const EdgeInsets.only(left: 66),
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

/// One person in the call picker: face, name, and a round check that springs
/// in when chosen — the Messages "New Group" picker.
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
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return SpringPress(
      onTap: onTap,
      semanticLabel: user.displayName,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        child: Row(
          children: [
            UserAvatar(user: user, api: api, size: 40, showStatus: false),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.displayName,
                style: theme.body.copyWith(fontSize: 17, color: theme.ink),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 26,
              height: 26,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    CupertinoIcons.circle,
                    size: 26,
                    color: theme.inkMuted.withValues(alpha: 0.6),
                  ),
                  AnimatedScale(
                    scale: on ? 1 : 0,
                    duration: motion.d(const Duration(milliseconds: 380)),
                    curve: on ? Curves.elasticOut : Curves.easeIn,
                    child: Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      size: 26,
                      color: theme.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
