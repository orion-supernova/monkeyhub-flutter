# Rewarded ads: bananas

Status: built 2026-11-16, not yet on a device. Rewarded videos only: no
banners, no interstitials, nothing a player did not ask for.

## The loop

A banana (🍌) is the currency. Players earn it, and spend it on the moment
they are stuck:

| Spend | Cost | Cap |
|---|---|---|
| Code puzzle: one more guess (out of guesses, answer still hidden) | 1 | 3 per puzzle |
| Daily puzzle: one more hint (after 3 free) | 1 | 3 per puzzle |
| Bot game: one more takeback (after the level's free ones; hard included) | 1 | none |
| Jungle Fist vs bot: get back up after a lost match | 1 | 3 per fight |
| Streak save: missed exactly one day | 2 | once per gap |

| Earn | Amount |
|---|---|
| Rewarded video | 1, every 3rd video of the day 2 |
| Free daily banana (mobile) | 1 |
| Daily video cap | 15 (UTC day) |

Why people keep watching: the sheet opens exactly when they are stuck, one
tap plays a video and the banana is spent at once on what they wanted (no
second tap); the bonus meter (three dots, the third bigger) always says how
close the next double is; leftover bananas carry over, so watching ahead
feels like saving up. The streak save is the strongest pull and costs 2.

Fairness: bought guesses and hints already rank below clean results (a
hinted solve is its own group on the daily board; a bought-guess Code solve
is 7/6 to 9/6), and neither ever sets a personal best (`noteSolve` `clean`).

## Platforms

Videos play on iOS and Android only (`RewardedAds.available`). The wallet is
the account's, so Mac, web, Windows and Linux can spend bananas earned on a
phone; where the watch button would be they get "Bananas come from short
videos in the phone app" and Get the app. Child accounts never see a video and
the server refuses to credit one.

## Ads setup

AdMob account: Maymun Partisi (publisher `pub-8148544480843214`).

| | App id | Rewarded unit "Lifeline" |
|---|---|---|
| iOS | `ca-app-pub-8148544480843214~2736027209` | `ca-app-pub-8148544480843214/2127467203` |
| Android | `ca-app-pub-8148544480843214~6240157947` | `ca-app-pub-8148544480843214/7852622518` |

Both apps were added as "not listed on a store" because MonkeyHub was not
publicly listed on 2026-11-16. Ad serving is limited until each is linked to
its store listing in AdMob (Apps > Add store) and reviewed. `app-ads.txt` on
the developer site must carry `google.com, pub-8148544480843214, DIRECT,
f08c47fec0942fa0`.

Non-personalised requests (`AdRequest(nonPersonalizedAds: true)`), so no ATT
prompt. Google's UMP consent form runs once before the first ad (EEA/UK).
Content rating capped at T. App Store privacy labels need the AdMob entries
(device id for ads is not collected since we never ask ATT; "Advertising
Data" / "Product Interaction" used for third-party advertising).

## Server-side verification

Bananas are credited only by AdMob's SSV callback, never by the app:
`GET https://termio-api.walhallaa.com/http/admob/ssv` (HTTP actions live under `/http` on this self-hosted origin; `backend/convex/http.ts`, `adSsv.ts`). The handler
verifies Google's ECDSA signature (keys from
`gstatic.com/admob/reward/verifier-keys.json`, cached 6 h, refetched on an
unknown key id), accepts only our two ad units (`ADMOB_AD_UNITS` env
overrides), then `lifelines.creditAd` dedupes on the transaction id (last 20
kept on the wallet row). Both ad units have this SSV URL set and verified in AdMob (2026-11-16;
ad unit > Advanced settings > Server-side verification). The app passes
`ServerSideVerificationOptions(userId)` and polls the wallet for up to ~17 s
after a watched video.

## Cost (R17)

| Action | Reads | Writes | Re-runs | Idle |
|---|---|---|---|---|
| Open the banana sheet | 1 (own wallet row) | 0 | none (no subscription) | 0 |
| Verified ad (SSV) | 2 (user, wallet) | 1 | none | 0 |
| Spend | 1-2 (wallet + one game row) | 2 | the game row's existing readers | 0 |
| Free daily banana | 2 | 1 | none | 0 |
| Hub streak check | ≤ 20 `gameRecords` rows, once per hub open | 0 | none | 0 |
| Poll after a video | 1 per poll, ≤ 20 polls | 0 | none | 0 |

No jobs, no crons, no fan-out. `lifelines` is one row per user, cascaded with
the account (`referenceRules.ts`).

## Code puzzle rule change

Out of guesses unsolved with extras still buyable, the attempt stays open:
`done: false`, the answer hidden, `finishedAt` unset (so friends do not see
it yet). The player buys a guess or concedes (`puzzle:concede`), which ends
it as a loss and reveals the code. An attempt abandoned in that state never
reaches the friends' board.

## Hints rule change

Hints used to be free and unlimited. Now 3 free per puzzle (`FREE_HINTS` in
`backend/convex/lifelines.ts`), then a banana each, up to 3 more
(`OUT_OF_HINTS`). Raising `FREE_HINTS` is the one-line revert.

## Open

- Link both AdMob apps to their store listings once public.
- Jungle Fist stages and paints as in-app purchases: undecided (user, 2026-11-16).
