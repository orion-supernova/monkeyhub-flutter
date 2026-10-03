import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/enums.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import 'room_screen.dart';
import '../widgets/sheet_kit.dart';
import '../widgets/ios_kit.dart';

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
      HapticFeedback.mediumImpact();
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
    // iOS's "New Group": a × and a centred title in the bar, the two
    // fields, then each either/or as a grouped pick-one block with a
    // checkmark, and one button at the foot. Bounded so the tallest sheet in
    // the app scrolls instead of silently clipping its own Create button when
    // the keyboard is up on a short phone.
    Widget choice({
      required bool selected,
      required VoidCallback onTap,
      required IconData icon,
      required TileTone tone,
      required String title,
      required String sub,
    }) =>
        GroupedRow.choice(
          icon: icon,
          tone: tone,
          title: sentenceCaseOf(context, title),
          subtitle: sub,
          selected: selected,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
        );

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
          child: Text(
            sentenceCaseOf(context, text),
            style: theme.caption.copyWith(fontSize: 13, color: theme.inkMuted),
          ),
        );

    return SheetFrame(
      leading: const SheetCloseButton(),
      title: sentenceCaseOf(context, l10n.createRoomSheetTitle),
      maxHeightFraction: context.isCompact ? 0.9 : null,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DefaultTextStyle(
        style: theme.body.copyWith(color: theme.ink),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                child: Text(
                  _type == RoomType.secret
                      ? sentenceCaseOf(
                          context,
                          l10n.createRoomSheetTaglineSecret,
                        )
                      : sentenceCaseOf(
                          context,
                          l10n.createRoomSheetTaglineRegular,
                        ),
                  textAlign: TextAlign.center,
                  style: theme.body.copyWith(
                    fontSize: 15,
                    color: theme.inkMuted,
                  ),
                ),
              ),
              LabeledField(
                label: l10n.createRoomSheetNameLabel,
                controller: _name,
                hint: l10n.createRoomSheetNameHint,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: l10n.createRoomSheetDescriptionLabel,
                controller: _desc,
                hint: l10n.createRoomSheetDescriptionHint,
                textInputAction: TextInputAction.done,
                // Same guard as the button, so Enter can't create a room the
                // button is currently refusing to.
                onSubmitted: (_) => _busy ? null : _create(),
              ),
              const SizedBox(height: 22),
              header(l10n.createRoomSheetVisibilityLabel),
              SheetGroup(
                children: [
                  choice(
                    selected: !_isPrivate,
                    onTap: () => setState(() => _isPrivate = false),
                    icon: CupertinoIcons.globe,
                    tone: TileTone.blue,
                    title: l10n.createRoomSheetVisibilityPublicTitle,
                    sub: l10n.createRoomSheetVisibilityPublicSub,
                  ),
                  choice(
                    selected: _isPrivate,
                    onTap: () => setState(() => _isPrivate = true),
                    icon: CupertinoIcons.eye_slash_fill,
                    tone: TileTone.gray,
                    title: l10n.createRoomSheetVisibilityPrivateTitle,
                    sub: l10n.createRoomSheetVisibilityPrivateSub,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              header(l10n.createRoomSheetTypeLabel),
              SheetGroup(
                children: [
                  choice(
                    selected: _type == RoomType.regular,
                    onTap: () => setState(() => _type = RoomType.regular),
                    icon: CupertinoIcons.chat_bubble_2_fill,
                    tone: TileTone.green,
                    title: l10n.createRoomSheetTypeStandardTitle,
                    sub: l10n.createRoomSheetTypeStandardSub,
                  ),
                  choice(
                    selected: _type == RoomType.secret,
                    onTap: () => setState(() => _type = RoomType.secret),
                    icon: CupertinoIcons.hourglass,
                    tone: TileTone.purple,
                    title: l10n.createRoomSheetTypeEphemeralTitle,
                    sub: l10n.createRoomSheetTypeEphemeralSub,
                  ),
                ],
              ),
              AnimatedSize(
                duration: theme.motionMed,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _type != RoomType.secret
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sentenceCaseOf(
                                        context,
                                        l10n.createRoomSheetMessageLifeLabel,
                                      ),
                                      style: theme.caption.copyWith(
                                        fontSize: 13,
                                        color: theme.inkMuted,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _fmtTtl(context, _ttl),
                                    style: theme.caption.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.accent,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final t in _ttls)
                                  SpringPress(
                                    onTap: () => setState(() => _ttl = t),
                                    child: AnimatedContainer(
                                      duration: theme.motionFast,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _ttl == t
                                            ? theme.accent
                                                .withValues(alpha: 0.18)
                                            : theme.ink.withValues(alpha: 0.07),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _fmtTtl(context, t),
                                        style: theme.body.copyWith(
                                          fontSize: 15,
                                          fontWeight: _ttl == t
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: _ttl == t
                                              ? theme.accent
                                              : theme.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
              // Password is independent of visibility: a public room can be
              // discoverable yet locked, a private room hidden yet open.
              const SizedBox(height: 22),
              PasswordField(
                label: l10n.createRoomSheetPasswordLabel,
                controller: _password,
                hint: l10n.createRoomSheetPasswordHint,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: theme.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(groupedRadius(theme)),
                  ),
                  child: Text(
                    _error!,
                    style: theme.body.copyWith(
                      fontSize: 15,
                      color: theme.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Semantics(
                label: l10n.createRoomSheetOpenRoomSemanticLabel,
                child: _busy
                    ? Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.ink.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            (theme.radiusXl * 0.8).clamp(6.0, 16.0),
                          ),
                        ),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CupertinoActivityIndicator(
                            radius: 9,
                            color: theme.inkMuted,
                          ),
                        ),
                      )
                    : SheetActionButton(
                        label: l10n.createRoomSheetOpenRoomButton,
                        onTap: _create,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
