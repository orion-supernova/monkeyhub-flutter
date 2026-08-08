# Seeding the MonkeyHub Logs avatar

`monkeyhub-logs-avatar.jpg` is the face of the account `problemReports.ts` posts
problem reports as. It lives here, and not in `ensureLogAccount`, because a
Convex **mutation cannot create a blob** — `ctx.storage.store` is action-only —
so the avatar is deployment data rather than something the account creates for
itself. A deployment without it still works; the client just draws its usual
monogram.

## Re-seeding a deployment

Run from `backend/`, after at least one report has created the account:

```sh
# 1. The account's id.
npx convex run --no-push users:searchUsers \
  '{"query":"monkeyhub_logs","currentUserId":"<any user id>"}'
#    …or read it straight off the users table in the dashboard. `searchUsers`
#    deliberately filters this account out, so the dashboard is the reliable route.

# 2. An upload URL, then the bytes. The Content-Type is what Convex serves the
#    blob back as, so it has to match the file.
URL=$(npx convex run files:generateUploadUrl '{}' | tr -d '"')
curl -s -X POST -H "Content-Type: image/jpeg" \
  --data-binary @tools/monkeyhub-logs-avatar.jpg "$URL"
#    → {"storageId":"kg2…"}

# 3. Point the account at it. `users:updateAvatar` deletes the blob it replaces,
#    so re-running this leaks nothing.
npx convex run users:updateAvatar \
  '{"userId":"<log account id>","storageId":"<storageId from step 2>"}'
```

## Where the image came from

A crop of the app icon already in this repo, so it needs no separate artwork and
cannot drift from the brand:

```sh
sips --cropOffset 35 195 --cropToHeightWidth 620 620 \
  ../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png \
  --out /tmp/head.png
sips -z 512 512 /tmp/head.png --out /tmp/avatar.png
sips -s format jpeg -s formatOptions 88 /tmp/avatar.png --out monkeyhub-logs-avatar.jpg
```

The crop is the head rather than the whole icon because an avatar renders at
48 px: full-frame, the face is ~12 px across a busy neon background and reads as
a smudge. JPEG rather than PNG because the source is photographic — the same
image is 397 KB as a PNG and 84 KB here, on a blob that loads behind every room
list render.
