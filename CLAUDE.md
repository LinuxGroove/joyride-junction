# Joyride Junction

A single-player theme park builder (wooden coasters, shops, guests with needs), in Godot 4.7 with GDScript. The concept is idea 07 in [game-ideas](https://github.com/LinuxGroove/game-ideas/blob/main/ideas/07-joyride-junction.md), including the planned online Park Gallery. The name is a working title. Online play will go through the shared [game server](https://github.com/LinuxGroove/game-server); **read game-ideas' [online-addon.md](https://github.com/LinuxGroove/game-ideas/blob/main/online-addon.md) before touching networking, online or the shared add-on.**

## Commands

```sh
godot --headless --path . --import
godot --headless --path . tools/check_scripts.tscn                  # every script compiles
godot --headless --path . tests/run_tests.tscn -- --days=120        # unit tests and a season in the sample park
godot --path . -- --demo                                            # straight into a ready-built sample park
godot --path . -- --new                                             # straight into Meadow Fair
xvfb-run -a godot --path . --rendering-driver opengl3 tools/screenshot.tscn -- /tmp/shot window=ride 3
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 tools/screenshot.tscn -- --all=docs/screenshots   # every screen
```

`docs/screenshots/` holds a picture of every screen, made by the last command (software Vulkan from `mesa-vulkan-drivers`, so they look like the game's Forward+ renderer); run it again after changing how something looks, or `group=builder` (parks, rides, builder, building, windows, menus) for one group.

Run the script check and the tests before every commit. Headless runs reimport assets and rewrite many `*.glb.import` files and `icon.png.import`; revert those (`git checkout -- '*.import'`, `rm icon.png.import`) unless you meant to change them.

## Layout

| Path | What |
|---|---|
| `game/game_config.gd` | `GAME_ID`, setting defaults, music, input map |
| `game/coaster/` | `Track` (pieces, poses, sampling), `RidePhysics` (test run, forces, ratings), `CoasterDesigns` (ready-made layouts) |
| `game/park/` | `ParkData` (tiles, rides, money, calendar, building rules, save format), `Pieces`, `Scenarios`, `SamplePark`, `ParkLibrary` |
| `game/sim/` | `ParkSim` and `Guest`: arrivals, routes, queues, trains, shops, litter, janitors, rating, goals |
| `game/view/` | `ParkView` (draws everything), `TrackMesh` (procedural track and supports), `ParkCamera` |
| `game/game.gd` | `Game`: the cursor, the build tools and what each control does |
| `game/ui/` | Title and park library, `Hud`, `BuildMenu`, `InfoWindow`, `PauseMenu`, `HowToPanel` |
| `game/net/online_server.gd` | Default game server; `SERVER_KEY` stays `defaultkey` in git |
| `addons/linuxgroove/` | Shared LinuxGroove add-on (settings, input, theme, LAN, online, names) |
| `addons/com.heroiclabs.nakama/` | Vendored Nakama client with a local patch (see its `VENDORED.md`) |
| `tests/run_tests.gd` | Headless test runner; add checks with `check(ok, "what")` |
| `tools/` | Script checker, screenshots (`screenshot_tour.gd` shoots every screen), `version.sh`, `release.sh` |

## How the game is built

- **Data, simulation, view.** `ParkData` is the park and the save file; `ParkSim` runs it with no nodes, in fixed 0.1 s steps from a seed, so tests run whole seasons headless; `ParkView` only reads both. After changing the park, call `Game._changed()` (it refreshes the sim, the view and the HUD).
- **Tiles** are `Vector2i(x, z)`, one unit each. Headings are `Track.DIRS` indices (0 is +z, adding one turns left). Saves use `"x,y"` string keys and drop ride stats, which are cheap to work out again.
- **Coasters are procedural.** Pieces are `[turn, slope, extra]`; `Track.build` turns a ride into dense points, and `RidePhysics.simulate` runs a train round them for speeds, forces and ratings. Kenney's fixed coaster pieces don't fit a one-tile grid, so `TrackMesh` builds the rails, sleepers and supports from the points; Kenney's stations and trains sit on top.
- **Kenney models face -z** (stalls, booths) and paths and queues open on the sides listed in `ParkView.PATH_SHAPES`; `ParkView.turn(from, to)` rotates between headings.
- **Parks are kept.** `ParkLibrary` stores each park as `user://parks/<id>.park` (gzipped JSON), a `.json` summary and a `.png` picture. Starting a park never touches the others. Bump `ParkData.FORMAT` when the save format changes in a way old builds can't read, and keep loading older formats.
- **Play tests.** The shared add-on's `LGPlaytest` records a play test when the Play test recording setting is on (or with `-- --playtest`): a picture every few seconds, game events, frame times and controls, the player's notes (F8, or Note this moment in the pause menu) and a survey when they quit, all in one zip in `user://playtest/`. Game events go through `LGPlaytest.event()` and `moment()`; the round's own survey questions (and standard ones to skip) are `GameConfig.PLAYTEST`. Quit through `LGScenes.quit()` so the survey comes first.
- **Everything works offline.** No server, no network and online turned off must all still play. Online features (the Park Gallery) need the game registered on game-server with `GAME_ID` first.
- **Launch ping.** `game/main.gd` calls `LGLaunchPing.send(GameConfig.GAME_ID)` at startup: one anonymous request to the game server's `/launch` (game, random install id, version, OS, CPU) so the server counts every player, online or not. It's skipped headless, from source and with `DO_NOT_TRACK` set, and never blocks or retries.

## The shared add-on

`addons/linuxgroove/` and `addons/com.heroiclabs.nakama/` are copies shared with [Foam Frenzy](https://github.com/LinuxGroove/foam-frenzy) and [Lantern Out](https://github.com/LinuxGroove/lantern-out). Fix shared behaviour in the add-on, not with a workaround here, keep it game-agnostic, and port the change to the other games in the same piece of work. When the change affects how games should use the add-on, update online-addon.md in game-ideas too. Keep the `_disconnect_peer` and `_close` patch in `NakamaMultiplayerPeer.gd` when updating nakama-godot.

## Style

- Match the surrounding code: `##` doc comments on classes and non-obvious functions, short comments only where the reason isn't obvious.
- Screens connect to autoload signals with methods, not lambdas (a lambda stays connected after the screen is freed).
- Build UI pieces so tests can drive them without a network or a scene change.
- Controller first: every tool works with a pad, and the mouse and keyboard always work too. Buttons that would steal focus from the park (the track builder's pickers) are `FOCUS_NONE`.
- Player-facing text is plain and short, in the game's words (guests, rides, the park, shops).

## Releases

Pushing to `main` builds the snap and publishes it to the `edge` channel; a GitHub release publishes to `candidate`. The **Windows and macOS** workflow (`desktop.yml`) exports both from Linux with the `Windows Desktop` and `macOS` presets: pushes to `main` keep the zips as artifacts for 5 days, and releases get them attached. They aren't signed by Microsoft or Apple, and the release notes tell players how to open them. CI injects the server key from the `GAME_SERVER_KEY` secret, so never commit the real key.

Versions are `vYYYY.WW.MINOR`: a release is a GitHub release tagged with the year and week and a number from 0 for that week's releases. Make releases with the **Release** workflow (Actions, Release, Run workflow): it refuses commits whose CI hasn't passed, picks the next tag, publishes a release whose notes lead with the Snap Store link and list the changes since the last release (`tools/release.sh`), and starts the snap and desktop builds. Commit subjects become the release notes, so write them for players. Nobody edits the version by hand: `tools/version.sh` derives it from git, CI stamps it into `project.godot` before building, and runs from source ask the same script (`LGVersion`).
