/**
 * The one Node-ish global this backend uses.
 *
 * `process.env` is how every deployment secret reaches the functions — the
 * Apple/Google client ids in `socialAuth.ts` and `appleTokens.ts`, the VAPID
 * pair in `webPush.ts`, the APNs and FCM credentials in `pushTransport.ts` and
 * `voipPush.ts`, the server directory's addresses. Convex provides it in both
 * its own runtime and in `"use node"` actions.
 *
 * Declared here rather than by depending on `@types/node`, which was tried and
 * is actively worse:
 *
 *  - It is 23 uses of ONE global. The rest of this backend is web-standard —
 *    `fetch`, `crypto.subtle`, `TextEncoder` — and none of it is Node's.
 *  - `@types/node` v22 redefines `Uint8Array` as generic over its backing
 *    buffer (`Uint8Array<ArrayBufferLike>`), which then stops being assignable
 *    to `BufferSource` and `BodyInit`. That invented ten errors in
 *    `webPush.ts` for correct, deployed code — the exact same false alarm the
 *    `lib: ESNext` mistake produced, arriving by a second route.
 *  - Convex's runtime is NOT Node. Claiming Node's whole surface would let
 *    someone reach for `fs` or `Buffer` and be told, by the typechecker, that
 *    it is fine.
 *
 * `tsconfig.json` pins `"types": []` so that installing `@types/node` for some
 * unrelated tool cannot silently pull all of it back in and reopen this.
 *
 * Deliberately narrow: `env` and nothing else. If a `"use node"` action ever
 * genuinely needs more of Node, add that member here with a note saying which
 * action needs it — that keeps the list of what we depend on honest.
 */
declare const process: {
  readonly env: Record<string, string | undefined>;
};
