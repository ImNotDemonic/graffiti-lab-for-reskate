# Graffiti Lab

Graffiti Lab is an offline ReSkate prototype for placing graffiti on walls. It includes one original design, **Switchback**. Aim at a suitable wall to preview it, confirm to leave it there, and remove it when you're done.

## Current status

Switchback passed the preview, placement and removal playtest on the metal kiosk at Blue Light Beach in San Vansterdam and on an interior wall in Turbo Token Arcade. Both marks stayed fixed as the camera moved. A grille at the kiosk accepted the preview but displayed the artwork only on its bars. [Playtest record](docs/MILESTONE_1.md)

An artwork selector, drawing editor and personal library are planned. Direct wall painting and multiplayer sharing are later investigations.

## Development setup

The plugin uses sandboxed **Luau** and ReSkate's `reskate.*` API. The tested build target is ReSkate `20261116` with game build `20260929`. [Plugin overview](https://docs.reskate.dev/plugins/overview) · [Runtime release](https://github.com/Dingo-Shenanigans/ReSkate/releases/tag/20261116)

1. For a fresh ReSkate setup, use the official launcher and a separate ReSkate folder. Let the launcher install its supported copy of `skate.` and start the game with **Play**. Keep the development checkout separate from the installed game. [ReSkate setup](https://docs.reskate.dev/quickstart)
2. To check an existing plugin installation, open the ReSkate console and run `plugin list`. The in-game **Insert → Plugins** menu manages approvals. [Plugin management](https://docs.reskate.dev/plugins/overview)
3. With the game closed, extract the prototype ZIP into `Mods/GraffitiLab/` beside the managed `Skate.exe`. The mod root should contain `layout.toc`, `Win32/`, `reskate-plugin.json` and `plugin/`. Start offline, approve Graffiti Lab and enter normal skating. [Plugin manifest](https://docs.reskate.dev/plugins/manifest)

## Controls

| Key | Action |
| --- | --- |
| Ctrl+G | Enter or cancel aim mode. Point the camera at a nearby flat wall. A translucent Switchback shows where the sticker fits. |
| Ctrl+P | Confirm a valid preview. The mark stays on the wall as you move. |
| Ctrl+R | Remove the mark or cancel aiming. Press Ctrl+G to start again. |

The prototype handles one mark at a time. Leaving the level clears it. The actions can be reassigned in ReSkate's binds. The console also accepts `graffiti aim`, `graffiti place`, `graffiti remove` and `graffiti status`.

## Build the test ZIP

On Windows x64, use Python 3.11+ with Pillow, a checkout of ReSkate at `8e4aefca153ce9cb622074ae4de05f81fa71d09c` and the x64 UCRT edition of LLVM-MinGW (`20261117` was used). The two commands below run from this checkout. Replace the external paths with your local folders.

```powershell
python tools/build_author.py --sdk "C:/dev/ReSkate" --llvm "C:/dev/llvm-mingw"
python tools/package_mod.py --game "C:/Games/ReSkate" --studio "C:/Tools/ReSkate Studio/reskate_cli.exe"
```

The author reads the supported local game data and the original `art/switchback.png`. Studio compiles the resulting resources into `outputs/GraffitiLab-0.1.0.zip`. The GPL offline tools derive from the gBGYo decal recipe and link ReSkate's resource readers. Their source and licence are under `tools/`. [Upstream decal author](https://github.com/gBGYo/ReSkate_blood) · [LLVM-MinGW release](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261117)

## Project documents

- [Project specification](docs/PROJECT_SPEC.md) defines the player workflow, milestones and prototype acceptance tests.
- [API findings](docs/API_FINDINGS.md) records verified calls, example packages, runtime limits and open questions.
- [Development checklist](docs/TASKS.md) gives the order of work, starting with one original decal.
