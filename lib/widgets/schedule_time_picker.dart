import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/scheduled_message.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// Height of one row in the time wheels, and how many rows are visible.
const double _kWheelRow = 38;
const int _kWheelVisibleRows = 3;

/// Minute granularity. Five is the coarsest step nobody notices missing and the
/// finest anyone actually wants — a 60-row wheel is a scroll, not a choice.
const int _kMinuteStep = 5;

/// Side of one day cell. Seven of these plus the grid's own gaps is what fixes
/// the picker's width, so it is the number to change if the calendar ever needs
/// to breathe.
const double _kCellSize = 40;

/// Rows the month grid always reserves.
///
/// Six, not "however many this month needs". A February starting on a Monday
/// needs four and a 31-day month starting on a Sunday needs six, so a grid
/// sized to its contents changes height as you page — and the wheels below it
/// would walk up and down the sheet while you were aiming at them.
const int _kWeekRows = 6;

/// A date and a time, chosen with the app's own controls.
///
/// ## Why this is hand-rolled
///
/// Flutter ships `showDatePicker`, and using it here was the obvious move. It
/// is also the wrong one: this app has no `ThemeData` at all — every surface is
/// drawn from [AppTheme]'s own tokens — and there is not one Material dialog
/// anywhere in `lib/`. Dropping one into the middle of a glass sheet would put
/// a differently-shaped, differently-coloured, differently-animated control in
/// front of the user at the exact moment they are making the feature's only
/// real decision.
///
/// What Material is still used for is the part nobody should re-derive.
/// [MaterialLocalizations] supplies the weekday abbreviations, the month names,
/// the date format, the digits and the 12/24-hour clock for all twelve locales,
/// so no string in here is assembled by hand and `intl` stays unimported.
///
/// ## Why a grid and not a strip
///
/// This started as a horizontal strip of 366 day cards. It could not answer
/// either question people actually bring to a date picker: *which* Saturday, and
/// how do I get to April. There was no week structure to read a weekday off, and
/// no jump — reaching next spring was something like two hundred swipes. A month
/// grid answers the first by construction and the header answers the second.
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
  /// The earliest instant that may be selected, and the latest. Read once —
  /// everything else is arithmetic from these, so the picker cannot drift
  /// mid-interaction if the minute rolls over under it.
  late final DateTime _floor;
  late final DateTime _ceiling;

  /// First day of the first selectable month, used as the origin for every
  /// month index. Always the 1st, so `_monthAt` is a plain month offset.
  late final DateTime _firstMonth;

  /// Midnight today, for the "you are here" dot. Captured once with everything
  /// else, so a picker left open across midnight keeps marking the day it
  /// opened on rather than silently moving the dot under the user.
  late final DateTime _today;

  late DateTime _day;
  late int _hour;
  late int _minute;

  /// Whether the month/year jump grid is showing instead of the calendar.
  bool _jumping = false;

  late final PageController _months;
  late FixedExtentScrollController _hours;
  late final FixedExtentScrollController _minutes;

  /// Only built in 12-hour locales; null elsewhere.
  FixedExtentScrollController? _meridiem;

  bool _use24Hour = true;
  bool _wheelsBuilt = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _floor = now.add(kScheduleMinLead);
    _ceiling = now.add(kScheduleMaxHorizon);
    _firstMonth = DateTime(_floor.year, _floor.month);
    _today = DateTime(now.year, now.month, now.day);

    // Snap onto the minute grid before anything reads it, so the wheel's
    // selected row and the value handed back can never disagree — a picker that
    // says 9:00 and schedules 9:02 is worse than one that refuses to open there.
    final start = _clamp(_snap(widget.initial));
    _day = DateTime(start.year, start.month, start.day);
    _hour = start.hour;
    _minute = start.minute;

    _months = PageController(initialPage: _monthIndexOf(_day));
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
    }
  }

  @override
  void dispose() {
    _months.dispose();
    _hours.dispose();
    _minutes.dispose();
    _meridiem?.dispose();
    super.dispose();
  }

  // ── Arithmetic ────────────────────────────────────────────────────────────

  /// Whole months between [_firstMonth] and [d]. Years fold into the month
  /// count rather than being carried separately, so December→January needs no
  /// special case anywhere.
  int _monthIndexOf(DateTime d) =>
      (d.year - _firstMonth.year) * 12 + (d.month - _firstMonth.month);

  DateTime _monthAt(int index) =>
      DateTime(_firstMonth.year, _firstMonth.month + index);

  /// How many month pages the window spans, inclusive of both ends.
  int get _monthCount => _monthIndexOf(_ceiling) + 1;

  /// The instant currently described by the calendar and the wheels.
  DateTime get _selected =>
      DateTime(_day.year, _day.month, _day.day, _hour, _minute);

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

  /// Whether [day] has any selectable time left in it.
  ///
  /// Only ever false for today (after the horizon's final day, and before the
  /// floor) — but a grid must not offer a cell whose every hour is unreachable.
  bool _dayIsSelectable(DateTime day) {
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59);
    if (endOfDay.isBefore(_floor)) return false;
    final startOfDay = DateTime(day.year, day.month, day.day);
    return !startOfDay.isAfter(_ceiling);
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
  /// a calendar sitting on *today* at 9am names an instant in the past. Rather
  /// than refusing the scroll — which fights the finger and reads as a broken
  /// wheel — the whole selection moves to the nearest legal instant and the
  /// wheels animate to follow, so what the user sees always matches what the
  /// sheet will schedule.
  void _apply({DateTime? day, int? hour, int? minute}) {
    setState(() {
      _day = day ?? _day;
      _hour = hour ?? _hour;
      _minute = minute ?? _minute;
    });
    final corrected = _clamp(_selected);
    if (corrected != _selected) {
      setState(() {
        _day = DateTime(corrected.year, corrected.month, corrected.day);
        _hour = corrected.hour;
        _minute = corrected.minute;
      });
      _syncWheels();
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
        c.animateToItem(
          item,
          duration: duration,
          curve: motion.c(theme.motionEntrance),
        );
      }
    }

    go(_hours, _use24Hour ? _hour : _hour12Index(_hour));
    go(_minutes, _minute ~/ _kMinuteStep);
    final m = _meridiem;
    if (m != null) go(m, _hour < 12 ? 0 : 1);
  }

  /// Moves the visible month by [delta] pages.
  void _stepMonth(int delta) {
    final target = (_months.page ?? _months.initialPage.toDouble()).round() + delta;
    if (target < 0 || target >= _monthCount) return;
    HapticFeedback.selectionClick();
    final motion = MotionScope.of(context);
    final theme = ThemeScope.of(context);
    final duration = motion.d(theme.motionMed);
    if (duration == Duration.zero) {
      _months.jumpToPage(target);
    } else {
      _months.animateToPage(
        target,
        duration: duration,
        curve: motion.c(theme.motionEntrance),
      );
    }
  }

  void _jumpToMonth(int index) {
    HapticFeedback.selectionClick();
    setState(() => _jumping = false);
    _months.jumpToPage(index);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One AnimatedSize around the swap so the sheet grows and shrinks
        // instead of jumping between the calendar and the month grid.
        AnimatedSize(
          duration: motion.d(theme.motionFast),
          curve: motion.c(theme.motionEntrance),
          alignment: Alignment.topCenter,
          child: _jumping ? _buildMonthJump(theme) : _buildCalendar(theme),
        ),
        const SizedBox(height: 12),
        _buildWheels(theme),
      ],
    );
  }

  Widget _buildCalendar(AppTheme theme) {
    final material = MaterialLocalizations.of(context);
    final motion = MotionScope.of(context);
    return Column(
      key: const ValueKey('calendar'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthHeader(
          // NOT upper-cased. `toUpperCase` is locale-independent in Dart, so a
          // Turkish "Ağustos" comes back with a dotless I where the language
          // needs İ — a visible mistranslation in one of the app's twelve
          // locales. The same trap is called out in `feed_screen.dart`.
          label: material.formatMonthYear(_visibleMonth()),
          onPrevious: _canStep(-1) ? () => _stepMonth(-1) : null,
          onNext: _canStep(1) ? () => _stepMonth(1) : null,
          onTapLabel: () => setState(() => _jumping = true),
        ),
        const SizedBox(height: 10),
        // Held still while the grid pages beneath it — the weekday columns do
        // not change, so animating them would be motion that means nothing.
        _WeekdayStrip(material: material),
        const SizedBox(height: 4),
        SizedBox(
          height: _kCellSize * _kWeekRows,
          child: PageView.builder(
            controller: _months,
            itemCount: _monthCount,
            // Rebuilds the header's month label as the page settles.
            onPageChanged: (_) => setState(() {}),
            itemBuilder: (context, index) => _MonthGrid(
              month: _monthAt(index),
              firstWeekday: material.firstDayOfWeekIndex,
              today: _today,
              selected: _day,
              isSelectable: _dayIsSelectable,
              formatDay: material.formatDecimal,
              semanticFor: material.formatFullDate,
              motion: motion,
              onPick: (day) => _apply(day: day),
            ),
          ),
        ),
      ],
    );
  }

  /// The month the pager is currently showing.
  ///
  /// Reads `page` rather than tracking a field: during a drag `page` is
  /// fractional, and rounding it is what makes the header flip at the halfway
  /// point of a swipe rather than at its end.
  DateTime _visibleMonth() {
    final page = _months.hasClients && _months.page != null
        ? _months.page!.round()
        : _monthIndexOf(_day);
    return _monthAt(page.clamp(0, _monthCount - 1));
  }

  bool _canStep(int delta) {
    final page = _months.hasClients && _months.page != null
        ? _months.page!.round()
        : _monthIndexOf(_day);
    final target = page + delta;
    return target >= 0 && target < _monthCount;
  }

  /// Every month in range, as one tap each.
  ///
  /// This is the whole of "month and year selection", and it is a flat list
  /// rather than a month wheel beside a year wheel because the horizon is a
  /// year: thirteen entries, so two controls to operate would be two more than
  /// the job needs, and the year wheel would hold two rows.
  ///
  /// Each cell carries the FULL `formatMonthYear` string rather than a bare
  /// month under a year heading. Splitting the localized string to get the
  /// month alone would need to know where the year sits in it, and that differs
  /// by locale — several of the app's twelve put the year first. Carrying the
  /// whole string is longer and always right.
  ///
  /// Bounded to the grid's own height and scrollable inside it, so switching
  /// between the calendar and this changes the sheet's height by the weekday
  /// strip alone. Thirteen full-width-ish cells laid out freely are taller than
  /// the calendar they replace, which pushed the wheels off the bottom.
  Widget _buildMonthJump(AppTheme theme) {
    final material = MaterialLocalizations.of(context);
    final motion = MotionScope.of(context);
    final visible = _monthIndexOf(_visibleMonth());
    return Column(
      key: const ValueKey('jump'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthHeader(
          label: material.formatMonthYear(_visibleMonth()),
          onPrevious: null,
          onNext: null,
          expanded: true,
          onTapLabel: () => setState(() => _jumping = false),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _kCellSize * _kWeekRows,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            itemCount: _monthCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              // Wide and short: these hold a word and a year, not a number.
              childAspectRatio: 3.2,
            ),
            itemBuilder: (context, i) => _MonthChip(
              label: material.formatMonthYear(_monthAt(i)),
              selected: i == visible,
              index: i,
              motion: motion,
              onTap: () => _jumpToMonth(i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWheels(AppTheme theme) {
    final material = MaterialLocalizations.of(context);
    // The band is sized to the wheels, not to the sheet. A `Positioned.fill`
    // with a centred child stretches the full width, which drew a highlight bar
    // across the whole sheet with three small columns of numbers floating
    // inside it.
    final wheelsWidth = 64.0 + 12.0 + 64.0 + (_use24Hour ? 0.0 : 6.0 + 60.0);
    return SizedBox(
      height: _kWheelRow * _kWheelVisibleRows,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: wheelsWidth,
            height: _kWheelRow,
            decoration: BoxDecoration(
              // Neutral, as iOS draws it. An accent wash here was a navy bar
              // on every dark theme.
              color: theme.ink.withValues(alpha: 0.08),
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
                    ? material.formatDecimal(row).padLeft(2, '0')
                    : material.formatDecimal(row == 11 ? 12 : row + 1),
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
                    style: _wheelStyle(theme).copyWith(color: theme.inkMuted),
                  ),
                ),
              ),
              _Wheel(
                controller: _minutes,
                itemCount: 60 ~/ _kMinuteStep,
                width: 64,
                label: (row) =>
                    material.formatDecimal(row * _kMinuteStep).padLeft(2, '0'),
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

/// ‹ month year ▾ ›
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onTapLabel,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onTapLabel;

  /// Whether the month grid is open, which flips the disclosure caret.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return Row(
      children: [
        _Arrow(icon: CupertinoIcons.chevron_left, onTap: onPrevious),
        Expanded(
          child: FocusableTap(
            onTap: onTapLabel,
            semanticLabel: label,
            selected: expanded,
            radius: theme.radiusMd,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: theme.bodyEmph.copyWith(
                          fontSize: 17,
                          color: theme.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // The iOS calendar's month disclosure: a chevron that
                    // turns down while the month list is open.
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: motion.d(theme.motionFast),
                      curve: motion.c(theme.motionEntrance),
                      child: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: theme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _Arrow(icon: CupertinoIcons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    return FocusableTap(
      onTap: onTap,
      enabled: enabled,
      shape: FocusRingShape.circle,
      semanticLabel: MaterialLocalizations.of(context).nextMonthTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? theme.accent
                : theme.inkMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// M T W T F S S, in the reader's own week order.
class _WeekdayStrip extends StatelessWidget {
  const _WeekdayStrip({required this.material});

  final MaterialLocalizations material;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                // `narrowWeekdays` is indexed Sunday-first; the locale's own
                // first day rotates it. Sweden starts on Monday, the US on
                // Sunday, and several locales on Saturday — a hardcoded order
                // is wrong for most of the twelve.
                material.narrowWeekdays[(material.firstDayOfWeekIndex + i) % 7],
                style: theme.bodySoft.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.inkMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One month of day cells.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.firstWeekday,
    required this.today,
    required this.selected,
    required this.isSelectable,
    required this.formatDay,
    required this.semanticFor,
    required this.motion,
    required this.onPick,
  });

  final DateTime month;
  final int firstWeekday;
  final DateTime today;
  final DateTime selected;
  final bool Function(DateTime) isSelectable;
  final String Function(int) formatDay;
  final String Function(DateTime) semanticFor;
  final MotionScope motion;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    // `DateTime(y, m + 1, 0)` is the last day of month m — day zero of the next
    // one. Handles December and leap Februaries without a table.
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // `weekday` is 1..7 Monday-first; the grid is 0..6 from the locale's first
    // day, so shift into that space before taking the offset.
    final firstOfMonth = DateTime(month.year, month.month);
    final lead = (firstOfMonth.weekday % 7 - firstWeekday + 7) % 7;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        // A FIXED row height, not an aspect ratio. `childAspectRatio: 1` ties
        // the height to the width, so on a wide surface — the desktop popover
        // form of this sheet is 460 — six rows grow past the box that holds
        // them and the calendar starts scrolling inside itself, hiding the end
        // of the month. The columns still divide the available width; only the
        // height is pinned.
        mainAxisExtent: _kCellSize,
      ),
      itemCount: _kWeekRows * 7,
      itemBuilder: (context, i) {
        final dayNumber = i - lead + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }
        final day = DateTime(month.year, month.month, dayNumber);
        final isToday = day == today;
        return _DayCell(
          label: formatDay(dayNumber),
          // "Tuesday, 12 August 2026, Today" — the marker under the number is
          // invisible to a screen reader, so the word carries it instead.
          semanticLabel: isToday
              ? '${semanticFor(day)}, ${AppLocalizations.of(context).scheduleTimePickerToday}'
              : semanticFor(day),
          selected: day == DateTime(selected.year, selected.month, selected.day),
          isToday: isToday,
          enabled: isSelectable(day),
          motion: motion,
          onTap: () => onPick(day),
        );
      },
    );
  }
}

/// One day.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.motion,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final MotionScope motion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      selected: selected,
      semanticLabel: semanticLabel,
      shape: FocusRingShape.circle,
      inset: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Center(
          child: SizedBox(
            width: _kCellSize - 6,
            height: _kCellSize - 6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The filled disc springs in behind the number rather than the
                // whole cell animating, so the digit never moves or rescales —
                // a number that grows as you pick it reads as a wobble.
                AnimatedScale(
                  scale: selected ? 1 : 0.4,
                  duration: motion.d(theme.motionFast),
                  curve: motion.c(Curves.easeOutBack),
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    // Opacity must stay inside 0..1, so the overshooting curve
                    // above drives only the scale — easeOutBack on a fade
                    // asserts. The same split `TransientPillSlot` makes.
                    duration: motion.d(theme.motionFast),
                    curve: motion.c(theme.motionEntrance),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: enabled ? 1 : 0.3,
                  child: Text(
                    label,
                    style: theme.body.copyWith(
                      color: selected ? theme.accentInk : theme.ink,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                // The conventional "you are here" dot. Suppressed once the day
                // is selected: the filled disc already says it, and a dot
                // inside it would read as a second, different mark.
                if (isToday && !selected)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: enabled ? theme.accent : theme.inkMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One month in the jump grid.
class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.index,
    required this.motion,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int index;
  final MotionScope motion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // The stagger lives in the duration, not in a delay — the house pattern,
      // so calm motion collapses thirteen chips to one zero duration rather
      // than to thirteen instant arrivals in sequence.
      duration: motion.stagger(theme.motionFast, index, strideMs: 18),
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 6),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: FocusableTap(
        onTap: onTap,
        selected: selected,
        semanticLabel: label,
        shape: FocusRingShape.capsule,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? theme.accent
                  : theme.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            // Shrink-to-fit rather than wrap or ellipsise. These hold a month
            // name, and "Setembro 2026" is a third longer than "May 2026" —
            // wrapping makes the cell two lines tall and truncating turns the
            // month into "Setem…", which is the one word the cell exists to
            // say.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: theme.body.copyWith(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? theme.accentInk : theme.ink,
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
/// A [ListWheelScrollView] rather than a styled `ListView`, because the physics
/// are the feature: `FixedExtentScrollPhysics` snaps to a row and reports it,
/// which is what makes a flick land on a value instead of between two.
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
              style: _wheelStyle(theme),
            ),
          ),
        ),
      ),
    );
  }
}

/// The figures on the time wheels: the body face at iOS's 21pt, tabular so a
/// rolling digit never shifts its neighbours. Not `monoLarge`, which several
/// themes set in a tracked monospace.
TextStyle _wheelStyle(AppTheme theme) => theme.body.copyWith(
      fontSize: 21,
      color: theme.ink,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
