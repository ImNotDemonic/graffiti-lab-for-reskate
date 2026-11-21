# Graffiti Lab project specification

The offline prototype passed its core placement test on a wall in each target map. The three-piece selector also passed its placement-preservation test on both maps. Broader surface and lifecycle checks remain open. [First placement playtest](MILESTONE_1.md) · [Premade selector playtest](MILESTONE_2.md) · [API findings](API_FINDINGS.md)

## Intended player workflow

1. Choose a premade piece, create a drawing in the editor, or open a saved drawing from the personal library.
2. Aim at nearby world geometry. Show the selected artwork at its proposed size and orientation when the surface is suitable. Clear the preview when the target becomes invalid.
3. Confirm to leave a mark that stays fixed as the camera moves. Cancel to discard the preview. Allow the player to remove their placement.
4. Save custom artwork independently of where it is placed. Reopening the game should restore the library, and the same drawing should be reusable on another supported map.

## Milestone 1 — place and remove one image

Use one original, asymmetric graphic with a transparent border, one temporary placement and one flat, static wall in offline play. Asymmetry makes flipped and mirrored projection easy to spot. The client uses `camera`, `world.raycast`, `effects` and `input` for placement, `session.read` for the offline guard and `console` for commands and status.

| Step | Proposed behaviour | Pass condition |
| --- | --- | --- |
| Prepare the decal | Compile the image and its material into a private, resident decal asset. | The image renders on a known wall with the intended colours, alpha and orientation. |
| Find a receiver | Cast a short ray from the camera. Estimate a plane from nearby hits and probe the intended corners. Reject unavailable collision, degenerate samples, obvious props and edges that cannot fit the graphic. | A broad wall accepts the preview. Sky, a narrow rail and a footprint crossing an outside corner do not. |
| Preview | Move one translucent decal while aim is valid. Clear it on a miss or cancel. | The preview follows the wall and disappears when aim leaves it. |
| Place and remove | Recheck the target on confirm. Make the current decal opaque, retain its handle and stop moving it. Release that handle on Remove. | The placed image stays fixed, is occluded by intervening solid geometry and disappears on removal. Repeated cycles leave no marks. |
| Change level or mode | Track the active level and effects epoch. Discard invalid handles. | A map switch during preview or after placement leaves the new map clean. Replay entry, plugin reload and disable leave no orphaned marks. |

Run the full sequence on **San Vansterdam** and **Turbo Token Arcade**, an installed custom map. Record the build, surface and visual result for each. Two passes establish initial coverage. Extend the supported-map list as more maps and receiver materials pass. Test thin walls for projection onto the reverse side.

## Later milestones

| Milestone | Deliverable | Acceptance |
| --- | --- | --- |
| 2. Premade artwork | A small curated catalogue and an artwork selector. | Switching designs changes the preview and a placed piece retains the design selected at confirmation. |
| 3. Editor and personal library | A local drawing canvas and a versioned drawing format. Save, reopen and edit named drawings within the verified storage limits. | A drawing survives a game restart and reopens with its strokes, colours and proportions intact. |
| 4. Place custom work | Test rendering a saved drawing on a wall. Compare bounded, precompiled brush stamps with offline compilation of exact images. | A saved piece can be selected from the library, previewed, placed and removed on each tested map. Document fidelity and measured frame cost. |
| 5. Later investigations | Explore drawing directly on geometry and sharing placements in multiplayer as separate experiments. | Report feasibility, surface and network limits, and the cost of each approach before scheduling a release. |

Persistent world placements are a separate decision from a persistent artwork library. Milestone 1 uses session-only placements.

## Runtime structure

`plugin/main.lua` owns the active premade design, transient preview and confirmed marks. `plugin/selector.lua` draws the Premade Art dock and `plugin/surface.lua` validates the wall footprint. `art/catalogue.json` and the three artwork PNGs feed the selector and offline asset build. `tools/` packages the compiled patch and Luau plugin.

`plugin/studio.lua` draws the editor and paginated Blackbook gallery, samples marker strokes in 2048 × 1024 design coordinates and handles undo/redo. `plugin/blackbook.lua` validates, lists, reads and saves version 1 drawing files. Each stroke stores its palette index, brush width and ordered coordinate pairs. Saving an edit retains the file ID. Four thumbnails per page and bounded stroke sizes keep the renderer within its shape budget.
