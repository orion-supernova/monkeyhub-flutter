import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import '../widgets/reply_indicator.dart';
import '../widgets/settings_pickers.dart';

/// How a reply shows the message it answers. A live reply in the chosen style
/// on top, drawn by the real [ReplyIndicator], and the four styles as a
/// checked list under it.
class ReplyStyleScreen extends StatelessWidget {
  const ReplyStyleScreen({super.key, required this.api});
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final current = SettingsStore.instance.replyStyle;
        GroupedRow option(ReplyStyle style, String title, String sub) =>
            GroupedRow.choice(
              title: title,
              subtitle: sub,
              selected: current == style,
              onTap: () {
                pickFeedback();
                SettingsStore.instance.setReplyStyle(style);
              },
            );
        return SettingsPage(
          title: l10n.settingsHubReplyStyle,
          children: [
            HeroPreview(
              valueKey: current,
              height: 210,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Center(child: _Preview(api: api, style: current)),
            ),
            GroupedSection(
              footer: l10n.replyStylePageFooter,
              children: [
                option(
                  ReplyStyle.quote,
                  l10n.settingsScreenValueReplyQuote,
                  l10n.replyQuoteSub,
                ),
                option(
                  ReplyStyle.classic,
                  l10n.settingsScreenValueClassic,
                  l10n.replyClassicSub,
                ),
                option(
                  ReplyStyle.phantomEcho,
                  l10n.settingsScreenValueReplyPhantomEcho,
                  l10n.replyPhantomSub,
                ),
                option(
                  ReplyStyle.stickyNote,
                  l10n.settingsScreenValueReplyStickyNote,
                  l10n.replyStickySub,
                ),
                option(
                  ReplyStyle.comicTail,
                  l10n.settingsScreenValueReplyComicTail,
                  l10n.replyComicSub,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.api, required this.style});
  final ChatApi api;
  final ReplyStyle style;

  // Listens to the settings it reads: this widget is built `const`, and a
  // const widget is never rebuilt by its parent, so a changed setting would
  // otherwise leave it showing the old value.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsStore.instance,
        builder: (context, _) => _buildListening(context),
      );

  Widget _buildListening(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final parentPreview = ReplyPreview(
      senderId: 'alice',
      senderName: 'alice',
      contentPreview: l10n.callButtonReplyPreviewSampleMessage,
      type: MessageType.text,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReplyIndicator(
            preview: parentPreview,
            isMine: false,
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
          // In the bubble shape the user actually has, so the picture is the
          // room's, not a generic one.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: theme.bubbleDecoration(
              isMine: false,
              ephemeral: false,
              style: SettingsStore.instance.bubbleStyle,
            ),
            child: Text(
              l10n.callButtonReplyPreviewSampleReply,
              style: theme.body.copyWith(color: theme.ink),
            ),
          ),
        ],
      ),
    );
  }
}
