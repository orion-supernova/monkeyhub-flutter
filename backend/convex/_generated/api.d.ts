/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as appleTokens from "../appleTokens.js";
import type * as auth from "../auth.js";
import type * as badges from "../badges.js";
import type * as bookmarks from "../bookmarks.js";
import type * as calls from "../calls.js";
import type * as childGuard from "../childGuard.js";
import type * as crons from "../crons.js";
import type * as deviceLogin from "../deviceLogin.js";
import type * as family from "../family.js";
import type * as feed from "../feed.js";
import type * as files from "../files.js";
import type * as friends from "../friends.js";
import type * as games from "../games.js";
import type * as games_queens from "../games/queens.js";
import type * as games_rng from "../games/rng.js";
import type * as games_sudoku from "../games/sudoku.js";
import type * as games_tango from "../games/tango.js";
import type * as games_zip from "../games/zip.js";
import type * as groupCalls from "../groupCalls.js";
import type * as http from "../http.js";
import type * as idToken from "../idToken.js";
import type * as messages from "../messages.js";
import type * as migrations from "../migrations.js";
import type * as mute from "../mute.js";
import type * as notifications from "../notifications.js";
import type * as pins from "../pins.js";
import type * as presence from "../presence.js";
import type * as problemReports from "../problemReports.js";
import type * as push from "../push.js";
import type * as pushCodec from "../pushCodec.js";
import type * as pushTransport from "../pushTransport.js";
import type * as puzzle from "../puzzle.js";
import type * as rateLimit from "../rateLimit.js";
import type * as reactions from "../reactions.js";
import type * as releases from "../releases.js";
import type * as roomAdmin from "../roomAdmin.js";
import type * as roomCleanup from "../roomCleanup.js";
import type * as roomContent from "../roomContent.js";
import type * as roomInvitations from "../roomInvitations.js";
import type * as roomInvites from "../roomInvites.js";
import type * as rooms from "../rooms.js";
import type * as scheduledMessages from "../scheduledMessages.js";
import type * as serverDirectory from "../serverDirectory.js";
import type * as socialAuth from "../socialAuth.js";
import type * as systemAccount from "../systemAccount.js";
import type * as typing from "../typing.js";
import type * as users from "../users.js";
import type * as visibility from "../visibility.js";
import type * as voipPush from "../voipPush.js";
import type * as voipTokens from "../voipTokens.js";
import type * as webPush from "../webPush.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  appleTokens: typeof appleTokens;
  auth: typeof auth;
  badges: typeof badges;
  bookmarks: typeof bookmarks;
  calls: typeof calls;
  childGuard: typeof childGuard;
  crons: typeof crons;
  deviceLogin: typeof deviceLogin;
  family: typeof family;
  feed: typeof feed;
  files: typeof files;
  friends: typeof friends;
  games: typeof games;
  "games/queens": typeof games_queens;
  "games/rng": typeof games_rng;
  "games/sudoku": typeof games_sudoku;
  "games/tango": typeof games_tango;
  "games/zip": typeof games_zip;
  groupCalls: typeof groupCalls;
  http: typeof http;
  idToken: typeof idToken;
  messages: typeof messages;
  migrations: typeof migrations;
  mute: typeof mute;
  notifications: typeof notifications;
  pins: typeof pins;
  presence: typeof presence;
  problemReports: typeof problemReports;
  push: typeof push;
  pushCodec: typeof pushCodec;
  pushTransport: typeof pushTransport;
  puzzle: typeof puzzle;
  rateLimit: typeof rateLimit;
  reactions: typeof reactions;
  releases: typeof releases;
  roomAdmin: typeof roomAdmin;
  roomCleanup: typeof roomCleanup;
  roomContent: typeof roomContent;
  roomInvitations: typeof roomInvitations;
  roomInvites: typeof roomInvites;
  rooms: typeof rooms;
  scheduledMessages: typeof scheduledMessages;
  serverDirectory: typeof serverDirectory;
  socialAuth: typeof socialAuth;
  systemAccount: typeof systemAccount;
  typing: typeof typing;
  users: typeof users;
  visibility: typeof visibility;
  voipPush: typeof voipPush;
  voipTokens: typeof voipTokens;
  webPush: typeof webPush;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
