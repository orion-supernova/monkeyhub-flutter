import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/room_mute.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;

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
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetGrabber(),
          Text(l10n.muteSheetTitle, style: theme.label),
          const SizedBox(height: 8),
          Text(l10n.muteSheetSubtitle, style: theme.bodySoft),
          const SizedBox(height: 18),
          _MuteSwitch(
            icon: CupertinoIcons.bell_slash,
            title: l10n.muteSheetNotificationsTitle,
            sub: l10n.muteSheetNotificationsSub,
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          const SizedBox(height: 10),
          _MuteSwitch(
            icon: CupertinoIcons.number,
            title: l10n.muteSheetBadgesTitle,
            sub: l10n.muteSheetBadgesSub,
            value: _badges,
            onChanged: (v) => setState(() => _badges = v),
          ),
          const SizedBox(height: 22),
          Text(l10n.muteSheetDurationLabel, style: theme.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in MuteDuration.values)
                _DurationChip(
                  label: _durationLabel(l10n, d),
                  selected: _duration == d,
                  onTap: () => setState(() => _duration = d),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryPanel(
            theme: theme,
            summary: _summary(l10n),
            // Suppressed while nothing is picked: "Until 8:00 PM" under "pick
            // something to silence" is a deadline for a mute that doesn't
            // exist yet, and reads as though the sheet has already committed.
            deadline: _anythingPicked
                ? muteDeadlineSentence(context, until: _previewUntil)
                : null,
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            label: _wasMuted
                ? l10n.muteSheetSaveButton
                : l10n.muteSheetConfirmButton,
            // Both switches off is not a mute. Rather than silently converting
            // it to an unmute — which would make the same button mean opposite
            // things depending on state the user can't see — the button goes
            // dead and the running sentence says why. UNMUTE below is the
            // deliberate way out.
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
            _SecondaryButton(
              label: l10n.muteSheetUnmuteButton,
              color: theme.danger,
              onTap: () => Navigator.of(context).pop(const _MuteLifted()),
            ),
          ],
          const SizedBox(height: 4),
          _SecondaryButton(
            label: l10n.destructiveSheetCancelButtonLabel,
            color: theme.inkMuted,
            bordered: false,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
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

/// One of the two things that can be silenced.
///
/// A whole tappable row rather than a bare [Switch], so the sub-line — which is
/// where the difference between the two switches actually lives — is part of
/// the target instead of decoration beside it.
class _MuteSwitch extends StatelessWidget {
  const _MuteSwitch({
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // With the tap a native switch gives; `Switch.adaptive` has none.
    void flip(bool v) {
      HapticFeedback.lightImpact();
      onChanged(v);
    }

    void toggle() => flip(!value);
    return FocusableTap(
      onTap: toggle,
      semanticLabel: title,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: value ? theme.accentSoft : theme.surface,
            border: Border.all(
              color: value ? theme.accent.withValues(alpha: 0.55) : theme.divider,
            ),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: value ? theme.accent : theme.inkMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.label.copyWith(
                        color: value ? theme.accent : theme.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(sub, style: theme.monoTiny),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Excluded from semantics: the row already announces itself and
              // its state through [FocusableTap], and a screen reader meeting
              // both would read the same switch twice.
              ExcludeSemantics(
                child: Switch.adaptive(
                  value: value,
                  onChanged: flip,
                  activeThumbColor: theme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One duration preset. Same chip treatment as the room info screen's
/// message-life row, so "how long until this changes back" looks like one idea
/// across the app.
class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: theme.chipDecoration(filled: selected),
          child: Text(
            label,
            style: theme.label.copyWith(
              color: selected ? theme.accentInk : theme.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// The running sentence: what this combination does, and when it stops.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.theme,
    required this.summary,
    required this.deadline,
  });

  final AppTheme theme;
  final String summary;
  final String? deadline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, style: theme.body),
          if (deadline != null) ...[
            const SizedBox(height: 6),
            Text(deadline!, style: theme.monoTiny.copyWith(color: theme.accent)),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;

  /// Null renders the button disabled — see the call site for why "nothing
  /// picked" is a dead button rather than a hidden unmute.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    return FocusableTap(
      onTap: onTap ?? () {},
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? theme.accent : theme.accentSoft,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.label.copyWith(
              color: enabled ? theme.accentInk : theme.inkMuted,
              letterSpacing: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bordered = true,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: bordered
                ? Border.all(color: color.withValues(alpha: 0.55), width: 1.2)
                : null,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.label.copyWith(color: color, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
