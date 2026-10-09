# Joyride Junction

Build the coasters. Feed the crowds. Keep the toilets clean.

A theme park building game for one player, built with Godot 4 for Ubuntu.
Design: [idea 07](https://github.com/LinuxGroove/game-ideas/blob/main/ideas/07-joyride-junction.md)
in game-ideas. Joyride Junction is a working title; the other names in the
running are listed there.

## How it plays

- Guests come in at the gate and walk the footpaths you lay. They ride,
  eat, drink, need the toilet, drop litter, get tired and go home. Keep
  them happy and the park's rating climbs and more come.
- **Wooden coasters**: place a station, then build the track piece by piece
  (turns, slopes, chain lifts and brakes) until it comes back round. Or place
  a ready-made one: Little Woody or Timber Twister. Every ride gets a test
  run: speeds and forces come from the track itself, and give it ratings for
  excitement, intensity and nausea. Guests pick rides they can handle.
- **Shops**: burger and drinks stalls, toilets and an information kiosk,
  each with a price you set. Benches, bins, trees and flowers keep guests
  happier.
- **Money**: an entry fee at the gate, ride tickets and shop prices; building
  and janitors' wages cost. Look at any guest to see what they think.
- **Scenario or sandbox**: Meadow Fair has a goal (100 guests and a rating
  of 500 by the end of the first October) and starting money; a sandbox has
  no limits.
- **Your parks**: every park is saved on its own, and the game saves as you
  play. Start a new one any time; the others stay in the list to pick up
  again, copy, rename or delete.

When the game starts with the internet on, it tells the LinuxGroove game
server once, so we can count how many people play and on what: a random id
made on the first run, the game's version, the OS and the CPU, and nothing
else. It never signs in, and with no network nothing is sent. Set
`DO_NOT_TRACK=1` to turn it off.

## Controls

Controller first; mouse and keyboard always work.

| Action | Controller | Keyboard and mouse |
|---|---|---|
| Move the cursor | Left stick | Mouse, or WASD |
| Move one tile (pick track pieces in the coaster builder) | D-pad | Arrow keys |
| Turn and tilt the camera | Right stick | Right-drag, or Q/E and R/F |
| Zoom | Triggers | Wheel, or Z/X |
| Build, or look at what's under the cursor | A | Left click, Space or Enter |
| Stop building, close a window | B | Right click or Backspace |
| Turn what you're building | X | T |
| Look (coaster station length; stop building track) | Y | I |
| Build menu | RB | B |
| Park window (money, staff, entry fee) | View / Back | P |
| Speed | LB | Tab |
| Pause | Menu / Start | Esc |

## Building and testing

You need Godot 4.7.

```sh
godot --headless --path . --import
godot --headless --path . tools/check_scripts.tscn             # every script compiles
godot --headless --path . tests/run_tests.tscn -- --days=120   # unit tests and a season in the sample park
godot --path . -- --demo                                       # straight into a ready-built sample park
godot --path . -- --new                                        # straight into Meadow Fair
```

`tools/screenshot.tscn` saves screenshots of menus and parks without a
screen (run it under `xvfb-run`; options are listed at the top of
`tools/screenshot.gd`). [docs/screenshots](docs/screenshots/README.md) has
a picture of every screen: parks, rides, the coaster builder, building,
windows and menus.

## Snap

`snapcraft pack` builds a strictly confined snap, `joyride-junction`, with
the exported game. See [docs/packaging.md](docs/packaging.md).

Pushing to `main` builds the snap and publishes it to the `edge` channel;
a GitHub release publishes to `candidate`. The **Windows and macOS** workflow
exports both from Linux and attaches the zips to releases.

## Layout

| Path | What |
|---|---|
| `game/coaster/` | Track geometry, the ride physics and ratings, ready-made designs |
| `game/park/` | The park's data (tiles, rides, money, calendar), build pieces, scenarios, the park library |
| `game/sim/` | The guest simulation (`ParkSim`, `Guest`): no nodes, so tests run whole seasons |
| `game/view/` | The 3D park (`ParkView`), the procedural track mesh, the camera |
| `game/ui/` | Title and park library, HUD, build menu, info windows, pause menu, tutorial |
| `addons/linuxgroove/` | The shared LinuxGroove add-on (settings, input and glyphs, theme, screen fitting, LAN, online) |
| `addons/com.heroiclabs.nakama/` | Vendored Nakama client, for the online park gallery to come |
| `assets/kenney/` | Kenney packs (CC0) |
| `tests/`, `tools/` | Test runner, script checker, screenshots, versioning and release scripts |
| `snap/` | Snap packaging |

Code is MIT (see `LICENSE`); assets and other credits in [CREDITS.md](CREDITS.md).
