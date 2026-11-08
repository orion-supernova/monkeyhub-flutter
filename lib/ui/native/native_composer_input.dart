import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../../theme/theme_scope.dart';
import '../../widgets/liquid_glass.dart';
import 'native_control.dart';

/// The chat composer's text field as a native UITextView in a glass capsule
/// (Settings › Glass › Native controls on Everything): the system's own
/// selection, loupe, dictation, Writing Tools, autocorrect and Genmoji, a
/// field that grows a line at a time to [maxLines] and then scrolls.
///
/// Driven by a [TextEditingController] and a [FocusNode] like the Flutter
/// field it replaces, by the one-line field's rules ([NativeTextInput]):
/// typing flows native to controller with its selection (so the `@` picker
/// reads it as usual) and is never echoed back; an edit made to the
/// controller from outside (the clear after a send, a mention inserted)
/// bumps `textRev` with the selection to apply, the only thing that makes
/// the native side overwrite its text.
class NativeComposerInput extends StatefulWidget {
  const NativeComposerInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder = '',
    this.maxLines = 5,
    this.minHeight = 44,
    this.cornerRadius = 22,
    this.trailingSymbol,
    this.trailingOn = false,
    this.trailingLabel = '',
    this.onTrailing,
    this.onChanged,
    this.onFieldTap,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final int maxLines;
  final double minHeight;
  final double cornerRadius;

  /// An SF Symbol drawn at the end of the capsule (the expressions smiley);
  /// null for none. Drawn as a keyboard while [trailingOn].
  final String? trailingSymbol;
  final bool trailingOn;
  final String trailingLabel;
  final VoidCallback? onTrailing;
  final ValueChanged<String>? onChanged;

  /// Called when the field takes focus from a touch, as the Flutter field's
  /// `onTap` (it closes the expressions panel).
  final VoidCallback? onFieldTap;

  @override
  State<NativeComposerInput> createState() => _NativeComposerInputState();
}

class _NativeComposerInputState extends State<NativeComposerInput> {
  final NativeControlHandle _handle = NativeControlHandle();
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  FocusNode? _listened;

  /// The value the native view holds as far as Dart knows, and the revision
  /// that last made it take Dart's.
  late TextEditingValue _native = widget.controller.value;
  int _rev = 0;
  bool _nativeFocused = false;
  late double _height = widget.minHeight;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _listenNode();
  }

  @override
  void didUpdateWidget(NativeComposerInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _onController();
    }
    if (old.focusNode != widget.focusNode) _listenNode();
  }

  void _listenNode() {
    _listened?.removeListener(_onFocus);
    _listened = _node..addListener(_onFocus);
  }

  /// A change Dart made (not one the native view reported): push it.
  void _onController() {
    final v = widget.controller.value;
    if (!mounted) return;
    if (v.text == _native.text && v.selection == _native.selection) return;
    setState(() {
      _native = v;
      _rev++;
    });
  }

  /// Flutter focus to the native first responder.
  void _onFocus() {
    final has = _node.hasFocus;
    if (has == _nativeFocused) return;
    _nativeFocused = has;
    if (has) {
      _handle.focus();
    } else {
      _handle.blur();
    }
  }

  TextSelection _sel(Map m, int length) {
    final start = ((m['start'] as num?)?.toInt() ?? length).clamp(0, length);
    final end = ((m['end'] as num?)?.toInt() ?? start).clamp(start, length);
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  void _onEvent(String event, Object? value) {
    switch (event) {
      case 'changed':
        final m = value is Map ? value : const {};
        final text = m['text'] as String? ?? '';
        final v = TextEditingValue(text: text, selection: _sel(m, text.length));
        _native = v;
        if (v == widget.controller.value) return;
        widget.controller.value = v;
        widget.onChanged?.call(text);
      case 'selection':
        final m = value is Map ? value : const {};
        final text = widget.controller.text;
        final v = widget.controller.value.copyWith(selection: _sel(m, text.length));
        _native = v;
        if (v != widget.controller.value) widget.controller.value = v;
      case 'height':
        final h = (value as num?)?.toDouble() ?? widget.minHeight;
        if ((h - _height).abs() >= 0.5) setState(() => _height = h);
      case 'trailing':
        widget.onTrailing?.call();
      case 'focus':
        final focused = value == true;
        if (focused) widget.onFieldTap?.call();
        if (focused == _nativeFocused) return;
        _nativeFocused = focused;
        if (focused) {
          _node.requestFocus();
        } else {
          _node.unfocus();
        }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _listened?.removeListener(_onFocus);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = _native.selection;
    final spec = NativeSpec.composerField(
      text: _native.text,
      textRev: _rev,
      selStart: sel.isValid ? sel.start : null,
      selEnd: sel.isValid ? sel.end : null,
      placeholder: widget.placeholder,
      maxLines: widget.maxLines,
      minHeight: widget.minHeight,
      cornerRadius: widget.cornerRadius,
      trailingSymbol: widget.trailingSymbol,
      trailingOn: widget.trailingOn,
      trailingLabel: widget.trailingLabel,
    );
    return LayoutBuilder(
      builder: (context, box) => Focus(
        focusNode: _node,
        // The native view is the text input; this node only mirrors focus.
        child: NativeControl(
          size: Size(
            box.hasBoundedWidth ? box.maxWidth : double.infinity,
            _height,
          ),
          standIn: _standIn(context),
          spec: spec,
          handle: _handle,
          onEvent: _onEvent,
        ),
      ),
    );
  }

  /// While the native view cannot show (covered, mid-fade): the same capsule
  /// in Flutter glass with the text, not editable. Never a Flutter text
  /// field, which would fight the native view for the [FocusNode].
  Widget _standIn(BuildContext context) {
    final theme = ThemeScope.of(context);
    final text = widget.controller.text;
    return IgnorePointer(
      child: LiquidGlass(
        shape: LiquidGlassShape.rounded,
        radius: widget.cornerRadius,
        size: Size(double.infinity, _height),
        shadow: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            widget.trailingSymbol == null ? 16 : 12,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: (widget.minHeight - 20.4) / 2,
                  ),
                  child: Text(
                    text.isEmpty ? widget.placeholder : text,
                    maxLines: widget.maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      color: text.isEmpty ? theme.inkMuted : theme.ink,
                    ),
                  ),
                ),
              ),
              if (widget.trailingSymbol != null)
                SizedBox(
                  height: widget.minHeight,
                  child: Icon(
                    widget.trailingOn
                        ? CupertinoIcons.keyboard
                        : CupertinoIcons.smiley,
                    size: 22,
                    color: theme.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
