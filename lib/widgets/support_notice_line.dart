import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../models/enums.dart';
import 'notice.dart';

/// Leads the content of a staff notice posted into a chat by the MonkeyHub
/// Support account (`moderation.postNotice` server-side, `MOD_NOTICE_PREFIX`).
/// The server refuses a `system` message carrying it from anyone else, so a
/// match is trusted. Never change it: older notices keep the old text.
const String kSupportNoticePrefix = 'MonkeyHub Support: ';

/// Who signs the notice. The brand, so the same in every language.
const String kSupportNoticeTitle = 'MonkeyHub Support';

/// The notice's sentence if [content] of a [type] message is a staff notice,
/// else null.
String? supportNoticeBody(MessageType type, String content) {
  if (type != MessageType.system) return null;
  if (!content.startsWith(kSupportNoticePrefix)) return null;
  final body = content.substring(kSupportNoticePrefix.length).trim();
  return body.isEmpty ? null : body;
}

/// A staff notice in the timeline: centred, not a bubble, because it is the
/// service speaking to the room rather than a member. The shared [Notice]
/// block in the warn tone, signed "MonkeyHub Support".
class SupportNoticeLine extends StatelessWidget {
  const SupportNoticeLine({super.key, required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Notice(
              body,
              title: kSupportNoticeTitle,
              tone: NoticeTone.warn,
              icon: CupertinoIcons.shield_lefthalf_fill,
            ),
          ),
        ),
      ),
    );
  }
}
