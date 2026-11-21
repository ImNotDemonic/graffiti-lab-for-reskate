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
| 5. Direct wall painting | Open a brush in offline play and draw a freehand path directly on a nearby flat wall. Release to finish and undo a stroke as one mark. | Draw a visibly curved stroke on the San Vansterdam kiosk and a Turbo Token Arcade wall. After closing the brush, verify the stroke stays on the wall and can be removed. [Test record](MILESTONE_5.md) |
| 6. Multiplayer premades | Share confirmed catalogue placements with players in the same map and session world. | A second signed-in player sees a piece placed before joining, then sees it disappear when its artist removes it. [Test record](MILESTONE_6.md) |

Offline freehand wall paint persists by full map name until the player erases it or removes its stroke. Premade and Blackbook wall placements retain their existing temporary lifetime.

`plugin/paint.lua` casts through the current cursor, checks each sampled brush footprint with `surface.lua` and joins nearby hits on the same wall plane. Each freehand stroke is one undoable mark in the shared placement history. `plugin/wall_ink.lua` keeps its samples with the stroke and assigns visible decal handles by proximity and recency as the engine pool allows. `plugin/wall_store.lua` saves the stroke IDs, colours and transforms in versioned per-map pages. Erasing edits intersecting samples on the targeted face and preserves the rest of each stroke. Blackbook drawing files are independent.

## Runtime structure

The Graffiti Lab entry opens a five-choice dock over the current map. `plugin/menu.lua` owns the main menu and Settings. `plugin/dock.lua` draws the shared headings and panel controls. From the dock, backing out of a tool returns to the menu. Choosing **Place on Wall** hands input back to gameplay for aiming. Direct editor, gallery and paint shortcuts remain available. Brush colour and width are shared by Settings, the current-can readout and the wall brush for the session.

`plugin/sharing.lua` sends a bounded list of the artist's confirmed premades and reconciles other players' lists against locally owned decal handles. Only the transport supplies the sender identity. Previews, saved drawings and freehand strokes stay local. Artist departure, expiry and world changes clear shared copies.

`plugin/main.lua` owns the active design, translucent preview and confirmed marks. Premade and Blackbook marks own their decal handles and one expiry time. Freehand marks use renewable handles and persistent stroke records. `plugin/selector.lua` draws the Premade Art dock and `plugin/surface.lua` validates the intended rectangular footprint. `plugin/wall_art.lua` samples a saved stroke list in drawing order, merges runs of the same colour into rectangles and maps them onto the wall plane. The palette in `art/palette.json` links the editor's stored colour indices to compiled ink materials. [Milestone 4 test and limits](MILESTONE_4.md)

`plugin/studio.lua` draws the editor and paginated Blackbook gallery, samples marker strokes in 2048 × 1024 design coordinates and handles undo/redo. `plugin/blackbook.lua` validates, lists, reads and saves version 1 drawing files. Each stroke stores its palette index, brush width and ordered coordinate pairs. Saving an edit retains the file ID. Four thumbnails per page and bounded stroke sizes keep the renderer within its shape budget.
