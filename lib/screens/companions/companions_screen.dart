/// Settings › Companions. The hub.
///
/// Two rows and a storage line. It exists rather than putting Sebastian
/// straight in Settings because there are now two residents and there will be
/// more, and because the one number a person actually comes here for — how
/// much disk this is costing — belongs to the group rather than to either of
/// them.
library;

import 'package:flutter/material.dart';

import '../../companions/brain_manager.dart';
import '../../companions/brain_spec.dart';
import '../../companions/companion.dart';
import '../../companions/sebastian.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import 'companion_page.dart';
import 'sebastian_screen.dart';
import 'vera_screen.dart';

class CompanionsScreen extends StatefulWidget {
  const CompanionsScreen({super.key});

  @override
  State<CompanionsScreen> createState() => _CompanionsScreenState();
}

class _CompanionsScreenState extends State<CompanionsScreen> {
  @override
  void initState() {
    super.initState();
    BrainManager.instance.addListener(_onChange);
    SettingsStore.instance.addListener(_onChange);
    // The disk is the authority on what is installed, and nothing has
    // necessarily asked it yet this session.
    BrainManager.instance.refresh();
  }

  @override
  void dispose() {
    BrainManager.instance.removeListener(_onChange);
    SettingsStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final sebastian = Sebastian.instance;

    return CompanionPage(
      title: l10n.companionsScreenTitle,
      subtitle: l10n.companionsScreenSubtitle,
      children: [
        if (!sebastian.isAvailable) ...[
          CompanionCard(
            children: [
              Text(
                l10n.companionUnsupportedPlatform,
                style: theme.body.copyWith(color: theme.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _CompanionRow(
          companion: Companion.sebastian,
          status: _sebastianStatus(l10n),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SebastianScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _CompanionRow(
          companion: Companion.vera,
          status: _veraStatus(l10n),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VeraScreen()),
          ),
        ),
        const SizedBox(height: 26),
        _StorageLine(theme: theme, l10n: l10n),
      ],
    );
  }

  /// The one line under Sebastian's name, in priority order: what is stopping
  /// him working, or else what he is doing.
  String _sebastianStatus(AppLocalizations l10n) {
    final s = Sebastian.instance;
    if (!s.isInstalled) return l10n.companionStatusNotInstalled;
    if (!s.isEnabled) return l10n.companionStatusOff;
    return l10n.companionStatusTranslatingInto(s.targetLanguage.autonym);
  }

  String _veraStatus(AppLocalizations l10n) {
    final installed = BrainCatalog.veraBrains
        .where(BrainManager.instance.isInstalled)
        .length;
    if (installed == 0) return l10n.companionStatusNoBrain;
    return l10n.companionStatusBrainsReady(installed);
  }
}

class _CompanionRow extends StatelessWidget {
  const _CompanionRow({
    required this.companion,
    required this.status,
    required this.onTap,
  });

  final Companion companion;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            CompanionMark(
              companion: companion,
              size: 38,
              foreground: theme.accentInk,
              background: theme.accent,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companion.displayName, style: theme.bodyEmph),
                  const SizedBox(height: 3),
                  Text(
                    companion.tagline(l10n),
                    style: theme.caption.copyWith(color: theme.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: theme.caption.copyWith(color: theme.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// What the companions cost, in the only unit anyone cares about.
///
/// Counts a shared brain once — Sebastian's is the first row of Vera's shelf,
/// so a naive sum would report 656 MB for 328 MB of files. See
/// [BrainManager.installedBytes].
class _StorageLine extends StatelessWidget {
  const _StorageLine({required this.theme, required this.l10n});

  final AppTheme theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final bytes = BrainManager.instance.installedBytes;
    return Row(
      children: [
        Icon(Icons.sd_storage_outlined, size: 14, color: theme.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            bytes == 0
                ? l10n.companionStorageEmpty
                : l10n.companionStorageUsed(_label(bytes)),
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
        ),
      ],
    );
  }

  static String _label(int bytes) {
    const mib = 1024 * 1024;
    if (bytes >= 1024 * mib) {
      return '${(bytes / (1024 * mib)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / mib).round()} MB';
  }
}
