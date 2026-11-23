# Development checklist

The [specification](PROJECT_SPEC.md) defines the pass conditions. Update [API findings](API_FINDINGS.md) when a test confirms or changes an assumption.

1. [x] **Preview, place and remove Switchback on one solid wall in each test map.** Verified offline in San Vansterdam and Turbo Token Arcade, including orientation, camera movement and removal. Also checked rejection of an upward aim and cleanup on map travel. [Build and playtest record](MILESTONE_1.md)
2. [x] **Select a premade design and preserve existing placements.** Switchback, Birds and Bonehead rendered together in Turbo Token Arcade. The first placement also survived switching and removal on the San Vansterdam kiosk. [Selector playtest](MILESTONE_2.md)
3. [x] **Save, restart, reopen and edit a Blackbook drawing.** A six-stroke drawing reopened in a new ReSkate process. Adding a seventh stroke updated the same gallery entry. [Editor playtest](MILESTONE_3.md)
4. [ ] Extend receiver and cleanup testing. Check rails, outside corners, foreground-object occlusion, thin partitions, replay and plugin reload with an active mark. Exercise a physical controller and measure frame time at 16 marks.
5. [x] **Preview, place and remove a saved drawing on both maps.** Blackbook kept the original seven strokes. A separate premade mark survived removal of the custom work. [Coverage, fidelity and timing](MILESTONE_4.md)
6. [x] **Draw directly on a wall in each test map.** Freehand waves stayed on the San Vansterdam kiosk and an arcade wall after closing the brush. Both were removed, and neighbouring kiosk artwork survived. [Wall Paint test record](MILESTONE_5.md)
7. [ ] **Verify premade sharing on a second signed-in ReSkate client.** The prototype, host placement and automated late-join checks are complete. On a separate client, confirm the pre-existing decal appears and disappears when its artist removes it. [Multiplayer test record](MILESTONE_6.md)
8. [x] **Publish and download through the live public gallery.** Two separate gallery accounts completed the exchange on one ReSkate installation in San Vansterdam. The visitor's saved ink and creator credit matched the published piece. [Live test](../service/gallery/README.md#live-graffiti-lab-test)
9. [ ] **Verify reuse on an independent installation.** Download the test piece on a second PC. Restart that client without gallery access and place the downloaded copy from My imports.

The [extension plan and feature status](EXTENSION.md) tracks save compatibility, library and placement editing, creative tools, paint capacity, media and the cross-session gallery.

## 0.8.1 qualification

The [feature status and reproducible checks](EXTENSION.md#081-development-build) cover all roadmap features. The open game checks are two-map placement of reshaped copies, silent animation playback, and a clean second installation downloading media and placing it offline. Public gallery cards, source compatibility and the 100,000-sample paint test have targeted regressions.

## 0.9.0 development

- [x] Build a layered project, produce a versioned premade, equip it and render the actual design above the local skater. Test a private custom activation on a separate Luau process with empty storage.
- [ ] Run the [two-client acceptance check](LAYERED_STUDIO.md#acceptance-checks) on signed-in ReSkate installations. Check local and remote head tracking through turns, crouches and bails, solid-wall occlusion, controller activation and map departure.
- [ ] Measure frame time with four simultaneous emotes and a dense Studio canvas on a lower-spec PC.
