import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/labeled_field.dart';

/// Everything the compose sheet collected, ready for `interactions:create`.
///
/// A plain result object rather than the sheet calling the repository itself,
/// for the reason [AttachmentMenuChoice] is one: the sheet's job is to gather a
/// definition, and the room screen's job is to decide what sending means there
/// — which room, which reply, which optimistic bubble, which failure toast. A
/// sheet that sent its own message would be a second send path with none of
/// that.
@immutable
class InteractionDraft {
  const InteractionDraft({
    required this.kind,
    required this.prompt,
    this.labels,
    this.multiple = false,
    this.anonymous = false,
    this.quiz = false,
    this.correctIndex,
    this.explanation,
    this.othersMayCheck = true,
    this.othersMayAdd = true,
    this.startsAt,
    this.endsAt,
    this.place,
  });

  final MessageType kind;
  final String prompt;
  final List<String>? labels;
  final bool multiple;
  final bool anonymous;
  final bool quiz;
  final int? correctIndex;
  final String? explanation;
  final bool othersMayCheck;
  final bool othersMayAdd;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? place;
}

/// The compose sheet for a poll, a checklist or an event.
///
/// ## One sheet, three modes
///
/// The same argument [InteractionBubble] makes on the read side. All three are
/// a prompt, a list of typed lines and a few switches; what differs is which
/// switches, and — for an event — that the list of lines is replaced by a date.
/// Three sheets would be three copies of the row-add/row-remove keyboard
/// choreography, which is the fiddly part and the part a user notices.
///
/// The kind is fixed at open and there is no mode switcher inside. Choosing
/// between a poll and a checklist is a decision about what you are about to
/// say, made in the attachment menu where the rest of "what am I sending" is
/// decided — a segmented control at the top of this sheet would put it in the
/// wrong place and invite changing it halfway through typing options that no
/// longer make sense.
Future<InteractionDraft?> showInteractionComposeSheet(
  BuildContext context, {
  required MessageType kind,
}) {
  return showAdaptiveSheet<InteractionDraft>(
    context,
    useSafeArea: true,
    builder: (_) => InteractionComposeSheet(kind: kind),
  );
}

class InteractionComposeSheet extends StatefulWidget {
  const InteractionComposeSheet({super.key, required this.kind});

  final MessageType kind;

  @override
  State<InteractionComposeSheet> createState() =>
      _InteractionComposeSheetState();
}

class _InteractionComposeSheetState extends State<InteractionComposeSheet> {
  /// Mirrors `MAX_POLL_OPTIONS` / `MAX_CHECKLIST_ITEMS` in
  /// `backend/convex/interactions.ts`, which is the authority — this only
  /// decides when to stop offering another row. Kept in step by hand; a drift
  /// here costs a refused send, not a wrong poll.
  static const _maxPollOptions = 12;
  static const _maxChecklistItems = 30;
  static const _minPollOptions = 2;

  final _prompt = TextEditingController();
  final _explanation = TextEditingController();
  final _place = TextEditingController();

  /// One controller and one focus node per line, kept in step by index.
  ///
  /// A parallel pair of lists rather than a list of a small record type,
  /// because both have to be disposed and pairing them made the dispose loop
  /// the one place a leak could hide. Two lists of the same length, torn down
  /// in one place, is the shape that cannot leak half of a row.
  final List<TextEditingController> _lines = [];
  final List<FocusNode> _lineFocus = [];

  bool _multiple = false;
  bool _anonymous = false;
  bool _quiz = false;
  int? _correctIndex;
  bool _othersMayCheck = true;
  bool _othersMayAdd = true;
  DateTime? _startsAt;
  DateTime? _endsAt;

  String? _error;

  bool get _isPoll => widget.kind == MessageType.poll;
  bool get _isChecklist => widget.kind == MessageType.checklist;
  bool get _isEvent => widget.kind == MessageType.event;
  int get _maxLines => _isPoll ? _maxPollOptions : _maxChecklistItems;

  @override
  void initState() {
    super.initState();
    if (!_isEvent) {
      // Two empty options for a poll (its minimum, so the sheet opens showing
      // the shape of the thing) and one for a checklist (which is valid with
      // one item, and where a second empty row would look like a list that had
      // already lost something).
      final initial = _isPoll ? _minPollOptions : 1;
      for (var i = 0; i < initial; i++) {
        _addLine(focus: false);
      }
    }
  }

  @override
  void dispose() {
    _prompt.dispose();
    _explanation.dispose();
    _place.dispose();
    for (final c in _lines) {
      c.dispose();
    }
    for (final f in _lineFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _addLine({bool focus = true}) {
    if (_lines.length >= _maxLines) return;
    final controller = TextEditingController();
    final node = FocusNode();
    _lines.add(controller);
    _lineFocus.add(node);
    if (focus) {
      setState(() {});
      // After the frame, because the node is not attached to anything until
      // the row it belongs to has been built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) node.requestFocus();
      });
    }
  }

  void _removeLine(int index) {
    if (index < 0 || index >= _lines.length) return;
    // A poll below its minimum cannot be sent, so the control stops being
    // offered rather than removing a row the CTA would then refuse.
    if (_lines.length <= (_isPoll ? _minPollOptions : 1)) return;
    setState(() {
      _lines.removeAt(index).dispose();
      _lineFocus.removeAt(index).dispose();
      // The correct answer is stored as an INDEX into the rows, so removing a
      // row above it moves it. Dropping the mark entirely when its own row goes
      // is deliberate: silently promoting the next option to "correct" would
      // put a wrong answer on a quiz without the author being told.
      final marked = _correctIndex;
      if (marked != null) {
        if (marked == index) {
          _correctIndex = null;
        } else if (marked > index) {
          _correctIndex = marked - 1;
        }
      }
    });
  }

  /// The typed lines, trimmed, with blanks dropped.
  ///
  /// Blanks are dropped rather than refused because an empty trailing row is
  /// what an author leaves behind after tapping "add" one time too many — that
  /// is a slip, not an option they meant. An empty row in the MIDDLE is the
  /// same slip and gets the same treatment, which is what makes the mapping
  /// from rows to labels the one the server will also apply.
  List<String> get _labels =>
      [for (final c in _lines) c.text.trim()].where((s) => s.isNotEmpty).toList();

  /// Where the marked answer lands once the blanks are gone.
  ///
  /// Recomputed rather than carried, because [_labels] renumbers: a quiz whose
  /// second row is blank would otherwise mark the wrong option. Returns null if
  /// the marked row was one of the blanks — the CTA then refuses, which is
  /// correct, since a quiz with no answer is not a quiz.
  int? get _resolvedCorrectIndex {
    final marked = _correctIndex;
    if (marked == null || marked >= _lines.length) return null;
    if (_lines[marked].text.trim().isEmpty) return null;
    var seen = 0;
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].text.trim().isEmpty) continue;
      if (i == marked) return seen;
      seen++;
    }
    return null;
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = l10n.interactionComposeErrorPrompt);
      return;
    }
    if (_isEvent) {
      if (_startsAt == null) {
        setState(() => _error = l10n.interactionComposeErrorWhen);
        return;
      }
      Navigator.of(context).pop(
        InteractionDraft(
          kind: widget.kind,
          prompt: prompt,
          startsAt: _startsAt,
          endsAt: _endsAt,
          place: _place.text.trim().isEmpty ? null : _place.text.trim(),
        ),
      );
      return;
    }

    final labels = _labels;
    if (labels.length < (_isPoll ? _minPollOptions : 1)) {
      setState(() => _error = _isPoll
          ? l10n.interactionComposeErrorOptions(_minPollOptions)
          : l10n.interactionComposeErrorItems);
      return;
    }
    final correct = _resolvedCorrectIndex;
    if (_isPoll && _quiz && correct == null) {
      setState(() => _error = l10n.interactionComposeErrorAnswer);
      return;
    }

    Navigator.of(context).pop(
      InteractionDraft(
        kind: widget.kind,
        prompt: prompt,
        labels: labels,
        // A quiz is single-answer by definition, and the switch below already
        // turns `_multiple` off when quiz mode goes on. Stated again here so
        // the draft is correct no matter what order the switches were touched
        // in — the server refuses the combination too.
        multiple: _isPoll && _multiple && !_quiz,
        anonymous: _isPoll && _anonymous,
        quiz: _isPoll && _quiz,
        correctIndex: _isPoll && _quiz ? correct : null,
        explanation: _isPoll && _quiz && _explanation.text.trim().isNotEmpty
            ? _explanation.text.trim()
            : null,
        othersMayCheck: _isChecklist ? _othersMayCheck : true,
        othersMayAdd: _isChecklist ? _othersMayAdd : true,
      ),
    );
  }

  Future<void> _pickWhen({required bool end}) async {
    final now = DateTime.now();
    final seed = (end ? _endsAt : _startsAt) ?? _startsAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: seed,
      // A year back, because an event card is also a record: somebody writing
      // up last week's dinner should be able to date it correctly. Two years
      // forward covers anything anybody plans in a group chat.
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (end) {
        // An end before its start is dropped rather than refused, matching the
        // server. The author gets the picker back rather than an error about a
        // combination they can simply pick again.
        _endsAt = _startsAt != null && picked.isAfter(_startsAt!) ? picked : null;
        if (_endsAt == null) _error = AppLocalizations.of(context).interactionComposeErrorEnd;
      } else {
        _startsAt = picked;
        // Keep the pair coherent: an end that is now before the start would
        // render as a range going backwards.
        if (_endsAt != null && !_endsAt!.isAfter(picked)) _endsAt = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: theme.sheetDecoration(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: DefaultTextStyle(
                style: theme.body.copyWith(color: theme.ink),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (context.isCompact)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 18),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.inkMuted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      _title(theme, l10n),
                      const SizedBox(height: 22),
                      LabeledField(
                        label: _promptLabel(l10n),
                        controller: _prompt,
                        hint: _promptHint(l10n),
                        autofocus: true,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      if (_isEvent)
                        ..._eventFields(theme, l10n)
                      else
                        ..._lineFields(theme, l10n),
                      const SizedBox(height: 20),
                      ..._switches(theme, l10n),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: theme.surfaceSunken,
                            border: Border(
                              left: BorderSide(color: theme.danger, width: 2),
                            ),
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                          ),
                          child: Text(
                            _error!,
                            style: theme.body.copyWith(color: theme.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _cta(theme, l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(AppTheme theme, AppLocalizations l10n) {
    final (title, tagline) = switch (widget.kind) {
      MessageType.checklist => (
          l10n.interactionComposeChecklistTitle,
          l10n.interactionComposeChecklistTagline,
        ),
      MessageType.event => (
          l10n.interactionComposeEventTitle,
          l10n.interactionComposeEventTagline,
        ),
      _ => (
          l10n.interactionComposePollTitle,
          l10n.interactionComposePollTagline,
        ),
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.displayLarge),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 2,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      tagline,
                      style: theme.caption.copyWith(
                        color: theme.accent,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.surfaceSunken,
              shape: BoxShape.circle,
              border: Border.all(color: theme.divider),
            ),
            child: Icon(CupertinoIcons.xmark, color: theme.inkSoft, size: 14),
          ),
        ),
      ],
    );
  }

  String _promptLabel(AppLocalizations l10n) => switch (widget.kind) {
        MessageType.checklist => l10n.interactionComposeTitleLabel,
        MessageType.event => l10n.interactionComposeEventNameLabel,
        _ => l10n.interactionComposeQuestionLabel,
      };

  String _promptHint(AppLocalizations l10n) => switch (widget.kind) {
        MessageType.checklist => l10n.interactionComposeTitleHint,
        MessageType.event => l10n.interactionComposeEventNameHint,
        _ => l10n.interactionComposeQuestionHint,
      };

  /// The poll's options or the checklist's items, one row each.
  List<Widget> _lineFields(AppTheme theme, AppLocalizations l10n) {
    final removable = _lines.length > (_isPoll ? _minPollOptions : 1);
    return [
      FieldLabel(
        _isPoll
            ? l10n.interactionComposeOptionsLabel
            : l10n.interactionComposeItemsLabel,
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _lines.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Quiz mode turns the leading glyph into the answer picker. A
              // separate column of radios beside the fields would double the
              // row's width budget for a mode most polls never enter — and the
              // mark belongs ON the option it marks.
              if (_isPoll && _quiz)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FocusableTap(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _correctIndex = i);
                    },
                    radius: 11,
                    selected: _correctIndex == i,
                    semanticLabel: l10n.interactionComposeMarkCorrect,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _correctIndex = i);
                      },
                      child: AnimatedContainer(
                        duration: theme.motionFast,
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _correctIndex == i
                              ? theme.success
                              : Colors.transparent,
                          border: Border.all(
                            color: _correctIndex == i
                                ? theme.success
                                : theme.inkMuted.withValues(alpha: 0.5),
                            width: 1.6,
                          ),
                        ),
                        child: _correctIndex == i
                            ? Icon(
                                CupertinoIcons.check_mark,
                                size: 13,
                                color: theme.accentInk,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _lines[i],
                  focusNode: _lineFocus[i],
                  style: theme.body.copyWith(color: theme.ink),
                  cursorColor: theme.accent,
                  textInputAction: TextInputAction.next,
                  // Enter on the last row adds another, which is how a list of
                  // five options is typed without reaching for a button between
                  // each one.
                  onSubmitted: (_) {
                    if (i == _lines.length - 1) {
                      _addLine();
                    } else {
                      _lineFocus[i + 1].requestFocus();
                    }
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: theme.surfaceSunken,
                    hintText: _isPoll
                        ? l10n.interactionComposeOptionHint(i + 1)
                        : l10n.interactionComposeItemHint(i + 1),
                    hintStyle: theme.body.copyWith(color: theme.inkMuted),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                      borderSide: BorderSide(color: theme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                      borderSide: BorderSide(color: theme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                      borderSide: BorderSide(color: theme.accent, width: 1.4),
                    ),
                  ),
                ),
              ),
              // Absent, not dimmed, at the minimum — a control whose only
              // outcome is nothing is worse than no control.
              if (removable) ...[
                const SizedBox(width: 6),
                FocusableTap(
                  onTap: () => _removeLine(i),
                  radius: theme.radiusSm,
                  semanticLabel: l10n.interactionComposeRemoveRow,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _removeLine(i);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        CupertinoIcons.minus_circle,
                        size: 18,
                        color: theme.inkMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      if (_lines.length < _maxLines)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FocusableTap(
            onTap: _addLine,
            radius: theme.radiusMd,
            semanticLabel: _isPoll
                ? l10n.interactionComposeAddOption
                : l10n.interactionComposeAddItem,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                _addLine();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.add, size: 14, color: theme.accent),
                    const SizedBox(width: 8),
                    Text(
                      _isPoll
                          ? l10n.interactionComposeAddOption
                          : l10n.interactionComposeAddItem,
                      style: theme.label.copyWith(color: theme.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _eventFields(AppTheme theme, AppLocalizations l10n) {
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final ml = MaterialLocalizations.of(context);
    String? show(DateTime? d) => d == null
        ? null
        : '${ml.formatMediumDate(d)} · '
            '${ml.formatTimeOfDay(TimeOfDay.fromDateTime(d), alwaysUse24HourFormat: use24)}';

    return [
      FieldLabel(l10n.interactionComposeWhenLabel),
      const SizedBox(height: 8),
      _pickerRow(
        theme,
        icon: CupertinoIcons.clock,
        value: show(_startsAt) ?? l10n.interactionComposePickStart,
        placeholder: _startsAt == null,
        onTap: () => _pickWhen(end: false),
      ),
      const SizedBox(height: 8),
      // Only after a start exists. An end time picked first has nothing to be
      // after, and the picker would have to invent a day for it.
      if (_startsAt != null)
        _pickerRow(
          theme,
          icon: CupertinoIcons.clock_fill,
          value: show(_endsAt) ?? l10n.interactionComposePickEnd,
          placeholder: _endsAt == null,
          onTap: () => _pickWhen(end: true),
          // An event with no end is the ordinary case, so this one clears.
          onClear: _endsAt == null ? null : () => setState(() => _endsAt = null),
        ),
      const SizedBox(height: 20),
      LabeledField(
        label: l10n.interactionComposePlaceLabel,
        controller: _place,
        hint: l10n.interactionComposePlaceHint,
        textInputAction: TextInputAction.done,
      ),
    ];
  }

  Widget _pickerRow(
    AppTheme theme, {
    required IconData icon,
    required String value,
    required bool placeholder,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return FocusableTap(
      onTap: onTap,
      radius: theme.radiusMd,
      semanticLabel: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(color: theme.divider),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: theme.inkSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: theme.body.copyWith(
                    color: placeholder ? theme.inkMuted : theme.ink,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 16,
                    color: theme.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _switches(AppTheme theme, AppLocalizations l10n) {
    if (_isEvent) return const [];
    if (_isChecklist) {
      return [
        _switch(
          theme,
          value: _othersMayCheck,
          title: l10n.interactionComposeOthersMayCheckTitle,
          sub: l10n.interactionComposeOthersMayCheckSub,
          onChanged: (v) => setState(() => _othersMayCheck = v),
        ),
        _switch(
          theme,
          value: _othersMayAdd,
          title: l10n.interactionComposeOthersMayAddTitle,
          sub: l10n.interactionComposeOthersMayAddSub,
          onChanged: (v) => setState(() => _othersMayAdd = v),
        ),
      ];
    }
    return [
      _switch(
        theme,
        // Off while quiz mode is on, and not merely ignored: a quiz has one
        // right answer, so "multiple answers" is not a setting it can hold. The
        // switch shows the truth rather than a value that would be discarded.
        value: _multiple && !_quiz,
        enabled: !_quiz,
        title: l10n.interactionComposeMultipleTitle,
        sub: l10n.interactionComposeMultipleSub,
        onChanged: (v) => setState(() => _multiple = v),
      ),
      _switch(
        theme,
        value: _anonymous,
        title: l10n.interactionComposeAnonymousTitle,
        // The default is OFF, and the subtitle says what that MEANS rather than
        // naming the setting again: a reader deciding whether to flip it needs
        // to know that leaving it alone publishes names.
        sub: _anonymous
            ? l10n.interactionComposeAnonymousOnSub
            : l10n.interactionComposeAnonymousOffSub,
        onChanged: (v) => setState(() => _anonymous = v),
      ),
      _switch(
        theme,
        value: _quiz,
        title: l10n.interactionComposeQuizTitle,
        sub: l10n.interactionComposeQuizSub,
        onChanged: (v) => setState(() {
          _quiz = v;
          if (!v) _correctIndex = null;
        }),
      ),
      if (_quiz) ...[
        const SizedBox(height: 12),
        LabeledField(
          label: l10n.interactionComposeExplanationLabel,
          controller: _explanation,
          hint: l10n.interactionComposeExplanationHint,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.done,
        ),
      ],
    ];
  }

  Widget _switch(
    AppTheme theme, {
    required bool value,
    required String title,
    required String sub,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final ink = enabled ? theme.ink : theme.inkMuted;
    void toggle() {
      if (!enabled) return;
      HapticFeedback.selectionClick();
      onChanged(!value);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FocusableTap(
        onTap: enabled ? toggle : null,
        enabled: enabled,
        radius: theme.radiusMd,
        selected: value,
        semanticLabel: title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: theme.surfaceSunken,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(
                color: value && enabled ? theme.accent : theme.divider,
                width: value && enabled ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.displaySmall
                            .copyWith(color: ink, fontSize: 16),
                      ),
                      Text(sub, style: theme.monoTiny),
                    ],
                  ),
                ),
                // Cupertino's switch, not Material's: it is what every other
                // toggle in this app uses, and it carries no ink ripple.
                CupertinoSwitch(
                  value: value,
                  onChanged: enabled ? (v) => onChanged(v) : null,
                  activeTrackColor: theme.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cta(AppTheme theme, AppLocalizations l10n) {
    final label = switch (widget.kind) {
      MessageType.checklist => l10n.interactionComposeSendChecklist,
      MessageType.event => l10n.interactionComposeSendEvent,
      _ => l10n.interactionComposeSendPoll,
    };
    return FocusableTap(
      onTap: _submit,
      semanticLabel: label,
      radius: theme.radiusLg,
      child: GestureDetector(
        onTap: _submit,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.label.copyWith(
                  color: theme.accentInk,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                CupertinoIcons.arrow_up_right,
                size: 14,
                color: theme.accentInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
