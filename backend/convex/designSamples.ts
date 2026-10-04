import { v } from "convex/values";
import { internalMutation, internalQuery, type QueryCtx } from "./_generated/server";
import { isKlipyUrl, sendCore } from "./messages";

/** Operator-only design examples. No room argument: samples can only reach
 * the named account's single-member Saved Messages room. Stable client ids
 * preserve edits and make retries harmless. */
const BATCH = "design-preview-2026-10-04";
const SAMPLE_KEYS = [
  "text", "image", "video", "videoNote", "audio", "file", "gif", "sticker",
  "url", "system", "location", "liveLocation", "poll", "quiz", "checklist", "event",
];

async function savedRoom(ctx: QueryCtx, username: string) {
  const user = await ctx.db.query("users")
    .withIndex("by_username", q => q.eq("username", username.trim().toLowerCase())).unique();
  if (!user) throw new Error("SAMPLE_USER_NOT_FOUND");
  const room = await ctx.db.query("rooms")
    .withIndex("by_name", q => q.eq("name", `dm:self:${user._id}`)).unique();
  if (!room || !room.isPrivate || room.createdBy !== user._id || room.memberCount !== 1) {
    throw new Error("SAMPLE_SAVED_ROOM_REQUIRED");
  }
  const members = await ctx.db.query("roomMembers")
    .withIndex("by_room_user", q => q.eq("roomId", room._id)).collect();
  if (members.length !== 1 || members[0].userId !== user._id) {
    throw new Error("SAMPLE_SAVED_ROOM_REQUIRED");
  }
  return { user, room };
}

export const inspect = internalQuery({
  args: { username: v.string() },
  handler: async (ctx, { username }) => {
    const { user, room } = await savedRoom(ctx, username);
    // Only this explicitly requested batch. No private history or recents.
    const samples = await Promise.all(SAMPLE_KEYS.map(key => ctx.db.query("messages")
      .withIndex("by_room_user_client", q => q.eq("roomId", room._id)
        .eq("userId", user._id).eq("clientId", `${BATCH}:${key}`)).unique()));
    const packs = await ctx.db.query("stickerPacks")
      .withIndex("by_kind_order", q => q.eq("kind", "official")).collect();
    let stickerId = null;
    for (const pack of packs) {
      const stickers = await ctx.db.query("stickers")
        .withIndex("by_pack_order", q => q.eq("packId", pack._id)).take(30);
      const sticker = stickers.find(s => s.deletedAt === undefined);
      if (sticker) { stickerId = sticker._id; break; }
    }
    return {
      username: user.username, roomId: room._id, stickerId,
      samples: samples.filter(m => m !== null)
        .map(m => ({ id: m._id, type: m.type, clientId: m.clientId })),
    };
  },
});

export const send = internalMutation({
  args: {
    username: v.string(), stickerId: v.id("stickers"),
    gif: v.object({
      url: v.string(), previewUrl: v.optional(v.string()), ref: v.optional(v.string()),
      width: v.optional(v.number()), height: v.optional(v.number()),
    }),
    media: v.object({
      image: v.id("_storage"), video: v.id("_storage"), videoNote: v.id("_storage"),
      audio: v.id("_storage"), file: v.id("_storage"),
      videoPoster: v.id("_storage"), videoNotePoster: v.id("_storage"),
    }),
  },
  handler: async (ctx, args) => {
    const { user, room } = await savedRoom(ctx, args.username);
    if (!isKlipyUrl(args.gif.url)) throw new Error("SAMPLE_REAL_GIF_REQUIRED");
    const sticker = await ctx.db.get(args.stickerId);
    const pack = sticker && await ctx.db.get(sticker.packId);
    if (!sticker || sticker.deletedAt !== undefined || pack?.kind !== "official") {
      throw new Error("SAMPLE_OFFICIAL_STICKER_REQUIRED");
    }
    const stored = await Promise.all(Object.values(args.media).map(id => ctx.db.system.get(id)));
    if (stored.some(file => !file)) throw new Error("SAMPLE_MEDIA_MISSING");
    const sizeOf = (id: string) => stored.find(file => file?._id === id)!.size;
    const now = Date.now();
    const startsAt = now + 2 * 24 * 60 * 60 * 1000;
    const choices = (labels: string[]) => labels.map((label, i) => ({ id: String(i), label, count: 0 }));
    // Original demo assets and a public landmark; no device GPS or publisher.
    const samples = [
      { key: "text", type: "text", content: "✨ Design test — one of every message type below. Try voting, checking a task, or replying to the event. Map pins are demo locations; the audio is a short chime." },
      { key: "image", type: "image", content: "Design test · Photo", mediaStorageId: args.media.image, mediaWidth: 512, mediaHeight: 512, mimeType: "image/png" },
      { key: "video", type: "video", content: "Design test · Video", mediaStorageId: args.media.video, mediaWidth: 512, mediaHeight: 512, mediaDurationMs: 3000, posterStorageId: args.media.videoPoster, mimeType: "video/mp4" },
      { key: "videoNote", type: "videoNote", content: "Design test · Round video", mediaStorageId: args.media.videoNote, mediaWidth: 512, mediaHeight: 512, mediaDurationMs: 3000, posterStorageId: args.media.videoNotePoster, mimeType: "video/mp4" },
      { key: "audio", type: "audio", content: "Design test · Three-second chime", mediaStorageId: args.media.audio, mediaDurationMs: 3000, mimeType: "audio/wav" },
      { key: "file", type: "file", content: "Design test · Document", mediaStorageId: args.media.file, fileName: "MonkeyHub design test.txt", mimeType: "text/plain" },
      { key: "gif", type: "gif", content: "Design test · GIF", mediaSource: "klipy", mediaUrl: args.gif.url, mediaPreviewUrl: args.gif.previewUrl, mediaRef: args.gif.ref, mediaWidth: args.gif.width, mediaHeight: args.gif.height },
      { key: "sticker", type: "sticker", content: "Design test · Sticker", stickerId: args.stickerId },
      { key: "url", type: "url", content: "https://flutter.dev" },
      { key: "system", type: "system", content: "Design test · Sample system notice" },
      { key: "location", type: "location", content: "Design test · Istanbul landmark", latitude: 41.0138, longitude: 28.9497, locationAccuracyM: 15 },
      { key: "liveLocation", type: "liveLocation", content: "Design test · Live-location card with a static demo pin (no GPS tracking)", latitude: 41.0138, longitude: 28.9497, locationAccuracyM: 15, liveDurationMs: 15 * 60 * 1000 },
      { key: "poll", type: "poll", content: "Pick our weekend plan ✨", interaction: { choices: choices(["Coffee by the sea ☕", "A picnic in the park 🌿", "Movie night 🍿"]) } },
      { key: "quiz", type: "poll", content: "A tiny design quiz 🎨", interaction: { quiz: true, correctChoiceId: "1", explanation: "A soft rim and restrained accents keep the content in focus.", choices: choices(["More borders", "Light, space & a little color", "Everything neon"]) } },
      { key: "checklist", type: "checklist", content: "Our picnic checklist 🌿", interaction: { nextItemId: 3, choices: choices(["Fresh bread 🥖", "Fruit & something sweet 🍓", "A blanket ☁️"]) } },
      { key: "event", type: "event", content: "Golden-hour picnic ✨", interaction: { startsAt, endsAt: startsAt + 2 * 60 * 60 * 1000, place: "Moda seaside · Design test", choices: [{ id: "going", label: "Going", count: 0 }, { id: "maybe", label: "Maybe", count: 0 }, { id: "no", label: "Can't", count: 0 }] } },
    ];
    const results = [];
    for (let i = 0; i < samples.length; i++) {
      const { key, interaction, ...message } = samples[i];
      const clientId = `${BATCH}:${key}`;
      const existing = await ctx.db.query("messages")
        .withIndex("by_room_user_client", q => q.eq("roomId", room._id).eq("userId", user._id).eq("clientId", clientId)).unique();
      const messageId = existing?._id ?? await sendCore(ctx, {
        ...message, roomId: room._id, userId: user._id, clientId,
        ...("mediaStorageId" in message ? { fileSize: sizeOf(message.mediaStorageId!) } : {}),
      });
      if (!existing) {
        // Convex freezes Date.now per mutation. Distinct times preserve order.
        const createdAt = now - samples.length + i;
        await ctx.db.patch(messageId, { createdAt });
        await ctx.db.patch(room._id, { lastMessageTime: createdAt });
      }
      if (interaction) {
        const body = await ctx.db.query("messageInteractions")
          .withIndex("by_message", q => q.eq("messageId", messageId)).unique();
        if (!body) await ctx.db.insert("messageInteractions", {
          ...interaction, messageId, roomId: room._id, kind: message.type,
          createdBy: user._id, createdAt: now - samples.length + i, respondentCount: 0,
        });
      }
      results.push({ type: message.type, variant: key, id: messageId, added: !existing });
    }
    return { username: user.username, roomId: room._id, messages: results };
  },
});
