import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import 'room_screen.dart';

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;
  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _password = TextEditingController();
  bool _isPrivate = true;
  RoomType _type = RoomType.regular;
  Duration _ttl = const Duration(seconds: 30);
  bool _busy = false;
  String? _error;

  static const _ttls = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(hours: 1),
  ];

  String _fmtTtl(BuildContext context, Duration d) {
    final l10n = AppLocalizations.of(context);
    if (d.inSeconds < 60) return l10n.createRoomSheetTtlSeconds(d.inSeconds);
    if (d.inMinutes < 60) return l10n.createRoomSheetTtlMinutes(d.inMinutes);
    return l10n.createRoomSheetTtlHours(d.inHours);
  }

  Future<void> _create() async {
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(
        () => _error = AppLocalizations.of(context).createRoomSheetNameRequiredError,
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.repo.createRoom(
        name: n,
        isPrivate: _isPrivate,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        password: _password.text.isEmpty ? null : _password.text,
        type: _type,
        messageLifetime: _type == RoomType.secret ? _ttl : null,
      );
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (context.isExpanded) {
        // Desktop: dismiss the sheet and open the new room in the chat pane.
        SettingsStore.instance.setSection(HomeSection.chat);
        UiSelectionStore.instance.selectRoom(id);
        nav.pop();
      } else {
        nav.pop();
        nav.push(
          MaterialPageRoute(
              builder: (_) =>
                  RoomScreen(roomId: id, repo: widget.repo, api: widget.api)),
        );
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    return Material(
      type: MaterialType.transparency,
      // Flush to the left, right and bottom edges, like every other sheet in
      // this app.
      //
      // This one was wrapped in `Padding(12, 0, 12, 12)` INSIDE a
      // `SafeArea(top: false)`, which is three separate mistakes wearing one
      // coat. `sheetDecoration` rounds its TOP corners and draws a top border
      // only — it is authored to sit against the bottom of the screen — so
      // floating it left square bottom corners over the scrim and a hairline
      // running across mid-air. The safe area then put the home indicator's
      // 34pt UNDER the card, and the 12 went under that: about 46pt of scrim
      // below a card that looked detached from everything.
      //
      // The insets belong INSIDE the card instead, where they push the content
      // clear of the keyboard and the indicator while the surface itself runs
      // to the edge of the glass.
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          // `viewInsets` and `padding` are never both non-zero: raising the
          // keyboard is what zeroes the second. Adding them is how one
          // expression covers a sheet at rest and a sheet being typed into.
          20 + media.viewInsets.bottom + media.padding.bottom,
        ),
        child: DefaultTextStyle(
          style: theme.body.copyWith(color: theme.ink),
          child: ConstrainedBox(
            // Bounded, so the sheet scrolls instead of clipping. This is the
            // tallest sheet in the app — two fields, two segment pairs, the
            // ephemeral chips and a CTA — and an `isScrollControlled` sheet
            // with an unbounded column does not overflow loudly, it silently
            // cuts off whatever runs past the viewport. With the keyboard up on
            // a short phone, what got cut off was OPEN ROOM: the button you
            // need to finish. The same fix both feed composers already carry.
            constraints: BoxConstraints(
              maxHeight: context.isCompact
                  ? media.size.height * 0.86
                  : double.infinity,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Meaningless once dismiss-by-drag isn't a thing — the
                  // desktop popover closes via barrier tap / Esc, not a
                  // drag gesture.
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.createRoomSheetTitle,
                                style: theme.displayLarge),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                width: 18,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: theme.accent,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Flexible: the tagline is a translated line at
                              // `letterSpacing: 2`, which is a lot of width for
                              // not many characters, and a bare `Text` in a
                              // `Row` has no way to give any of it back. On a
                              // 360pt phone it ran 12pt off the right edge — a
                              // loud layout exception in debug and a clipped
                              // yellow-and-black stripe in a build.
                              Flexible(
                                child: Text(
                                  _type == RoomType.secret
                                      ? l10n.createRoomSheetTaglineSecret
                                      : l10n.createRoomSheetTaglineRegular,
                                  style: theme.caption.copyWith(
                                    color: theme.accent,
                                    letterSpacing: 2.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
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
                  ),
                  const SizedBox(height: 26),
                  LabeledField(
                    label: l10n.createRoomSheetNameLabel,
                    controller: _name,
                    hint: l10n.createRoomSheetNameHint,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 18),
                  LabeledField(
                    label: l10n.createRoomSheetDescriptionLabel,
                    controller: _desc,
                    hint: l10n.createRoomSheetDescriptionHint,
                    textInputAction: TextInputAction.done,
                    // Same guard as the CTA, so Enter can't create a room
                    // the button is currently refusing to.
                    onSubmitted: (_) => _busy ? null : _create(),
                  ),
                  const SizedBox(height: 22),
                  FieldLabel(l10n.createRoomSheetVisibilityLabel),
                  Row(children: [
                    Expanded(
                      child: _seg(
                        theme,
                        active: !_isPrivate,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isPrivate = false);
                        },
                        icon: theme.visibilityIcon(isPublic: true, size: 14),
                        title: l10n.createRoomSheetVisibilityPublicTitle,
                        sub: l10n.createRoomSheetVisibilityPublicSub,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _seg(
                        theme,
                        active: _isPrivate,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isPrivate = true);
                        },
                        icon: theme.visibilityIcon(isPublic: false, size: 14),
                        title: l10n.createRoomSheetVisibilityPrivateTitle,
                        sub: l10n.createRoomSheetVisibilityPrivateSub,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  FieldLabel(l10n.createRoomSheetTypeLabel),
                  Row(children: [
                    Expanded(
                      child: _seg(
                        theme,
                        active: _type == RoomType.regular,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _type = RoomType.regular);
                        },
                        icon: Icon(CupertinoIcons.number, size: 14, color: theme.inkSoft),
                        title: l10n.createRoomSheetTypeStandardTitle,
                        sub: l10n.createRoomSheetTypeStandardSub,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _seg(
                        theme,
                        active: _type == RoomType.secret,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _type = RoomType.secret);
                        },
                        icon: theme.hourglassIcon(size: 14, color: theme.accent),
                        title: l10n.createRoomSheetTypeEphemeralTitle,
                        sub: l10n.createRoomSheetTypeEphemeralSub,
                        highlight: true,
                      ),
                    ),
                  ]),
                  AnimatedCrossFade(
                    duration: theme.motionMed,
                    crossFadeState: _type == RoomType.secret
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(height: 22),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            FieldLabel(l10n.createRoomSheetMessageLifeLabel),
                            const Spacer(),
                            Text(_fmtTtl(context, _ttl),
                                style: theme.monoLarge.copyWith(color: theme.accent)),
                          ]),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in _ttls)
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _ttl = t);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 9),
                                    decoration: theme.chipDecoration(filled: _ttl == t),
                                    child: Text(
                                      _fmtTtl(context, t),
                                      style: theme.label.copyWith(
                                          color: _ttl == t
                                              ? theme.accentInk
                                              : theme.inkSoft),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Password is independent of visibility: a public room
                  // can be discoverable yet locked, a private room can be
                  // hidden yet open. Show the field for both.
                  const SizedBox(height: 22),
                  PasswordField(
                    label: l10n.createRoomSheetPasswordLabel,
                    controller: _password,
                    hint: l10n.createRoomSheetPasswordHint,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: theme.surfaceSunken,
                        border: Border(
                            left: BorderSide(color: theme.danger, width: 2)),
                        borderRadius: BorderRadius.circular(theme.radiusMd),
                      ),
                      child: Text(_error!,
                          style: theme.body.copyWith(color: theme.danger)),
                    ),
                  ],
                  const SizedBox(height: 26),
                  FocusableTap(
                    onTap: _busy ? null : _create,
                    enabled: !_busy,
                    semanticLabel: l10n.createRoomSheetOpenRoomSemanticLabel,
                    radius: theme.radiusLg,
                    child: GestureDetector(
                    onTap: _busy ? null : _create,
                    child: AnimatedContainer(
                      duration: theme.motionFast,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _busy ? theme.accentSoft : theme.accent,
                        borderRadius: BorderRadius.circular(theme.radiusLg),
                        boxShadow: _busy
                            ? null
                            : [
                                BoxShadow(
                                  color: theme.accent.withValues(alpha: 0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: _busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: theme.accentInk),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(l10n.createRoomSheetOpenRoomButton,
                                    style: theme.label.copyWith(
                                        color: theme.accentInk,
                                        letterSpacing: 2.4)),
                                const SizedBox(width: 10),
                                Icon(CupertinoIcons.arrow_up_right,
                                    size: 14, color: theme.accentInk),
                              ],
                            ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seg(AppTheme theme, {
    required bool active,
    required VoidCallback onTap,
    required Widget icon,
    required String title,
    required String sub,
    bool highlight = false,
  }) {
    final ink = active ? theme.ink : theme.inkSoft;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: active ? theme.surfaceRaised : theme.surfaceSunken,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(
            color: active ? (highlight ? theme.accent : theme.ink.withValues(alpha: 0.35)) : theme.divider,
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: Center(child: icon)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.displaySmall.copyWith(color: ink, fontSize: 16)),
                  Text(sub, style: theme.monoTiny),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
