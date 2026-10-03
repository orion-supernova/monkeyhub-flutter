import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/username_availability_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/labeled_field.dart';
import '../widgets/username_status_label.dart';
import 'pairing_code_screen.dart';
import '../widgets/ios_kit.dart';
import '../widgets/prominent_button.dart';
import '../widgets/sheet_kit.dart' show sentenceCaseOf;

/// Creates a child account, then goes straight to pairing.
///
/// There's deliberately no password field: a child account has no usable
/// password (`auth.login` refuses them outright), so a guardian-issued code is
/// the only way in. That removes a credential a child could carry to another
/// device, and one more thing for a parent to invent and remember.
class ChildSetupScreen extends StatefulWidget {
  const ChildSetupScreen({
    super.key,
    required this.api,
    required this.guardianId,
  });

  final ChatApi api;
  final String guardianId;

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Live "is this free?" for the handle being minted for the child.
  ///
  /// The guardian is picking a name for someone who does not exist yet, so this
  /// is the same question the adult signup form asks, asked by a third party.
  late final _availability = UsernameAvailabilityController(api: widget.api);

  @override
  void dispose() {
    _availability.dispose();
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final username = _username.text.trim();
    final name = _name.text.trim();
    if (username.isEmpty) {
      setState(() =>
          _error = AppLocalizations.of(context).childSetupScreenErrorPickUsername);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      final res = await widget.api.createChildAccount(
        guardianId: widget.guardianId,
        username: username,
        name: name.isEmpty ? username : name,
      );
      if (!mounted) return;
      // Straight into pairing — an unpaired child account is useless, so
      // don't make the parent find a second button. `pushReplacement` so
      // Back from pairing lands on the dashboard, not this form.
      nav.pushReplacement(MaterialPageRoute(
        builder: (_) => PairingCodeScreen(
          api: widget.api,
          guardianId: widget.guardianId,
          child: ChatUser(
            id: res.userId,
            username: res.username,
            name: res.name,
          ),
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(Object e) {
    final s = e.toString();
    final l10n = AppLocalizations.of(context);
    if (s.contains('USERNAME_TAKEN')) return l10n.childSetupScreenErrorUsernameTaken;
    if (s.contains('USERNAME_REQUIRED')) return l10n.childSetupScreenErrorPickUsername;
    if (s.contains('CHILD_NOT_ALLOWED')) {
      return l10n.childSetupScreenErrorChildNotAllowed;
    }
    return l10n.childSetupScreenErrorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Row(
                    children: [
                      const GlassBackButton(),
                      const SizedBox(width: 12),
                      Text(
                        sentenceCaseOf(context, l10n.childSetupScreenTitle),
                        style: theme.bodyEmph.copyWith(color: theme.ink),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.childSetupHeadingIos,
                          style: theme.displayLarge.copyWith(letterSpacing: 0.37),
                        ),
                        const SizedBox(height: 24),
                        LabeledField(
                          label: l10n.childSetupScreenNameLabel,
                          controller: _name,
                          hint: l10n.childSetupScreenNameHint,
                        ),
                        const SizedBox(height: 16),
                        LabeledField(
                          label: l10n.childSetupScreenUsernameLabel,
                          controller: _username,
                          hint: l10n.childSetupScreenUsernameHint,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: _availability.onChanged,
                        ),
                        UsernameStatusLabel(controller: _availability),
                        const SizedBox(height: 24),
                        GroupedSection(
                          header: sentenceCaseOf(
                            context,
                            l10n.childSetupScreenWhatTheyGetTitle,
                          ),
                          margin: EdgeInsets.zero,
                          children: [
                            _Bullet(l10n.childSetupScreenBulletTalkImmediately),
                            _Bullet(l10n.childSetupScreenBulletNeedsApproval),
                            _Bullet(l10n.childSetupScreenBulletPublicRoomsOff),
                            _Bullet(l10n.childSetupScreenBulletCantSignOut),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            decoration: BoxDecoration(
                              color: theme.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                groupedRadius(theme) * 0.6,
                              ),
                            ),
                            child: Text(_error!,
                                style:
                                    theme.body.copyWith(color: theme.danger)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ProminentButton(
                          label: sentenceCaseOf(
                            context,
                            l10n.childSetupScreenCreateButton,
                          ),
                          busy: _busy,
                          onTap: _busy ? null : _create,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One thing the child's account comes with, as a grouped row with a check.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 12),
            child: Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 18,
              color: theme.success,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.body.copyWith(fontSize: 15, color: theme.ink),
            ),
          ),
        ],
      ),
    );
  }
}
