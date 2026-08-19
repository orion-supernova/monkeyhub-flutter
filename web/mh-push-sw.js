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

  const title = d.title || 'MonkeyHub';
  // The Notification API has no third "subtitle" line the way `aps.alert`
  // does on iOS (see push.ts's `AlertSpec.subtitle`) — title and body is all
  // Chrome renders. For a group message this puts the room name on its own
  // line ahead of the text, the closest approximation of "SenderName / Group
  // Name / message" that two lines can carry. Never set for a DM: `roomName`
  // is only ever sent when `isGroup` is `"true"`.
  const body =
    d.isGroup === 'true' && d.roomName ? `${d.roomName}\n${d.body || ''}` : (d.body || '');
  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      // Same semantics as the APNs collapse-id and the Android tag: a later
      // notification with this tag replaces this one rather than stacking.
      tag: d.collapseId || d.threadId || undefined,
      renotify: !!(d.collapseId || d.threadId),
      // The sender's own face, WhatsApp/Telegram-style, when they have one
      // and the recipient is allowed to see it (see rooms.ts's
      // `resolvePushContext` — the backend never sends this key otherwise).
      icon: d.senderAvatarUrl || '/web/icons/Icon-192.png',
      badge: '/web/icons/Icon-192.png',
      data: d,
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const roomId = data.roomId || '';
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clients) => {
        // Prefer an open tab. postMessage reaches it even though this worker
        // does not control it — matchAll with includeUncontrolled is what makes
        // the narrow scope above harmless.
        for (const c of clients) {
          if (c.url.includes('/web/')) {
            c.postMessage({ mh: 'openRoom', roomId: roomId });
            return c.focus();
          }
        }
        return self.clients.openWindow(
          '/web/' + (roomId ? '#room=' + encodeURIComponent(roomId) : ''),
        );
      }),
  );
});
