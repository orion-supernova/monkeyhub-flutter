import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../media/image_raster.dart';
import '../media/upload_service.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/chrome_motion.dart';
import '../widgets/invite_chips.dart';
import '../widgets/ios_kit.dart';
import '../widgets/labeled_field.dart';
import '../widgets/message_life_picker.dart';
import '../widgets/password_field.dart';
import '../widgets/room_kind_segment.dart';
import '../widgets/room_preview_card.dart';
import '../widgets/sheet_kit.dart';
import '../l10n/text_case.dart';
import '../backend/server_limits.dart';
import 'image_crop_screen.dart';
import 'room_screen.dart';

/// The new-room sheet: one living card you shape.
///
/// A preview of the room sits pinned at the top and reacts to every choice
/// (name, picture, who is invited, regular or secret, who can find it). Under it
/// are four short sections: Name, People, Room, Who can find it. The room kind
/// is just Regular or Secret: a secret room's messages always disappear and
/// screenshots are always blocked, and choosing it reveals the shared
/// [MessageLifePicker].
///
/// "Open the room" creates the room, invites everyone picked, then the card
/// squashes, bounces and flies up as the sheet hands over to the room. Calm
/// motion skips the flight.
class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({
    super.key,
    required this.repo,
    required this.api,
    this.pickPicture,
  });
  final ChatRepository repo;
  final ChatApi api;

  /// Picks and crops a room picture. Null uses the real flow (library picker,
  /// then the circle crop room info uses); tests inject a stand-in.
  final Future<CroppedImage?> Function(BuildContext context)? pickPicture;
  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _password = TextEditingController();

  /// The cropped room picture, or null while the card wears the default face.
  CroppedImage? _picture;

  /// Seeds the default face's colour for the life of the sheet, so typing a
  /// name changes the letter but never the hue.
  final String _avatarSeed = 'new-room-${DateTime.now().microsecondsSinceEpoch}';

  bool _isPrivate = true;
  bool _passwordOn = false;
  bool _descOpen = false;
  RoomType _type = RoomType.regular;
  MessageLife _life = kDefaultMessageLife;
  final List<String> _picked = [];
  bool _busy = false;
  String? _error;

  /// The card's squash, bounce and flight after a successful create.
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );
  bool _flying = false;

  /// Marks the timer picker so choosing Secret can scroll it into view.
  final _lifeKey = GlobalKey();

  List<ChatUser> get _friends => widget.repo.friends;

  List<ChatUser> get _pickedUsers {
    final all = _friends;
    return [
      for (final id in _picked)
        for (final u in all)
          if (u.id == id) u,
    ];
  }

  String _fmtTtl(AppLocalizations l10n, Duration d) {
    if (d.inSeconds < 60) return l10n.createRoomSheetTtlSeconds(d.inSeconds);
    if (d.inMinutes < 60) return l10n.createRoomSheetTtlMinutes(d.inMinutes);
    return l10n.createRoomSheetTtlHours(d.inHours);
  }

  /// The preview card's one-line subtitle, e.g.
  /// "Invite only · you + 2 · secret · 1m after seen".
  String _subtitle(AppLocalizations l10n) {
    final parts = <String>[
      _isPrivate ? l10n.newRoomFindInviteOnly : l10n.newRoomFindFindable,
      if (_passwordOn) l10n.newRoomSubLocked,
      _picked.isEmpty
          ? l10n.newRoomSubJustYou
          : l10n.newRoomPeopleYouPlus(_picked.length),
      if (_type == RoomType.secret)
        _life.clock == MessageClock.seen
            ? l10n.newRoomSubSecretSeen(_fmtTtl(l10n, _life.lifetime))
            : l10n.newRoomSubSecretSent(_fmtTtl(l10n, _life.lifetime))
      else
        l10n.newRoomSubRegular,
    ];
    return parts.join(' · ');
  }

  /// Pick and crop a picture exactly like room info does (gallery, then the
  /// circle crop). Nothing is uploaded until the room exists.
  Future<void> _pickPicture() async {
    final custom = widget.pickPicture;
    CroppedImage? cropped;
    if (custom != null) {
      cropped = await custom(context);
    } else {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: pickerImageQuality,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      cropped = await ImageCropScreen.open(
        context,
        source: bytes,
        shape: CropShape.circle,
      );
    }
    if (cropped == null || !mounted) return;
    setState(() => _picture = cropped);
  }

  void _setType(RoomType t) {
    setState(() => _type = t);
    if (t != RoomType.secret) return;
    // The picker grows in under the choice; bring it into view once it has
    // its height, so the new options are not hiding below the fold.
    final scroll =
        MotionScope.of(context).d(const Duration(milliseconds: 320));
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      final c = _lifeKey.currentContext;
      if (!mounted || c == null || !c.mounted) return;
      Scrollable.ensureVisible(
        c,
        alignment: 0.6,
        duration: scroll,
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _toggle(ChatUser u) {
    setState(() {
      if (!_picked.remove(u.id)) _picked.add(u.id);
    });
  }

  Future<void> _uploadPicture(String roomId, CroppedImage picture) async {
    final me = widget.repo.userId;
    if (me == null) return;
    try {
      final storageId = await UploadService(widget.api).uploadFile(
        bytes: picture.bytes,
        contentType: picture.contentType,
      );
      await widget.api.updateRoomAvatar(
          roomId: roomId, userId: me, storageId: storageId);
    } catch (e) {
      // The room already exists and works; it just keeps the default face.
      debugPrint('new room: picture upload failed: $e');
    }
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = l10n.createRoomSheetNameRequiredError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final secret = _type == RoomType.secret;
      final life = normalizeMessageLife(_life);
      // Read before the first await: the toast host that outlives this sheet.
      final toast = AppToast.onOverlay(
        Navigator.of(context, rootNavigator: true).overlay,
      );
      final id = await widget.repo.createRoom(
        name: n,
        isPrivate: _isPrivate,
        description: _descOpen && _desc.text.trim().isNotEmpty
            ? _desc.text.trim()
            : null,
        password: _passwordOn && _password.text.isNotEmpty ? _password.text : null,
        type: _type,
        messageLifetime: secret ? life.lifetime : null,
        messageClock: secret ? life.clock.name : null,
      );
      // The already-cropped picture is uploaded and set in the background:
      // the room opens now, the picture lands a moment later.
      final picture = _picture;
      if (picture != null) unawaited(_uploadPicture(id, picture));
      // Invite everyone picked, all at once. One person failing (they turned
      // invitations off, say) must not stop the room from opening, but the
      // creator is told who wasn't invited rather than left to find out.
      final failed = <String>[];
      if (_picked.isNotEmpty) {
        final byId = {for (final u in _friends) u.id: u};
        await Future.wait([
          for (final p in _picked)
            widget.repo
                .inviteToRoom(roomId: id, inviteeId: p)
                .then<void>((_) {}, onError: (Object _) {
              failed.add(byId[p]?.displayName ?? byId[p]?.username ?? '');
            }),
        ]);
        failed.removeWhere((n) => n.isEmpty);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await _flyAway();
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (context.usesSplitShell) {
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
      if (failed.isNotEmpty) {
        toast?.show(l10n.newRoomInviteFailed(failed.join(', ')),
            tone: ToastTone.danger);
      }
    } catch (e) {
      final s = e.toString();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _flying = false;
        // The language filter on the name or description, said in words.
        _error = s.contains('NAME_INAPPROPRIATE')
            ? AppLocalizations.of(context).nameInappropriate
            : friendlyServerError(e, AppLocalizations.of(context), s);
      });
    }
  }

  /// Squash, bounce, fly. Skipped under calm motion (the route change is the
  /// crossfade).
  Future<void> _flyAway() async {
    if (MotionScope.of(context).calm) return;
    setState(() => _flying = true);
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) HapticFeedback.lightImpact();
    });
    await _flight.forward(from: 0);
  }

  /// The card's transform at flight time [t] (0..1).
  Matrix4 _flightMatrix(double t) {
    double sx = 1, sy = 1, dy = 0;
    if (t < 0.28) {
      // Squash down.
      final s = Curves.easeOut.transform(t / 0.28);
      sx = 1 + 0.07 * s;
      sy = 1 - 0.13 * s;
    } else if (t < 0.52) {
      // Spring back past rest into a stretch, hopping up a little.
      final s = Curves.easeOutBack.transform((t - 0.28) / 0.24);
      sx = 1.07 + (0.94 - 1.07) * s;
      sy = 0.87 + (1.10 - 0.87) * s;
      dy = -10 * s;
    } else {
      // Take off.
      final u = Curves.easeInCubic.transform((t - 0.52) / 0.48);
      sx = 0.94 + (0.86 - 0.94) * u;
      sy = 1.10 + (0.86 - 1.10) * u;
      dy = -10 - 260 * u;
    }
    return Matrix4.identity()
      ..translateByDouble(0, dy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1);
  }

  @override
  void dispose() {
    _flight.dispose();
    _name.dispose();
    _desc.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final secret = _type == RoomType.secret;

    Widget card = RoomPreviewCard(
      name: _name.text,
      picture: _picture?.bytes,
      avatarSeed: _avatarSeed,
      onPictureTap: _pickPicture,
      onPictureClear: () => setState(() => _picture = null),
      pictureSemantic: l10n.newRoomPictureSemantic,
      pictureClearSemantic: l10n.newRoomPictureRemoveSemantic,
      subtitle: _subtitle(l10n),
      secret: secret,
      people: _pickedUsers,
      api: widget.api,
    );
    card = AnimatedBuilder(
      animation: _flight,
      builder: (context, child) => Transform(
        alignment: Alignment.bottomCenter,
        transform: _flying ? _flightMatrix(_flight.value) : Matrix4.identity(),
        child: child,
      ),
      child: card,
    );

    return SheetFrame(
      title: sentenceCaseOf(context, l10n.createRoomSheetTitle),
      maxHeightFraction: context.isCompact ? 0.92 : null,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      footer: Semantics(
        label: l10n.createRoomSheetOpenRoomSemanticLabel,
        child: SheetActionButton(
          label: l10n.createRoomSheetOpenRoomButton,
          busy: _busy,
          onTap: (_busy || _flying) ? null : _create,
        ),
      ),
      child: DefaultTextStyle(
        style: theme.body.copyWith(color: theme.ink),
        child: IgnorePointer(
          ignoring: _flying,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: card,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GroupedHeader(l10n.createRoomSheetNameLabel),
                      ThemedInput(
                        controller: _name,
                        hint: l10n.createRoomSheetNameHint,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                      AnimatedSize(
                        duration: MotionScope.of(context)
                            .d(const Duration(milliseconds: 260)),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _descOpen
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: ThemedInput(
                                  controller: _desc,
                                  hint: l10n.createRoomSheetDescriptionHint,
                                  autofocus: true,
                                  textInputAction: TextInputAction.done,
                                  // Same guard as the button, so Enter can't
                                  // create a room the button is refusing to.
                                  onSubmitted: (_) => _busy ? null : _create(),
                                ),
                              )
                            : Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: SpringPress(
                                  onTap: () => setState(() => _descOpen = true),
                                  focusRadius: 10,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      l10n.newRoomAddDescription,
                                      style: theme.bodyEmph.copyWith(
                                        color: theme.accent,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      GroupedHeader(
                        l10n.newRoomSectionPeople,
                        trailing: InviteCount(count: _picked.length),
                      ),
                      InviteChips(
                        friends: _friends,
                        selected: _picked,
                        onToggle: _toggle,
                        api: widget.api,
                      ),
                      const SizedBox(height: 14),
                      GroupedHeader(l10n.newRoomSectionRoom),
                      RoomKindSegment(
                        value: _type,
                        regularLabel: l10n.newRoomKindRegular,
                        secretLabel: l10n.newRoomKindSecret,
                        onChanged: _setType,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                        child: SlideSwap(
                          child: Text(
                            secret
                                ? l10n.newRoomKindSecretDesc
                                : l10n.newRoomKindRegularDesc,
                            key: ValueKey(secret),
                            style:
                                theme.caption.copyWith(color: theme.inkMuted),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: MotionScope.of(context)
                            .d(const Duration(milliseconds: 300)),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: !secret
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: MessageLifePicker(
                                  key: _lifeKey,
                                  value: _life,
                                  onChanged: (v) => setState(() => _life = v),
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      GroupedHeader(l10n.newRoomSectionFind),
                      IosSegmentedControl<bool>(
                        segments: [
                          IosSegment(
                            value: true,
                            label: l10n.newRoomFindInviteOnly,
                          ),
                          IosSegment(
                            value: false,
                            label: l10n.newRoomFindFindable,
                          ),
                        ],
                        value: _isPrivate,
                        onChanged: (v) => setState(() => _isPrivate = v),
                      ),
                      // Password is independent of visibility: a findable room
                      // can be locked, an invite-only room open.
                      const SizedBox(height: 6),
                      SpringPress(
                        onTap: () => setState(() => _passwordOn = !_passwordOn),
                        focusRadius: 12,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.newRoomPasswordSwitch,
                                  style: theme.body.copyWith(color: theme.ink),
                                ),
                              ),
                              IgnorePointer(
                                child: RowSwitch(
                                  value: _passwordOn,
                                  onChanged: (_) {},
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: MotionScope.of(context)
                            .d(const Duration(milliseconds: 280)),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: !_passwordOn
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: PasswordField(
                                  controller: _password,
                                  hint: l10n.createRoomSheetPasswordHint,
                                ),
                              ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        FormErrorBanner(_error!),
                      ],
                    ],
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
