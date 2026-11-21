# Graffiti Lab

A ReSkate graffiti mod with premade artwork, custom drawing and surface placement.

Graffiti Lab is an offline ReSkate mod for placing premade graffiti on walls. Its in-game library includes **Switchback**, a mint arrow stencil, **Birds**, three swifts over a cobalt sun, and **Bonehead**, a skull in a blaze-orange cap.

## Current status

Switchback passed the preview, placement and removal playtest on the metal kiosk at Blue Light Beach in San Vansterdam and on an interior wall in Turbo Token Arcade. Both marks stayed fixed as the camera moved. A grille at the kiosk accepted the preview but displayed the artwork only on its bars. [Playtest record](docs/MILESTONE_1.md)

The Premade Art selector shows a thumbnail and larger preview of each design. Picking a new design leaves confirmed marks in place. A drawing editor and a personal library for original drawings are planned. Direct wall painting and multiplayer sharing are later investigations. [Selector playtest](docs/MILESTONE_2.md)

## Development setup

The plugin uses sandboxed **Luau** and ReSkate's `reskate.*` API. The tested build target is ReSkate `20261116` with game build `20260929`. [Plugin overview](https://docs.reskate.dev/plugins/overview) · [Runtime release](https://github.com/Dingo-Shenanigans/ReSkate/releases/tag/20261116)

1. For a fresh ReSkate setup, use the official launcher and a separate ReSkate folder. Let the launcher install its supported copy of `skate.` and start the game with **Play**. Keep the development checkout separate from the installed game. [ReSkate setup](https://docs.reskate.dev/quickstart)
2. To check an existing plugin installation, open the ReSkate console and run `plugin list`. The in-game **Insert → Plugins** menu manages approvals. [Plugin management](https://docs.reskate.dev/plugins/overview)
3. With the game closed, extract the prototype ZIP into `Mods/GraffitiLab/` beside the managed `Skate.exe`. The mod root should contain `layout.toc`, `Win32/`, `reskate-plugin.json` and `plugin/`. Start offline, approve Graffiti Lab and enter normal skating. [Plugin manifest](https://docs.reskate.dev/plugins/manifest)

## Controls

| Key | Action |
| --- | --- |
| Ctrl+L | Open Premade Art. Click a thumbnail or use Left / Right to browse. Click **Place on Wall** or press Enter to aim with that design. Esc closes the selector. |
| Ctrl+G | Enter or cancel aim mode using the current design. A translucent preview appears on a suitable wall within eight metres. |
| Ctrl+P | Confirm the preview. The mark stays fixed as you move or select another design. |
| Ctrl+R | Cancel an active preview. When idle, remove the newest confirmed mark. |

The local limit is 16 confirmed marks and one preview. Marks clear when leaving the level and expire just before ReSkate's ten-minute limit. The console accepts `graffiti library`, `graffiti aim`, `graffiti place`, `graffiti remove` and `graffiti status`. The actions can be reassigned in ReSkate's binds. A controller binding opens the library with Back + Y, then D-pad Left / Right browses, A chooses and B closes.

## Build the test ZIP

On Windows x64, use Python 3.11+ with Pillow, a checkout of ReSkate at `8e4aefca153ce9cb622074ae4de05f81fa71d09c` and the x64 UCRT edition of LLVM-MinGW (`20261117` was used). The two commands below run from this checkout. Replace the external paths with your local folders.

```powershell
python tools/build_author.py --sdk "C:/dev/ReSkate" --llvm "C:/dev/llvm-mingw"
python tools/package_mod.py --game "C:/Games/ReSkate" --studio "C:/Tools/ReSkate Studio/reskate_cli.exe"
```

The author reads the supported game data and the 512 × 512 RGBA PNGs in `art/catalogue.json`. Each entry's slot reserves stable private asset identities. Keep existing slots when changing display order. The two shared lookup tables are patched once with all three materials. Studio compiles the resources into `outputs/GraffitiLab-0.2.0.zip`. The GPL offline tools derive from the gBGYo decal recipe and link ReSkate's resource readers. Their source and licence are under `tools/`. [Upstream decal author](https://github.com/gBGYo/ReSkate_blood) · [LLVM-MinGW release](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261117)

## Project documents

- [Project specification](docs/PROJECT_SPEC.md) defines the player workflow, milestones and prototype acceptance tests.
- [API findings](docs/API_FINDINGS.md) records verified calls, example packages, runtime limits and open questions.
- [Development checklist](docs/TASKS.md) gives the order of work, starting with one original decal.
