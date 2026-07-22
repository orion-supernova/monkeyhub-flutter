import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/labeled_field.dart';
import 'pairing_code_screen.dart';

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

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final username = _username.text.trim();
    final name = _name.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Pick a username for them.');
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
    if (s.contains('USERNAME_TAKEN')) return 'That username is already taken.';
    if (s.contains('USERNAME_REQUIRED')) return 'Pick a username for them.';
    if (s.contains('CHILD_NOT_ALLOWED')) {
      return 'Only a grown-up account can add a child.';
    }
    return 'Couldn\'t create the account — try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.arrow_back,
                            size: 20, color: theme.inkSoft),
                      ),
                      const SizedBox(width: 14),
                      Text('ADD A CHILD',
                          style: theme.label.copyWith(letterSpacing: 2.8)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('who\nare they?', style: theme.displayHero),
                        const SizedBox(height: 24),
                        LabeledField(
                          label: 'NAME',
                          controller: _name,
                          hint: 'what you call them',
                        ),
                        const SizedBox(height: 16),
                        LabeledField(
                          label: 'USERNAME',
                          controller: _username,
                          hint: 'how friends find them',
                          autocorrect: false,
                          enableSuggestions: false,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.surfaceSunken,
                            border: Border.all(color: theme.divider),
                            borderRadius:
                                BorderRadius.circular(theme.radiusMd),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WHAT THEY GET',
                                  style: theme.label.copyWith(
                                      letterSpacing: 2.4,
                                      color: theme.accent)),
                              const SizedBox(height: 12),
                              _Bullet('They can talk to you and their '
                                  'brothers and sisters right away.'),
                              _Bullet('Everyone else needs your OK first — '
                                  'both people they ask for, and people who '
                                  'ask for them.'),
                              _Bullet('Public rooms are switched off until '
                                  'you turn them on.'),
                              _Bullet('They can\'t sign out, and you can '
                                  'always see how they\'re doing.'),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            decoration: BoxDecoration(
                              color: theme.danger.withValues(alpha: 0.12),
                              border: Border(
                                left:
                                    BorderSide(color: theme.danger, width: 2),
                              ),
                              borderRadius:
                                  BorderRadius.circular(theme.radiusMd),
                            ),
                            child: Text(_error!,
                                style:
                                    theme.body.copyWith(color: theme.danger)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: _busy ? null : _create,
                          child: AnimatedContainer(
                            duration: theme.motionFast,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _busy ? theme.accentSoft : theme.accent,
                              borderRadius:
                                  BorderRadius.circular(theme.radiusMd),
                            ),
                            child: _busy
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.accentInk,
                                    ),
                                  )
                                : Text(
                                    'CREATE + PAIR',
                                    style: theme.label.copyWith(
                                      color: theme.accentInk,
                                      letterSpacing: 2.4,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.bodySoft)),
        ],
      ),
    );
  }
}
