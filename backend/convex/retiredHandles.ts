import { isStaffHandle, REPORT_INBOX_USERNAME } from "./systemAccount";

/**
 * Handles that may never be registered again.
 *
 * Moderator rights follow the HANDLE (`systemAccount.isModerationStaff`), so
 * when a staff account is deleted its handle must not become free: whoever
 * registered it next would inherit the rights. Staff accounts also cannot
 * rename (`users.applyUsernameChange`), so deletion is the only way a staff
 * handle could ever be released, and this is where it isn't.
 */

export async function isRetiredHandle(ctx: any, name: string): Promise<boolean> {
  const row = await ctx.db
    .query("retiredHandles")
    .withIndex("by_username", (q: any) =>
      q.eq("username", name.trim().toLowerCase()),
    )
    .first();
  return row !== null;
}

/** Called by account deletion before the row goes. */
export async function retireIfStaff(ctx: any, username: string | undefined) {
  if (!username) return;
  if (username !== REPORT_INBOX_USERNAME && !isStaffHandle(username)) return;
  const handle = username.trim().toLowerCase();
  if (await isRetiredHandle(ctx, handle)) return;
  await ctx.db.insert("retiredHandles", { username: handle, retiredAt: Date.now() });
}
