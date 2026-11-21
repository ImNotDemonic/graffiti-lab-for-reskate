# Graffiti Lab

Graffiti Lab is a planned ReSkate mod for placing graffiti on suitable map surfaces. Players will be able to pick a premade design or draw their own, save it in a personal library, and preview it on a wall before placing it.

## Current status

This repository contains the project specification, API research and development checklist. There is no playable release, plugin entry point, artwork pack or build command yet.

The first technical milestone is to **place and remove one premade image on a flat, static wall in offline play**. The artwork selector, drawing editor, personal library and broader map testing follow that milestone. Direct wall painting and multiplayer sharing are later investigations.

## Development setup

The target is a sandboxed **Luau** plugin using ReSkate's `reskate.*` API. The inspected installation runs ReSkate `20261116`. Two installed client plugins use API version `1` and declare `plugin/main.lua` as their entry. This establishes the target runtime. The offline toolchain for building Graffiti Lab's own decal still needs an end-to-end test. [Plugin overview](https://docs.reskate.dev/plugins/overview) · [Inspected runtime release](https://github.com/Dingo-Shenanigans/ReSkate/releases/tag/20261116)

1. For a fresh ReSkate setup, use the official launcher and a separate ReSkate folder. Let the launcher install its supported copy of `skate.` and start the game with **Play**. Keep the development checkout separate from the installed game. [ReSkate setup](https://docs.reskate.dev/quickstart)
2. To check an existing plugin installation, open the ReSkate console and run `plugin list`. The in-game **Insert → Plugins** menu manages approvals. [Plugin management](https://docs.reskate.dev/plugins/overview)
3. Once a Graffiti Lab test package exists, install its contents under `Mods/GraffitiLab/` beside the ReSkate-managed `Skate.exe`. The mod root will hold `reskate-plugin.json`, the declared entry script and compiled artwork assets. Approve the plugin in game and check `plugin list`. The repository itself currently contains only documentation and ignore rules. [Plugin manifest](https://docs.reskate.dev/plugins/manifest)

## Project documents

- [Project specification](docs/PROJECT_SPEC.md) defines the player workflow, milestones and prototype acceptance tests.
- [API findings](docs/API_FINDINGS.md) records verified calls, example packages, runtime limits and open questions.
- [Development checklist](docs/TASKS.md) gives the order of work, starting with one original decal.
