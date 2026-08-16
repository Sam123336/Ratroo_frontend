# Changes — session of 15 August 2026

Both repos. Navigation architecture and the home screen's hierarchy in
`Ratroo_app`; getting the Vercel deployment to boot at all in `Ratroo_backend`.

**State at the end:** `flutter analyze` clean · 105 Flutter tests (93 → 105) ·
backend typechecks clean · Vercel builds and serves · every app change looked
at in a running app rather than reasoned about.

---

## The screen is now visible

The previous session closed on this:

> Every change so far was made without being able to see the result — roughly
> half needed correcting. A working simulator, or one reference screen per
> change, is what makes this converge.

`xcrun simctl` is unavailable on this Mac (`xcode-select` is not pointed at a
full Xcode), but the web target needs none of that. `.claude/launch.json` runs
`flutter run -d web-server -t lib/main_dev.dart`, and the browser at a 375×812
viewport is a good enough phone for layout, hierarchy, type and both themes.

That changed the character of this session: **three of the five defects below
are ones the code's own comments asserted were impossible.** They were only
findable by looking.

---

## Navigation — the bar is now the app's, not Home's

The five destinations were `context.push`ed from a `NavigationBar` built
*inside* `HomeScreen`. Three consequences, all wrong:

- **The bar vanished the moment you left Home.** Plan → Nearby meant going
  back to Home first.
- **Tabs stacked.** Home → Plan → Nearby → Ask → Profile was a five-deep back
  stack of five top-level places.
- **`selectedIndex` was hardcoded to `0`.** Nothing was ever marked current
  except Home, including when you were not on it.

Now a `StatefulShellRoute.indexedStack` in `router.dart` with the bar in
`widgets/app_shell.dart`. Each branch owns its navigator, so a drill-down in
Nearby and half-typed input in Plan both survive a trip to another tab.
Re-tapping the current tab pops that branch to its root.

Detail routes — `/route-details`, `/place-details`, `/search`, `/providers` —
stay **outside** the shell on purpose. A timetable wants the whole screen, and
a bar over it only offers ways to abandon it halfway.

`CityCard`'s "View map" and its mode cards still used `push('/nearby')`, which
under the shell stacked a second Nearby *over* the bar while the bar underneath
still said Home. Both are `go` now.

`AppShell.contentInset` (100) is what a scrolling tab root reserves so its last
row clears the floating bar.

Pinned by `test/app_shell_test.dart` — five cases, one per failure above.

## Home — the hierarchy decision, finally made

Home now answers three questions, in order, once each: **where do you want to
go** (the search field, the screen's single primary action) → **what runs
around here** (the city card) → **what did you keep** (your journeys).

Everything below follows from that.

### The hero was painting over its own copy

The headline sat in a `Row` beside a 178px slot holding the bus video. Above it:

> A Row cannot get the order wrong, and the text can never be overlapped
> because the two occupy different space.

Except the video was in an `OverflowBox` with `maxWidth: 232` — which is
precisely how a child escapes the space it was given — translated 30px left,
under two nested `ShaderMask`es. On screen the subtitle read **"Bus, ferry,
rail and t"** and stopped, with a hard-edged rectangle over the rest. The
fades did not survive the video texture either, so 45 lines of masking bought
a hard rectangle sitting on the copy.

The banner is now full-width above the headline, as the rounded card
`BusBanner` already knew how to draw. The animation gets the room that
widget's own doc comment asks for, and the headline gets all 327px of a small
phone instead of wrapping to four ragged lines in 180. `OverflowBox`,
`Transform`, both `ShaderMask`es and the fixed 176px row are gone.

### Two headings, two map links, nothing between them

`_buildNearbySection` opened with "Ready to travel?" and a **See Map** button.
`CityCard` — the only thing it renders in the normal case — then opened with
"Travel across West Bengal" and a **View map** button immediately underneath.
The outer heading is deleted; the card names its own section. That also closed
~100px of dead space nobody had noticed.

### The placeholder had drifted from the layout again

Home drew four grey circles while coverage loaded, left over from when the
section *was* four photo circles. It has been a strip of 132×172 cards since
the last session, so the screen resolved from four circles into three
rectangles. `skeletonizer` is in `pubspec.yaml` specifically so this cannot
happen; home was the one place still hand-drawing bones. Now
`CityCardSkeleton`, built from the real `_ModeRow`, plus `SkeletonList` for
saved routes.

### Smaller

- **"Your journeys" empty state** was a 24px-padded box around a 48px glyph —
  the tallest thing on the screen, for one sentence. It also read "Ask Ratroo a
  question and keep the answer" inside a dead box. Now a row, and tappable to
  the thing it names.
- The headline used an inline `GoogleFonts.outfit(fontSize: 26, …)`;
  `displaySmall` already defines that size, weight and tracking.

## The bottom inset was counted twice

Home, Profile and Ask each wrapped their body in a plain `SafeArea` *and*
reserved `AppShell.contentInset` (100). Under `extendBody: true` Flutter
already adds the navigation bar's height to the body's `MediaQuery`, so the
`SafeArea` reserved it once and `contentInset` reserved it again — ~184px of
inset where the bar covers 84, leaving a bar-sized band of dead space below
the content. Most obvious on Ask, where the composer floated ~100px clear of
the bar with nothing in between.

All three are `SafeArea(bottom: false)` now: the inset at the end of the
scroll is the one that clears the bar. Nearby and the planner were always
correct — they have no `SafeArea` — which is why the gap appeared on three
screens and not five.

## Ask — the composer floats

Clearing the floating bar meant 100px of bottom padding, and the composer's
own full-bleed surface filled all of it: the screen ended in a 330px empty
slab with the input stranded at its top. It is a rounded pill with a margin
now, matching the language of the bar it sits above.

## Place names — one getter instead of six call sites

Nearby listed **"KOLKATA"** and **"CHANDRAKONA ROAD"**; search listed the same
stops title-cased, because search was the only screen that wrapped its rows in
`titleCaseName`. Rather than add that call in five more places, `Place` gained
`displayName`. `canonicalName` stays raw for the things that must match the
API — query strings, deep links, the WBBUS timetable URL.

Applied in Nearby, place details, the planner and search. Covered in
`test/place_display_test.dart`, including that `canonicalName` is unchanged.

## Visual direction — ported from the Stitch project

`stitch.withgoogle.com/projects/7122472696415410006` ("Ratroo Transit App Map",
7 screens). Taken as the design direction; the tokens below are its Material 3
scheme.

### Tokens

| | Was | Now |
|---|---|---|
| Ground | `#0F1115` neutral | `#111316` warm |
| Cards | one flat `#1C1F26` | ramp: `#1A1C1F · #1E2023 · #282A2D · #333538` |
| Hairline | white at 6–12% | `#554336`, a line you can see |
| Brand | `#2563EB` blue | `#FF9933` saffron, `#FFC08D` on dark |
| Display | Outfit | Space Grotesk |
| Figures | Inter | **JetBrains Mono**, tabular |

The flat dark theme was the main reason the app read as one black sheet: two
near-identical blacks and an invisible border. An elevation ramp plus a warm
visible outline fixes it without a single shadow.

`RatrooTheme.mono()` is new — every departure time, countdown, route code,
distance and count goes through it. A timetable aligns numerals in columns all
day, and proportional digits make 14:05 and 14:15 different widths.

### Mode colours are now separate from the brand

`modeColors['bus']` was an alias for `primaryColor`. The moment the brand went
saffron, every bus tile turned the same hue as the Save button and the selected
tab — a *mode* became indistinguishable from an *action*. Bus has its own blue
now, and `modeColor()` falls back to grey rather than to the brand. Two tests
pin it, including one asserting no mode ever aliases `primaryColor`.

### The coverage strip is a grid

Was a horizontal strip that clipped its third tile mid-word — "8 route… /
25 stati…", which reads as a rendering fault, not an invitation to scroll. Now
a two-column grid: every mode visible, twice the width each, and the odd
trailing cell holds the map link instead of air.

The tile itself leads with the figure at display size on a mode-tinted icon
plate, rather than a 26px glyph pinned to a corner with the middle third empty.

Height is `mainAxisExtent: 134`, not `childAspectRatio`. A ratio grows the tile
with the column, so a 400px-wide cell on a tablet became a 330px-tall one.
`city_card_test` caught this.

### What was deliberately not copied

The Stitch mocks put **LIVE** in five places — `LIVE ACCURACY`, `LIVE: On
Schedule`, `Live Beta Active`, `FROM LIVE ROUTE DATA`, a green `Live` pill —
plus `142 Active Buses`, a `Normal` status chip, `12 min Away` per favourite,
`Every 15 mins`, and stop amenities.

**Ratroo has no live feed**, and this file already records deleting exactly
these claims from route details once. None of it is held data. The badge
*slots* are worth keeping; they get filled from the provenance vocabulary that
already exists — `SCRAPED` vs `INTERPOLATED`, `timeIsEstimated`,
`OPERATOR_VERIFIED`, `confidence` — so the badge carries information instead of
decoration.

### Mode illustrations — in

Generated illustrations for bus, rail, tram and ferry, plus a map tile.

| Consumer | Asset |
|---|---|
| `ModeAvatar` — coverage grid plate (44px) and Nearby rows (48px) | `mode_<mode>.jpg` |
| `_ViewMapTile` | `tile_map.jpg` |
| `ModeHero` — mode-filtered Nearby banner (168px) | `mode_<mode>.jpg` |

Each falls back to the tinted glyph, so a missing file degrades rather than
showing a broken-image box.

**Two art sets arrived.** The first was app-icon art — a small vehicle inside a
night scene inside a baked rounded-square frame. In a 44px plate that gave a
frame inside a frame and a vehicle too small to identify, and the bus sat on a
white page so its tile had a white halo. Cropping each to its subject rescued
them, but the second set is the right material: **transparent cut-out vehicles,
no scene, no frame.**

That flipped the fit. Cut-out art wants `BoxFit.contain` on the mode-tinted
plate, so the whole vehicle shows and the tint reads through behind it; `cover`
is for full-bleed scenes and crops the nose off.

`ModeHero` was rebuilt for the same reason. It was a photograph filling a
168px banner under a black scrim — but a scrim exists to rescue white text from
a bright sky, and a cut-out has no sky. It is now words left, vehicle right, on
a wash of the mode's own colour, which does the contrast job and names the mode
at the same time.

**Sizes.** They arrived at 1.4–1.6 MB each. All carry alpha so PNG stays;
downscaled to 768, which is ample for a 48px plate and for a ~250px contained
vehicle in the banner at 3x. ~260–400 KB each. No `cwebp` or ImageMagick here
and `sips` cannot encode WebP — that would roughly halve them again.

`assets/brand/` is declared in pubspec as a *directory*, so everything in it
ships, including a `.DS_Store`. That is now gitignored.

**The unlicensed stock photos are gone.** All four `hero_*.jpg` deleted —
including `hero_bus.jpg`, which was `BusBanner`'s fallback and had no
`errorBuilder` behind it. `BusBanner` now falls back to the generated cut-out
on a tinted ground, and to a plain tinted panel if even that is missing. This
closes the provenance blocker `assets/README.md` has carried for three sessions.

**Still missing: auto / shared auto** — the operator-submitted modes no scraper
covers, and the app's differentiator. Amber `#D97706`. Metro can wait; nothing
is ingested.

### Three bugs the saffron rebrand exposed

**`ModeAvatar` painted every mode `colorScheme.primary`.** Right glyph per
mode, one colour for all of them — so a tram stop, a ferry ghat and a bus stop
were identical but for a 24px silhouette. Once the brand went saffron it also
meant every list row matched the selected tab and the primary button: a *stop*
looked like an *action*. Now `RatrooTheme.modeColor`, matching the grid.

**Skeleton bones were saffron discs.** `CircleAvatar` defaults to the scheme's
primary, so every loading row showed a solid brand-coloured circle. A bone that
draws the eye is the opposite of a bone.

**Two switches over the same seven modes.** `modeIcon(category)` keyed on
`BUS_STOP`; the coverage grid holds the bare `bus`. Calling one with the
other's spelling fell through to the generic map pin — every tile in the grid
drew a pin instead of its vehicle. Collapsed to one mapping: `modeIconFor(mode)`
is the switch, `modeIcon(category)` delegates through `modeKey`.

### `titleCaseName` fixed

Its doc comment has always claimed "C.R. Avenue" was handled. It was not:
`C.R.` is four characters, so the `length <= 3` initialism guard missed it and
Nearby rendered **"C.r. Avenue"**. Invisible until `displayName` made every
screen title-case; before that Nearby showed the raw `C.R. AVENUE`.

Dotted initialisms of any length are now kept (`C.R.`, `B.B.D.`), and the short
rule only applies to dotless tokens, so `ST.` correctly becomes `St.`.

## Sign-up form had no labels

All three fields were placeholder-only:

```
hintText: 'Your name (optional)'   hintText: 'Email'   hintText: 'Password'
```

A hint disappears the moment you type, so a *filled* form carries no labels at
all. A rider who typed their email into the name box saw two identical rows
reading "sam@gmail.com" and nothing to tell them apart. Screen readers had the
same problem: once a field has content there is nothing left to announce.

`_LabelledField` puts the label above the field. Not `labelText`: these inputs
use `radiusPill`, and a floating label notches the outline — a notch cut into a
full-radius curve reads as a rendering fault. `Semantics(label:)` carries the
same name to assistive tech, since a sibling `Text` is not programmatically
tied to the field.

Also: hints became examples rather than repeated labels (`you@example.com`),
the name field gained `AutofillHints.name` and word capitalisation, and the
8-character rule is now stated under the password field on sign-up instead of
only appearing as an error after failing.

## Backend — the Vercel deployment had never worked

Every path on the deployed API returned Vercel's own `NOT_FOUND` page. Not one
bug: **six, stacked**, each hidden behind the one before it, so each fix
revealed the next.

| # | Symptom | Cause |
|---|---|---|
| 1 | Vercel `NOT_FOUND` on `/`, `/v1`, everything | Root Directory unset — `apps/api/vercel.json` was never read, so no function was ever built |
| 2 | `crons[0] should NOT have additional property "//"` | a JSON pseudo-comment; Vercel validates against a strict schema |
| 3 | `No Output Directory named "public"` | Vercel ran `npm run build` then looked for a static site |
| 4 | `TypeError: Invalid URL` | `DATABASE_URL` pasted with template placeholders still in it |
| 5 | `getaddrinfo ENOTFOUND db.<ref>.supabase.co` | Supabase's direct host is **IPv6-only**; Vercel functions are IPv4-only |
| 6 | `tenant/user … not found` | right pooler, wrong cluster |

Fixes, in the same order: Root Directory set to `apps/api` (via the API, since
the setting is server-side); the `"//"` key removed and the note it carried —
that `30 20 * * *` UTC is 02:00 IST — moved to `docs/deployment.md`; an empty
`apps/api/public/` with a `.gitkeep` explaining why it must stay; and
`DATABASE_URL` repointed at the connection pooler.

**`assets/`-style footgun in `apps/api`:** `vercel.json` declares the
*directory*, so everything in it ships — including a `.DS_Store`. Now
gitignored.

### Finding the right pooler took a sweep, not a guess

Supabase's direct host has no `A` record at all:

```
db.daqeyqrsnkxaocbwnecd.supabase.co   A: (none)   AAAA: 2406:da12:557:f802:…
```

That IPv6 prefix is AWS Mumbai, so `ap-south-1` looked obvious. It was wrong.
Probing every region × cluster with a deliberately junk password separates the
two failure modes — a wrong tenant says `tenant/user not found`, a *correct*
tenant says `password authentication failed`:

```
HIT  aws-1-ap-northeast-2.pooler.supabase.com   password authentication failed
```

Worth remembering as a technique: **an auth error is a positive result** when
you are looking for which host owns a tenant, and it needs no real credential.

### Two serverless correctness fixes

- **`connectionTimeoutMillis: 10000`.** `pg` defaults to *no* connect timeout.
  Sequelize connects during module init, so an unreachable database does not
  make one route slow — `NestFactory.create` never resolves and **every**
  endpoint 500s, `/health` included, after a silent ~27 s. That is exactly how
  this presented, with nothing in the logs naming the database.
- **`pool: { max: 2, acquire: 15000 }`.** Sequelize defaults to 5 per instance;
  every warm Vercel container holds its own pool, which against pgbouncer
  multiplies into connection exhaustion.

Both overridable via `DB_CONNECT_TIMEOUT_MS` / `DB_POOL_MAX`.

### A malformed DATABASE_URL now says so

`new URL()` throws a bare `TypeError: Invalid URL` naming neither the variable
nor the value, three frames deep, during module init — so the whole app fails
to boot and the only clue is a stack trace. It now names the variable, the
expected shape, and the specific reason: unreplaced `< >` placeholders,
stray `[ ]`, whitespace, or a missing scheme. Four cases exercised.

**Security note recorded here on purpose:** the database password appeared in
Vercel's runtime logs, because a mis-encoded `@` made Supavisor echo it back as
part of the username. It needs rotating, and `@` `:` `/` `#` must be
percent-encoded in the connection URL.

## The dev API host was hardcoded to a machine that does not exist

`flavors.dart` pinned `192.168.1.6`. This Mac is `.13`, and an Android emulator
cannot reach the host by LAN IP anyway — it needs `10.0.2.2`, the alias the
emulator maps to the host. The symptom was "Can't reach Ratroo. Check your
connection." with a perfectly healthy server on `:3000`.

Now chosen per platform, with `--dart-define=API_HOST=` still the override for
a physical device — the one case with no correct default.

The previous session's notes claim this was already fixed. It was not; the code
was a plain constant.

## A debug pin for the rider's position

```
flutter run --dart-define=DEBUG_LAT=12.9629 --dart-define=DEBUG_LNG=77.5775
```

Coverage differs sharply by state — 2,750 routes in West Bengal, 50 in
Karnataka, nothing in Bihar — and each renders a different screen, so switching
regions is routine work. An emulator's GPS is not dependable enough for it:
the Android emulator console answers `OK` to every `geo fix` and then serves
the previous position, or none, indefinitely.

Gated on `kDebugMode`, a compile-time constant, so the branch is tree-shaken
out of release builds entirely. `location_cache_test.dart` asserts the gate
stays written in that form, so it cannot later be "fixed" into a runtime flag.

## Bengaluru has stops and routes but no times, by choice

A rider opening a BMTC stop sees "The routes below do stop here — we just do
not have their times". That is accurate: 5,610 stops and 50 routes are
ingested, and **zero** `stop_times`.

The blocker is not engineering. `bmtc-gtfs-network.ts` already parses
`agency/routes/stops/trips/stopTimes`, so a feed could be ingested in a day.
It is `providers/karnataka/bengaluru/README.md` holding the line:

> Unofficial BMTC GTFS datasets are fixtures/research only unless publisher,
> license, freshness, and permissions are verified.

Three candidate sources were assessed:

| Source | Verdict |
|---|---|
| [OpenCity](https://data.opencity.in) BMTC datasets | Cleanest licence, but stops/routes/facilities only — **no timetables**. Duplicates what we hold. |
| `nimmbus.netlify.app` — OpenAPI for the Namma BMTC backend | Has exactly the gaps: `/GetTimetableByRouteid_v3`, `/GetAllServiceTypes` (Vajra, Vayu Vajra, feeders), fares. But it *is* the AVLS backend our own registry marks **access review required**, on a vendor **staging** host. |
| `iotakodali/bmtc-realtime-api` | **CC BY-NC-SA** — excluded by our own rule that NonCommercial licences are unusable. Live ETAs only, no timetables. Author warns of IT Act exposure. |

`ServiceClass` already models the bus types — `REGULAR · EXPRESS ·
LIMITED_STOP · AIRPORT · METRO_FEEDER · INTERCITY · NIGHT · PREMIUM`. The
schema is ready; only the feed is missing.

Request drafted at `Ratroo_backend/docs/data-requests/dult-bmtc.md`, addressed
to DULT with BMTC copied. Not yet sent.

## Still open from this session

- The **planner's destination pin is red** — the same red as
  `confidenceLowFill`, the app's error colour.
- **Not yet ported from Stitch:** Nearby's mode filter chips, Place details'
  departure rows with a route badge and countdown, Route details' stop
  timeline, Plan's departure→arrival result cards. The token layer is in, so
  these are screen-level work.
- **Mode marks are still Phosphor.** Real SVG marks were drawn and reviewed
  (bus, rail, ferry, tram, metro, auto, walk) but not wired in; that needs
  `flutter_svg` and an `assets/icons/` pipeline.
- Journey planner and Profile both centre a short empty state in a very tall
  void.
- **`DATABASE_URL`'s password is in Vercel's runtime logs** and must be
  rotated; percent-encode `@` when re-setting it.
- **BMTC timetables** are blocked on the DULT request being sent and answered.
- The emulator's GPS is wedged on this machine; a cold boot is the fix, and the
  debug pin is the workaround.
- `hero_map_pins.png` (375 KB) ships but nothing renders it.
- Untouched from the previous session's Open list: `Arambagh → Kolkata`
  returning 1,021 minutes, `by-mode` reporting `departures: 0`, metro at zero,
  ~450 untimed WBBUS routes.

---

# Changes — session of 12–13 August 2026

Covers both repos: `Ratroo_app` (Flutter) and `Ratroo_backend` (NestJS).

**State at the end:** `flutter analyze` clean · 93 Flutter tests · backend
typechecks clean · 14 backend tests · both migrations applied · API running
against a live database.

**Nothing in this file is committed** unless noted. `git status` in each repo
shows the working tree.

---

## Backend — new modules

### `modules/operators/` — first-party operators

A transport business registers, adds vehicles, and publishes routes with stops,
times and fares. Tier 1 layout, **zero raw SQL**, every query through Sequelize
models.

| Endpoint | |
|---|---|
| `POST /v1/operators` | register |
| `GET · PATCH /v1/operators/me` | the business on this account |
| `GET · POST /v1/operators/me/vehicles` · `DELETE /:id` | fleet |
| `GET · POST /v1/operators/me/routes` · `GET/DELETE /:id` | services |
| `PUT /v1/operators/me/routes/:id/stops` | replace the timetable |
| `PUT /v1/operators/me/routes/:id/publish-state` | draft ⇄ published |

Decisions worth keeping:

- **Vehicle types go wider than transit modes** — `AUTO`, `E_RICKSHAW`,
  `SHARED_TAXI`, `MINIBUS` alongside bus/ferry/tram. These are the services the
  scrapers never cover.
- **Registration is not trust.** `status` starts `PENDING`; publishing is
  refused until a human verifies the operator.
- **Nothing writes into `routes`/`stops`.** Submissions become rider-facing only
  through the normal staging → resolution → promotion pipeline.
- **Backwards timetables are rejected**, naming both stops.
- Operators type a stop name and optionally drop a pin; `placeId` stays null
  until resolution fills it.

Migration: `20260812120000-create-operator-tables.ts` — **applied**.

### `providers/operator-submitted.provider.ts` — operators as a provider

The fetch reads the database instead of a website; everything downstream is
unchanged. Operator data gets canonical stop resolution, the quality gate,
provenance and dataset versioning for free.

How "trust the owner" takes effect:

| Field | Operator | Scraped equivalent |
|---|---|---|
| Times | `timeIsEstimated: false` | `INTERPOLATED` for ~450 WBBUS routes |
| Fares | `fareType: 'FIXED'` | `ESTIMATED_BY_DISTANCE` |
| Observation | `confidence: 1`, `OPERATOR_VERIFIED` | 0.6–0.9, `AUTO_VALIDATED` |
| Coordinates | 0.95 with a pin, 0.6 without | varies |

Only `VERIFIED` operators are read. The validator rejects routes that lost their
stops or picked up a malformed time rather than repairing them.

### `modules/data-quality/` — consistency as a scheduled job

Three one-off repair scripts became a nightly pass, because ingestion recreates
all three defects every night.

- `@Cron('30 3 * * *')` — **after** the 02:00 provider sync, not before
- `POST /internal/cron/data-consistency` — **dry-run by default**
- `DATA_CONSISTENCY_CRON` / `_DRY_RUN` / `_ENABLED` env switches

Merges duplicate stops → normalises times and drops duplicate `stop_times` →
seeds place aliases. **Zero raw SQL.**

### `modules/service-requests/` — waitlist for uncovered states

`POST /v1/service-requests` (public — no account, the whole point) and
`GET /v1/service-requests/demand` (internal — the expansion queue, states ranked
by request count). Idempotent per number *and* state.

Migration: `20260813090000-create-service-requests.ts` — **applied**.

---

## Backend — data repairs

### Duplicate stops merged — 12,521 → 7,930

4,591 rows removed. **No timetable row lost** (`stop_times` unchanged at
37,362), zero orphaned references. Durgapur City Center went 9 → 1; Kolkata
3 → 1.

Merged, never dropped: three "Kolkata" rows carried *different* services, so
keeping only the first would have hidden two-thirds of the buses. Requires
matching names **and** ≤150 m apart, so genuine namesakes stay separate.

### 505 place aliases seeded

`findPlacesByName` never looked at `place_aliases` — 6,209 rows sat unused. The
app was printing "Durgapur (Muchipara)" in a journey leg and then failing to
resolve the same string when typed back.

---

## Backend — bugs fixed

**Telipukur → Asansol reported "no route" while six routes connect them.** Three
separate causes:

1. **Stops without coordinates were dropped from the graph entirely.** True for
   walking transfers, but riding needs no coordinates — and Asansol's busiest
   record has none and 144 scheduled calls. Now kept in the graph, excluded only
   from the spatial grid.
2. **Hop cost was purely geometric**, so an unlocated stop returned `NaN`
   minutes — never less than an existing label, so the route died there. Hops are
   now costed from the operator's timetable first.
3. **Endpoint resolution fell through instead of unioning.** `stopsForPlace`
   returned one operator's stops so the name and proximity lookups never ran.

**"Arambagh" resolved to a postal address with no services.** Geocoding created a
second `places` row per town. `findPlacesByName` ranked "has coordinates" above
"exact name", so the address won. A "has services" term now outranks both.

**`stop_times.timeSource` existed in the database but not on `StopTimeModel`** —
any ORM write dropped it silently, making an estimate indistinguishable from an
operator's published time. Surfaced by the ORM conversion.

**`parseFloat` on a numeric column**, hidden because the repository returned
`any`. Surfaced by typing it.

**Mode was derived from provider code**, which breaks the moment one operator
runs both a bus and an auto route. Now read per route from
`bus_routes.metadata.mode`.

---

## Backend — raw SQL removed

Converted entirely to Sequelize models:

- `CanonicalTransitProjectionService` — all five projection steps
- `DataConsistencyService` — 11 statements → 0
- `journey.repository.ts` — ranked search now ranks in TypeScript
- `stops.controller.ts` `by-mode` — joined through associations

Still raw SQL: `transit-graph.service.ts` (3 queries) and `coverage.controller.ts`.

---

## Backend — architecture

`docs/04-folder-structure.md` already defined two tiers; the code had drifted
into four. Fixed:

| Module | Was | Now |
|---|---|---|
| `planner` | 4 empty DDD folders, **0 files** | deleted |
| `graph`, `health` | flat files | `services/`, `controllers/` |
| `places`, `journey` | DDD skeleton over Tier 1 code | Tier 1 |
| `regions` | Tier 2 | Tier 1 |
| `transit` | Tier 2 | **stays** — doc updated to admit it |

The doc now also records the failure mode: *empty layering is worse than none —
it tells the next developer to look somewhere nothing lives.*

---

## Backend — deletions (~1,200 lines)

- Three repair scripts superseded by `DataConsistencyService` (~660 lines);
  their rules kept as `data-quality/stop-clustering.ts` and `time-format.ts`
- `scaffold.js` and the root `src/` prototype (505 lines) — superseded July 30
- `data/*.json` (~134,000 lines, 4 MB) — nothing read it; `data/` gitignored
- Dead exports: `routeTypeFor`, `VEHICLE_LABELS`, `metresBetween`, `Cluster`

Root `npm start` ran the deleted prototype; both `start` and `test` now delegate
to `apps/api`.

---

## App — new

- **`city_card.dart`** — one card naming the place, four modes as a horizontal
  strip (icon + chevron top, name, routes, stops). Scoped to the rider's city
  when known, state otherwise. Busiest mode first. Modes with no routes are
  omitted, never shown as zero.
- **`not_serviced_yet.dart`** — what a rider in Bihar sees: what we do cover, one
  phone field, what the number is for.
- **`chat_store.dart`** — assistant conversations persisted per message, past
  chats sheet, new chat. Titled by the rider's question, not our answer.
- **`saved_answers_service.dart`** — keep an answer; appears under Your journeys
  with the provenance badge it had when live.
- **`status_view.dart`** — one component for offline / error / empty /
  no-results / no-location / no-route. Replaced five near-duplicates.
- **`bus_banner.dart`**, **`aurora_backdrop.dart`**, **`spot_carousel.dart`**
- **`app_icons.dart`** — the whole icon vocabulary at one weight
- **`format.dart`** — `groupedNumber`, `timeAgo`, `titleCaseName`,
  `distanceLabel`, `mergeSamePlace`

## App — changed

- **Material Icons → Phosphor**, 91 call sites. Material mixed filled and
  outlined drawings of the same idea — eleven such pairs were in use at once.
- **Shared-axis page transitions** via `animations`, as go_router
  `pageBuilder` — *not* `OpenContainer`, which would have cost every deep link.
- **`skeletonizer`** replaced hand-drawn skeleton rectangles.
- **Home rebuilt**: brand mark → greeting + account button; compact hero with the
  video bleeding in from the right; quick-action card removed (it duplicated the
  bottom bar); network section folded into the city card (it printed the same
  numbers twice); saved items became rows, not cards.
- **Bottom bar**: Home · Plan · Nearby · Ask · Profile. Search left it — the hero
  search field is the way in. The Nearby tab used a bookmark icon.
- **Search**: empty state shows nearby stops instead of instructions; duplicate
  stops merged; ALL-CAPS names title-cased; repeated photo + "Bus stop" replaced
  by a mode glyph and distance.
- **Journey planner**: "where you can go from here" now also runs once an origin
  is chosen, not only on first open.
- **Mode photos deleted** — four `mode_*.jpg` removed with their code paths. Four
  of the eight unlicensed photographs are gone; `hero_*.jpg` remain and still
  need their origin confirmed before release.

## App — bugs fixed

- **`ref` used after `await` on a disposed widget** — crashed Nearby. Found in
  two more places, including `checkLocationDrift`, which runs on app resume.
- **Retry did nothing for 24 seconds** — ran the 12 s attempt twice because
  failures were uncached, gave no sign of working, and on a blocked device opened
  Settings then retried before the rider could change anything.
- **"No stops within 30 km" from a request that never completed.** The screen
  read `apiResponse.data` without checking `success`, and the 30 km came from the
  radius label's own default. The server had 26 stops at those coordinates.
- **The dev API host was a stale LAN address** (`192.168.1.6`; this Mac is
  `.13`), and an emulator can't use a LAN address anyway. `flavors.dart` now
  picks by platform — `10.0.2.2` on Android, `localhost` on iOS — so a plain
  restart works.
- Raw `DioException` text shown to riders; history sheet under the nav bar;
  `shared_auto` rendering as "Shared_auto".

---

## Open

**Verified working:** Telipukur → Asansol (305 min), Kolkata → Arambagh,
Howrah → Digha, Jhalda → Jhargram, `ARAMBAG (NS)` and `Durgapur (Muchipara)`
resolving, city tree live in the app.

**Known wrong:**

- `Arambagh → Kolkata` returns **1,021 minutes** ending at a stop called
  "JHARGRAM (KOLKATA)" — 17 hours for ~100 km. Bad transfer chain or a stop
  misnamed with "(KOLKATA)" in it.
- `/v1/stops/by-mode` returns `departures: 0`; the count is not surfacing through
  the grouped include.
- Metro: **0 stops, 0 routes** ingested.
- ~450 WBBUS routes still untimed.

**Not started:** recent searches, continue journey, inspiration cards (needs real
routes with planner-computed durations, never typed), the state → city → mode
tree beyond one city (`stops.city` is sparsely filled), `place_aliases` for
variant names like "Asansol" vs "Asansol Bus Terminus".

**Needs assets:** hero illustration, Popular places photography, the promo card.
Specs are in `assets/README.md`. Rive and LottieFiles need a signed-in account to
download, so those have to come from you.

**Design:** the home screen has had several passes but no single decision about
its hierarchy. Every change so far was made without being able to see the result
— roughly half needed correcting. A working simulator, or one reference screen
per change, is what makes this converge.
