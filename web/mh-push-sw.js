// MonkeyHub Web Push service worker.
//
// Receives the payloads backend/convex/webPush.ts encrypts (RFC 8291) and
// renders them. No SDK: the whole protocol is `push` + `notificationclick`.
//
// Registered at scope /web/push/ rather than /web/ — a worker script may claim
// any scope at or below its own directory, and a narrower one cannot collide
// with whatever service worker `flutter build web` decides to ship. Push events
// do not require the scope to match a navigable page.
//
// The payload keys are a cross-language contract with push.ts,
// AppDelegate.swift and ChatNotifications.kt. Renaming one here breaks a
// platform you are not looking at.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let d = {};
  try {
    d = event.data ? event.data.json() : {};
  } catch (_) {
    // A payload we can't parse is not worth a blank notification.
    return;
  }

  // Chrome subscribes with `userVisibleOnly: true`, which obliges us to show
  // something for every push. The backend therefore never sends the silent
  // `dismiss` kind to web — the page reconciles its own notifications when it
  // regains focus instead. Guard anyway: a stray one must not spend the
  // browser's hidden budget and earn a "site updated in the background" banner.
  if (d.kind === 'dismiss') return;

  // The second tick, from the browser that just received it — see
  // reportDelivery below. Inside the same waitUntil, so the worker is not
  // torn down with the post still in flight.
  event.waitUntil(Promise.all([reportDelivery(d), show(d)]));
});

// How many lines a room's notification keeps. Android's MessagingStyle keeps
// more, but a browser toast clips long before this.
const MAX_LINES = 5;
const APP_ICON = '/web/icons/Icon-192.png';

async function show(d) {
  if (d.kind === 'message' && d.roomId) return showRoom(d);

  // Everything that is not a chat message (calls, approvals, friend activity)
  // keeps the one-notification-per-event behavior.
  const tagged = d.collapseId || d.threadId || undefined;
  return self.registration.showNotification(d.title || 'MonkeyHub', {
    body: d.body || '',
    tag: tagged,
    silent: d.quiet === 'true',
    renotify: d.quiet !== 'true' && !!tagged,
    icon: d.senderAvatarUrl || APP_ICON,
    badge: APP_ICON,
    data: d,
  });
}

// One notification per room, updated in place with the room's last few lines
// the way Android's MessagingStyle does (ChatNotifications.kt). The tag is the
// room, so each new message REPLACES the previous notification; the lines
// already shown are read back off it and carried in `data.lines`, because a
// replaced notification keeps nothing of its own.
//
// Each line keeps its messageId so a deletion can drop just that line.
async function showRoom(d) {
  const tag = 'room:' + d.roomId;
  let lines = [];
  try {
    const prev = await self.registration.getNotifications({ tag });
    const carried = prev.length ? prev[prev.length - 1].data : null;
    if (carried && Array.isArray(carried.lines)) lines = carried.lines;
  } catch (_) {
    // No history is better than no notification.
  }

  // Group: the room takes the TITLE and the sender moves in front of the text
  // (the Android shape; the Notification API has no subtitle line). A mention
  // used to vanish for a group because "X mentioned you" WAS the title the
  // room's name replaced, so it rides in the line instead. A DM keeps the
  // sender as the title and bare text lines; `roomName` is only ever sent when
  // `isGroup` is "true".
  const isGroup = d.isGroup === 'true' && !!d.roomName;
  const sender = d.senderName || d.title || '';
  const mentioned = d.mention === 'true';
  const text = isGroup && sender
    ? `${sender}${mentioned ? ' mentioned you' : ''}: ${d.body || ''}`
    : (d.body || '');

  // A retried push must not print the same line twice.
  if (!d.messageId || !lines.some((l) => l.id === d.messageId)) {
    lines = lines.concat([{ id: d.messageId || '', text }]).slice(-MAX_LINES);
  }

  const quiet = d.quiet === 'true';
  const icon = isGroup
    ? d.roomAvatarUrl || d.senderAvatarUrl || APP_ICON
    : d.senderAvatarUrl || APP_ICON;
  return self.registration.showNotification(
    (isGroup ? d.roomName : d.title) || 'MonkeyHub',
    {
      body: lines.map((l) => l.text).join('\n'),
      tag,
      // `quiet`: mid-burst, or the person is chatting on another of their
      // devices (backend alertBurst.ts / engagement.ts). The line still lands
      // in the tray, without a sound. `renotify` must be false alongside it,
      // or Chrome alerts anyway for a replaced tag.
      silent: quiet,
      renotify: !quiet,
      icon,
      badge: APP_ICON,
      data: Object.assign({}, d, { lines }),
    },
  );
}

// Tells the sender's server this message reached this browser. The push
// carries a proof signed for this recipient and message (rcptUrl / rcptUser /
// rcptSig — see backend/convex/receiptToken.ts) and this echoes it back; the
// signature is the authentication. Never rejects: a lost receipt is corrected
// when the app next opens, and must not cost the notification.
function reportDelivery(d) {
  if (d.kind !== 'message' || !d.rcptUrl || !d.rcptSig) {
    return Promise.resolve();
  }
  return fetch(d.rcptUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      roomId: d.roomId,
      userId: d.rcptUser,
      createdAt: d.createdAt,
      sig: d.rcptSig,
    }),
  }).catch(() => {});
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const roomId = data.roomId || '';
  const kind = data.kind || '';
  const momentId = data.momentId || '';

  // Friend activity has no room to open, so it travels as its own message
  // rather than as an `openRoom` with an empty id — which the page treats as
  // "nothing to do" and would silently swallow. See socialPush.ts.
  //
  // A separate message name rather than an extra field on `openRoom`, because
  // `mhPushOnOpenRoom` is wired by a build that predates these kinds: a tab
  // running the old bundle ignores what it does not recognise and merely
  // focuses, instead of navigating somewhere on a partly-read payload.
  const social =
    kind === 'friend_moment' || kind === 'game_result'
      ? { mh: 'openTarget', kind: kind, momentId: momentId }
      : null;
  const hash = social
    ? kind === 'friend_moment' && momentId
      ? '#moment=' + encodeURIComponent(momentId)
      : '#games'
    : roomId
      // The app's own chat URL (lib/web/web_url_sync.dart), so a closed tab
      // reopens ON the chat. Nothing ever read the old `#room=` spelling.
      ? '#/c/' + encodeURIComponent(roomId)
      : '';

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clients) => {
        // Prefer an open tab. postMessage reaches it even though this worker
        // does not control it — matchAll with includeUncontrolled is what makes
        // the narrow scope above harmless.
        for (const c of clients) {
          if (c.url.includes('/web/')) {
            c.postMessage(social || { mh: 'openRoom', roomId: roomId });
            return c.focus();
          }
        }
        return self.clients.openWindow('/web/' + hash);
      }),
  );
});
