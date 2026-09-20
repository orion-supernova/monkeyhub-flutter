import 'package:flutter/foundation.dart';

import '../l10n/generated/app_localizations.dart';
import '../media/file_meta.dart';
import 'drop_classifier.dart';
import 'drop_item.dart';

/// What the verdict chip says, and in what tone.
@immutable
class DropMessage {
  const DropMessage({required this.headline, required this.tone, this.detail});

  /// One short line: what letting go would DO.
  final String headline;

  /// The caveat, when there is one. Null is the common case and the chip
  /// collapses to a single line for it.
  final String? detail;

  final DropTone tone;

  @override
  bool operator ==(Object other) =>
      other is DropMessage &&
      other.headline == headline &&
      other.detail == detail &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(headline, detail, tone);
}

/// Turns a plan into the sentence the user reads WHILE the file is in the air.
///
/// Split out of the widget for two reasons. It is the part worth testing —
/// "three photos and a folder over a room a guardian has restricted" has one
/// right answer and a dozen plausible wrong ones — and it is the part the
/// post-drop notice needs to reuse, because a browser only learns what it was
/// carrying at the moment it lands. See [dropLandingNotice].
DropMessage dropMessage(
  AppLocalizations l10n, {
  required DropPlan plan,
  String? targetLabel,
  bool hasTarget = true,
}) {
  if (!hasTarget) {
    return DropMessage(
      headline: l10n.dropHintNoTarget,
      tone: DropTone.refuse,
    );
  }
  if (!plan.sendsAnything) {
    return DropMessage(
      headline: _refusalLine(l10n, plan) ?? l10n.dropNothingToSend,
      tone: DropTone.refuse,
    );
  }

  final headline = _acceptLine(l10n, plan);
  final detail = _cautionLine(l10n, plan) ??
      (targetLabel == null ? null : l10n.dropTargetTo(targetLabel));
  return DropMessage(headline: headline, detail: detail, tone: plan.tone);
}

/// The sentence shown AFTER a drop, or null when the drop was unremarkable.
///
/// This is the half of the feature a browser cannot do any other way. On macOS
/// every caveat was already on screen before the user let go; on web the names
/// and sizes arrive with the drop itself, so "that one went as a file" and
/// "that one was too big" can only be said afterwards. Returning null for a
/// clean drop is deliberate — a toast that fires on every successful send is
/// noise, and the transcript is already the confirmation.
String? dropLandingNotice(AppLocalizations l10n, DropPlan plan) {
  final refusal = _refusalLine(l10n, plan);
  if (refusal != null) return refusal;
  return _cautionLine(l10n, plan);
}

/// A short word for one dragged thing — what the ghost card is labelled with
/// when there is no filename to show, which in a browser is always.
String dropKindWord(AppLocalizations l10n, DropKind kind) {
  switch (kind) {
    case DropKind.photo:
      return l10n.dropKindPhoto;
    case DropKind.video:
      return l10n.dropKindVideo;
    case DropKind.audio:
      return l10n.dropKindAudio;
    case DropKind.folder:
      return l10n.dropKindFolder;
    case DropKind.text:
      return l10n.dropKindText;
    case DropKind.link:
      return l10n.dropKindLink;
    case DropKind.document:
    case DropKind.unknown:
      return l10n.dropKindFile;
  }
}

// ──────────────────────────────── internals ────────────────────────────────

String _acceptLine(AppLocalizations l10n, DropPlan plan) {
  final accepted = plan.accepted;
  if (accepted.isEmpty) {
    // Text or a link with no files beside it. A draft, not a message — the
    // wording says "add", because nothing is sent by letting go.
    if (plan.carriesLink && !plan.carriesText) return l10n.dropSendLink;
    return l10n.dropSendText;
  }
  final n = accepted.length;
  if (plan.photoCount == n) return l10n.dropSendPhotos(n);
  if (plan.videoCount == n) return l10n.dropSendVideos(n);
  if (plan.audioCount == n) return l10n.dropSendAudio(n);
  if (plan.documentCount == n) return l10n.dropSendFiles(n);
  return l10n.dropSendItems(n);
}

/// Why nothing can be sent. Null when something can.
String? _refusalLine(AppLocalizations l10n, DropPlan plan) {
  final refused = plan.refused;
  if (refused.isEmpty) return null;
  // Only spoken as a REFUSAL when it is the whole story. A folder dragged in
  // beside three photographs is a caution, not a refusal, and is handled by
  // [_cautionLine] instead.
  if (plan.sendsAnything) return null;
  switch (plan.soleRefusal) {
    case DropRefusal.folder:
      return l10n.dropNoticeFolder;
    case DropRefusal.notPermitted:
      return l10n.dropNoticeNotAllowed;
    case DropRefusal.tooLarge:
      return l10n.dropNoticeTooLarge(
        refused.length,
        formatFileSize(kMaxFileUploadBytes),
      );
    case DropRefusal.empty:
      return l10n.dropNoticeEmpty(refused.length);
    case DropRefusal.batchFull:
      // Only reachable when the budget was spent entirely on items that then
      // turned out to be unsendable for their own reasons, which is a shape
      // worth answering rather than falling through to "nothing to send".
      return l10n.dropNoticeBatchFull(refused.length);
    case null:
      return l10n.dropNothingToSend;
  }
}

/// The one caveat worth the line, in descending order of consequence.
///
/// Exactly one, never a list. A chip that stacks three warnings is a chip
/// nobody finishes reading, and the ordering here is the ordering of regret:
/// a file that will not arrive at all matters more than one that arrives
/// looking different from what was expected.
String? _cautionLine(AppLocalizations l10n, DropPlan plan) {
  final refused = plan.refused;
  if (refused.isNotEmpty) {
    final byKind = <DropRefusal, int>{};
    for (final item in refused) {
      final r = item.refusal;
      if (r != null) byKind[r] = (byKind[r] ?? 0) + 1;
    }
    final tooLarge = byKind[DropRefusal.tooLarge] ?? 0;
    if (tooLarge > 0) {
      return l10n.dropNoticeTooLarge(
        tooLarge,
        formatFileSize(kMaxFileUploadBytes),
      );
    }
    if ((byKind[DropRefusal.notPermitted] ?? 0) > 0) {
      return l10n.dropNoticeNotAllowed;
    }
    // Above folders and empties: a file left out of the batch is one the user
    // deliberately selected and would otherwise assume had been sent, where a
    // folder is something they already know cannot go.
    final batchFull = byKind[DropRefusal.batchFull] ?? 0;
    if (batchFull > 0) return l10n.dropNoticeBatchFull(batchFull);
    if ((byKind[DropRefusal.folder] ?? 0) > 0) return l10n.dropNoticeFolder;
    final empty = byKind[DropRefusal.empty] ?? 0;
    if (empty > 0) return l10n.dropNoticeEmpty(empty);
  }
  if (plan.downgradedCount > 0) return l10n.dropNoticeAsFile(plan.downgradedCount);
  if (plan.fragileCount > 0) return l10n.dropNoticeFragile(plan.fragileCount);
  return null;
}
