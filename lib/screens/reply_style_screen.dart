import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/reply_indicator.dart';

/// Picker for the inline reply indicator's visual style. Each card shows a
/// live preview rendered against a sample (Alice → Bob) reply pair. Tapping
/// a card commits the choice to [SettingsStore.replyStyle] and updates the
/// border to mark it active.
class ReplyStyleScreen extends StatefulWidget {
  const ReplyStyleScreen({super.key, required this.api});
  final ChatApi api;

  @override
  State<ReplyStyleScreen> createState() => _ReplyStyleScreenState();
}

class _ReplyStyleScreenState extends State<ReplyStyleScreen> {
  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    SettingsStore.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _set(ReplyStyle v) => SettingsStore.instance.setReplyStyle(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final current = SettingsStore.instance.replyStyle;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back,
                        color: theme.inkSoft, size: 18),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('reply style.', style: theme.displayMedium),
                const SizedBox(height: 10),
                Row(children: [
                  Container(width: 18, height: 1, color: theme.accent),
                  const SizedBox(width: 8),
                  Text('how a reply shows its parent', style: theme.caption),
                ]),
                const SizedBox(height: 28),
                _StyleCard(
                  label: 'PHANTOM ECHO',
                  sub:
                      'a ghost-bubble of the parent floats above with a curved connector and the branch icon at the join point.',
                  active: current == ReplyStyle.phantomEcho,
                  preview: _Preview(
                    api: widget.api,
                    style: ReplyStyle.phantomEcho,
                  ),
                  onTap: () => _set(ReplyStyle.phantomEcho),
                ),
                const SizedBox(height: 14),
                _StyleCard(
                  label: 'STICKY NOTE',
                  sub:
                      'a slightly rotated polaroid-style card clipped to the bubble corner.',
                  active: current == ReplyStyle.stickyNote,
                  preview: _Preview(
                    api: widget.api,
                    style: ReplyStyle.stickyNote,
                  ),
                  onTap: () => _set(ReplyStyle.stickyNote),
                ),
                const SizedBox(height: 14),
                _StyleCard(
                  label: 'COMIC TAIL',
                  sub:
                      'a small parent mini-bubble with a comic-book triangle tail pointing down.',
                  active: current == ReplyStyle.comicTail,
                  preview: _Preview(
                    api: widget.api,
                    style: ReplyStyle.comicTail,
                  ),
                  onTap: () => _set(ReplyStyle.comicTail),
                ),
                const SizedBox(height: 14),
                _StyleCard(
                  label: 'CLASSIC',
                  sub:
                      'accent-tinted quote pill with a tether bar and avatar — the familiar WhatsApp-style look.',
                  active: current == ReplyStyle.classic,
                  preview: _Preview(
                    api: widget.api,
                    style: ReplyStyle.classic,
                  ),
                  onTap: () => _set(ReplyStyle.classic),
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

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.label,
    required this.sub,
    required this.active,
    required this.preview,
    required this.onTap,
  });
  final String label;
  final String sub;
  final bool active;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(
            color: active ? theme.accent : theme.divider,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.25),
                    blurRadius: 18,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.label)),
                if (active)
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: theme.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('ACTIVE',
                        style: theme.monoTiny.copyWith(color: theme.accent)),
                  ]),
              ],
            ),
            const SizedBox(height: 6),
            Text(sub, style: theme.monoTiny),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                borderRadius: BorderRadius.circular(theme.radiusMd),
                border: Border.all(color: theme.divider),
              ),
              child: preview,
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.api, required this.style});
  final ChatApi api;
  final ReplyStyle style;

  static const _parentPreview = ReplyPreview(
    senderId: 'alice',
    senderName: 'alice',
    contentPreview: 'hey did you see the new demo though?',
    type: MessageType.text,
  );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReplyIndicator(
            preview: _parentPreview,
            isMine: false,
            distanceLabel: null,
            api: api,
            onTap: () {},
            onViewThread: () {},
            parentAuthor: ChatUser(
              id: 'alice',
              username: 'alice',
              name: 'alice',
            ),
            styleOverride: style,
          ),
          // Sample reply bubble (theirs side, surfaceRaised) so previews are
          // visually grounded — picker viewers see "this is how a reply
          // looks attached to a bubble."
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: theme.surfaceRaised,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: const Radius.circular(6),
                bottomRight: const Radius.circular(20),
              ),
            ),
            child: Text(
              'yeah, that blur is sick.',
              style: theme.body.copyWith(color: theme.ink),
            ),
          ),
        ],
      ),
    );
  }
}
