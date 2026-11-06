import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'native_control.dart';

/// A native one-line text field (or the search capsule) that behaves like the
/// Flutter field it replaces: it is driven by a [TextEditingController] and a
/// [FocusNode].
///
/// Sync rules (the React Native port's lessons, `docs/native-ui.md`):
/// - typing flows native → controller (`changed`), caret at the end, and is
///   never echoed back to the native field;
/// - an edit made to the controller from outside (a clear, a paste of a
///   template) bumps the spec's `textRev`, which is the only thing that makes
///   the native side overwrite its text;
/// - the [FocusNode] and the native first responder follow each other.
class NativeTextInput extends StatefulWidget {
  const NativeTextInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder = '',
    this.search = false,
    this.secure = false,
    this.contentType,
    this.keyboard,
    this.submitLabel,
    this.leadingSymbol,
    this.clearButton = false,
    this.plain = false,
    this.capitalization,
    this.autocorrect,
    this.enabled = true,
    this.autofocus = false,
    this.height = 50,
    this.cornerRadius = 22,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final bool search;
  final bool secure;
  final String? contentType;
  final String? keyboard;
  final String? submitLabel;
  final String? leadingSymbol;
  final bool clearButton;
  final bool plain;
  final String? capitalization;
  final bool? autocorrect;
  final bool enabled;
  final bool autofocus;
  final double height;
  final double cornerRadius;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<NativeTextInput> createState() => _NativeTextInputState();

  /// Maps Flutter's [TextInputType] to the native keyboard name.
  static String? keyboardFor(TextInputType? type) {
    if (type == null) return null;
    if (type == TextInputType.emailAddress) return 'email';
    if (type == TextInputType.url) return 'url';
    if (type == TextInputType.phone) return 'phone';
    if (type == TextInputType.number) return 'number';
    return null;
  }

  /// Maps [TextCapitalization] to the native name.
  static String capitalizationFor(TextCapitalization c) => switch (c) {
    TextCapitalization.words => 'words',
    TextCapitalization.sentences => 'sentences',
    TextCapitalization.characters => 'characters',
    TextCapitalization.none => 'none',
  };

  /// Maps [AutofillHints] to the native content type.
  static String? contentTypeFor(Iterable<String>? hints) {
    if (hints == null) return null;
    for (final h in hints) {
      switch (h) {
        case 'username':
        case 'password':
        case 'newPassword':
        case 'oneTimeCode':
        case 'url':
        case 'name':
          return h;
        case 'email':
          return 'emailAddress';
      }
    }
    return null;
  }

  /// Maps [TextInputAction] to the native return-key label.
  static String? submitLabelFor(TextInputAction? action) => switch (action) {
    TextInputAction.search => 'search',
    TextInputAction.next => 'next',
    TextInputAction.go => 'go',
    TextInputAction.send => 'send',
    TextInputAction.join => 'join',
    TextInputAction.continueAction => 'continue',
    TextInputAction.done => 'done',
    _ => null,
  };
}

class _NativeTextInputState extends State<NativeTextInput> {
  final NativeControlHandle _handle = NativeControlHandle();
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  FocusNode? _listened;

  /// The text the native field holds as far as Dart knows, and the revision
  /// that made it overwrite its own.
  late String _native = widget.controller.text;
  int _rev = 0;
  bool _nativeFocused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _listenNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(NativeTextInput old) {
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

  void _onController() {
    final text = widget.controller.text;
    if (text == _native || !mounted) return;
    setState(() {
      _native = text;
      _rev++;
    });
  }

  /// Flutter focus → the native first responder.
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

  void _onEvent(String event, Object? value) {
    switch (event) {
      case 'changed':
        final text = value as String? ?? '';
        if (text == widget.controller.text) return;
        _native = text;
        widget.controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        widget.onChanged?.call(text);
      case 'submitted':
        widget.onSubmitted?.call(value as String? ?? widget.controller.text);
      case 'focus':
        final focused = value == true;
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
    final spec = widget.search
        ? NativeSpec.searchField(
            text: _native,
            textRev: _rev,
            placeholder: widget.placeholder,
            submitLabel: widget.submitLabel ?? 'search',
            height: widget.height,
            enabled: widget.enabled,
          )
        : NativeSpec.textField(
            text: _native,
            textRev: _rev,
            placeholder: widget.placeholder,
            secure: widget.secure,
            contentType: widget.contentType,
            keyboard: widget.keyboard,
            leadingSymbol: widget.leadingSymbol,
            submitLabel: widget.submitLabel,
            clearButton: widget.clearButton,
            plain: widget.plain,
            capitalization: widget.capitalization,
            autocorrect: widget.autocorrect,
            height: widget.height,
            cornerRadius: widget.cornerRadius,
            enabled: widget.enabled,
          );
    return LayoutBuilder(
      builder: (context, box) => Focus(
        focusNode: _node,
        // The native field is the text input; this node only mirrors focus.
        child: NativeControl(
          size: Size(
            box.hasBoundedWidth ? box.maxWidth : double.infinity,
            widget.height,
          ),
          spec: spec,
          handle: _handle,
          onEvent: _onEvent,
        ),
      ),
    );
  }
}
