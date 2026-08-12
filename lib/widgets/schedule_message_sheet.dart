import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/scheduled_message.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;
import 'schedule_time_picker.dart';

/// When a scheduled message will go out, as a sentence in the reader's
/// language.
///
/// The sibling of `muteDeadlineSentence`, and deliberately the same recipe:
/// the clock comes from [MaterialLocalizations] with the platform's 24-hour
/// preference honoured, the date comes from the same place, and the two are
/// joined by an ARB string rather than by a separator — "August 16 at 8:00 PM"
/// and "16 août à 20:00" do not differ by punctuation alone.
///
/// Three shapes rather than one, because "today at 9:00 PM" and "tomorrow at
/// 9:00 AM" are how people say these, and a bare date for tomorrow makes the
/// reader work out whether that is soon.
String scheduleWhenPhrase(BuildContext context, DateTime at, {DateTime? now}) {
  final l10n = AppLocalizations.of(context);
  final material = MaterialLocalizations.of(context);
  final today = now ?? DateTime.now();
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(at),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  // Compared by calendar date, not by elapsed hours: `difference(...).inDays`
  // answers 0 for something 23 hours away that is nevertheless tomorrow.
  final days = DateTime(at.year, at.month, at.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (days == 0) return l10n.scheduleWhenToday(time);
  if (days == 1) return l10n.scheduleWhenTomorrow(time);
  return l10n.scheduleWhenDated(material.formatMediumDate(at), time);
}

/// What the sheet was opened to do, which decides only its primary button's
/// word — everything else about the two cases is identical.
enum ScheduleSheetMode {
  /// Queue the message currently in the composer.
  create,

  /// Move something already queued to a different time.
  reschedule,
}

/// Opens the schedule sheet and returns the chosen instant, or null if the user
/// backed out.
///
/// Returns rather than applies, unlike `showMuteRoomSheet` — the opposite call
/// on purpose. That sheet is opened from three surfaces that all want the same
/// mutation, so applying inside it keeps the mapping in one place. This one is
/// opened to schedule a NEW message from the composer and to move an EXISTING
/// one from the list, which are different mutations with different failure
/// handling and different things to do with the composer afterwards.
///
/// [preview] is the message being scheduled, shown under the title so the user
/// can see what they are about to commit to a date. Null when rescheduling
/// something the list is already showing them.
Future<DateTime?> showScheduleMessageSheet(
  BuildContext context, {
  ScheduleSheetMode mode = ScheduleSheetMode.create,
  String? preview,
  DateTime? initial,
}) {
  return showAdaptiveSheet<DateTime>(
    context,
    // The picker page is tall enough to reach the status bar on a small phone,
    // and an inner SafeArea would be a silent no-op — see showAdaptiveSheet.
    useSafeArea: true,
    builder: (_) => _ScheduleSheet(
      mode: mode,
      preview: preview,
      initial: initial,
    ),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({
    required this.mode,
    required this.preview,
    required this.initial,
  });

  final ScheduleSheetMode mode;
  final String? preview;
  final DateTime? initial;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  /// The chip currently lit, or null once the custom picker has taken over.
  SchedulePreset? _preset = SchedulePreset.inAnHour;

  /// Whether the sheet is showing the picker rather than its quick choices.
  /// Set in [initState] when the sheet was opened on an existing time.
  bool _picking = false;

  /// The instant the picker is showing. Only meaningful while [_picking].
  late DateTime _custom;

  /// Read once, at the moment the sheet opens.
  ///
  /// Every preset resolves against this rather than against a fresh
  /// `DateTime.now()` per build. Otherwise the running sentence would drift
  /// while the sheet sat open — and worse, "Tomorrow morning" would silently
  /// relabel itself to "This morning" if the sheet happened to be open across
  /// 9am, changing what the lit chip means without the user touching anything.
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    // Clamped on the way in, and this is not belt-and-braces: the picker
    // clamps its own selection to the same window, so a sheet that kept an
    // out-of-range `initial` would show a picker sitting on a legal date while
    // its own summary underneath called that date impossible. Agreeing here
    // means the two can never say different things about the same instant.
    //
    // Reachable in practice from a row scheduled by an older build with a
    // wider horizon, or one whose time has since passed.
    _custom = _clampToWindow(
      widget.initial ?? _openedAt.add(const Duration(hours: 1)),
    );
    // Opened on a message that already has a time — start on the picker,
    // showing that time. Landing on the quick chips instead would light one
    // that is not what the message is currently set to, so the sheet would
    // open by silently proposing to change something the user came here to
    // look at.
    _picking = widget.initial != null;
  }

  /// Pulls [at] into the window the server will accept.
  ///
  /// A minute inside each edge rather than exactly on it: the two bounds are
  /// measured from [_openedAt], and a value sitting precisely on the boundary
  /// would fall outside it again by the time the user finished reading the
  /// sheet.
  DateTime _clampToWindow(DateTime at) {
    final floor = _openedAt.add(kScheduleMinLead + const Duration(minutes: 1));
    final ceiling =
        _openedAt.add(kScheduleMaxHorizon - const Duration(minutes: 1));
    if (at.isBefore(floor)) return floor;
    if (at.isAfter(ceiling)) return ceiling;
    return at;
  }

  /// The instant this sheet would schedule for right now.
  DateTime get _resolved =>
      _picking ? _custom : _preset!.resolve(_openedAt);

  bool get _isValid {
    final at = _resolved;
    return at.isAfter(_openedAt.add(kScheduleMinLead)) &&
        at.isBefore(_openedAt.add(kScheduleMaxHorizon));
  }

  void _pick(SchedulePreset p) {
    HapticFeedback.selectionClick();
    setState(() {
      _preset = p;
      _picking = false;
    });
  }

  void _openPicker() {
    HapticFeedback.selectionClick();
    setState(() {
      // Seeded from whatever chip was lit, so opening the picker continues the
      // choice already made rather than resetting it to now.
      _custom = _resolved;
      _picking = true;
    });
  }

  String _presetLabel(AppLocalizations l10n, SchedulePreset p) => switch (p) {
        SchedulePreset.inAnHour => l10n.schedulePresetInAnHour,
        SchedulePreset.inEightHours => l10n.schedulePresetInEightHours,
        // The wording follows where the next 9am actually falls. See the enum's
        // doc: a chip that says "tomorrow" at 2am is lying about a decision the
        // user is making on the strength of that word.
        SchedulePreset.tomorrowMorning =>
          p.resolve(_openedAt).day == _openedAt.day
              ? l10n.schedulePresetThisMorning
              : l10n.schedulePresetTomorrowMorning,
        SchedulePreset.inAWeek => l10n.schedulePresetInAWeek,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
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
          Text(
            _picking ? l10n.scheduleTimePickerTitle : l10n.scheduleSheetTitle,
            style: theme.label,
          ),
          const SizedBox(height: 8),
          Text(l10n.scheduleSheetSubtitle, style: theme.bodySoft),
          if (widget.preview != null && widget.preview!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _MessagePreview(text: widget.preview!.trim()),
          ],
          const SizedBox(height: 18),
          // One AnimatedSize around both pages so the sheet grows and shrinks
          // instead of jumping. Bottom-aligned for the reason the composer's
          // reply card is: the sheet is anchored to the bottom of the screen,
          // so growth has to happen upward or the whole thing appears to slide.
          AnimatedSize(
            duration: motion.d(theme.motionMed),
            curve: motion.c(theme.motionEntrance),
            alignment: Alignment.bottomCenter,
            child: _picking
                ? ScheduleTimePicker(
                    initial: _custom,
                    onChanged: (at) => setState(() => _custom = at),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.scheduleSheetWhenLabel, style: theme.label),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in SchedulePreset.values)
                            _PresetChip(
                              label: _presetLabel(l10n, p),
                              // The resolved clock time under every label, so
                              // no chip can be read as promising a time it does
                              // not mean.
                              detail: _clockOf(context, p.resolve(_openedAt)),
                              selected: !_picking && _preset == p,
                              onTap: () => _pick(p),
                            ),
                          _PresetChip(
                            label: l10n.scheduleSheetCustomChip,
                            detail: null,
                            selected: false,
                            icon: Icons.calendar_today_outlined,
                            onTap: _openPicker,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          _SummaryPanel(
            theme: theme,
            sentence: l10n.scheduleSendsAtSentence(
              scheduleWhenPhrase(context, _resolved, now: _openedAt),
            ),
            warning: _isValid ? null : l10n.scheduleErrorOutOfRange,
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            label: widget.mode == ScheduleSheetMode.create
                ? l10n.scheduleSheetConfirmButton
                : l10n.scheduleSheetSaveButton,
            onTap: _isValid
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop(_resolved);
                  }
                : null,
          ),
          if (_picking) ...[
            const SizedBox(height: 10),
            _SecondaryButton(
              label: l10n.scheduleTimePickerBack,
              color: theme.inkSoft,
              onTap: () => setState(() => _picking = false),
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

  static String _clockOf(BuildContext context, DateTime at) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(at),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
}

/// The message being scheduled, so the user is committing something they can
/// see rather than something they wrote a moment ago and are trusting.
class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // The accent strip is a SIBLING of the text, not a `BorderSide` on the
    // container — Flutter asserts on a non-uniform border colour the moment a
    // `borderRadius` is involved, and it asserts at PAINT time, so the widget
    // builds fine and only fails once it is on screen. `ComposerReplyCard`
    // draws the same strip the same way and for the same reason; the clip is
    // what rounds the corners.
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radiusMd),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.surfaceRaised,
          border: Border.all(color: theme.divider, width: 0.5),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: theme.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 12, 14, 12),
                  child: Text(
                    text,
                    style: theme.body.copyWith(color: theme.inkSoft),
                    // Two lines is enough to recognise a message without
                    // turning the sheet into a reader; the whole thing is still
                    // in the composer behind it.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

/// One quick choice, with the clock time it resolves to underneath.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return FocusableTap(
      onTap: onTap,
      selected: selected,
      // The clock time goes in the label too: a screen reader hearing only
      // "In 8 hours" gets none of what the sighted user reads underneath it.
      semanticLabel: detail == null ? label : '$label, $detail',
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion.d(theme.motionFast),
          curve: motion.c(theme.motionEntrance),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: theme.chipDecoration(filled: selected),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 13, color: theme.inkSoft),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: theme.label.copyWith(
                      color: selected ? theme.accentInk : theme.inkSoft,
                    ),
                  ),
                ],
              ),
              if (detail != null) ...[
                const SizedBox(height: 3),
                // Excluded because the FocusableTap label above already carries
                // it — a screen reader meeting both reads the time twice.
                ExcludeSemantics(
                  child: Text(
                    detail!,
                    style: theme.monoTiny.copyWith(
                      color: selected
                          ? theme.accentInk.withValues(alpha: 0.72)
                          : theme.inkMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The running sentence: when this goes out, and why it can't if it can't.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.theme,
    required this.sentence,
    required this.warning,
  });

  final AppTheme theme;
  final String sentence;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final bad = warning != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (bad ? theme.danger : theme.accent).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sentence, style: theme.body),
          if (bad) ...[
            const SizedBox(height: 6),
            Text(
              warning!,
              style: theme.monoTiny.copyWith(color: theme.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lifted from `mute_room_sheet.dart` so the two sheets' CTAs are the same
/// object rather than two that resemble each other.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;

  /// Null renders the button disabled — an out-of-range time is a dead button
  /// with the reason stated above it, never a silent no-op.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    return FocusableTap(
      onTap: onTap,
      enabled: enabled,
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
