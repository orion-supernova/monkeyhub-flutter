import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/scheduled_message.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// Height of the day strip. Fixed so the sheet's height does not depend on
/// which card is selected.
const double _kRailHeight = 74;

/// Height of one row in the time wheels, and how many rows are visible. The
/// wheel shows the selected row plus one either side — enough to read as a
/// wheel rather than a text field, and short enough that the whole picker still
/// fits above a keyboard-less sheet on a small phone.
const double _kWheelRow = 38;
const int _kWheelVisibleRows = 3;

/// Minute granularity. Five is the coarsest step nobody notices missing and the
/// finest anyone actually wants — a 60-row wheel is a scroll, not a choice.
const int _kMinuteStep = 5;

/// A date and a time, chosen with the app's own controls.
///
/// ## Why this is hand-rolled
///
/// Flutter ships `showDatePicker` and `showTimePicker`, and using them here was
/// the obvious move. It is also the wrong one: this app has no `ThemeData` at
/// all — every surface is drawn from [AppTheme]'s own tokens (see
/// `lib/theme/app_theme.dart`), and there is not one Material dialog anywhere
/// in `lib/`. Dropping two of them into the middle of a glass sheet would put
/// a differently-shaped, differently-coloured, differently-animated control in
/// front of the user at the exact moment they are making the feature's only
/// real decision.
///
/// What Material is still used for is the part nobody should re-derive:
/// [MaterialLocalizations] supplies the weekday abbreviations, the month names,
/// the date format and the 12/24-hour clock for all twelve locales, so no
/// string in here is assembled by hand and `intl` is not imported. That is the
/// same division `muteDeadlineSentence` already draws.
///
/// ## The two halves
///
/// A horizontal **day strip**, built lazily over the whole allowed range, and
/// two (or three) **time wheels**. They are separate because the questions are
/// different sizes: picking a day out of 366 is a scan, picking an hour out of
/// 24 is a flick. A single wheel-per-field date picker makes "next Tuesday" a
/// three-wheel arithmetic problem, which is exactly what the quick presets on
/// the previous page exist to avoid needing.
class ScheduleTimePicker extends StatefulWidget {
  const ScheduleTimePicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  /// Where the picker opens. Clamped into the allowed window on the way in, so
  /// a caller may hand it "now" without doing the arithmetic.
  final DateTime initial;

  /// Fires on every change with the currently-selected instant — never with one
  /// outside the window, so the sheet's confirm button can trust it.
  final ValueChanged<DateTime> onChanged;

  @override
  State<ScheduleTimePicker> createState() => _ScheduleTimePickerState();
}

class _ScheduleTimePickerState extends State<ScheduleTimePicker> {
  /// Midnight today, in local time. The day strip's origin, and the only place
  /// "now" is read — everything else is arithmetic from here, so the picker
  /// cannot drift mid-interaction if the minute rolls over.
  late final DateTime _today;

  /// The earliest instant that may be selected, and the latest.
  late final DateTime _floor;
  late final DateTime _ceiling;

  late int _dayOffset;
  late int _hour;
  late int _minute;

  late final ScrollController _rail;

  /// Not `final`: in a 12-hour locale the hour wheel counts 1..12 rather than
  /// 0..23, so it is rebuilt once in `didChangeDependencies` — the first place
  /// `MediaQuery.alwaysUse24HourFormatOf` can be read.
  late FixedExtentScrollController _hours;
  late final FixedExtentScrollController _minutes;

  /// Only built in 12-hour locales; null elsewhere. See [_use24Hour].
  FixedExtentScrollController? _meridiem;

  /// Resolved in `didChangeDependencies`, because it comes from `MediaQuery`.
  bool _use24Hour = true;
  bool _wheelsBuilt = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _floor = now.add(kScheduleMinLead);
    _ceiling = now.add(kScheduleMaxHorizon);

    // Snap the incoming instant onto the minute grid before anything reads it,
    // so the wheel's selected row and the value handed back can never disagree
    // — a picker that says 9:00 and schedules 9:02 is worse than one that
    // refuses to open there.
    final start = _clamp(_snap(widget.initial));
    _dayOffset = _offsetOf(start);
    _hour = start.hour;
    _minute = start.minute;

    _rail = ScrollController();
    _hours = FixedExtentScrollController(initialItem: _hour);
    _minutes = FixedExtentScrollController(initialItem: _minute ~/ _kMinuteStep);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    if (!_wheelsBuilt) {
      _wheelsBuilt = true;
      if (!_use24Hour) {
        _meridiem = FixedExtentScrollController(initialItem: _hour < 12 ? 0 : 1);
        // The hour wheel counts 1..12 in this mode, so its row is not the hour.
        _hours.dispose();
        _hours = FixedExtentScrollController(initialItem: _hour12Index(_hour));
      }
      // Centre the selected day once the strip has a width to scroll within.
      WidgetsBinding.instance.addPostFrameCallback((_) => _centreRail());
    }
  }

  @override
  void dispose() {
    _rail.dispose();
    _hours.dispose();
    _minutes.dispose();
    _meridiem?.dispose();
    super.dispose();
  }

  // ── Arithmetic ────────────────────────────────────────────────────────────

  /// Days between [_today] and [d], by calendar date rather than by elapsed
  /// hours — `difference(...).inDays` truncates, so it answers 0 for "23 hours
  /// from now" even when that is tomorrow, and it answers wrong across a DST
  /// boundary in either direction.
  int _offsetOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(_today).inDays;

  DateTime _dayAt(int offset) =>
      DateTime(_today.year, _today.month, _today.day + offset);

  /// The instant currently described by the three controls.
  DateTime get _selected {
    final day = _dayAt(_dayOffset);
    return DateTime(day.year, day.month, day.day, _hour, _minute);
  }

  /// Rounds down onto the [_kMinuteStep] grid the minute wheel offers.
  DateTime _snap(DateTime d) => DateTime(
        d.year,
        d.month,
        d.day,
        d.hour,
        (d.minute ~/ _kMinuteStep) * _kMinuteStep,
      );

  DateTime _clamp(DateTime d) {
    if (d.isBefore(_floor)) {
      // Up to the next whole step, not to the floor itself — landing the wheel
      // between two of its own rows would leave it showing a minute it cannot
      // be scrolled back to.
      final snapped = _snap(_floor);
      return snapped.isBefore(_floor)
          ? snapped.add(const Duration(minutes: _kMinuteStep))
          : snapped;
    }
    if (d.isAfter(_ceiling)) return _snap(_ceiling);
    return d;
  }

  /// The last day the strip offers. Inclusive.
  int get _maxOffset => _offsetOf(_ceiling);

  /// Whether [offset]'s day has any selectable time left in it. Only ever false
  /// for today, and only after [_ceiling] minus a couple of minutes — but the
  /// strip must not offer a card whose every hour is in the past.
  bool _dayIsSelectable(int offset) {
    final day = _dayAt(offset);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59);
    return !endOfDay.isBefore(_floor);
  }

  int _hour12Index(int hour24) {
    final h = hour24 % 12;
    return h == 0 ? 11 : h - 1; // rows are 12, 1, 2 … 11 → index 11 is noon/12
  }

  int _hour24From(int row, bool pm) {
    final display = row == 11 ? 12 : row + 1;
    if (!pm) return display == 12 ? 0 : display;
    return display == 12 ? 12 : display + 12;
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  /// Applies a change, pulling it back into the window if it fell out.
  ///
  /// The correction is the interesting part: scrolling the hour wheel to 8am on
  /// a strip sitting on *today* at 9am names an instant in the past. Rather
  /// than refusing the scroll — which fights the finger and reads as a broken
  /// wheel — the whole selection moves to the nearest legal instant and the
  /// wheels are animated to follow it, so what the user sees always matches
  /// what the sheet will schedule.
  void _apply({int? dayOffset, int? hour, int? minute}) {
    setState(() {
      _dayOffset = dayOffset ?? _dayOffset;
      _hour = hour ?? _hour;
      _minute = minute ?? _minute;
    });
    final corrected = _clamp(_selected);
    if (corrected != _selected) {
      setState(() {
        _dayOffset = _offsetOf(corrected);
        _hour = corrected.hour;
        _minute = corrected.minute;
      });
      _syncWheels();
      _centreRail();
    }
    HapticFeedback.selectionClick();
    widget.onChanged(_selected);
  }

  void _syncWheels() {
    final motion = MotionScope.of(context);
    final theme = ThemeScope.of(context);
    final duration = motion.d(theme.motionFast);
    void go(FixedExtentScrollController c, int item) {
      if (!c.hasClients || c.selectedItem == item) return;
      if (duration == Duration.zero) {
        c.jumpToItem(item);
      } else {
        c.animateToItem(item, duration: duration, curve: motion.c(theme.motionEntrance));
      }
    }

    go(_hours, _use24Hour ? _hour : _hour12Index(_hour));
    go(_minutes, _minute ~/ _kMinuteStep);
    final m = _meridiem;
    if (m != null) go(m, _hour < 12 ? 0 : 1);
  }

  /// Brings the selected day card into view, roughly centred.
  void _centreRail() {
    if (!_rail.hasClients) return;
    const cardStride = 62.0; // card width + gap; see _DayCard
    final viewport = _rail.position.viewportDimension;
    final target = (_dayOffset * cardStride) - (viewport / 2) + (cardStride / 2);
    final motion = MotionScope.of(context);
    final theme = ThemeScope.of(context);
    final clamped = target.clamp(
      _rail.position.minScrollExtent,
      _rail.position.maxScrollExtent,
    );
    final duration = motion.d(theme.motionMed);
    if (duration == Duration.zero) {
      _rail.jumpTo(clamped);
    } else {
      _rail.animateTo(
        clamped,
        duration: duration,
        curve: motion.c(theme.motionEntrance),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ONE month heading for the whole strip, following the selection.
        //
        // Not a divider card inside the rail, which is where this started: the
        // label is far wider than a 56pt day card, so it stretched that card's
        // column and shunted the first day out of alignment with every other
        // one. A heading cannot do that, and it is legible at a glance rather
        // than only when the right card happens to be on screen.
        Text(
          MaterialLocalizations.of(context)
              .formatMonthYear(_dayAt(_dayOffset))
              .toUpperCase(),
          style: theme.monoTiny.copyWith(color: theme.inkMuted),
        ),
        const SizedBox(height: 8),
        SizedBox(height: _kRailHeight, child: _buildRail(theme)),
        const SizedBox(height: 14),
        _buildWheels(theme),
      ],
    );
  }

  Widget _buildRail(AppTheme theme) {
    final material = MaterialLocalizations.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView.builder(
      controller: _rail,
      scrollDirection: Axis.horizontal,
      // Lazy, because the range is 366 cards and all but a handful are off
      // screen for the whole life of the sheet.
      itemCount: _maxOffset + 1,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      itemBuilder: (context, offset) {
        final day = _dayAt(offset);
        // `narrowWeekdays` is indexed by `firstDayOfWeekIndex`-agnostic weekday
        // number where Sunday is 0, which is what `DateTime.weekday % 7` gives
        // (DateTime counts Monday..Sunday as 1..7).
        final weekday = material.narrowWeekdays[day.weekday % 7];
        return _DayCard(
          weekday: weekday,
          dayNumber: day.day,
          // The first two cards say what they are rather than what date they
          // are: "Today" is how anybody refers to it, and a bare number there
          // makes the reader do the lookup themselves.
          overrideLabel: switch (offset) {
            0 => l10n.scheduleTimePickerToday,
            1 => l10n.scheduleTimePickerTomorrow,
            _ => null,
          },
          selected: offset == _dayOffset,
          enabled: _dayIsSelectable(offset),
          semanticLabel: material.formatFullDate(day),
          onTap: () => _apply(dayOffset: offset),
        );
      },
    );
  }

  Widget _buildWheels(AppTheme theme) {
    final material = MaterialLocalizations.of(context);
    // The band is sized to the wheels, not to the sheet. A `Positioned.fill`
    // with a centred child stretches the full width, which drew a highlight
    // bar across the whole sheet with three small columns of numbers floating
    // somewhere inside it — the band has to say "these numbers are selected",
    // and one wider than the numbers says nothing.
    final wheelsWidth = 64.0 + 12.0 + 64.0 + (_use24Hour ? 0.0 : 6.0 + 60.0);
    return SizedBox(
      height: _kWheelRow * _kWheelVisibleRows,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Behind the wheels. Drawn once here rather than as a per-row
          // decoration so it does not scroll away with the numbers.
          Container(
            width: wheelsWidth,
            height: _kWheelRow,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Wheel(
                controller: _hours,
                itemCount: _use24Hour ? 24 : 12,
                width: 64,
                label: (row) => _use24Hour
                    ? row.toString().padLeft(2, '0')
                    : (row == 11 ? 12 : row + 1).toString(),
                onSelected: (row) => _apply(
                  hour: _use24Hour
                      ? row
                      : _hour24From(row, (_meridiem?.selectedItem ?? 0) == 1),
                ),
              ),
              SizedBox(
                width: 12,
                child: Center(
                  child: Text(
                    ':',
                    style: theme.monoLarge.copyWith(color: theme.inkMuted),
                  ),
                ),
              ),
              _Wheel(
                controller: _minutes,
                itemCount: 60 ~/ _kMinuteStep,
                width: 64,
                label: (row) =>
                    (row * _kMinuteStep).toString().padLeft(2, '0'),
                onSelected: (row) => _apply(minute: row * _kMinuteStep),
              ),
              if (!_use24Hour) ...[
                const SizedBox(width: 6),
                _Wheel(
                  controller: _meridiem!,
                  itemCount: 2,
                  width: 60,
                  label: (row) => row == 0
                      ? material.anteMeridiemAbbreviation
                      : material.postMeridiemAbbreviation,
                  onSelected: (row) => _apply(
                    hour: _hour24From(_hours.selectedItem, row == 1),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One day in the horizontal strip.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.dayNumber,
    required this.overrideLabel,
    required this.selected,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  final String weekday;
  final int dayNumber;
  final String? overrideLabel;
  final bool selected;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Center(
        child: FocusableTap(
            onTap: enabled ? onTap : null,
            enabled: enabled,
            selected: selected,
            semanticLabel: semanticLabel,
            radius: theme.radiusMd,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? onTap : null,
              child: AnimatedContainer(
                duration: motion.d(theme.motionFast),
                curve: motion.c(theme.motionEntrance),
                width: 56,
                height: 52,
                alignment: Alignment.center,
                // NOT `theme.chipDecoration`, which is a 999-radius capsule —
                // on a 56x52 box that draws a circle, and a circular date card
                // reads as an avatar. Same fill and border as a chip so the two
                // stay family; only the corner radius differs.
                decoration: BoxDecoration(
                  color: selected ? theme.accent : Colors.transparent,
                  border: Border.all(
                    color: selected ? theme.accent : theme.divider,
                  ),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Opacity(
                  opacity: enabled ? 1 : 0.32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        overrideLabel ?? weekday,
                        style: theme.monoTiny.copyWith(
                          color: selected ? theme.accentInk : theme.inkMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dayNumber',
                        style: theme.label.copyWith(
                          fontSize: 17,
                          color: selected ? theme.accentInk : theme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ),
    );
  }
}

/// One column of numbers.
///
/// A [ListWheelScrollView] rather than a styled `ListView`, because the
/// physics are the feature: `FixedExtentScrollPhysics` snaps to a row and
/// reports it, which is what makes a flick land on a value instead of between
/// two.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.width,
    required this.label,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final double width;
  final String Function(int row) label;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _kWheelRow,
        physics: const FixedExtentScrollPhysics(),
        // Flat rather than the default cylinder. The rest of this app's chrome
        // is flat glass, and a perspective-warped column of numbers in the
        // middle of it reads as a control borrowed from somewhere else.
        diameterRatio: 100,
        perspective: 0.0001,
        overAndUnderCenterOpacity: 0.38,
        onSelectedItemChanged: onSelected,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, row) => Center(
            child: Text(
              label(row),
              style: theme.monoLarge.copyWith(color: theme.ink),
            ),
          ),
        ),
      ),
    );
  }
}
