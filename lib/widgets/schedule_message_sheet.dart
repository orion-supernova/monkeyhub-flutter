import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/scheduled_message.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'schedule_time_picker.dart';
import 'sheet_kit.dart';

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

/// What the schedule sheet was closed with.
///
/// A sealed result rather than a bare `DateTime?`, following the
/// `showMuteRoomSheet` precedent: the sheet now has two ways to succeed, and
/// distinguishing them by "null means cancelled, non-null means scheduled"
/// stops working the moment there is a third outcome.
sealed class ScheduleChoice {
  const ScheduleChoice();
}

/// Queue the message for this instant.
class ScheduleAt extends ScheduleChoice {
  const ScheduleAt(this.at);
  final DateTime at;
}

/// Never mind the new message — show me the ones already waiting.
///
/// This is the ONLY route to the queued list when the pill is switched off, so
/// it is not a convenience: without it, choosing "badge" strands both the list
/// and the setting that would bring the pill back, because the badge cannot be
/// tapped (tapping the send button sends).
class ScheduleShowQueued extends ScheduleChoice {
  const ScheduleShowQueued();
}

/// Opens the schedule sheet and returns what the user chose, or null if they
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
/// can see what they are about to commit to a date.
Future<ScheduleChoice?> showScheduleMessageSheet(
  BuildContext context, {
  ScheduleSheetMode mode = ScheduleSheetMode.create,
  String? preview,
  DateTime? initial,

  /// How many messages this room already has waiting. Drives the row that
  /// opens the queue; only consulted in [ScheduleSheetMode.create], because
  /// rescheduling is reached FROM that list and offering a way back into it
  /// would be a loop.
  int queuedCount = 0,
}) {
  return showAdaptiveSheet<ScheduleChoice>(
    context,
    // The calendar page is tall enough to reach the status bar on a small
    // phone, and an inner SafeArea would be a silent no-op — see
    // showAdaptiveSheet.
    useSafeArea: true,
    builder: (_) => _ScheduleSheet(
      mode: mode,
      preview: preview,
      initial: initial,
      queuedCount: queuedCount,
    ),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({
    required this.mode,
    required this.preview,
    required this.initial,
    required this.queuedCount,
  });

  final ScheduleSheetMode mode;
  final String? preview;
  final DateTime? initial;
  final int queuedCount;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  /// The lit quick choice. Non-null always: the picker page does not clear it,
  /// it simply stops being what [_resolved] reads.
  SchedulePreset _preset = SchedulePreset.inAnHour;

  /// Whether [_preset] is the user's choice or only the default lit row.
  /// Decides where the calendar opens — see [_openPicker].
  bool _presetChosen = false;

  /// Whether the sheet is showing the calendar rather than its quick choices.
  bool _picking = false;

  /// The instant the calendar is showing. Only meaningful while [_picking].
  late DateTime _custom;

  /// Read once, at the moment the sheet opens.
  ///
  /// Every preset resolves against this rather than against a fresh
  /// `DateTime.now()` per build. Otherwise the running sentence would drift
  /// while the sheet sat open — and worse, "Tomorrow morning" would silently
  /// relabel itself to "This morning" if the sheet happened to be open across
  /// 9am, changing what the lit row means without the user touching anything.
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    // Clamped on the way in, and this is not belt-and-braces: the calendar
    // clamps its own selection to the same window, so a sheet that kept an
    // out-of-range `initial` would show a picker sitting on a legal date while
    // its own summary underneath called that date impossible.
    _custom = _clampToWindow(
      widget.initial ?? _openedAt.add(const Duration(hours: 1)),
    );
    // Opened on a message that already has a time — start on the calendar,
    // showing that time. Landing on the quick choices instead would light one
    // that is not what the message is currently set to.
    _picking = widget.initial != null;
  }

  /// Pulls [at] into the window the server will accept.
  ///
  /// A minute inside each edge rather than exactly on it: the two bounds are
  /// measured from [_openedAt], and a value sitting precisely on the boundary
  /// would fall outside it again by the time the user finished reading.
  DateTime _clampToWindow(DateTime at) {
    final floor = _openedAt.add(kScheduleMinLead + const Duration(minutes: 1));
    final ceiling =
        _openedAt.add(kScheduleMaxHorizon - const Duration(minutes: 1));
    if (at.isBefore(floor)) return floor;
    if (at.isAfter(ceiling)) return ceiling;
    return at;
  }

  /// The instant this sheet would schedule for right now.
  DateTime get _resolved => _picking ? _custom : _preset.resolve(_openedAt);

  bool get _isValid {
    final at = _resolved;
    return at.isAfter(_openedAt.add(kScheduleMinLead)) &&
        at.isBefore(_openedAt.add(kScheduleMaxHorizon));
  }

  void _pick(SchedulePreset p) {
    HapticFeedback.selectionClick();
    setState(() {
      _preset = p;
      _presetChosen = true;
      _picking = false;
    });
  }

  void _openPicker() {
    HapticFeedback.selectionClick();
    setState(() {
      // A row the user actually tapped is a choice, and the calendar continues
      // it rather than resetting it. The row that is merely lit by default is
      // not — opening the calendar from there opens on NOW: today's page, the
      // current hour, the first minute that can still be scheduled. Starting
      // an hour ahead made every "in twenty minutes" a matter of winding the
      // clock backwards first.
      _custom = _presetChosen ? _resolved : _clampToWindow(DateTime.now());
      _picking = true;
    });
  }

  String _presetLabel(AppLocalizations l10n, SchedulePreset p) => switch (p) {
        SchedulePreset.inAnHour => l10n.schedulePresetInAnHour,
        SchedulePreset.inEightHours => l10n.schedulePresetInEightHours,
        // The wording follows where the next 9am actually falls. See the enum's
        // doc: a row that says "tomorrow" at 2am is lying about a decision the
        // user is making on the strength of that word.
        SchedulePreset.tomorrowMorning =>
          p.resolve(_openedAt).day == _openedAt.day
              ? l10n.schedulePresetThisMorning
              : l10n.schedulePresetTomorrowMorning,
        SchedulePreset.inAWeek => l10n.schedulePresetInAWeek,
      };

  static (IconData, TileTone) _presetGlyph(SchedulePreset p) => switch (p) {
        SchedulePreset.inAnHour => (CupertinoIcons.clock_fill, TileTone.blue),
        SchedulePreset.inEightHours => (CupertinoIcons.moon_fill, TileTone.indigo),
        SchedulePreset.tomorrowMorning => (
          CupertinoIcons.sunrise_fill,
          TileTone.orange,
        ),
        SchedulePreset.inAWeek => (CupertinoIcons.calendar, TileTone.red),
      };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final preview = widget.preview?.trim();
    // Bounded and scrollable, because this sheet can genuinely be taller than
    // the window: a preview, the queue row, five choices or a calendar with
    // its wheels, the sentence and the button. A short phone in a 12-hour
    // locale (which adds the AM/PM wheel) is the worst case. The bound also
    // keeps this safe inside the desktop popover, which wraps sheet content
    // in a scroll view of its own.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: SheetFrame(
        title: sentenceCaseOf(
          context,
          _picking ? l10n.scheduleTimePickerTitle : l10n.scheduleSheetTitle,
        ),
        // Cancel at the top left, always — the iOS sheet's own escape, so it
        // is there on the calendar page as much as on the quick choices.
        leading: _TextAction(
          label: sentenceCaseOf(context, l10n.destructiveSheetCancelButtonLabel),
          onTap: () => Navigator.of(context).pop(),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.scheduleSheetSubtitle,
                textAlign: TextAlign.center,
                style: theme.bodySoft.copyWith(color: theme.inkMuted),
              ),
              if (preview != null && preview.isNotEmpty) ...[
                const SizedBox(height: 14),
                _MessagePreview(text: preview),
              ],
              // Shown even at zero, and that is the point: this is the only
              // way into the queue when the pill is off, so it also has to be
              // the way BACK to the setting that turns the pill on. Hiding it
              // on an empty queue would make that a one-way door.
              if (widget.mode == ScheduleSheetMode.create && !_picking) ...[
                const SizedBox(height: 16),
                SheetGroup(
                  children: [
                    GroupedRow(
                      icon: CupertinoIcons.tray_full_fill,
                      tone: TileTone.gray,
                      title: l10n.scheduleSheetQueuedRow(widget.queuedCount),
                      onTap: () => Navigator.of(context)
                          .pop(const ScheduleShowQueued()),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              // One AnimatedSize around both pages so the sheet grows and
              // shrinks instead of jumping. Bottom-aligned: the sheet is
              // anchored to the bottom of the screen, so growth has to happen
              // upward or the whole thing appears to slide.
              AnimatedSize(
                duration: motion.d(theme.motionMed),
                curve: motion.c(theme.motionEntrance),
                alignment: Alignment.bottomCenter,
                child: _picking
                    ? Column(
                        key: const ValueKey('picker'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TextAction(
                            label: l10n.scheduleTimePickerBack,
                            leadingIcon: CupertinoIcons.chevron_back,
                            onTap: () => setState(() => _picking = false),
                          ),
                          const SizedBox(height: 8),
                          ScheduleTimePicker(
                            initial: _custom,
                            onChanged: (at) => setState(() => _custom = at),
                          ),
                        ],
                      )
                    : SheetRise(child: _buildPresets(theme, l10n)),
              ),
              const SizedBox(height: 14),
              _Summary(
                theme: theme,
                motion: motion,
                sentence: l10n.scheduleSendsAtSentence(
                  scheduleWhenPhrase(context, _resolved, now: _openedAt),
                ),
                warning: _isValid ? null : l10n.scheduleErrorOutOfRange,
              ),
              const SizedBox(height: 18),
              SheetActionButton(
                label: widget.mode == ScheduleSheetMode.create
                    ? l10n.scheduleSheetConfirmButton
                    : l10n.scheduleSheetSaveButton,
                onTap: _isValid
                    ? () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop(ScheduleAt(_resolved));
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The quick choices, as one grouped block: a coloured glyph, the choice in
  /// words, the clock time it lands on against one right edge, and a check
  /// that springs onto the chosen row. The last row opens the calendar.
  Widget _buildPresets(AppTheme theme, AppLocalizations l10n) {
    return SheetGroup(
      key: const ValueKey('presets'),
      header: l10n.scheduleSheetWhenLabel,
      children: [
        for (final p in SchedulePreset.values)
          GroupedRow(
            icon: _presetGlyph(p).$1,
            tone: _presetGlyph(p).$2,
            title: _presetLabel(l10n, p),
            value: _clockOf(context, p.resolve(_openedAt)),
            chevron: false,
            trailing: _Check(selected: !_picking && _preset == p),
            onTap: () => _pick(p),
          ),
        GroupedRow(
          icon: CupertinoIcons.calendar_badge_plus,
          tone: TileTone.gray,
          title: l10n.scheduleSheetCustomChip,
          onTap: _openPicker,
        ),
      ],
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
    // draws the same strip the same way and for the same reason.
    return ClipRRect(
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: sheetGroupFill(theme)),
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

/// The running sentence: when this goes out, and why it can't if it can't.
/// Plain footnote text under the choices — no panel, no tint — the way iOS
/// explains a setting beneath it.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.theme,
    required this.motion,
    required this.sentence,
    required this.warning,
  });

  final AppTheme theme;
  final MotionScope motion;
  final String sentence;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final bad = warning != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The sentence slides up and out as the new one slides in, so the
          // time visibly CHANGES rather than silently being different. Keyed
          // on the text, which is what makes the switcher fire at all.
          // ClipRect and a non-overshooting curve, both load-bearing: the
          // outgoing line would otherwise paint outside its box.
          ClipRect(
            child: AnimatedSwitcher(
              duration: motion.d(theme.motionFast),
              switchInCurve: motion.c(theme.motionEntrance),
              switchOutCurve: motion.c(Curves.easeInCubic),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                sentence,
                key: ValueKey(sentence),
                style: theme.bodySoft.copyWith(
                  fontSize: 15,
                  color: bad ? theme.inkMuted : theme.inkSoft,
                ),
              ),
            ),
          ),
          if (bad) ...[
            const SizedBox(height: 4),
            Text(
              warning!,
              style: theme.bodySoft.copyWith(
                fontSize: 13,
                color: theme.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A text button in the sheet's bar or above the calendar, in the accent —
/// the iOS "Cancel" / "‹ Back".
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onTap,
    this.leadingIcon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 17, color: theme.accent),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: theme.body.copyWith(fontSize: 17, color: theme.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// The check that springs onto the chosen quick choice. Its width is kept
/// when hidden so the clock beside it never shifts as the choice moves.
class _Check extends StatelessWidget {
  const _Check({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return SizedBox(
      width: 20,
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: motion.d(const Duration(milliseconds: 380)),
        curve: selected ? Curves.elasticOut : Curves.easeIn,
        child: Icon(CupertinoIcons.checkmark_alt, size: 20, color: theme.accent),
      ),
    );
  }
}
