// OneSignal Web Push service worker. Served at the site root (Flutter copies
// web/ to the build root), which is where the OneSignal SDK expects it by
// default. It runs independently of the page, so it can show call/message push
// banners even when the tab's WebSocket is frozen or the tab is closed.
importScripts("https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.sw.js");
