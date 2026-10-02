import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/room_mute.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import '../theme/theme_preference.dart';
import 'sheet_kit.dart';
import 'ios_kit.dart';

/// The deadline of a mute, as a sentence in the viewer's language.
///
/// [until] null means "always" — [RoomMute.until] returns null for the
/// sentinel deliberately, so the two callers of this (the sheet's live preview
/// and the room info screen's stored state) both land on the right sentence
/// without either of them knowing what the sentinel is.
///
/// Never string-concatenated and never a raw timestamp. "8:00 PM" vs "20:00"
/// is a per-user setting, not a per-locale one, so the clock comes from
/// [MaterialLocalizations] with the platform's 24-hour preference honoured; the
/// date comes from the same place; and joining them is an ARB string, because
/// "August 16, 8:00 PM" and "16 août à 20:00" do not differ by a separator
/// alone.
String muteDeadlineSentence(BuildContext context, {required DateTime? until}) {
  final l10n = AppLocalizations.of(context);
  if (until == null) return l10n.muteUntilAlwaysSentence;
  final material = MaterialLocalizations.of(context);
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(until),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final now = DateTime.now();
  // A deadline later today is a time; anything further out needs the day, or
  // "until 9:00" on a Tuesday reads as nine hours from now rather than six
  // days. The 1-week option makes this the common case, not an edge one.
  final sameDay =
      until.year == now.year && until.month == now.month && until.day == now.day;
  return l10n.muteUntilSentence(
    sameDay
        ? time
        : l10n.muteUntilDateAndTime(material.formatMediumDate(until), time),
  );
}

/// Open the mute sheet for [room] and apply whatever the user chose.
///
/// Applies rather than returning, unlike `showChatRowActionMenu`, because
/// three surfaces open this — the chat-list long-press, the archived-chats
/// sheet and the room info screen — and the mapping from "what the user picked"
/// to "which mutation" is the same at all three. Returning a result would put
/// that mapping in three places and give it three chances to drift.
///
/// Does nothing at all when [RoomCapabilities.canMute] is false for this room;
/// callers already hide the entry points, and this is the backstop.
Future<void> showMuteRoomSheet(
  BuildContext context, {
  required ChatRepository repo,
  required ChatRoom room,
}) async {
  final result = await showAdaptiveSheet<_MuteResult>(
    context,
    builder: (_) => _MuteRoomSheet(mute: room.mute),
  );
  switch (result) {
    case null:
      return;
    case _MuteLifted():
      await repo.unmuteRoom(room.id);
    case _MuteApplied(
        :final notifications,
        :final badges,
        :final duration,
      ):
      await repo.muteRoom(
        room.id,
        notifications: notifications,
        badges: badges,
        duration: duration,
      );
  }
}

sealed class _MuteResult {
  const _MuteResult();
}

class _MuteApplied extends _MuteResult {
  const _MuteApplied({
    required this.notifications,
    required this.badges,
    required this.duration,
  });
  final bool notifications;
  final bool badges;
  final MuteDuration duration;
}

class _MuteLifted extends _MuteResult {
  const _MuteLifted();
}

/// Two switches and a clock.
///
/// The hard part of this sheet is not the controls, it's making the
/// COMBINATION legible. Two independent switches produce four states, three of
/// which are meaningfully different, and a user who ticks one box has no way to
/// know from the box itself what the other one would have changed. So the sheet
/// keeps a running sentence at the bottom that says, in plain words, what the
/// current selection will actually do — "No notifications. The unread count
/// keeps climbing." — plus a second line naming when it ends. Everything above
/// is a way to edit that sentence.
///
/// That is also why this is not two menu items ("Mute notifications" / "Mute
/// everything"), which was the obvious cheaper design: a menu forces the two
/// switches into a ladder, and they genuinely aren't one. Hiding an unread
/// count while letting notifications through is a real thing people want from a
/// busy room they check on their own schedule, and a ladder cannot express it.
class _MuteRoomSheet extends StatefulWidget {
  const _MuteRoomSheet({required this.mute});

  /// The room's current mute, so re-opening the sheet on an already-muted room
  /// starts from what is in force rather than from a blank form. Editing a
  /// mute and re-muting are the same gesture here, which is what makes
  /// "extend it by another hour" a two-tap operation.
  final RoomMute mute;

  @override
  State<_MuteRoomSheet> createState() => _MuteRoomSheetState();
}

class _MuteRoomSheetState extends State<_MuteRoomSheet> {
  late bool _notifications;
  late bool _badges;
  late MuteDuration _duration;

  /// Whether the room was ALREADY muted when the sheet opened — which changes
  /// the primary button's word and earns the sheet an UNMUTE row. Captured
  /// once rather than re-derived, since the switches below are about to stop
  /// describing the stored state.
  late final bool _wasMuted;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _wasMuted = widget.mute.isLiveAt(now);
    // Notifications-only is the default for a fresh mute: it is what most
    // people mean by "mute", and the stronger switch is one tap away rather
    // than pre-selected on their behalf.
    _notifications = _wasMuted ? widget.mute.notifications : true;
    _badges = _wasMuted && widget.mute.badges;
    // A live mute's remaining time is not one of the four presets, so there is
    // nothing honest to pre-select from it except "always", which IS one.
    // Everything else starts the clock again from the chosen preset — stated
    // by the running sentence, so nobody has to infer it.
    _duration = _wasMuted && widget.mute.isAlways
        ? MuteDuration.always
        : MuteDuration.hour;
  }

  bool get _anythingPicked => _notifications || _badges;

  /// When the mute being composed would end, or null for "always".
  ///
  /// Computed from this device's clock purely to show the user what they are
  /// about to get. The instant that actually lands in the database is the
  /// server's own `Date.now() + durationMs` (see `rooms.muteRoom`), which is
  /// the whole reason the mutation takes a length rather than this value: a
  /// preview that is a few seconds out is fine, a stored deadline that is
  /// minutes out because a phone's clock drifted is not.
  DateTime? get _previewUntil {
    final span = _duration.span;
    return span == null ? null : DateTime.now().add(span);
  }

  String _summary(AppLocalizations l10n) {
    if (!_anythingPicked) return l10n.muteSummaryNothingPicked;
    if (_notifications && _badges) return l10n.muteSummaryAll;
    return _badges
        ? l10n.muteSummaryBadgesOnly
        : l10n.muteSummaryNotificationsOnly;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final deadline = _anythingPicked
        ? muteDeadlineSentence(context, until: _previewUntil)
        : null;
    // With the tap a native switch gives; `Switch.adaptive` has none.
    void flip(void Function() apply) {
      HapticFeedback.lightImpact();
      setState(apply);
    }

    // The iOS settings sheet: what goes quiet as a grouped pair of switches,
    // for how long as a segmented control, the running sentence as the
    // footnote under it, and one button. The × in the bar is the way out.
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.muteSheetTitle),
      leading: const SheetCloseButton(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Text(
                l10n.muteSheetSubtitle,
                textAlign: TextAlign.center,
                style: theme.body.copyWith(
                  fontSize: 15,
                  color: theme.inkMuted,
                ),
              ),
            ),
            SheetRise(
              child: SheetGroup(
                children: [
                  GroupedRow.toggle(
                    icon: CupertinoIcons.bell_slash_fill,
                    tone: TileTone.indigo,
                    title: l10n.muteSheetNotificationsTitle,
                    subtitle: l10n.muteSheetNotificationsSub,
                    value: _notifications,
                    onChanged: (v) => flip(() => _notifications = v),
                  ),
                  GroupedRow.toggle(
                    icon: CupertinoIcons.number,
                    tone: TileTone.gray,
                    title: l10n.muteSheetBadgesTitle,
                    subtitle: l10n.muteSheetBadgesSub,
                    value: _badges,
                    onChanged: (v) => flip(() => _badges = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                sentenceCaseOf(context, l10n.muteSheetDurationLabel),
                style: theme.caption.copyWith(
                  fontSize: 13,
                  color: theme.inkMuted,
                ),
              ),
            ),
            SheetRise(
              index: 1,
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<MuteDuration>(
                  groupValue: _duration,
                  backgroundColor: theme.ink.withValues(alpha: 0.08),
                  thumbColor: theme.isLight
                      ? Colors.white
                      : Color.alphaBlend(
                          theme.ink.withValues(alpha: 0.12),
                          theme.surfaceRaised,
                        ),
                  onValueChanged: (d) {
                    if (d == null) return;
                    HapticFeedback.selectionClick();
                    setState(() => _duration = d);
                  },
                  children: {
                    for (final d in MuteDuration.values)
                      d: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _durationLabel(l10n, d),
                          maxLines: 1,
                          style: theme.body.copyWith(
                            fontSize: 14,
                            fontWeight: _duration == d
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: _duration == d ? theme.ink : theme.inkSoft,
                          ),
                        ),
                      ),
                  },
                ),
              ),
            ),
            // The running sentence: what this combination does, and when it
            // stops. The deadline is suppressed while nothing is picked —
            // "Until 8:00 PM" under "pick something to silence" reads as
            // though the sheet had already committed.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
              child: AnimatedSwitcher(
                duration: theme.motionFast,
                child: Text(
                  deadline == null
                      ? _summary(l10n)
                      : '${_summary(l10n)} $deadline',
                  key: ValueKey('$_notifications$_badges$_duration'),
                  style: theme.caption.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    color: theme.inkMuted,
                  ),
                ),
              ),
            ),
            SheetActionButton(
              label: _wasMuted
                  ? l10n.muteSheetSaveButton
                  : l10n.muteSheetConfirmButton,
              // Both switches off is not a mute. Rather than silently
              // converting it to an unmute — which would make the same button
              // mean opposite things depending on state the user can't see —
              // the button goes dead and the running sentence says why.
              onTap: _anythingPicked
                  ? () => Navigator.of(context).pop(
                        _MuteApplied(
                          notifications: _notifications,
                          badges: _badges,
                          duration: _duration,
                        ),
                      )
                  : null,
            ),
            if (_wasMuted) ...[
              const SizedBox(height: 10),
              SheetActionButton(
                label: l10n.muteSheetUnmuteButton,
                tonal: true,
                destructive: true,
                onTap: () => Navigator.of(context).pop(const _MuteLifted()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _durationLabel(AppLocalizations l10n, MuteDuration d) =>
      switch (d) {
        MuteDuration.hour => l10n.muteDurationHour,
        MuteDuration.eightHours => l10n.muteDurationEightHours,
        MuteDuration.week => l10n.muteDurationWeek,
        MuteDuration.always => l10n.muteDurationAlways,
      };
}

