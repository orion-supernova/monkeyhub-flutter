# Local patches to convex_flutter 3.0.1

Vendored from `pub.dev/convex_flutter-3.0.1` and wired up through
`dependency_overrides` in the app's `pubspec.yaml`. `example/`, `doc/` and
`test_driver/` were dropped; nothing else differs from the published package
except the changes below, each bracketed by `monkeyhub patch` comments so the
whole delta is greppable.

Every change is in **`lib/src/impl/convex_client_web.dart`**. The native client
(`convex_client_native.dart`) needs none of them — it is a thin bridge to the
official `convex` Rust crate, which owns the socket and its query set and
maintains both across reconnects. There is no Dart-side socket, reconnect timer
or subscription registry on that path to get any of this wrong.

## Why

The web client got into a reconnect loop it could not leave: the banner sat on
"reconnecting…" indefinitely while mutations kept succeeding, and a sent message
stayed on "SENDING" on the sender's screen after the recipient's phone had
already displayed it.

The client log made this look like a server fault — every episode opened with
`Close code: 1011, reason: "InternalServerError"`. The deployment's log says
otherwise: the client was feeding the server a protocol error (defect 4), and
1011 is what the server closes the connection over. The hangup was the
*consequence*. Worth remembering the next time this shape appears — a socket
that keeps dying is not automatically evidence about the far end.

Five separate defects compounded into that:

### 1. A deliberate close is indistinguishable from the connection dropping

`onclose` scheduled a reconnect for *any* socket. But `_connect()` and
`reconnect()` both close sockets on purpose, and `onclose` fires asynchronously,
after `_ws` has already been reassigned. So closing an old socket dragged the
live connection's reported state down to `connecting` and scheduled a teardown
of the socket that had just replaced it, ~1s later.

That is self-sustaining: every heal produces the close that triggers the next
heal. In the log it reads as `Manual reconnect requested` → `Executing reconnect
attempt 0`, over and over.

**Fix:** the handler now returns early unless the socket that closed is the
current one. Sockets closed on purpose go through `_abandonSocket`, which
records them as expected. Same guard on `onerror`.

### 2. Superseded sockets were left open, and still routed

`_connect()` assigned `_ws = web.WebSocket(...)` without closing the previous
one. The browser keeps an open socket alive whether or not anything references
it, so it stayed connected, kept its server-side query set, and kept delivering
`Transition`s into `_handleMessage` — which dispatches on `queryId`/`requestId`
alone and cannot tell which connection a message came from. Since
`_querySetVersion` restarts at 0 on every open, those id spaces eventually
collide and one subscriber is fed another's rows.

**Fix:** `_connect()` abandons the outgoing socket before replacing it, and
`onmessage` ignores anything arriving on a socket that is no longer `_ws`.

### 3. `reconnect()` built a connection the backoff loop then replaced

It closed the socket and connected immediately, but left any already-queued
`_reconnectTimer` running. That timer fired a second later and replaced the
socket the call had just built — one requested reconnect, two connections, the
second arriving after `reconnect()` had already returned its verdict.

This is what made health probes unreliable rather than merely slow. A probe is a
one-shot `query()`, which registers on whichever socket is current and waits for
a `Transition`; every probe issued during the churn was stranded on an abandoned
socket and could only fail by timeout — sending the caller straight back into
another reconnect.

**Fix:** cancel the pending timer first, and close through `_abandonSocket`.

### 4. Query ids outlived the connection that owned them — the actual 1011

Found in the deployment's own logs, and this is the one that made a single
hangup unrecoverable rather than merely annoying:

```
ERROR common::errors: Nonexistent query id: 176
ERROR common::errors: Nonexistent query id: 188
ERROR common::errors: Nonexistent query id: 201
WARN  common::errors: WebSocket protocol error: Connection reset ...
```

117 of them in three hours, one every ~15 seconds, the id climbing steadily and
resetting to a low number exactly when the client reconnected.

A query id means nothing to the server except within the connection that
`Add`ed it. `_unsubscribe` sent a `Remove` for whatever was in `_subscriptions`,
with no notion of which socket that id came from — so after any reconnect, every
cancelled subscription and every completed one-shot query retracted an id the
new connection had never registered. The server treats that as a protocol error
and can close the socket over it, which strands everything in flight, which
orphans more ids, which produces more bogus `Remove`s.

That is the loop. It is why the client burned through ten reconnect attempts
instead of succeeding on the first: each "recovery" immediately re-armed the
fault that had killed the previous connection.

**Fix:** a `_connectionGeneration` counter, bumped on every `onopen`. Each
`_WebSubscription` records the generation it was registered on; `_unsubscribe`
drops the record locally rather than sending a `Remove` when they disagree, and
`_replaySubscriptions` re-stamps what it re-registers. One-shot `query()` now
carries its name and args too, so a query whose socket died is re-asked on the
new connection instead of hanging until `operationTimeout` — which matters
because the app's health probe *is* a one-shot query, and a probe that can only
fail by timeout makes a healthy server look permanently unreachable.

### 5. A reconnected client never re-registered its query set

`onopen` resets `_querySetVersion` to 0 because a new connection genuinely
starts with an empty query set — but nothing replayed the subscriptions into it.
After any reconnect the client held a map full of subscriptions the server had
never been told about: `isConnected` true, callbacks intact, and nothing ever
arriving again.

This is the one with teeth, because it is silent. It is why the app carries
`ChatRepository.resubscribe()` at all, and why a stuck send could not clear: the
`messages:list` echo that was supposed to reconcile the optimistic bubble was
never coming.

**Fix:** `_WebSubscription` now remembers its `name`/`args`, and
`_replaySubscriptions()` re-adds the live set as one batched `ModifyQuerySet` on
every open. Query ids are safe to reuse — `_queryIdCounter` is deliberately not
reset on open, so each id stays unique within the client and still matches the
`_subscriptions` key its updates dispatch through.

The app-side `resubscribe()` is kept as a belt: it also re-runs `attach()` and
re-opens the active room, which repairs app-level state this cannot see.

## Deliberately not changed: the web client gives up after 10 attempts

`_maxReconnectAttempts = 10`, after which `_scheduleReconnect` logs "Max
reconnection attempts reached" and stops — permanently. Nothing inside the
client ever reconnects again.

Left alone, because the app already covers it: `ConvexBackend.reconnect()` calls
into here at most once per 12s for as long as `ConnectionHealth` keeps failing
probes, and `reconnect()` resets `_reconnectAttempts` to 0. So the recovery
ceiling is the app's loop, which does not give up, rather than this counter.

Worth knowing that the native path has no equivalent cliff: convex-rs runs an
uncapped `loop` with backoff capped at 15s (`client/worker.rs:90`), resets on
success, and resends queries and mutations after every reconnect. That is why
`ConnectionHealth` only calls `reconnect()` under `kIsWeb` — on native the
client's own loop is the recovery mechanism, and `reconnect()` there is not a
reconnect at all (it runs `healthCheckQuery` and reports the result).

## Upgrading

`pubspec.yaml` pins the override to this directory, so `flutter pub upgrade`
cannot pull these fixes out from under the app — but it also means a
`convex_flutter` bump is a manual job. Re-apply these against the new version,
or drop the override if upstream has fixed them. Check specifically whether
`onclose`/`onmessage` still ignore which socket an event came from, and whether
`onopen` replays the query set.

Getting this wrong fails quietly: the app reports itself connected and simply
stops receiving.
