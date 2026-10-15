/**
 * How a password is stored.
 *
 * The client sends `sha256(password)` (`lib/backend/hashing.dart`), unsalted.
 * That value used to be stored as-is, which made it the password: a leaked
 * `users` row could be replayed straight into `auth.login` with no cracking,
 * and identical passwords had identical rows. It is now salted and stretched
 * here, so the stored string is neither replayable nor shared.
 *
 *   pbkdf2-sha256$<iterations>$<salt hex>$<derived hex>
 *
 * Rows written before this keep the bare 64-hex form and are re-stored in the
 * new form the next time their owner proves the password ([needsUpgrade]).
 * Sentinels (`CHILD_PASSWORD_SENTINEL`, `SOCIAL_ONLY_PASSWORD_SENTINEL`, the
 * system prefix) are left exactly as they are: other code tests for them by
 * value, and every caller refuses those accounts before comparing.
 */

const PREFIX = "pbkdf2-sha256$";
const ITERATIONS = 60_000;

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function fromHex(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

async function derive(
  clientHash: string,
  salt: Uint8Array,
  iterations: number,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(clientHash),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt: salt as BufferSource, iterations },
    key,
    256,
  );
  return toHex(new Uint8Array(bits));
}

/** Equal-time string compare, so a mismatch's position isn't measurable. */
function sameString(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * The value to store for [clientHash]. Falls back to the bare form if this
 * runtime can't derive, so a missing primitive degrades to the old storage
 * rather than to nobody being able to sign up.
 */
export async function hashPassword(clientHash: string): Promise<string> {
  try {
    const salt = new Uint8Array(16);
    crypto.getRandomValues(salt);
    const derived = await derive(clientHash, salt, ITERATIONS);
    return `${PREFIX}${ITERATIONS}$${toHex(salt)}$${derived}`;
  } catch (e) {
    console.warn(`passwords.hashPassword: PBKDF2 unavailable, storing bare: ${e}`);
    return clientHash;
  }
}

/** True when [clientHash] is the password [stored] was made from. */
export async function verifyPassword(
  stored: string | undefined,
  clientHash: string,
): Promise<boolean> {
  if (!stored) return false;
  if (stored.startsWith(PREFIX)) {
    const [iterations, saltHex, expected] = stored.slice(PREFIX.length).split("$");
    const actual = await derive(clientHash, fromHex(saltHex), Number(iterations));
    return sameString(actual, expected);
  }
  return sameString(stored, clientHash);
}

/** A bare legacy hash that should be re-stored after a successful check. */
export function needsUpgrade(stored: string | undefined): boolean {
  return !!stored && /^[0-9a-f]{64}$/.test(stored);
}

/**
 * Re-stores a legacy row's password in the salted form. Call only after
 * [verifyPassword] succeeded with [clientHash].
 */
export async function upgradeIfLegacy(
  ctx: any,
  user: { _id: any; passwordHash?: string },
  clientHash: string,
) {
  if (!needsUpgrade(user.passwordHash)) return;
  const next = await hashPassword(clientHash);
  if (next !== clientHash) await ctx.db.patch(user._id, { passwordHash: next });
}
