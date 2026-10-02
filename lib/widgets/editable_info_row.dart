import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';

/// A field that reads as content until you touch it.
///
/// Room info is a screen people OPEN to read — who is in here, what is this,
/// what have we shared — and only occasionally to edit. Rendering the name and
/// description as live text inputs got that backwards twice over: five input
/// boxes stacked before anything else pushed the roster and the media row far
/// down the page, and a screen made of empty-looking boxes reads as a form to
/// fill in rather than a room to look at.
///
/// None of the reference apps do it. WhatsApp, Signal and Telegram all show the
/// value as text and put editing behind an explicit affordance. This is that,
/// inline: tap the row and it becomes the field, focused, keyboard up.
///
/// **Saving is explicit; leaving discards.** While editing, the row shows a
/// tick and a cross. Tapping the tick, or pressing Done on the keyboard,
/// commits. Tapping anywhere else — another row, the member list, the
/// background — cancels and puts the original value back.
///
/// That is the opposite of the toggles beside it, and deliberately so. A
/// toggle's tap IS the decision and there is nothing to get wrong. Free text
/// is different: a stray tap while a name is half-retyped would otherwise
/// commit "Hafta So" as the room's name for everyone in it. Discarding on the
/// way out is recoverable — the value is still on screen to try again — where
/// committing a half-edit is not.
///
/// The cost is that backing out of the screen mid-edit loses the edit. That is
/// the honest trade of this direction, and it is why the tick sits right next
/// to the field rather than anywhere the eye has to travel to.
class EditableInfoRow extends StatefulWidget {
  const EditableInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.controller,
    required this.placeholder,
    required this.onCommit,
    required this.saveLabel,
    required this.cancelLabel,
    this.enabled = true,
    this.maxLines = 1,
    this.emptyIsPlaceholder = true,
    this.note,
  });

  /// Small caps above the value, matching [FieldLabel] elsewhere.
  final String label;

  /// The truth, straight from the room. What the DISPLAY state renders.
  ///
  /// Separate from [controller] on purpose: the controller is an edit buffer,
  /// live only between tapping in and committing. Rendering the buffer instead
  /// would leave this row showing a stale name forever if another admin
  /// renamed the room while you had the screen open — the controller is seeded
  /// once and nothing else writes to it.
  final String value;

  /// The edit buffer. Seeded from [value] each time an edit session opens, so
  /// it can never drift.
  final TextEditingController controller;

  /// Shown in place of an empty value — "Add a description", not "". An empty
  /// row with a label above it looks broken; a prompt looks like an invitation.
  final String placeholder;

  /// Called when an edit is COMMITTED with something changed. Never on cancel.
  final ValueChanged<String> onCommit;

  /// Accessibility labels for the tick and the cross. Passed in rather than
  /// read from `AppLocalizations` here so this widget stays independent of the
  /// app's l10n and testable without a delegate.
  final String saveLabel;
  final String cancelLabel;

  /// False renders the value as plain text with no affordance at all: a member
  /// who cannot edit the room should not see a control that refuses them.
  final bool enabled;

  final int maxLines;

  /// When false an empty value renders as nothing rather than as [placeholder]
  /// — for rows where "unset" is a normal, unremarkable state.
  final bool emptyIsPlaceholder;

  /// A quiet line under the value saying what committing will actually DO.
  ///
  /// Exists for the one case where an editable-looking row does not write the
  /// thing it is showing: a group member's name or description edit becomes a
  /// suggestion the admins answer. Shown in BOTH states, display and edit —
  /// the point is to be read before the tap, and dropping it once the field is
  /// open would take it away at the exact moment it is being acted on.
  ///
  /// Null on every ordinary row, which is most of them.
  final String? note;

  @override
  State<EditableInfoRow> createState() => _EditableInfoRowState();
}

class _EditableInfoRowState extends State<EditableInfoRow> {
  final _focus = FocusNode();
  bool _editing = false;

  /// The text as it was when this edit session opened. Restored on cancel, and
  /// compared on commit so tapping in and straight back out writes nothing.
  String _entryText = '';

  /// Set on the tick's `onTapDown`, so the focus loss that tap causes is not
  /// mistaken for a tap-away. Cleared by whichever of [_commit] or [_cancel]
  /// runs next.
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus || !_editing) return;
    // Losing focus means a tap landed somewhere else — cancel. Except when the
    // tick was what took the focus: its `onTapDown` sets [_committing] first,
    // because a tap steals focus BEFORE its own onTap runs, and without the
    // flag pressing save would cancel instead.
    if (_committing) return;
    _cancel();
  }

  void _begin() {
    if (!widget.enabled || _editing) return;
    // Seed from the room, not from whatever the buffer last held.
    widget.controller.text = widget.value;
    widget.controller.selection =
        TextSelection.collapsed(offset: widget.value.length);
    _entryText = widget.value;
    setState(() => _editing = true);
    // The field does not exist until this frame is built, so the request has
    // to wait for it. Without the hop the keyboard opens and immediately
    // closes again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _focus.requestFocus();
    });
  }

  void _commit() {
    if (!_editing) return;
    final text = widget.controller.text;
    _committing = false;
    _focus.unfocus();
    setState(() => _editing = false);
    if (text != _entryText) widget.onCommit(text);
  }

  void _cancel() {
    if (!_editing) return;
    _committing = false;
    widget.controller.text = _entryText;
    _focus.unfocus();
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedSize(
      duration: theme.motionFast,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _editing ? _field(theme) : _display(theme),
    );
  }

  /// Laid out to sit inside a grouped block (see `InsetGroup`): it brings its
  /// own row padding and no border of its own, so the block is the frame.
  Widget _field(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: theme.caption.copyWith(fontSize: 13, color: theme.accent),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  style: theme.body.copyWith(fontSize: 17, color: theme.ink),
                  cursorColor: theme.accent,
                  maxLines: widget.maxLines,
                  minLines: 1,
                  textInputAction: widget.maxLines == 1
                      ? TextInputAction.done
                      : TextInputAction.newline,
                  onSubmitted: (_) => _commit(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.placeholder,
                    hintStyle: theme.body.copyWith(
                      fontSize: 17,
                      color: theme.inkMuted,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              _IconAction(
                icon: CupertinoIcons.xmark_circle_fill,
                tint: theme.inkMuted.withValues(alpha: 0.6),
                semantic: widget.cancelLabel,
                onTap: _cancel,
              ),
              _IconAction(
                icon: CupertinoIcons.checkmark_circle_fill,
                tint: theme.accent,
                semantic: widget.saveLabel,
                onTapDown: () => _committing = true,
                onTap: _commit,
              ),
            ],
          ),
          _note(theme),
        ],
      ),
    );
  }

  Widget _note(AppTheme theme) {
    final note = widget.note;
    if (note == null || note.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        note,
        style: theme.caption.copyWith(color: theme.inkMuted),
      ),
    );
  }

  Widget _display(AppTheme theme) {
    final value = widget.value.trim();
    final empty = value.isEmpty;
    if (empty && !widget.emptyIsPlaceholder && !widget.enabled) {
      return const SizedBox.shrink();
    }
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: theme.caption.copyWith(fontSize: 13, color: theme.inkMuted),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  empty ? widget.placeholder : value,
                  style: theme.body.copyWith(
                    fontSize: 17,
                    color: empty ? theme.inkMuted : theme.ink,
                  ),
                  maxLines: widget.maxLines == 1 ? 1 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // The affordance is a glyph, not a button: it says "editable"
              // without competing with the value for attention.
              if (widget.enabled) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    CupertinoIcons.pencil,
                    size: 17,
                    color: theme.inkMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          _note(theme),
        ],
      ),
    );
    if (!widget.enabled) return row;
    return FocusableTap(
      onTap: _begin,
      semanticLabel: '${widget.label}. ${empty ? widget.placeholder : value}',
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _begin,
        child: row,
      ),
    );
  }
}

/// The tick and the cross. Small, square, and quiet — they sit beside a label,
/// not under the field, and must not out-shout the text being edited.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tint,
    required this.semantic,
    required this.onTap,
    this.onTapDown,
  });

  final IconData icon;
  final Color tint;
  final String semantic;
  final VoidCallback onTap;
  final VoidCallback? onTapDown;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semantic,
      radius: theme.radiusSm,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onTapDown == null ? null : (_) => onTapDown!(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: tint),
        ),
      ),
    );
  }
}
