# Packaging

Joyride Junction ships as the strictly confined snap `joyride-junction`
(`snap/snapcraft.yaml`, core24, amd64 and arm64).

## What the build does

1. The **joyride-junction part** downloads the Godot editor and export templates
   for the pinned version (`GODOT_VERSION` in the yaml, keep it in step with
   `project.godot` and the CI workflow), imports the project and runs
   `--export-release` with the `Linux` or `Linux ARM64` preset from
   `export_presets.cfg`. The binary and `.pck` go to `$SNAP/game`, the
   launcher to `$SNAP/bin`.
2. The version comes from `config/version` in `project.godot`.
3. The app uses the **gnome extension**, which brings the GNOME runtime,
   Mesa through `gpu-2404`, and the desktop plugs (`wayland`, `x11`,
   `opengl`, `desktop`). The same snap runs on an Ubuntu desktop and on a
   handheld's gamepad shell.

Build locally with `snapcraft pack`.

## Workflows

| Workflow | When | What |
|---|---|---|
| CI (`.github/workflows/ci.yml`) | Every push to `main` and every pull request | Imports the project, checks every script compiles, runs the tests (including a season in the sample park) |
| Snap (`.github/workflows/snap.yml`) | Every push to `main`, every pull request, and published releases | Builds the snap on amd64 and arm64 runners and uploads each as an artifact. On a published release it also uploads to the store's candidate channel, using the `SNAPCRAFT_STORE_CREDENTIALS` secret |

## Interfaces

The gnome extension's desktop plugs, plus `audio-playback`, `joystick`
(controllers), and `network` and `network-bind` (for the online park gallery
and LAN play to come).
`joystick` is not auto-connected on desktops:

```sh
sudo snap connect joyride-junction:joystick
```

## Where data lives

Settings, tutorial progress and the saved parks (`parks/`, see
`ParkLibrary`) are in `$SNAP_USER_DATA/.local/share/joyride-junction`.

## Updating Godot

Change `GODOT_VERSION` in `snap/snapcraft.yaml` and in
`.github/workflows/ci.yml` together.
