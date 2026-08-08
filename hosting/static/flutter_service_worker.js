// Tombstone for the Flutter service worker that used to live here.
//
// The web app was served from the site root until the /web/ move, so a browser
// that opened it back then can still have a Flutter worker registered at scope
// "/". Left alone it would serve the cached app shell over the landing page,
// which would then look like it never changed.
//
// Insurance, not a certainty: current `flutter build web` already ships
// Flutter's own self-unregistering worker stub, so recent visitors have nothing
// registered at all. It is the visitors from an older, genuinely-caching build
// this is here for — and it costs one small file to be sure.
//
// Browsers re-fetch the worker script when navigating to a page in its scope,
// find these bytes instead of the old ones, and install this. It then wipes
// the caches, unregisters itself, and reloads the tab once so the landing page
// arrives from the network.
//
// Deliberately NOT a blanket "unregister everything at scope /" script on the
// page itself — only this one self-destructs. (It used to matter more: a push
// SDK's worker also sat at scope "/", and killing it would have unsubscribed
// every web-push user. The app's own push worker now lives under /web/, so the
// origin root holds nothing worth keeping — but a blanket unregister is still
// a blunt instrument aimed at whatever a future build might install.)
//
// Keep serving this file for as long as anyone might still have the old worker
// installed. It costs nothing.

self.addEventListener('install', () => {
  // Don't wait for the old worker's clients to close — it is the thing we're
  // trying to get rid of.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((k) => caches.delete(k)));

    await self.registration.unregister();

    // One reload per tab. After unregister() there is no controller left, so
    // the reload fetches from the network and this cannot loop.
    const windows = await self.clients.matchAll({type: 'window'});
    for (const client of windows) {
      try {
        await client.navigate(client.url);
      } catch (e) {
        // Navigating a client can be refused (a different origin took it over,
        // the tab is closing). The unregister above already did the real work.
      }
    }
  })());
});

// No 'fetch' listener on purpose: with none registered, every request goes
// straight to the network for however long this worker stays alive.
