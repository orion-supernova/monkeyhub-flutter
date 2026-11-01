# Chat chrome: design language

The controls that sit around a transcript: the header's call buttons, the
pinned banner, the floating scroll column, the reply and edit cards over the
composer, the composer's own buttons, and the quote inside a bubble.

**Clean, simple, functional, expressive.** Every rule below follows from that.

## 1. Material

- **Floating chrome is glass** (`LiquidGlass`): header buttons, the pinned
  banner, the scroll column, the composer field and its buttons, the reply/edit
  card in the floating style. The classic style uses the raised plate.
- **Inline context is a tinted plate**: the quote inside a bubble.
- **Glass is never faded.** It grows in (`GlassReveal`), because a
  `BackdropFilter` inside an opacity layer blurs an empty buffer and flashes
  flat. Never animate the blur itself.

## 2. Colour

- **Glyphs are ink.** Header call buttons, the record/camera button, the "+",
  the scroll chevron and the jump-back arrow are all `theme.ink`.
- **The accent marks only what is yours or waiting for you**: the send disc,
  the `@` glyph, unread/mention counts, the active pin marker, your own edit.
- **Whose message it is gets that person's colour** (`SpeakerScope`): the rail
  and name on a quote and on the reply card. It falls back to the accent.
- A screen at rest should carry almost no colour.

## 3. Shape

- **One rail** (`ContextRail`) for "this is about another message": a 3pt
  rounded bar, used by the in-bubble quote, the reply/edit cards and (as
  segments) the pinned banner's position marker.
- Round buttons: 44pt in bars and the composer, 34pt for the scroll column.
- The scroll column is centred on the composer's trailing button
  (`composerTrailingCenter` / `scrollFabRightInset`).
- Close glyphs are drawn (`DrawnCloseGlyph`), not the font ×.

## 4. Motion (`lib/widgets/chrome_motion.dart`)

One vocabulary, geometric only (never a colour flash), and it all snaps to
rest under Reduce Motion (`MotionScope.calm`).

| Move | Where |
|---|---|
| `GlyphKick.dip` | scroll chevron: on tap, and when the unread count rises |
| `GlyphKick.rock` | voice call handset on tap; `@` when a new mention arrives; pencil on the edit card |
| `GlyphKick.pop` | video call camera on tap; `@` on tap |
| `GlyphKick.back` | jump-back arrow on tap; reply arrow as the reply card lands (mirrored) |
| `GlyphKick.lift` | pin glyph each time the banner steps to another pin (pressed down) |
| `SlideSwap` | pinned banner text stepping between pins; reply card retargeted |
| `ContextRail(animateIn)` | the reply/edit card's rail draws in from the middle |
| `DrawnCloseGlyph` | the card's × draws its two strokes in |
| `CountBump` | every count capsule pops when its number changes |
| Glide | the pinned banner's active marker slides between segments |

Rules:
- A kick is one stroke out and home, 380 to 560 ms. Kicks fire on an action or
  on a state change the reader did not cause (a new mention), never on a loop.
- Continuous loops are only for live states (recording, typing, a ringing call).
- Kick the glyph inside the glass, never the glass.
- Haptics: `selectionClick` on navigation taps, `mediumImpact` on destructive
  or "commit" actions (clear all mentions, start a call).

## 5. Building new chrome

Use the shared primitives (`LiquidGlass`, `GlassIconButton`, `ChatScrollFab`,
`CallGlyphButton`, `ComposerContextCard`, `ContextRail`, `KickGlyph`,
`SlideSwap`, `SpringPress`). Extend one with a parameter rather than copying it.
