/**
 * One rule per reference in the schema.
 *
 * Convex has no foreign keys, so every `v.id(...)` in `schema.ts` is a pointer
 * nothing enforces. This table is the stand-in for `ON DELETE ...`: it says,
 * for each reference path, what must happen to the child when the parent goes.
 * `referenceRules.test.ts` walks the schema (`schemaRefs.ts`) and fails when a
 * path has no entry here, an entry names a path that is gone, or a
 * `cascade`/`setNull` rule has no index to find its rows by.
 *
 * Keys are `"<table>.<path>"`, paths exactly as `schemaRefs` prints them
 * (`replyToPreview.senderId`, `mentions[].userId`).
 *
 * The rules (`rule`) are what SHOULD happen, from section 2 of
 * docs/data-integrity-and-scale-plan-2026-10-22.md. Where today's code does
 * something else, `today` says what; that is Phase 2's worklist. An entry with
 * no `today` is handled as the rule says (as of 2026-10-22, Phase 0 included).
 *
 *   cascade    delete the child with the parent
 *   setNull    unset the field, keep the row
 *   restrict   refuse the parent's deletion while the child exists
 *   history    a dead id is kept on purpose; readers must handle a missing target
 *   ephemeral  short-lived row, swept by a TTL cron, so a dead id has a bounded life
 *   softRef    a documented soft pointer (readers tolerate a missing target)
 *   file       a `_storage` reference, handled by the Phase 3 refcounts; `why`
 *              names who owns the file
 *
 * `index`: the index whose FIRST field is this path, used to find the children
 * of a given parent. `via`: when the path cannot be indexed (arrays, nested
 * fields, or no index worth having), the name of an index on the same table
 * whose first field is a different field the rows are found through (say
 * `roomId`); the cleanup then walks those rows and edits the field.
 */

export type ReferenceRuleKind =
  | "cascade"
  | "setNull"
  | "restrict"
  | "history"
  | "ephemeral"
  | "softRef"
  | "file";

export interface ReferenceRule {
  rule: ReferenceRuleKind;
  /** Index on the same table whose first field is the path. */
  index?: string;
  /** Index on the same table (first field is another field) the rows are found through. */
  via?: string;
  /** One line: why this rule. */
  why: string;
  /** Present only when today's code does something other than `rule`. */
  today?: string;
}

export const REFERENCE_RULES: Record<string, ReferenceRule> = {
  // ── approvalRequests ──────────────────────────────────────────────────────
  "approvalRequests.childId": { rule: "cascade", index: "by_child_status", why: "A child's requests are theirs; they go with the account." },
  "approvalRequests.decidedByGuardianId": { rule: "setNull", index: "by_decider", why: "Decided rows are the child's live permissions; only the decider pointer is cleared." },
  "approvalRequests.targetRoomId": { rule: "setNull", index: "by_target_room", why: "Pending asks about a deleted room are deleted; decided ones keep the row, lose the pointer.", today: "wipeRoomRows never touches approvalRequests; a pending join-room ask for a deleted room sits in the guardian's queue" },
  "approvalRequests.targetUserId": { rule: "cascade", index: "by_target_user", why: "An approval about a person is meaningless once they are gone." },

  // ── blocks ────────────────────────────────────────────────────────────────
  "blocks.blockedUserId": { rule: "cascade", index: "by_blocked", why: "A block on a deleted account has nothing left to block." },
  "blocks.userId": { rule: "cascade", index: "by_user", why: "The blocker's own list." },

  // ── calls ─────────────────────────────────────────────────────────────────
  "calls.calleeId": { rule: "cascade", index: "by_callee", why: "A call row belongs to both ends; deleted with either account." },
  "calls.callerId": { rule: "cascade", index: "by_caller", why: "A call row belongs to both ends; deleted with either account." },
  "calls.roomId": { rule: "ephemeral", index: "by_room_status", why: "Live calls are ended when the room goes; terminal rows are swept by gcTerminalCalls." },

  // ── callSignals ───────────────────────────────────────────────────────────
  "callSignals.callId": { rule: "cascade", index: "by_call", why: "Signals are meaningless without their call; gcTerminalCalls and purgeUser delete them." },
  "callSignals.fromUserId": { rule: "cascade", index: "by_from", why: "Short-lived WebRTC signalling; purgeUser sweeps strays whose call is gone." },
  "callSignals.toUserId": { rule: "cascade", index: "by_to", why: "Short-lived WebRTC signalling; purgeUser sweeps strays whose call is gone." },

  // ── deviceLoginRequests ───────────────────────────────────────────────────
  "deviceLoginRequests.approvedByUserId": { rule: "cascade", index: "by_approver", why: "A QR/code sign-in this user approved; unapproved rows expire on their own." },

  // ── friendRequestMessages ─────────────────────────────────────────────────
  "friendRequestMessages.requestId": { rule: "cascade", index: "by_request", why: "Messages riding on a friend request die with it (clearFriendRequestMessages, Phase 0)." },
  "friendRequestMessages.userId": { rule: "cascade", index: "by_user", why: "The sender's messages go with their account." },

  // ── friendships ───────────────────────────────────────────────────────────
  "friendships.friendId": { rule: "cascade", index: "by_friend", why: "A friendship needs both people." },
  "friendships.roomId": { rule: "setNull", index: "by_room", why: "The DM room can be deleted while the friendship stays; the friendship just loses its pointer.", today: "wipeRoomCompletely never clears friendships.roomId, so it keeps naming the deleted DM" },
  "friendships.userId": { rule: "cascade", index: "by_user", why: "A friendship needs both people." },

  // ── gameChallenges ────────────────────────────────────────────────────────
  "gameChallenges.messageId": { rule: "cascade", index: "by_message", why: "The challenge body is the card's content (purgeChallengeForMessage)." },
  "gameChallenges.roomId": { rule: "cascade", index: "by_room", why: "Room teardown (purgeChallengesForRoom)." },
  "gameChallenges.userId": { rule: "cascade", index: "by_user", why: "Challenges a user sent go with the account (purgeChallengesOfUser)." },

  // ── gameRecords / gameResults ─────────────────────────────────────────────
  "gameRecords.userId": { rule: "cascade", index: "by_user_game", why: "All-time records are the user's own (purgeRecordsOf)." },
  "gameResults.userId": { rule: "cascade", index: "by_user_day_game", why: "Daily results are the user's own; retention policy is a separate decision (plan section 7)." },

  // ── groupCalls and friends ────────────────────────────────────────────────
  "groupCallParticipants.groupCallId": { rule: "cascade", index: "by_call", why: "gcTerminalGroupCalls deletes participants with the call." },
  "groupCallParticipants.userId": { rule: "cascade", index: "by_user_status", why: "Roster rows go with the account." },
  "groupCalls.joinedUserIds[]": { rule: "ephemeral", why: "Derived roster snapshot (syncJoined); the call row is swept after it ends." },
  "groupCalls.roomId": { rule: "ephemeral", index: "by_room_status", why: "Live calls are ended when the room goes (endGroupCallsInRoom); terminal rows are swept by gcTerminalGroupCalls." },
  "groupCalls.startedBy": { rule: "ephemeral", why: "Attribution on a row that gcTerminalGroupCalls reaps; nothing reads it for authorization." },
  "groupCallSignals.fromUserId": { rule: "ephemeral", why: "Pair signalling, swept with the call and by gcConsumedGroupSignals; no index by design." },
  "groupCallSignals.groupCallId": { rule: "cascade", index: "by_call", why: "Signals are meaningless without their call." },
  "groupCallSignals.toUserId": { rule: "cascade", index: "by_to_unconsumed", why: "Short-lived signalling addressed to the user." },

  // ── guardianships ─────────────────────────────────────────────────────────
  "guardianships.childId": { rule: "cascade", index: "by_child", why: "A child's links go with the child." },
  "guardianships.guardianId": { rule: "restrict", index: "by_guardian", why: "Refuse (LAST_GUARDIAN) while this user is any child's only guardian; otherwise the link is removed." },

  // ── interactions ──────────────────────────────────────────────────────────
  "integrityCounts.runId": { rule: "ephemeral", index: "by_run_table", why: "Counter rows of an integrity scan run; the run row is the only parent and nothing deletes either yet." },
  "interactionResponses.messageId": { rule: "cascade", index: "by_message_user", why: "Answers die with the poll message (purgeInteraction)." },
  "interactionResponses.roomId": { rule: "cascade", index: "by_room_user", why: "Room teardown." },
  "interactionResponses.userId": { rule: "cascade", index: "by_user", why: "A person's votes go with their account; tallies are recounted on the next write." },
  "messageInteractions.choices[].respondents[].userId": { rule: "softRef", why: "Denormalized tally derived from interactionResponses; `recount` rebuilds it on the next write.", today: "dead ids stay in the tally until somebody next writes to the poll (accepted in purgeUser)" },
  "messageInteractions.closedBy": { rule: "history", why: "Who closed the poll; attribution only." },
  "messageInteractions.createdBy": { rule: "cascade", via: "by_message", why: "The poll body is the author's message, which purgeUser deletes (taking the poll with it)." },
  "messageInteractions.messageId": { rule: "cascade", index: "by_message", why: "The body of the poll message." },
  "messageInteractions.roomId": { rule: "cascade", index: "by_room_time", why: "Room teardown." },

  // ── matches ───────────────────────────────────────────────────────────────
  "matches.createdBy": { rule: "history", why: "Who opened the game; finished games outlive their creator in surviving rooms." },
  "matches.messageId": { rule: "cascade", index: "by_message", why: "The game goes with its card (purgeMatchForMessage)." },
  "matches.roomId": { rule: "cascade", index: "by_room_status", why: "Room teardown (purgeMatchesForRoom)." },
  "matches.seatRequest.userId": { rule: "setNull", via: "by_room_status", why: "A pending seat request; cleared when the requester leaves (leaveMatchesInRoom)." },
  "matches.seats[].userId": { rule: "history", why: "Seat snapshot with the player's name; open games forfeit the seat, finished ones keep the id." },
  "matches.turnUserId": { rule: "setNull", index: "by_turn_user_status", why: "Cleared when the game finishes or the seat is forfeited." },
  "matches.watchers[]": { rule: "setNull", via: "by_room_status", why: "Live viewers; should be cleared when the match finishes.", today: "frozen on finish; dead ids stay in finished games" },
  "matchHidden.matchId": { rule: "cascade", index: "by_match", why: "Party-game secrets die with the match (eraseMatch)." },
  "matchMoves.matchId": { rule: "cascade", index: "by_match_seq", why: "Move history dies with the match (eraseMatch)." },
  "matchMoves.messageId": { rule: "setNull", index: "by_message", why: "A move's bubble can be deleted while the match lives; takeback already clears it.", today: "a player deleting their own move bubble leaves a dead messageId" },
  "matchMoves.userId": { rule: "history", why: "Who played the move; moves are deleted with their match." },
  "matchPresence.matchId": { rule: "cascade", index: "by_match_user", why: "Heartbeats die with the match (eraseMatch)." },
  "matchPresence.userId": { rule: "cascade", index: "by_user", why: "A leaving or deleted player's heartbeat row has no use.", today: "not removed when a player leaves or the account is purged in a surviving room; only match deletion removes it" },

  // ── bookmarks, pins ───────────────────────────────────────────────────────
  "messageBookmarks.messageId": { rule: "cascade", index: "by_message", why: "removeMessageAndFanout." },
  "messageBookmarks.roomId": { rule: "cascade", index: "by_room_user_message", why: "Room teardown." },
  "messageBookmarks.userId": { rule: "cascade", index: "by_user", why: "Private marks die with the account (and on leaving a room)." },
  "pinnedMessages.messageId": { rule: "cascade", index: "by_message", why: "removeMessageAndFanout." },
  "pinnedMessages.roomId": { rule: "cascade", index: "by_room_message", why: "Room teardown." },
  "pinnedMessages.userId": { rule: "cascade", index: "by_user", why: "A pin survives its author leaving a room, but not the account (a dead id would be a broken reference)." },

  // ── messages ──────────────────────────────────────────────────────────────
  "messages.gameMove.matchId": { rule: "softRef", why: "Move bubbles are removed with their match (purgeMatchForMessage reads matchMoves.messageId); a bubble that outlives it opens nothing." },
  "messages.mediaStorageId": { rule: "file", index: "by_media", why: "Owner: the message; shared by forwards, so released only when no other message uses it (releaseMessageBlobs)." },
  "messages.mentions[].userId": { rule: "history", why: "Frozen with a username snapshot on purpose (it matches the typed text)." },
  "messages.moderationCard.reportId": { rule: "softRef", why: "Card points at a report that expires after 24 months, as does the card's evidence room.", today: "unverified" },
  "messages.posterStorageId": { rule: "file", index: "by_poster", why: "Owner: the message (video poster frame); checked against its own by_poster index." },
  "messages.replyToId": { rule: "softRef", index: "by_replyTo", why: "Documented soft reference; the preview shows 'deleted' and readers cope." },
  "messages.replyToPreview.mediaStorageId": { rule: "file", why: "Owner: the parent message (borrowed copy); must only be dropped when the file is actually gone.", today: "removeMessageAndFanout drops it on every child even when a forward keeps the file alive" },
  "messages.replyToPreview.senderId": { rule: "history", why: "Copy of the parent's sender; an old quote keeps naming them." },
  "messages.replyToPreview.stickerStorageId": { rule: "file", why: "Owner: the sticker row (borrowed copy); cleared when the sticker file is deleted.", today: "never removed, dangles when a personal sticker's file is deleted" },
  "messages.roomId": { rule: "cascade", index: "by_room_time", why: "Room teardown, in batches of 300 (wipeMessagesBatch)." },
  "messages.rootId": { rule: "softRef", index: "by_root_time", why: "Thread root; documented soft reference like replyToId." },
  "messages.stickerId": { rule: "softRef", why: "Stickers are tombstoned, never hard-deleted, so a sent sticker resolves to 'unavailable'." },
  "messages.stickerStorageId": { rule: "file", why: "Owner: the sticker row (borrowed copy).", today: "personal sticker files are deleted with the owner's account, so every use breaks (accepted on privacy grounds, see Phase 0 item 7)" },
  "messages.userId": { rule: "cascade", index: "by_user", why: "An account's messages go with it, in batches (purgeMessagesLater)." },

  // ── moments ───────────────────────────────────────────────────────────────
  "momentCommentReactions.commentId": { rule: "cascade", index: "by_comment", why: "deleteCommentCascade." },
  "momentCommentReactions.momentId": { rule: "cascade", index: "by_moment", why: "purgeMomentComments." },
  "momentCommentReactions.userId": { rule: "cascade", index: "by_user", why: "purgeUserComments." },
  "momentComments.momentId": { rule: "cascade", index: "by_moment_created", why: "purgeMomentComments." },
  "momentComments.parentId": { rule: "cascade", index: "by_parent", why: "Replies hang off their root (deleteCommentCascade)." },
  "momentComments.replyToUserId": { rule: "history", why: "Copy with a name (replyToName); a deleted account still reads as a name." },
  "momentComments.stickerId": { rule: "softRef", why: "Tombstoned stickers resolve to 'unavailable'." },
  "momentComments.stickerStorageId": { rule: "file", why: "Owner: the sticker row (borrowed copy).", today: "dangles when a personal sticker's owner deletes their account" },
  "momentComments.userId": { rule: "cascade", index: "by_user", why: "purgeUserComments." },
  "momentReactions.momentId": { rule: "cascade", index: "by_moment", why: "feed.remove and purgeUser." },
  "momentReactions.userAvatarStorageId": { rule: "file", why: "Owner: users.avatarStorageId (borrowed copy, moved by repointAvatarCopies); Phase 6 profiles remove it." },
  "momentReactions.userId": { rule: "cascade", index: "by_user", why: "A person's reactions go with their account." },
  "moments.authorAvatarStorageId": { rule: "file", why: "Owner: users.avatarStorageId (borrowed copy, moved by repointAvatarCopies); Phase 6 profiles remove it." },
  "moments.mediaStorageId": { rule: "file", index: "by_media", why: "Owner: the moment; refcounted across moments.", today: "purgeUser deletes the file without the shared-file check feed.remove does" },
  "moments.posterStorageId": { rule: "file", index: "by_poster", why: "Owner: the moment; checked against its own by_poster index.", today: "purgeUser deletes the file without the shared-file check feed.remove does" },
  "moments.userId": { rule: "cascade", index: "by_user", why: "A person's moments, with children first, go with the account." },
  "momentViews.momentId": { rule: "cascade", index: "by_moment_viewer", why: "feed.remove and purgeUser; also should go when the moment expires.", today: "views of expired moments are kept forever" },
  "momentViews.viewerId": { rule: "cascade", index: "by_viewer", why: "A viewer's footprints go with their account." },

  // ── family codes ──────────────────────────────────────────────────────────
  "pairingCodes.childId": { rule: "cascade", index: "by_child", why: "Codes minted for a child go with the child." },
  "pairingCodes.createdByGuardianId": { rule: "cascade", index: "by_creator", why: "A code outlives neither its creator nor its 5-minute life." },
  "releaseCodes.childId": { rule: "cascade", index: "by_child", why: "Codes minted for a child go with the child." },
  "releaseCodes.createdByGuardianId": { rule: "cascade", index: "by_creator", why: "A code outlives neither its creator nor its life." },

  // ── reports ───────────────────────────────────────────────────────────────
  "problemReports.messageId": { rule: "history", why: "Never read; the delivered message lives in the log room. Plan suggests dropping the field.", today: "7 dangling test rows; deleted by the 90-day retention on 2026-11-06" },
  "problemReports.reporterId": { rule: "setNull", index: "by_reporter", why: "The row is the device rate-limit ledger, so it is tombstoned, not deleted." },
  "reports.actionedBy": { rule: "history", why: "Moderation record; 24-month retention." },
  "reports.cardMessageId": { rule: "history", why: "Moderation evidence; 24-month retention." },
  "reports.messageId": { rule: "history", why: "Moderation evidence; the excerpt lives on the card." },
  "reports.reportedUserId": { rule: "history", index: "by_reportedUser", why: "A report must outlive the person reported (24-month retention)." },
  "reports.reporterId": { rule: "setNull", index: "by_reporter", why: "A report outlives its author; the author is tombstoned." },
  "reports.roomId": { rule: "history", why: "Moderation record; readers must handle a missing room." },

  // ── puzzles, records ──────────────────────────────────────────────────────
  "puzzleResults.userId": { rule: "cascade", index: "by_user_day", why: "Daily results are the user's own; retention policy is a separate decision (plan section 7)." },
  "reactions.messageId": { rule: "cascade", index: "by_message", why: "removeMessageAndFanout." },
  "reactions.userId": { rule: "cascade", index: "by_user", why: "Reactions left on other people's messages go with the account." },
  "recordReactions.recordId": { rule: "cascade", index: "by_record_user", why: "Reactions die with the record (purgeRecordsOf)." },
  "recordReactions.userId": { rule: "cascade", index: "by_user", why: "purgeRecordsOf." },

  // ── rooms and membership ──────────────────────────────────────────────────
  "roomAccess.roomId": { rule: "cascade", index: "by_room_user", why: "revokeAllRoomAccess on teardown." },
  "roomAccess.userId": { rule: "cascade", index: "by_user", why: "revokeUserRoomAccess on account deletion." },
  "roomBans.roomId": { rule: "cascade", index: "by_room_user", why: "A ban on a deleted room means nothing.", today: "never deleted by room deletion, account deletion or expiry" },
  "roomBans.userId": { rule: "cascade", index: "by_user", why: "A deleted account's bans go with it; expired bans are swept via by_until.", today: "never deleted by anything (the by_user index is new)" },
  "roomChangeRequests.decidedBy": { rule: "setNull", index: "by_decider", why: "Other people's request history is kept; only the decider pointer is cleared." },
  "roomChangeRequests.roomId": { rule: "cascade", index: "by_room_status", why: "Room teardown, every status." },
  "roomChangeRequests.storageId": { rule: "file", index: "by_storage", why: "Owner: the request while pending; an approved row's file is the room's avatar (rooms.avatarStorageId owns it), so the field must be cleared on release.", today: "a rejected row keeps a dead storageId (1 live orphan); approved rows do the same at the next photo change" },
  "roomChangeRequests.userId": { rule: "cascade", index: "by_user", why: "A person's suggestions go with their account (pending files released)." },
  "roomInvitations.inviteeId": { rule: "cascade", index: "by_invitee_status", why: "An invite nobody can answer." },
  "roomInvitations.inviterId": { rule: "cascade", index: "by_inviter", why: "Would show a deleted person's name to the invitee." },
  "roomInvitations.roomId": { rule: "cascade", index: "by_room_invitee", why: "Room teardown." },
  "roomInvites.createdBy": { rule: "cascade", index: "by_creator", why: "A live join link must not outlive its creator." },
  "roomInvites.roomId": { rule: "cascade", index: "by_room", why: "A link to a deleted room crashes the join screen." },
  "roomJoinRequests.decidedBy": { rule: "setNull", index: "by_decider", why: "Other people's request history is kept; only the decider pointer is cleared." },
  "roomJoinRequests.inviteId": { rule: "setNull", index: "by_invite", why: "The request survives its link being rotated or its creator leaving.", today: "invites are deleted with their creator but requests keep the dead inviteId" },
  "roomJoinRequests.roomId": { rule: "cascade", index: "by_room_status", why: "Room teardown." },
  "roomJoinRequests.userId": { rule: "cascade", index: "by_user", why: "A person's requests go with their account." },
  "roomMembers.roomId": { rule: "cascade", index: "by_room_user", why: "Room teardown (wipeRoomRows); the orphan cron is the backstop." },
  "roomMembers.userId": { rule: "cascade", index: "by_user", why: "Account deletion walks every membership (removing owners and emptied rooms)." },
  "rooms.avatarStorageId": { rule: "file", index: "by_avatar", why: "Owner: the room; released through releaseRoomPhoto.", today: "system rooms share the system account's avatar file, so re-avatarring or wiping one deletes it; systemAvatars.apply never frees the old file" },
  "rooms.createdBy": { rule: "history", why: "Required attribution; the owner SEAT is roomMembers.role, and ensureOwner re-points createdBy when it re-seats.", today: "re-pointed only when the owner seat is vacated, so a non-owner creator's deletion leaves a dead id (plan 2.2 says always re-point; field is required so it cannot be nulled)" },
  "rooms.lastMessageSenderId": { rule: "softRef", why: "Denormalized from the newest message; repaired when that message is deleted (removeMessageAndFanout)." },
  "scheduledMessages.jobId": { rule: "ephemeral", why: "Points at the scheduler's `_scheduled_functions`; dropJob cancels it whenever the row goes, and it is gone once fired." },
  "scheduledMessages.mediaStorageId": { rule: "file", why: "Owner: the scheduled row (a queued photo) until it is sent.", today: "failed rows keep their file forever" },
  "scheduledMessages.mentionedUserIds[]": { rule: "history", why: "Re-validated at send time; a dead id is simply dropped.", today: "unverified" },
  "scheduledMessages.replyToId": { rule: "softRef", why: "Parent may vanish before sending; the send goes out as a plain message.", today: "the sender is not told that the reply tether was lost" },
  "scheduledMessages.roomId": { rule: "cascade", index: "by_room_user_due", why: "purgeScheduledForRoom (also on leave, via purgeScheduledForRoomUser)." },
  "scheduledMessages.userId": { rule: "cascade", index: "by_user", why: "purgeScheduledForUser (cancels the job, releases the photo)." },
  "sessions.userId": { rule: "cascade", index: "by_user", why: "A session for a deleted account must not outlive it.", today: "revoked at purge and deleted later by gcRevokedSessions (800 a day), so rows keep a dead id until then, by design" },
  "socialIdentities.userId": { rule: "cascade", index: "by_user", why: "An orphan identity would sign people into a ghost account." },
  "speakerColors.roomId": { rule: "cascade", index: "by_room_subject", why: "purgeSpeakerColorsForRoom." },
  "speakerColors.subjectId": { rule: "cascade", index: "by_subject", why: "purgeSpeakerColorsForUser / ForMember." },
  "speakerColors.viewerId": { rule: "cascade", index: "by_viewer_room_subject", why: "purgeSpeakerColorsForUser / ForMember." },

  // ── stickers, expressions ─────────────────────────────────────────────────
  "stickerPacks.ownerId": { rule: "setNull", index: "by_owner", why: "The pack is tombstoned, not deleted, so existing uses still resolve (purgeUserExpressions)." },
  "stickers.packId": { rule: "cascade", index: "by_pack_order", why: "Stickers belong to their pack; packs are never hard-deleted today, so this has no deleting path." },
  "stickers.storageId": { rule: "file", why: "Owner: the sticker row. Official art stays; a personal sticker's file goes with its owner and the row is tombstoned.", today: "soft delete keeps the file forever while account deletion deletes it (plan 2.4/2.5 want one always-tombstone rule; Phase 0 chose delete for privacy)" },
  "userExpressions.favorites[].stickerId": { rule: "softRef", why: "Recents/favourites are snapshots; the picker filters missing stickers on read.", today: "the server never checks the sticker exists; other people's lists keep dead stickers" },
  "userExpressions.favorites[].storageId": { rule: "file", why: "Owner: the sticker row (borrowed copy in a snapshot)." },
  "userExpressions.installedPackIds[]": { rule: "softRef", why: "A pack id the user installed; readers skip packs that no longer list." },
  "userExpressions.recents[].stickerId": { rule: "softRef", why: "Recents/favourites are snapshots; the picker filters missing stickers on read.", today: "the server never checks the sticker exists; other people's lists keep dead stickers" },
  "userExpressions.recents[].storageId": { rule: "file", why: "Owner: the sticker row (borrowed copy in a snapshot)." },
  "userExpressions.userId": { rule: "cascade", index: "by_user", why: "purgeUserExpressions." },

  // ── typing, uploads, users ────────────────────────────────────────────────
  "typingIndicators.avatarStorageId": { rule: "file", why: "Owner: users.avatarStorageId (borrowed copy); Phase 6 profiles remove it.", today: "rows outlive membership, so the copy dangles for good unless that person types in that room again (2 live orphans)" },
  "typingIndicators.roomId": { rule: "cascade", index: "by_room_user", why: "Room teardown (should also go when the user leaves the room)." },
  "typingIndicators.userId": { rule: "cascade", index: "by_user", why: "Account deletion." },
  "uploads.storageId": { rule: "file", index: "by_storage", why: "Owner: the ledger row IS the file's record; deleted with the file (releaseLedger)." },
  "uploads.userId": { rule: "setNull", index: "by_user", why: "A file can outlive its uploader (a room photo they set); the ledger row stays, ownerless.", today: "purgeUser never touches uploads rows by user, so the id dangles (plan 2.1 says SET NULL, 2.5 says KEEP-AS-HISTORY)" },
  "uploadUsage.userId": { rule: "cascade", index: "by_user", why: "The per-user byte counter has no meaning without the user.", today: "never deleted" },
  "userDevices.userId": { rule: "cascade", index: "by_user", why: "Left behind, these keep waking a phone for a dead account." },
  "users.avatarStorageId": { rule: "file", why: "Owner: the user row; the old file is deleted on change and copies are moved (repointAvatarCopies)." },
  "users.suspendedBy": { rule: "history", why: "Which moderator suspended; never read as live." },
  "viewOnceViews.messageId": { rule: "cascade", index: "by_message", why: "purgeViewOnceViews." },
  "viewOnceViews.roomId": { rule: "cascade", index: "by_room_user", why: "Room teardown." },
  "viewOnceViews.userId": { rule: "cascade", index: "by_user", why: "A viewer's ledger rows go with their account." },
};
