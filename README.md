# ratroo_app

The Ratroo rider app. Flutter, talking to `Ratroo_backend`.

## Running it

Flavours pick the API host, so run an entrypoint rather than `lib/main.dart`:

```bash
flutter run -t lib/main_dev.dart
```

`lib/core/flavors.dart` resolves the dev host by platform — `10.0.2.2` on an
Android emulator, `localhost` on iOS and web — so a plain restart works
wherever you are.

## Seeing a design change

Layout, hierarchy, type and both themes can all be judged in a browser at a
phone viewport, and that needs no Xcode or emulator:

```bash
flutter run -d web-server --web-port 8080 -t lib/main_dev.dart
```

Then open `http://localhost:8080` at 375×812. `.claude/launch.json` holds the
same command for tools that read it.

This matters more than it sounds. Several defects in the last two sessions —
a video painting over its own caption, a placeholder shaped like a layout that
had been replaced, two section headings stacked with nothing between them —
were invisible in code review and obvious in one screenshot. Look at the
screen before and after a design change.

## Checks

```bash
flutter analyze && flutter test
```

## Where things live

| Path | |
|---|---|
| `lib/core/theme.dart` | design tokens and both themes — colours, radii, spacing, type scale |
| `lib/core/app_icons.dart` | the whole icon vocabulary, Phosphor at one weight |
| `lib/core/router.dart` | routes; the five tabs are a `StatefulShellRoute` |
| `lib/widgets/app_shell.dart` | the persistent navigation bar |
| `lib/screens/` | one file per screen |
| `lib/widgets/status_view.dart` | every "nothing here" state — offline, error, empty, no results |
| `assets/README.md` | asset specs and what is still missing |

Read colours, radii and spacing from `RatrooTheme` or `Theme.of(context)`
rather than hardcoding them, so a brand change stays a one-file change.

`CHANGES.md` is the running log of what changed and why.
