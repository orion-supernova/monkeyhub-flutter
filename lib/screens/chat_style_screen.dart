import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

class ChatStyleScreen extends StatefulWidget {
  const ChatStyleScreen({super.key});

  @override
  State<ChatStyleScreen> createState() => _ChatStyleScreenState();
}

class _ChatStyleScreenState extends State<ChatStyleScreen> {
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

  void _set(ChatStyle v) => SettingsStore.instance.setChatStyle(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final current = SettingsStore.instance.chatStyle;
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
                    icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
                  ),
                ]),
                const SizedBox(height: 10),
                Text('chat style.', style: theme.displayMedium),
                const SizedBox(height: 10),
                Row(children: [
                  Container(width: 18, height: 1, color: theme.accent),
                  const SizedBox(width: 8),
                  Text('how the room looks', style: theme.caption),
                ]),
                const SizedBox(height: 28),
                _StyleCard(
                  label: 'CLASSIC',
                  sub: 'divider-bordered header, flat composer.',
                  active: current == ChatStyle.classic,
                  preview: const _ClassicPreview(),
                  onTap: () => _set(ChatStyle.classic),
                ),
                const SizedBox(height: 14),
                _StyleCard(
                  label: 'COMPACT',
                  sub: 'frosted pills floating over the conversation.',
                  active: current == ChatStyle.compact,
                  preview: const _CompactPreview(),
                  onTap: () => _set(ChatStyle.compact),
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
              ? [BoxShadow(color: theme.accent.withValues(alpha: 0.25), blurRadius: 18)]
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
                      decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('ACTIVE', style: theme.monoTiny.copyWith(color: theme.accent)),
                  ]),
              ],
            ),
            const SizedBox(height: 6),
            Text(sub, style: theme.monoTiny),
            const SizedBox(height: 14),
            Container(
              height: 140,
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

class _ClassicPreview extends StatelessWidget {
  const _ClassicPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top header: flat row of back-glyph · title bars · info-glyph,
        // separated from the conversation by a hairline divider.
        Row(
          children: [
            _flatGlyph(theme),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 70, height: 6, color: theme.inkSoft),
                  const SizedBox(height: 4),
                  Container(width: 40, height: 4, color: theme.inkMuted),
                ],
              ),
            ),
            _flatGlyph(theme),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: theme.divider),
        const SizedBox(height: 10),
        // Two stacked message-bar mocks
        Expanded(child: _bubble(theme, mine: false)),
        const SizedBox(height: 6),
        Expanded(child: _bubble(theme, mine: true)),
        const SizedBox(height: 10),
        Container(height: 1, color: theme.divider),
        const SizedBox(height: 8),
        // Bottom composer: bordered rect + accent circle send
        Row(
          children: [
            Expanded(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: theme.divider),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
            ),
          ],
        ),
      ],
    );
  }

  Widget _flatGlyph(AppTheme theme) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: theme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: theme.divider),
      ),
    );
  }

  Widget _bubble(AppTheme theme, {required bool mine}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: mine ? theme.accent.withValues(alpha: 0.20) : theme.surface,
            border: Border.all(
              color: mine ? theme.accent.withValues(alpha: 0.55) : theme.divider,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _CompactPreview extends StatelessWidget {
  const _CompactPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top header: glass back · glass pill · glass info
        Row(
          children: [
            _miniGlass(theme, shape: BoxShape.circle, width: 22, height: 22),
            const Spacer(),
            _miniPill(theme),
            const Spacer(),
            _miniGlass(theme, shape: BoxShape.circle, width: 22, height: 22),
          ],
        ),
        const SizedBox(height: 10),
        // Mid messages — overlap visually under the floating chrome
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: theme.divider),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Bottom composer: glass attach · glass field · glass tinted send
        Row(
          children: [
            _miniGlass(theme, shape: BoxShape.circle, width: 22, height: 22),
            const SizedBox(width: 6),
            Expanded(
              child: _miniGlass(theme, shape: BoxShape.rectangle, width: 0, height: 22, radius: 11),
            ),
            const SizedBox(width: 6),
            _miniGlass(theme, shape: BoxShape.circle, width: 22, height: 22, tinted: true),
          ],
        ),
      ],
    );
  }

  Widget _miniGlass(
    AppTheme theme, {
    required BoxShape shape,
    required double width,
    required double height,
    double radius = 0,
    bool tinted = false,
  }) {
    final base = tinted
        ? theme.accent.withValues(alpha: 0.50)
        : theme.surface.withValues(alpha: 0.55);
    return Container(
      width: width > 0 ? width : null,
      height: height,
      decoration: BoxDecoration(
        color: base,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null,
        border: Border.all(color: theme.accent.withValues(alpha: 0.30), width: 1),
        gradient: tinted
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
      ),
    );
  }

  Widget _miniPill(AppTheme theme) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(maxWidth: 90, minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: theme.accent.withValues(alpha: 0.30), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.35), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Container(width: 30, height: 4, color: theme.inkMuted),
        ],
      ),
    );
  }
}
