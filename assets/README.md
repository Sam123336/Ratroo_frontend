# Assets

Single source of truth for every visual asset in Ratroo: what is here, where it
came from, what licence it carries, and what is still missing.

**Rule: nothing ships in `assets/` without a row in this file.** An asset with
no recorded source cannot be audited, re-exported, or legally defended later,
and "I think it was free" is not a licence.

---

## Workflow — before building any visual component

Search in this order. Stop at the first rung that gives a usable result.

| # | Look here | For |
|---|---|---|
| 1 | `lib/widgets/`, `lib/core/` | A widget this project already has |
| 2 | Installed packages (`pubspec.yaml`) | Something a current dependency already does |
| 3 | [Flutter Gems](https://fluttergems.dev) · [pub.dev](https://pub.dev) · [ForUI](https://forui.dev) · [GetWidget](https://www.getwidget.dev) | A published Flutter component |
| 4 | [Rive Community](https://rive.app/community) | Interactive / state-driven animation |
| 5 | [LottieFiles](https://lottiefiles.com) | Linear playback animation |
| 6 | [Sketchfab](https://sketchfab.com) · [Poly Pizza](https://poly.pizza) · [BlenderKit](https://www.blenderkit.com) | 3D models (GLB) |
| 7 | [Storyset](https://storyset.com) · [DrawKit](https://www.drawkit.com) · [ManyPixels](https://www.manypixels.co/gallery) | Illustrations |
| — | Custom code | Only when nothing above fits |

**UX reference first** (patterns, not pixels): [Mobbin](https://mobbin.com) ·
[Refero](https://refero.design) · [Screenlane](https://screenlane.com) ·
[Layers](https://layers.to) · [Dribbble](https://dribbble.com) ·
[Behance](https://www.behance.net). Products worth studying directly:
Citymapper, Transit, Uber, Google Maps, Moovit.

Every asset added must record: **source URL · licence · attribution required?
· optimisation applied · why this over the alternatives.**

---

## Access reality

Recorded so nobody re-litigates it every session.

| Source | Reachable by an agent? | Notes |
|---|---|---|
| pub.dev, Flutter Gems, ForUI, GetWidget | ✅ yes | Packages install directly |
| Phosphor, Lucide, Heroicons | ✅ yes | Ship as packages/SVG |
| Google Fonts | ✅ yes | via `google_fonts` |
| Poly Pizza, Sketchfab | ⚠️ browsable | Most downloads need an account |
| **Rive Community** | ❌ **account required** | Files are **CC-BY**, but downloading/remixing needs a signed-in Rive account |
| **LottieFiles** | ❌ **account required** for most | Licence varies per file — check each |
| **Mobbin, Refero** | ❌ **auth-walled** | Patterns can be applied from knowledge; screens cannot be browsed |

**What this means:** anything in rungs 4–6 needs *you* to download the file and
drop it in. That is a two-minute job with a free account, and it is the single
biggest thing blocking the app's "wow" gap. See **Wanted** below.

---

## In the project now

### Brand — `assets/brand/`

| File | Source | Licence |
|---|---|---|
| `ratroo_logo.png`, `ratroo_icon.png`, `ratroo_icon_foreground.png` | Generated in-project by `tool/build_brand_assets.py` | Owned |
| `mode_bus.jpg`, `mode_rail.jpg`, `mode_ferry.jpg`, `mode_tram.jpg` | ⚠️ **unrecorded — needs confirming** | ⚠️ **unknown** |
| `hero_bus.jpg`, `hero_rail.jpg`, `hero_ferry.jpg`, `hero_tram.jpg` | ⚠️ **unrecorded — needs confirming** | ⚠️ **unknown** |

> **Open item:** the eight photographs predate this file and their origin is not
> recorded anywhere in the repo. Before any public release, either confirm their
> licence or replace them. Unlicensed stock photography in a shipped app is a
> real liability, not a formality.

### Icons

**Phosphor Icons** via [`phosphor_flutter`](https://pub.dev/packages/phosphor_flutter)
`^2.1.0` — MIT. Fonts ship inside the package; nothing lives in `assets/`.

All icons go through **`lib/core/app_icons.dart`** — one weight (Regular), with
Fill reserved exclusively for selected states. Do not reference
`PhosphorIcons*` or `Icons.*` directly in a screen; add a name to `AppIcons`.
*Chosen over Material Icons because Material mixes filled and outlined drawings
of the same idea — the app had eleven such pairs in use simultaneously.*

### Fonts

**Outfit** (display) + **Inter** (body/UI) via
[`google_fonts`](https://pub.dev/packages/google_fonts) — both SIL Open Font
License 1.1. Fetched at runtime, cached; nothing in `assets/`.

### Animation

No `.riv` or `.lottie` files yet. Current motion is hand-written Flutter:

| Widget | What it does |
|---|---|
| `lib/widgets/journey_preview.dart` | Multi-modal journey chain — the home hero |
| `lib/widgets/tilt_tap.dart` | Perspective press feedback |
| `lib/widgets/status_view.dart` | Empty / error / offline entrances |
| `skeletonizer` | Loading skeletons generated from the real widget tree |

### 3D

None. See the note on Spline below.

---

## Wanted — drop files here and they get wired in

Exact specs, so a downloaded file works without rework.

| Slot | Format | Spec | Search terms |
|---|---|---|---|
| Journey found | `.riv` or `.json` | ≤120 KB, loops once, transparent | "success", "route found", "check" |
| No route found | `.riv` or `.json` | ≤120 KB, non-looping | "empty", "not found", "search" |
| Offline | `.riv` or `.json` | ≤80 KB, loops | "offline", "no connection" |
| Searching | `.riv` | ≤80 KB, loops, ~1 s cycle | "loading", "radar", "scanning" |
| Bus / ferry / train | `.riv` | ≤200 KB each, side profile, loops | "bus", "ferry", "train", "vehicle" |
| Home hero 3D | `.glb` | **≤2 MB**, ≤20k tris, 1 material, Draco-compressed | "low poly bus", "city", "bus stop" |
| Empty-state illustrations | SVG | 2-colour, themeable | Storyset "travel", "map", "location" |

**Licence rule for anything dropped in:** CC-BY is fine — record the
attribution in the table above *and* add it to the in-app credits before
release. CC-BY-NC and "personal use only" are **not** usable: Ratroo is a
commercial product.

---

## Engineering notes on the recommended stack

Recorded so these get decided once.

**Rive over Lottie for interaction.** Rive files are state machines that react
to input and are typically far smaller; Lottie is linear playback. Use Lottie
for fire-and-forget moments (success ticks), Rive for anything responding to
the rider. [`rive`](https://pub.dev/packages/rive) `0.14.11`, verified
publisher, 1.9k likes, updated within the last week.

**Spline — recommended *against* for this app.** The only Flutter binding,
[`spline_flutter`](https://pub.dev/packages/spline_flutter), is `v0.0.1` with
0 likes and 146 total downloads, and renders scenes **inside a WebView via a JS
bridge**. Ratroo's users are largely on mid-range Android in West Bengal; a
WebView-hosted 3D scene on the home screen is a serious battery, memory and
frame-rate cost for decoration. If a 3D hero is wanted, the cheaper path is a
GLB via `model_viewer_plus`/`flutter_3d_controller`, or — cheapest and
smoothest — a pre-rendered sprite sequence or a Rive file that *looks*
dimensional. Revisit if `spline_flutter` matures.

**Maps: stay on `flutter_map`.** Already integrated, no API key, no per-load
billing, and OSM has good West Bengal coverage. `google_maps_flutter` would add
a billed key and a Google dependency for a nicer default style — not worth it
until styling is the actual bottleneck.

**ForUI** — free and open source, shadcn-inspired, plausible for future form
and sheet primitives. Not adopted: the app's components are already themed and
swapping them wholesale is churn without a user-visible win. Reconsider when
building genuinely new primitives. *(Licence not stated on its homepage —
confirm on GitHub before adopting.)*

---

## Colour palette

Defined in `lib/core/theme.dart` — that file is authoritative, this is a map.

| Token | Hex | Use |
|---|---|---|
| Primary | `#2563EB` | Brand, primary actions, **Bus** |
| Accent | `#EA580C` | Highlights |
| Secondary | `#0891B2` | **Ferry** |
| Rail | `#7C3AED` | **Train** |
| Metro | `#059669` | **Metro** |
| Tram | `#DB2777` | **Tram** |
| Walk | `#64748B` | Walking legs |

Mode colours are the app's main wayfinding device — a rider should identify a
mode by colour before reading the label. Always via `RatrooTheme.modeColor()`;
never a raw hex in a widget.

---

## The constraint that outranks everything here

**Ratroo must never display a transit fact it cannot source.** No invented
times, fares, ratings, coordinates or status indicators — however good it
looks. A fabricated departure sends a real person to an empty stop at night in
a rural district.

This applies to assets too: a decorative journey illustration must not carry
real-looking place names, times or fares. `journey_preview.dart` shows modes
and no numbers for exactly this reason.
