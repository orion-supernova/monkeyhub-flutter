# Stickers and GIFs — store review and privacy

What changes for App Review, Google Play and the privacy policy now that the
composer has an emoji / GIF / sticker panel. Backend setup (the KLIPY key, the
ads switch, seeding the packs) is in [DEPLOY.md](DEPLOY.md#gifs-and-stickers--per-backend-setup);
the design notes are in the code (`lib/expressions/`, `backend/convex/expressions.ts`).

## 0. Where it stands (2026-09-30)

- Backend deployed to **both** boxes; 4 official packs / 116 stickers seeded on
  each; `KLIPY_API_KEY` set on both.
- **Ads are OFF** (`KLIPY_ADS=0` on both). Read §5 before turning them on — the
  privacy policy, Play's "Contains ads" answer and the children-in-audience
  question all currently say "no ads", and a build that shows one would
  contradict all three.
- Nothing about the feature needs a new permission, entitlement or Info.plist
  key on any platform. The photo picker it uses for "make a sticker" is the one
  the app already asks for.

## 1. What third parties see

| Who | What | From where |
| --- | --- | --- |
| **KLIPY** (GIF & sticker search) | search text, the category tapped, which item was sent (a "share" ping, which KLIPY's terms require), the device's IP address and user agent, and an opaque per-user id | the user's **device**, directly — KLIPY's terms forbid routing it through our servers. Never our servers. |
| KLIPY's CDN | requests for the GIF/sticker images, from every device that displays one (IP address, user agent) | the device |
| Google Fonts' `fonts.gstatic.com` | nothing at runtime — the Noto sticker files were copied into **our** storage once, at seed time, by the server (the Fluent and MonkeyHub packs are uploaded there from a Mac) | — |

The "opaque per-user id" is `sha256("monkeyhub-klipy:" + userId)` truncated —
stable per account so KLIPY can keep that user's recents, meaningless to
anyone who does not already hold our user ids. **No advertising identifier**
(IDFA / Android ad ID) is ever read or sent. Child accounts send
`content_filter=high` on every call and never request ads.

On **our** server: recently sent and starred GIFs/stickers (per account, synced
across devices), and the stickers a user makes from their photos. Both are
deleted with the account (`purgeUserExpressions`). A deleted personal sticker
stays visible in messages already sent, like any other photo in a chat.

## 2. App Review notes

Paste into **App Review Information → Notes** (append to what is there):

> **GIFs and stickers**
>
> The message composer has an emoji / GIF / sticker panel (the smiley in the
> message field). GIF and sticker search is provided by KLIPY
> (klipy.com), a licensed GIF API: the app calls KLIPY directly and shows its
> results with the required "Search KLIPY" / "Powered by KLIPY" attribution.
> The built-in sticker packs are MonkeyHub's own mascot art, Google's Noto
> Animated Emoji (CC BY 4.0) and Microsoft's Fluent Emoji (MIT), each credited
> in the app and on the licences page.
>
> Content controls:
> - KLIPY content is filtered by KLIPY's content-rating filter; supervised
>   (child) accounts always request KLIPY's strictest filter, and a guardian
>   who has turned media off leaves the child with the built-in sticker packs
>   only (enforced on the server, not just hidden in the UI).
> - Any GIF or sticker can be reported to KLIPY from its sheet (tap it →
>   Report); any message, including one carrying a GIF or a sticker made from
>   a photo, can be reported to us and its sender blocked, as before.
> - Users can make stickers from their own photos. These are shared only as
>   messages in conversations the user is already in — there is no public
>   sticker directory — and are covered by the same report/block tools.
>
> The app contains no advertising.

(Drop the last line, and revisit this whole note, if ads are ever enabled.)

**Guideline 1.2 (user-generated content)** is already met by the existing
report + block + EULA flow; personal stickers add no new public surface.

## 3. App Store privacy details ("nutrition label")

Apple counts data a third-party partner receives as collected by the app.
Recommended changes under **App Privacy**:

- **Search History** — *new*. Collected (by KLIPY). Used for: **App
  Functionality**, **Product Personalization** (KLIPY ranks and keeps recents
  off it). Linked to the user: **No** (KLIPY gets an opaque hash, not an
  account). Tracking: **No**.
- **Usage Data → Product Interaction** — add, or extend if already declared:
  recents and favourites are stored on our server, linked to the account, for
  App Functionality. Tracking: No.
- **Photos or Videos** — already declared for chat photos; "make a sticker"
  uploads the cut-out the same way. No change beyond confirming it is there.
- **Identifiers → Device ID** / **Advertising Data** — **leave undeclared**
  while ads are off. See §5.

## 4. Google Play

- **Data safety → App activity → In-app search history**: collected **and
  shared** (with KLIPY), purpose *App functionality* and *Personalization*,
  not optional to use GIF search, encrypted in transit.
- **Data safety → App activity → Other user-generated content / Other
  actions**: recents and favourites, collected, not shared, App functionality.
- **Data safety → Photos**: already declared for chat photos; unchanged.
- **Policy → App content → Ads**: stays **"No, my app does not contain ads"**
  while `KLIPY_ADS=0`.
- No new permissions: the web view used for ad tiles adds none, and
  `com.google.android.gms.permission.AD_ID` is not requested.

## 5. Privacy policy — text to add

The policy at `walhallaa.com/monkeyhub-privacy-terms.html` is not in this repo.
Add under **"Who else receives your data"**:

> **GIF and sticker search (KLIPY).** When you open the GIF or sticker panel,
> search, tap a category, or send a GIF or sticker from it, your device talks
> directly to KLIPY (klipy.com), the service that provides GIF and sticker
> search. KLIPY receives what you searched for, which item you sent, your IP
> address, your device's user agent, and a random-looking identifier derived
> from your account that lets KLIPY show you your own recent GIFs. We do not
> send KLIPY your name, username, messages, contacts or any advertising
> identifier. Anyone who sees a GIF or KLIPY sticker in a chat loads it from
> KLIPY's servers, which therefore see their IP address too. KLIPY's own
> privacy policy applies to what it receives. Supervised accounts always use
> KLIPY's strictest content filter.
>
> **Stickers.** The built-in sticker packs are stored on our server. Your
> recently used and starred GIFs and stickers are stored on our server with
> your account so they appear on all your devices. Stickers you make from your
> own photos are uploaded to our server like any other photo; they are deleted
> when you delete your account (copies you already sent in chats stay in those
> chats until then, like any other photo).

And under **"What we collect"**, a line for recents/favourites and personal
stickers pointing at the paragraph above.

## 6. Before turning ads on (`KLIPY_ADS` unset)

All of these, or none:

1. **Privacy policy**: remove "We do not run ads" / "No advertising" and
   describe KLIPY ads (ad content is fetched from the device with its user
   agent, IP, screen size and OS; no advertising ID).
2. **App Store**: privacy label gains **Third-Party Advertising** as a purpose
   for the data KLIPY receives, plus **Advertising Data**; update the review
   note in §2.
3. **Google Play**: "Contains ads" → **Yes**; Data safety gains *Advertising
   or marketing* as a purpose.
4. **Children**: MonkeyHub's audience includes children. Ads are already never
   requested for supervised accounts, but Play's **Families policy** allows
   only *Families Self-Certified Ads SDKs* in apps whose target audience
   includes children, and KLIPY is not one — so either confirm with KLIPY that
   its ad network is certified / COPPA-compliant, or keep the Play target
   audience 13+ (and the App Store age rating to match). Apple's Kids Category
   forbids third-party ads outright (guideline 1.3); MonkeyHub must not be in
   it with ads on.
5. `npx convex env remove KLIPY_ADS` on **both** boxes. No release needed.

## 7. KLIPY Partner Panel

Set the **content filter** there (KLIPY's terms say filtering is configured in
the panel, not in code). "Medium" keeps results compatible with a 12+/Teen
rating; the app's child accounts additionally force "high" per request.
