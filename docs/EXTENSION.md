# Graffiti Lab extension work

## Baseline and order of work

The baseline is 0.6.12 at Git commit `340b2ae`. It targets ReSkate 20261116 and skate. 20260929. The seven existing Luau checks passed, including the actual release ZIP's 46 packaged designs. These runs used simulated host callbacks and the released native bundle. No new in-game run is implied.

1. Establish compatibility and performance measurements, then migrate a drawing only on explicit save.
2. Introduce library metadata, persistent map instances, contextual history, independent scale/rotation and import preparation.
3. Add tile wrapping, symmetry and nondestructive deformation to the editor and wall pipeline.
4. Lower memory per stored wall sample and stream reconstructible rendering resources. Measure early and late strokes after a restart.
5. Add playback, positional sound controls and photo capture through the verified host APIs.
6. Integrate the public gallery over HTTPS, with account ownership on the server.
7. Run regressions, package a development build, test on both maps and update the player guide.

## Runtime and data

- Sandboxed Luau draws the dock with ReSkate overlay primitives and captures input via named screens. The separate HTML helper runs in the player's browser. A PNG is never assigned directly to world geometry. Static catalogue IDs select compiled decal materials. Imported GLART1 rectangles and rasterised Blackbook lines select among 16 resident inks.
- Legacy Blackbook filenames identify individual drawings. Version 2 records the same ID inside the saved drawing. Opening an existing file is read-only. Its first edited save preserves its exact bytes in `recovery/blackbook-v1/` before replacing it. Conflicting backups and external edits stop the write. No bulk migration runs on install.
- GLART1 originals, packaged art and GLW1 wall pages remain readable. A versioned library record stores organisation independently from drawing source. A map instance needs its own ID, transform and appearance separate from its catalogue entry. Baseline placements were transient, so there are no durable legacy placement records to migrate.
- GLW1 uses 53-byte samples, 2,048 per page. The current loader restores at most 96 samples per call. Individual source samples are retained in RAM with matrices, run membership, eraser bins and page rows. Renderer state is reconstructible but the full source working set still grows with a map.
- The baseline stress test recorded 3,424 samples, 26 strokes and 2,048 live decals. The renderer can allocate 2,048 handles per plugin and 4,096 globally. The baseline limits ordinary art to 16 placements, 768 artwork handles and 256 rectangles per custom drawing. Blackbook allows 96 strokes and 448 points. The host limits the VM heap to 128 MiB, a data file to 1 MiB, and the data directory to 1,000 files. Distinguish these constraints from a stroke quota. The old test verifies unload/reconstruction and persistence but does not measure GPU frame time or maximum practical map size.
- Only current-session premade replication existed in 0.6.12. A cross-session public gallery needs independently hosted storage. The project now contains a Workers/D1 service outside the runtime package. ReSkate accepts GET and POST to manifest-allowlisted public HTTPS hosts on port 443, with a 64 KiB outgoing body, 1 MiB response, four outstanding requests, ten requests/minute and eight outstanding across plugins. No arbitrary authorization headers, cookies, redirects, or loopback hosts. Use a scoped owner credential in the HTTPS POST body.
- Native capture supports a single PNG frame written under plugin data with both capture and files permissions. Packaged WAV sounds and positional playback already work in the spray effects. Camera capture, per-placement playback and UI cleanup still require game checks.

[Runtime overview](https://docs.reskate.dev/plugins/overview) · [HTTP implementation](https://github.com/Dingo-Shenanigans/ReSkate/blob/8e4aefca153ce9cb622074ae4de05f81fa71d09c/Extension/Plugins/plugin_api_more.cpp) · [VM limits](https://github.com/Dingo-Shenanigans/ReSkate/blob/8e4aefca153ce9cb622074ae4de05f81fa71d09c/Extension/Plugins/plugin_vm.h) · [Files](https://docs.reskate.dev/plugins/api/files) · [Capture](https://docs.reskate.dev/plugins/api/capture) · [Audio](https://docs.reskate.dev/plugins/api/audio) · [Decals](https://docs.reskate.dev/plugins/api/effects)

## Feature status

| Requirement | Current evidence and next acceptance check |
| --- | --- |
| Save compatibility | Implemented for Blackbook. Luau migration, failed write, concurrent-edit and round-trip checks. Restart with a copied legacy drawing still needs a game pass. |
| Folders, favourites, recent and search | Organisation model in development. Requires connected screens and restart fixtures across all three source types. |
| Resize and edit map placements | Planned. Exercise two independent copies, selection, transforms, restoration and cancellation after a restart. |
| Import preparation | Planned. Verify edge-connected removal, internal whites, rotation, trim, crop and transparency on a placed import. |
| Contextual Undo/Redo | Existing editor supports stroke undo/redo. Separate world/library histories and grouped collection imports require verification. |
| Tile patterns, symmetry, deformation | Planned. Cover edges and corners, asymmetric origins, grouped undo, handles and transparent edges. |
| Increased paint capacity | Existing limit reproduced. Measure the new working set, incremental restore and renderer reconstruction before claiming an increase. |
| Animation and sound | Planned. Check frame edit scope, all trigger modes, visibility, per-instance state and cleanup. |
| Game photo to artwork | Host API verified. Real scene capture through preparation, treatment, save and placement pending. |
| Cross-session public gallery | Live Worker and D1 verified on 21 November 2026. On one ReSkate installation in San Vansterdam, Lab Test Artist published Lab Relay and Lab Test Visitor downloaded it through Public Artworks. The local copy retained all seven ink rectangles and the artist credit. A second-PC test and offline wall placement after restart remain open. |
| Delivery | 0.6.12 is the release baseline. The 0.7.0 gallery test ZIP was built, installed and exercised in ReSkate. The rest of the extension roadmap has separate acceptance checks. |
