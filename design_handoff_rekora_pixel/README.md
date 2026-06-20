# Handoff: Rekora — "Premium Pixel · Nord Light" iOS Direction

## Overview
Rekora is an iPhone-first Apple Music backup app. It lets a user snapshot their
library (songs, albums, playlist order), export a backup file they own, preview a
restore, check live Apple Music matches, and rebuild playlists — all on-device,
nothing leaves the phone. This package covers the **"Premium Pixel · Nord Light"**
visual direction across the five core screens.

The aesthetic is a *crafted* pixel voice (Panic / Playdate, not Game Boy): pixel
display type, hard-edged blocks with chunky bevels, dithered panels, and
hand-built pixel-art icons on a cool Nord "Snow Storm" light surface.

## About the Design Files
The file in this bundle (`Rekora Pixel.dc.html`) is a **design reference created
in HTML** — a prototype showing intended look and behavior, **not production code
to copy directly**. It renders all five screens side-by-side as labeled iPhone
frames on a gray board.

The task is to **recreate these designs in Rekora's real environment** — the app
is a native **iOS app built in Swift / SwiftUI with MusicKit** (the repo already
contains models like `RebuildPlanSummary`, `LiveMusicMatching`, `PlaylistRebuild`,
`RestorePreviewViewModel`). Reproduce the visual direction using SwiftUI views,
`Color` assets, and a bundled pixel font — do not ship the HTML.

> Note: the HTML uses a reusable `IOSDevice` frame component purely to simulate the
> phone bezel/status bar for presentation. In SwiftUI that chrome is the OS itself —
> ignore the bezel and build only the screen content.

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing, and layout are
specified below to exact values. Recreate pixel-perfectly. The one thing to treat
as flexible is real iOS safe-area / nav-bar behavior, which replaces the simulated
status-bar padding used in the prototype.

---

## Design Tokens

### Colors (Nord palette — light theme)
| Role | Hex | Usage |
|---|---|---|
| Screen background | `#E5E9F0` | App background (Nord Snow Storm nord5) |
| Card / surface | `#ECEFF4` | Raised cards, list rows (nord6) |
| Card border / divider | `#D8DEE9` | 2px borders, row separators (nord4) |
| Text primary | `#2E3440` | Headlines, numbers, body (nord0) |
| Text secondary | `#3B4252` | Feature-bullet body (nord1) |
| Text muted | `#4C566A` | Subtitles, label text (nord3) |
| Text faint | `#616E88` | Micro meta labels (Nord "comment") |
| Signal green (accent) | `#A3BE8C` | Buttons, status dots, strong-match (Aurora green) |
| Green button bevel | `#8FA878` | Bottom bevel shadow on primary buttons |
| Green text (readable) | `#607D43` | Green text/numbers on light surfaces |
| Green text alt | `#6E8B57` / `#5E7D43` | Check-icon fill / "Matched" pill text |
| Green tint panel | `#E4EBDD` | "New playlist" confirmation card bg |
| Frost teal | `#88C0D0` | Secondary "search match" tier (Frost) |
| Frost blue | `#81A1C1` | Chevron icons (Frost) |
| Review orange | `#D08770` | "Metadata only" / review tier (Aurora orange) |
| Review orange text | `#C57A50` / `#B0654A` | Review numbers / titles |
| Review label text | `#A86347` | "Need review" label |
| Review panel bg | `#F6E7DF` | Playlist-order warning bg |
| Review panel border | `#E0B49E` | Warning card border |
| Review panel body | `#8A6A58` | Warning body text |
| Missing grey | `#9BA3B2` | "Missing record" tier dot |

### Hard pixel shadows (no blur — solid offset block)
- Cards: `4px 4px 0 rgba(46,52,64,.14)`
- List rows: `3px 3px 0 rgba(46,52,64,.12)`
- Primary button: `inset 0 2px 0 rgba(255,255,255,.55), 0 4px 0 #8FA878` (top highlight + bottom bevel)

### Borders / radius
- **No border-radius anywhere** — everything is hard square (pixel aesthetic).
- Standard border: `2px solid #D8DEE9` (or accent color for emphasis cards).

### Typography
Three pixel typefaces. Embed the TTFs in the iOS bundle (Google Fonts: Jersey 15,
Jersey 25, Silkscreen — all SIL OFL, free to embed).
| Token | Family | Notes |
|---|---|---|
| Display / numbers / buttons | **Jersey 25** | Heavier square pixel face; use for all large/emphasis text. Weight is intrinsic — do NOT apply bold. |
| Body / list items / paragraphs | **Jersey 15** | Lighter square pixel face; body copy and list rows. |
| Micro labels (ALL CAPS) | **Silkscreen** 400 | Section/meta labels, status pills. `letter-spacing: .02–.04em`, `text-transform: uppercase`. |

Apply a slight `letter-spacing: .01em` on Jersey 25 display text. All pixel fonts
should render crisp — for the small pixel-art SVG icons use `shape-rendering:
crispEdges` (SwiftUI: draw with `Path`/`Rectangle`s on an integer grid, no
anti-aliasing smoothing).

### Pixel texture
- **Scanlines** overlay on each screen: `repeating-linear-gradient(0deg, rgba(46,52,64,.04) 0 1px, transparent 1px 3px)`, pointer-events none, sits above background but below content. Very subtle.
- **Dither** on the warning panel: 4px checkerboard of `rgba(208,135,112,.08)` (two offset 45° linear-gradients, `background-size:4px 4px`, positions `0 0, 2px 2px`).

### Spacing
Screen content padding: `~58px top` (status bar/safe area), `22–26px` sides,
`34px` bottom. Card padding: `16–20px`. Vertical gaps between sections: `16–20px`.
Stat rows separated by a `2px solid #D8DEE9` top border with `16–18px` padding.

---

## Screens / Views

All five screens share: `#E5E9F0` background, scanline overlay, a Silkscreen micro
label (faint `#616E88`/`#4C566A`) above a Jersey 25 title, and a chunky primary
button (`#A3BE8C` fill, `#2E3440` text, bevel shadow) pinned near the bottom.

### 1. Connect (onboarding / permission)
- **Purpose**: First run — explain the app and request Apple Music access.
- **Layout**: Vertical flex. Top micro-label `APPLE MUSIC // BACKUP`. Centered block: "Rekora" wordmark (Jersey 25, 60px), subtitle (Jersey 15, 20px, `#4C566A`, max-width 272px), a 48×3px `#D8DEE9` divider, then three feature bullets. Bottom: primary button `CONNECT APPLE MUSIC` + faint centered caption `Your library never leaves this device`.
- **Feature bullets**: pixel check icon (green `#6E8B57`, 16×16 grid) + body text (Jersey 15, 17px, `#3B4252`):
  - "Snapshots of songs, albums & playlist order"
  - "Export your own backup file, anytime"
  - "Rebuild playlists when you're ready"

### 2. Home (latest backup status)
- **Purpose**: Show latest snapshot + history; trigger a new backup.
- **Layout**: Label `YOUR LIBRARY` → title "Backups" (Jersey 25, 40px). 
- **Latest snapshot card** (`#ECEFF4`, 2px `#D8DEE9` border, hard shadow): header row `LATEST SNAPSHOT` label + status (8×8 green square + "On device" in `#607D43`); date "June 6, 2026" (Jersey 25, 31px); meta "8:44 PM · 4.2 MB" (`#616E88`); a `2px #D8DEE9` top-bordered stat row — **9,453 Songs / 93 Albums / 19 Lists** (numbers Jersey 25 25px, labels Silkscreen `#4C566A`); primary button `BACK UP NOW`.
- **Earlier list**: label `EARLIER`, then 3 cards (each its own hard-shadow block, 10px gap) — "May 22, 2026" / "Apr 30, 2026" / "Apr 3, 2026" with faint meta ("9,448 songs · 19 lists" etc.) and a pixel chevron (`#81A1C1`).

### 3. Backup complete
- **Purpose**: Confirmation after a backup; offer export.
- **Layout**: Centered. 66×66 green badge with a large pixel check (`#2E3440` on `#A3BE8C`); "Backup complete" (Jersey 25, 34px); caption "9,453 songs saved · just now". Stat card (9,453 / 93 / 19). **Playlist order note** — dithered orange panel (`#F6E7DF` bg, `#E0B49E` border, `#D08770` dot): title "Playlist order note" (`#B0654A`), body explaining Apple reported unusual order for 2 playlists and Rekora saved its own observed order. Bottom: secondary button `SAVE A COPY TO FILES` (floppy pixel icon, outline style — transparent bg, 2px `#A3BE8C` border, `#607D43` text) + primary `DONE`.

### 4. Restore preview (readiness tiers)
- **Purpose**: Show how well a backed-up playlist can be restored before acting.
- **Layout**: Label `RESTORE PREVIEW` → title "Late Night Drive" (Jersey 25, 32px) → meta "64 tracks · from Jun 6 backup". 
- **Readiness bar**: 24 hard pixel blocks (2px gaps, 16px tall) proportioned ~75/13/8/4: 18× green `#A3BE8C`, 3× teal `#88C0D0`, 2× orange `#D08770`, 1× grey `#9BA3B2`.
- **Tier list** (rows separated by `2px #D8DEE9`): colored 11×11 square + label + faint sublabel + count (Jersey 25):
  - Strong match `#A3BE8C` — "Catalog or Apple Music ID" — **48**
  - Search match `#88C0D0` — "ISRC lookup" — **9**
  - Metadata only `#D08770` — "Needs your review" — **5**
  - Missing record `#9BA3B2` — "Not in this backup" — **2**
- Reassurance line (`#4C566A`): "Rekora only rebuilds confident matches… nothing changes without asking." Primary button `CHECK APPLE MUSIC MATCHES`.

### 5. Match results (matched / needs review + rebuild)
- **Purpose**: Live Apple Music match outcome; confirm playlist rebuild.
- **Layout**: Label `MATCH CHECK` → title "Results" (Jersey 25, 34px). 
- **Two stat tiles**: "51 / Ready to rebuild" (green-bordered card, number `#607D43`) and "13 / Need review" (orange-bordered `#E0B49E`, number `#C57A50`).
- **Track list** (card, rows split by `2px #D8DEE9`): title (Jersey 15, 17px, ellipsis) + artist (Silkscreen faint) + a Silkscreen status pill:
  - "Nightcall" / Kavinsky — **Matched** (`#5E7D43` on `rgba(163,190,140,.32)`)
  - "Midnight City" / M83 — **Matched**
  - "Resonance" / Home — **Review** (`#B0654A` on `rgba(208,135,112,.2)`)
  - "Untitled Demo" / Unknown artist — **Missing** (`#4C566A` on `rgba(76,86,106,.1)`)
- **New-playlist card** (green-tint `#E4EBDD`, 2px `#A3BE8C`): label `NEW PLAYLIST`, title "Rekora Restore — Late Night Drive", body "Your 19 existing playlists won't be touched. Rekora only ever creates new playlists."
- Bottom: primary `REBUILD PLAYLIST · 51 TRACKS` + faint caption "13 tracks will be skipped".

---

## Pixel-art icons (build as integer-grid shapes, crisp edges)
- **Check** (16×16 grid): stair of 2×2 squares at (2,7)(4,9)(6,11)(8,9)(10,7)(12,5). Green `#6E8B57` on light, or `#2E3440` on the green badge.
- **Chevron** (8×10): 2×2 squares at (2,0)(4,2)(6,4)(4,6)(2,8), fill `#81A1C1`.
- **Floppy / save** (16×16): green body `2,2 → 12×12`; top-right corner notch `12,2 2×2` in bg color; shutter window `5,3 3×3` bg; label panel `5,9 6×4` bg; one label line `6,11 4×1` green.

## Interactions & Behavior
- **Connect** → requests `MusicKit` authorization; on grant, route to Home.
- **Back Up Now** → runs snapshot, shows progress, lands on **Backup complete**.
- **Save a Copy to Files** → exports the backup file via the iOS share/Files sheet.
- **Check Apple Music Matches** → runs `LiveMusicMatching`, transitions Restore preview → Match results.
- **Rebuild Playlist** → calls `PlaylistRebuild`, creates a NEW playlist only (never mutates existing). Disabled/secondary affordance must make clear skipped tracks won't be added.
- Buttons use the chunky bevel; on press, suggest a 2px downward translate + bevel collapse (tactile pixel feel). Transitions otherwise minimal/instant to suit the aesthetic.
- All copy above is final — use verbatim.

## State Management
Reuse existing Swift types where present:
- `RestorePreviewViewModel` / `RestorePreviewState` (`.loading`, `.ready(summary)`) drives screen 4.
- `RebuildPlanSummary` supplies snapshot date, playlist list, counts.
- `LiveMusicTrackMatch` (status tiers) drives the readiness bar + tier counts.
- `MatchedPlaylistTrack` drives screen 5's track list + pill status.
- Counts shown (9,453 / 93 / 19; 48/9/5/2; 51/13) are sample data — bind to real models.

## Assets
No raster assets. All icons are vector pixel-art reproducible from the specs above.
Fonts must be added to the bundle: **Jersey 15**, **Jersey 25**, **Silkscreen**
(Google Fonts, SIL OFL).

## Files
- `Rekora Pixel.dc.html` — the five-screen design reference (open in a browser to view).
  The relevant Swift model files referenced above live in the project's `uploads/`
  source set (`RebuildPlan.swift`, `LiveMusicMatching.swift`, `PlaylistRebuild.swift`,
  `RestorePreviewViewModel.swift`).
