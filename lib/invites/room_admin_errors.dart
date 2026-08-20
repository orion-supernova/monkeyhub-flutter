import '../l10n/generated/app_localizations.dart';

/// Backend error codes from `roomAdmin.ts`, `roomInvites.ts` and
/// `roomInvitations.ts`, in the shape `humanizeAuthError` takes as its
/// `overrides` argument.
///
/// Kept out of `authErrorMessages` on purpose. That map is consulted by every
/// screen in the app, and it is where a code like `REQUEST_NOT_FOUND` already
/// means something about a friend request. These are passed as overrides at
/// the handful of call sites that can actually produce them, which also makes
/// them win the substring match — `JOIN_REQUEST_NOT_FOUND` contains
/// `REQUEST_NOT_FOUND`, and without the override precedence the group copy
/// would lose to the friendship copy.
///
/// `USER_NOT_FOUND` and `UNBLOCK_FIRST` are deliberately absent: the shared map
/// already words both, and a room invite hitting them means exactly what it
/// means everywhere else.
Map<String, String> roomAdminErrorMessages(AppLocalizations l10n) => {
      // ── Rank ──────────────────────────────────────────────────────────────
      'NOT_A_MEMBER': l10n.roomAdminErrorNotMember,
      'NOT_ADMIN': l10n.roomAdminErrorNotAdmin,
      'NOT_OWNER': l10n.roomAdminErrorNotOwner,
      'NOT_A_GROUP': l10n.roomAdminErrorNotGroup,
      'OWNER_IMMUTABLE': l10n.roomAdminErrorOwnerImmutable,
      // Only reachable by a hand-made call — the sheet never offers "remove"
      // on your own row — but worded rather than left to the generic fallback,
      // because the generic one would send someone looking for a bug.
      'CANNOT_REMOVE_SELF': l10n.roomAdminErrorCannotRemoveSelf,
      'INVITES_ADMINS_ONLY': l10n.roomAdminErrorInvitesLocked,

      // ── The link ──────────────────────────────────────────────────────────
      //
      // Four separate sentences rather than one "invalid link", because the
      // right next move differs: a revoked or expired link means ask for a new
      // one, an exhausted link means ask the admin to raise the cap, and a
      // not-found link usually means a typo.
      'INVITE_REVOKED': l10n.roomInviteErrorRevoked,
      'INVITE_EXPIRED': l10n.roomInviteErrorExpired,
      'INVITE_EXHAUSTED': l10n.roomInviteErrorExhausted,
      'INVITE_NOT_FOUND': l10n.roomInviteErrorNotFound,
      'INVALID_EXPIRY': l10n.roomInviteErrorInvalidLimits,
      'INVALID_MAX_USES': l10n.roomInviteErrorInvalidLimits,
      'INVALID_JOIN_POLICY': l10n.roomAdminGenericError,

      // ── Invites and requests ──────────────────────────────────────────────
      'ALREADY_MEMBER': l10n.roomInviteErrorAlreadyMember,
      'ALREADY_INVITED': l10n.roomInviteErrorAlreadyInvited,
      'CANNOT_INVITE_SELF': l10n.roomInviteErrorSelf,
      'INVITATION_NOT_FOUND': l10n.roomInviteErrorInvitationGone,
      'JOIN_REQUEST_PENDING': l10n.roomInviteErrorRequestPending,
      'JOIN_REQUEST_NOT_FOUND': l10n.roomInviteErrorRequestGone,

      // Reachable from the Discover door, which no longer opens onto a private
      // room — the only ways in are a link somebody handed out and an invite
      // somebody sent.
      'ROOM_IS_PRIVATE': l10n.roomInviteErrorRoomPrivate,
    };
