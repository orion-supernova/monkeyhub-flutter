# Call quality overhaul, 2026-11-05

Why MonkeyHub video calls looked worse than WhatsApp, what was changed, how the
new system behaves in real situations, and everything that still has to be
tested on real phones.

**Status:** all code is on `dev`, committed, tests green (308 call tests).
**Nothing here has run on a real phone yet.** It needs a fresh native build
(`flutter build`), because the camera fix lives in native iOS/macOS/Android
code. No backend deploy is needed.

Commits, oldest first:

| Commit | What |
|---|---|
| `ee42abfc` | Camera resolution bug, dark-room exposure, audio that survives packet loss |
| `e341ce52` | Dropped calls hold on for a minute; first version of auto-lowering quality |
| `d5bef064` | Smooth FaceTime-style quality changes (no camera restart), group calls per person |

---

## 1. The problem

Murat and zeynepoz tried a MonkeyHub video call under a table lamp. The picture
was too dark on both sides. The same call on WhatsApp was "day and night"
better. A second wish: on bad networks the call must keep going, pixelated if
it has to, but never drop.

---

## 2. Root causes found

### 2.1 iPhone and Mac were sending tiny video (the main bug)

We asked the camera for 1280×720. The calling library (flutter_webrtc) only
read that request when the number arrived as **text**. We send a **number**, so
on iPhone and Mac it read the target as 0×0 and picked the **smallest format the
camera has**, about **192×144** on an iPhone front camera. That tiny picture was
stretched to full screen: blurry, muddy and dark.

Android had a twin bug (it looked for the value in the wrong place) but happened
to fall back to 720p, so Android was less affected.

Side effect of this bug: the HD and 4K quality settings **never did anything on
Apple devices** before this fix. Now they work for real.

### 2.2 The camera was locked at exactly 30 frames per second

At 30 fps each frame can be exposed for at most 33 ms. Under a lamp the sensor
can't collect enough light in 33 ms, so it boosts gain instead, which gives a
dark, grainy picture. FaceTime and WhatsApp let the frame rate drop toward
15 fps in dim light, which doubles the exposure time and brightens the image.

### 2.3 No TURN relay server (still open, see section 7)

The live backend has no `TURN_URL` set, so calls only get STUN, which helps two
phones find each other but can't carry the call. When both people are behind
mobile-carrier NAT, hotel or office Wi-Fi, there is no relay to fall back on.
Expect about 10-15% of calls to fail to connect or drop after a network switch.

---

## 3. What was fixed

### 3.1 Camera (commit `ee42abfc`)

- The app now sends the resolution as plain numbers on iPhone, Mac and Android
  (`videoConstraintsFor` in `lib/calls/call_media.dart`). The browser keeps the
  range form it understands.
- The library's own parsing is fixed too, on iOS/macOS and Android
  (vendored flutter_webrtc, **PATCH W8**, documented in
  `third_party/flutter_webrtc/PATCHES.md`).
- After the camera starts (and after a camera flip), the frame rate may float
  between 15 and 30 fps instead of being pinned at 30. In dim light exposure can
  go up to 66 ms.
- On iPhone, where the camera supports it: low-light boost, continuous
  auto-exposure, continuous autofocus, continuous white balance, automatic
  video HDR.

### 3.2 Audio on bad networks (commit `ee42abfc`)

- **The voice comes first.** Audio goes out at high priority, so when the
  connection is congested the picture loses quality before the voice does.
  Audio packets are also marked for the "voice" queue that home Wi-Fi routers
  use (DSCP).
- **Redundant audio (Opus RED).** Each audio packet also carries a copy of the
  previous bit of speech. A lost packet is rebuilt from the next one instead of
  becoming a gap. Google Meet uses the same technique. Costs about 30 kbps
  extra, so it is skipped when "use less data for calls" is on.
- **A backup connection path stays warm**, so when Wi-Fi drops the call can
  switch to a path already proven to work instead of starting from cold.

### 3.3 Dropped calls hold on longer (commit `e341ce52`)

A call used to be ended after about 30 seconds of being cut off. Now it waits
**60 seconds** (1:1 and group). The 2-minute absolute limit stays. WhatsApp
holds through lifts, tunnels and trains between stations; we now do too.

### 3.4 Video adapts to a weak connection (commits `e341ce52`, `d5bef064`)

See section 4 for how it works. Key points:

- Only matters when someone picked **1080p or 4K**. On **Auto (720p)** the
  calling engine already adapts by itself.
- Works for **1:1 and group calls**. In a group, each person's link adapts on
  its own.
- New setting: **Settings → Video quality → "Lower on weak connections"**, on by
  default.
- The saved quality setting is **never changed** by any of this. It all applies
  to the current call only.

### 3.5 Smaller fixes along the way

- The group call screen was asking for connection stats a second time on top of
  the call service. Removed; it now reads the service's stats.
- Group calls now count toward **Data Usage**. They never did before.

---

## 4. How adaptive video works

Think of the **camera** as a photographer and the **encoder** as the person who
packs the photos into envelopes to post them.

### 4.1 Two tools

**Tool 1: shrink the picture (used for every step).** The photographer keeps
shooting 4K. When the connection gets weak, the packer shrinks each photo before
sending it. It is a single setting change on a running encoder: no camera
restart, no black frame, no flash, and it can stop shrinking at any moment.
This is how FaceTime and WhatsApp do it.

**Tool 2: switch the camera to a lower quality (only when it helps).** The
camera itself restarts at 1080p or 720p. That costs one brief hitch, so it is
saved for two cases:

1. **The phone is overheating:** the encoder reports it can't keep up (CPU
   limited). Shrinking alone doesn't help, because the phone still captures 4K.
2. **A long bad patch:** every link has been lowered for **2 minutes**. There is
   no point capturing 4K that nobody receives; capturing smaller saves battery
   and heat.

When the camera is switched down, the shrinking stops. It is always one or the
other, never both:

| Situation | Camera shoots | Encoder shrinks | Other person receives |
|---|---|---|---|
| Good Wi-Fi | 4K | no | 4K |
| Short dip (kitchen) | 4K | yes, to 720p | 720p |
| Bad for 2+ minutes, or phone overheating | **720p** | **no** | 720p |
| Connection recovers after that | back to 4K (one restart) | no | 4K |

### 4.2 Why not always switch the camera?

Switching means a brief freeze or flash for the other person, and going back up
needs a second restart. Most bad patches last seconds, not minutes. A kitchen
dip handled by switching would cost two hitches; handled by shrinking it costs
none.

### 4.3 Which looks better: 4K shrunk to 720p, or the camera at 720p?

Usually the same, or 4K-shrunk is slightly better: each 720p pixel is an average
of 9 real camera pixels, which cancels out grain. But both go through the same
720p "pipe" (about 1.2 Mbps), and on a weak connection the pipe decides the
quality. The real difference is not the picture, it is **smoothness versus
battery and heat**:

| | 4K shrunk to 720p | Camera at 720p |
|---|---|---|
| Picture the other person sees | same, sometimes a touch cleaner | same |
| Phone heat and battery | **higher** (4× the pixels) | lower |
| Going back up later | instant, invisible | one brief restart |

Two unconfirmed exceptions, see the test list: some phones may look slightly
brighter in dim light at their native lower resolution, and some cameras crop
the view differently at some resolutions.

### 4.4 When does it step down?

The call checks the connection every 2 seconds. A check counts as "struggling"
when, for the quality being sent:

- the estimated upload capacity is under **60%** of what that quality needs
  (4K needs 8 Mbps, 1080p 2.5 Mbps, 720p 1.2 Mbps), or
- the encoder says it is limited by bandwidth and sends under half of what that
  quality needs, or
- the encoder says it is limited by the phone's processor (overheating).

**5 struggling checks in a row (10 seconds)** step down, straight to the highest
quality the connection can carry (4K can go directly to 720p). In a group call
the "needs" numbers are lowered per person, because the phone sends one stream
to each person.

The **first 15 seconds** after connecting are ignored: the connection estimate
always starts low and climbs, and reading that as a weak link would downgrade
every call.

### 4.5 When does it step back up?

After **30 seconds** of no struggling, it tries **one step up** (720p → 1080p,
then → 4K). If the connection can't hold it and drops again soon after, the
wait before the next try **doubles** (60 s, 120 s, up to 8× = 4 minutes). That
stops it bouncing up and down every half minute on a borderline connection.

It never steps up past the saved setting, and never while the user lowered it
by hand.

### 4.6 What the user sees

**"Lower on weak connections" ON (default):**

- First drop in a call: banner *"Weak connection. Video lowered to 720p."* with
  a close button (top-left). It disappears after 6 seconds. Later drops in the
  same call are silent.
- When it steps back up, any banner still showing goes away. No "back to 4K"
  message.
- The in-call "More" sheet shows the quality actually being sent.

**"Lower on weak connections" OFF:**

- Nothing changes on its own.
- Banner: *"Your connection can't keep up with 4K."* with a **"Lower to 1080p"**
  button and a close button. It stays until tapped or closed, and it comes back
  at most once per quality level per call.
- Tapping "Lower" lowers it for the rest of that call; it won't step back up by
  itself.

**Picking a quality by hand in the call's "More" sheet** always wins: it clears
any automatic drop and saves the new choice.

Banner strings exist in all 12 languages.

### 4.7 Group calls

- One adaptive "ladder" per person.
- The camera is shared by everyone, so it is only switched down when **every**
  person's link has been lower for 2 minutes (or on overheating).

---

## 5. Real scenarios

**A. Dim room, table lamp, two iPhones, Auto quality.**
Before: 192×144 stretched to full screen, dark and blurry. Now: real 720p, and
the frame rate can sag toward 15 fps so each frame gets more light. Should look
close to WhatsApp. Nothing adaptive kicks in (Auto).

**B. 4K selected, you walk into the kitchen where Wi-Fi is weak.**
After about 10 seconds the other person's view of you goes soft (720p). One
banner: "Weak connection. Video lowered to 720p." Your camera never restarts.
You walk back; after about 30 seconds it goes to 1080p, about 30 seconds later
4K. No flash at any point.

**C. 4K selected, hotel Wi-Fi bad all evening.**
Drops to 720p by shrinking. After 2 minutes of staying bad, the camera itself
switches to 720p (one brief hitch) to save heat and battery. It keeps probing
upward with growing waits. If the Wi-Fi ever gets good, the camera goes back to
4K (one more hitch).

**D. 4K selected on an older or hot phone, good Wi-Fi.**
The encoder reports the phone can't keep up. It drops one step to 1080p and the
camera also switches to 1080p, because shrinking alone would still make the phone
process 4K.

**E. Group call: you, zeynepoz on good Wi-Fi, a friend on a train.**
Only the friend gets a softer picture of you. zeynepoz still gets 4K, and your
camera keeps shooting 4K for her.

**F. "Lower on weak connections" OFF, 4K, weak link.**
Picture stays 4K (and probably stutters). Banner offers "Lower to 1080p". Tap it:
1080p for the rest of the call. Close it: no more offers for 4K in this call.

**G. Lift or tunnel mid-call.**
"Reconnecting" shows. The call now waits 60 seconds (was 30) for the network to
come back before ending it. The voice stays clearer through packet loss thanks
to redundant audio.

**H. Both people on mobile data behind carrier NAT.**
May fail to connect at all, or drop after a network switch, because there is no
TURN relay. Not fixed yet, see section 7.

---

## 6. Test checklist (real phones)

Build fresh native apps first. Follow the VoIP test protocol for iOS
(install, restart both phones, open the app once, then test).

### 6.1 Camera and darkness (most important)

- [ ] **Same lamp-lit room, MonkeyHub vs WhatsApp**, two iPhones. Is the
      picture now comparable?
- [ ] **Check the log line on iPhone/Mac:**
      `target format 1280x720 ... selected format 1280x720`. If it still says a
      tiny format (like 192x144), the fix didn't take.
- [ ] **Check the new log line:** `mh_tuneCallCamera: 15-30 fps`. If missing,
      the exposure fix didn't run.
- [ ] **Flip to the back camera mid-call**, then back. The picture should stay
      bright both ways (the tuning re-runs on flip).
- [ ] **Mac (FaceTime camera)** in a dim room: brighter than before?
- [ ] **Android in dim light:** only reasoned about, never confirmed. Does the
      camera let the frame rate drop in the dark, or is it dark?
- [ ] **Framing:** does 720p show the same view as 4K, or is it cropped/zoomed?
- [ ] **HD and 4K now actually work on iPhone.** Pick 4K on a good network: is
      the phone getting hot? How fast?

### 6.2 Adaptive video

To make a weak link on purpose: macOS **Network Link Conditioner**
(Xcode additional tools) on a Mac, or iPhone **Settings → Developer → Network
Link Conditioner** (profiles "3G" / "Very Bad Network"). Or walk to a weak-Wi-Fi
spot.

- [ ] **4K, then weaken the network.** Within about 10 s: banner shows, the
      other phone's picture goes soft, **no flash or black frame**.
- [ ] **Restore the network.** About 30 s later one step up, about 30 s later
      another. Still no flash.
- [ ] **Keep it weak for 2+ minutes.** One brief hitch when the camera
      switches down. Log: `[Quality] camera re-captured at auto`.
- [ ] **Borderline network** (just barely enough for 1080p): does it bounce up
      and down, or settle with growing waits between tries?
- [ ] **Turn "Lower on weak connections" OFF**, repeat: offer banner with a
      Lower button, nothing changes until tapped. Close it: it doesn't come
      back for that quality.
- [ ] **In-call "More" sheet** while lowered: shows the actual quality. Picking
      4K by hand restores full quality right away.
- [ ] **Group call, 3 phones, weaken only one.** Only that person's view of you
      drops; the others keep full quality.
- [ ] **Screen sharing while lowered:** the shared screen should stay sharp
      (only the camera is shrunk).
- [ ] **Network stats panel** (Settings → call stats) in a group call still
      shows numbers per person (it now reads the service's stats).
- [ ] **Data Usage** after a group call: now shows call data.

### 6.3 Audio and connection

- [ ] **Bad network voice clarity:** with Network Link Conditioner at high
      packet loss, is speech clearer than before (redundant audio)?
- [ ] **Data saver on** ("use less data for calls"): calls still work, voice
      fine (redundant audio is off in this mode).
- [ ] **Wi-Fi → mobile data mid-call** (walk out the door): call survives.
- [ ] **Lift/tunnel:** call holds for up to 60 s and recovers.
- [ ] **Web peer** (browser on one side): calls still connect (new connection
      settings are ignored by browsers, should be harmless).

### 6.4 Translations

- [ ] Banner strings in all 12 languages were machine-written by Claude.
      Turkish was reviewed in a rendered preview; the other 10 need a quick look
      from a native speaker. Keys: `videoQualityAutoLowerTitle`,
      `videoQualityAutoLowerFootnote`, `callQualityLoweredBanner`,
      `callQualityOfferBanner`, `callQualityOfferAction`.

---

## 7. Known gaps and decisions

- **No TURN relay.** Decided 2026-11-05 not to self-host (one free Oracle Ampere
  box). Option for later: **Cloudflare Realtime TURN**, first 1,000 GB per month
  free, then $0.05/GB, nothing to run on our side. TURN only carries the calls
  that can't connect directly (about 1 in 7); at about 15 MB per 5 minutes of
  relayed video, 1,000 GB is about 65,000 relayed 5-minute calls a month.
  Backend change needed: request credentials from Cloudflare in
  `calls:getIceConfig` instead of generating our own. Self-host instructions
  remain in `backend/turn/README.md`.
- **Group calls with 5+ people** still upload one stream per person (mesh). A
  real fix is an SFU (see glossary), which costs money to run. Deferred.
- **No "back to 4K" banner** when quality recovers, on purpose (FaceTime shows
  nothing either).

---

## 8. Glossary (simple terms)

- **TURN:** a relay server. Normally your phone sends video straight to the
  other phone. Some networks block that, and the call never connects. TURN is a
  middleman that passes the video along, only when the direct path fails.
  **This is the one we need.**
- **STUN:** a tiny helper that tells your phone its public address so the
  direct path can be found. Free and already in use (Google's).
- **SFU:** a group-call hub. Today, in a 5-person call your phone uploads your
  video 4 times, once per person. With an SFU you upload once and the hub copies
  it to everyone. Only matters for big group calls. Not needed yet.
- **Cloudflare RealtimeKit:** a ready-made calling kit (SDK, call screens and
  SFU bundled). We built all of that ourselves, so we don't need it; switching
  would mean replacing our calling system.
- **Encoder:** the part that compresses video before sending. It can shrink
  frames on the fly.
- **Bitrate:** how much data per second the video uses (Mbps = megabits per
  second).
- **Opus RED:** redundant audio; each packet also carries the previous bit of
  speech, so a lost packet can be rebuilt.

---

## 9. Where things are in the code

| What | Where |
|---|---|
| Camera constraints, audio priority, RED, encoder shrink (`scaleCameraSender`) | `lib/calls/call_media.dart` |
| Adaptive policy (`VideoQualityGovernor`, `SendQualityLadder`, `CallQualityAdapter`) | `lib/calls/video_quality_governor.dart` |
| Connection stats, now incl. upload estimate | `lib/calls/call_stats_monitor.dart` |
| Reconnect window (`kMaxCallOutage` = 60 s) | `lib/calls/call_recovery.dart` |
| 1:1 wiring | `lib/calls/call_service.dart` |
| Group wiring, per-person stats | `lib/calls/group_call_service.dart` |
| Banner widget (`CallNoticeChip`) | `lib/calls/widgets/call_chrome.dart` |
| Banner layer (1:1 and group screens) | `lib/calls/widgets/video_quality_notice_layer.dart` |
| Settings switch | `lib/screens/video_quality_screen.dart`, `SettingsStore.autoLowerVideoQuality` |
| Native camera patch W8 | `third_party/flutter_webrtc/common/darwin/Classes/FlutterRTCMediaStream.m` (+ ios/, macos/ copies), `CameraUtils.m`, Android `GetUserMediaImpl.java` |
| Patch notes | `third_party/flutter_webrtc/PATCHES.md` |
| Tests | `test/video_quality_governor_test.dart`, `test/call_media_quality_test.dart`, `test/call_recovery_test.dart` |
| Banner render preview | `test/design_preview/quality_notice_preview.dart` → `build/design_preview/` |
