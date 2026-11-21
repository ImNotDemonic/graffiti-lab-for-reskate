# Development checklist

The [specification](PROJECT_SPEC.md) defines the pass conditions. Update [API findings](API_FINDINGS.md) when a test confirms or changes an assumption.

1. [x] **Preview, place and remove Switchback on one solid wall in each test map.** Verified offline in San Vansterdam and Turbo Token Arcade, including orientation, camera movement and removal. Also checked rejection of an upward aim and cleanup on map travel. [Build and playtest record](MILESTONE_1.md)
2. [x] **Select a premade design and preserve existing placements.** Switchback, Birds and Bonehead rendered together in Turbo Token Arcade. The first placement also survived switching and removal on the San Vansterdam kiosk. [Selector playtest](MILESTONE_2.md)
3. [x] **Save, restart, reopen and edit a Blackbook drawing.** A six-stroke drawing reopened in a new ReSkate process. Adding a seventh stroke updated the same gallery entry. [Editor playtest](MILESTONE_3.md)
4. [ ] Extend receiver and cleanup testing. Check rails, outside corners, foreground-object occlusion, thin partitions, replay and plugin reload with an active mark. Exercise a physical controller and measure frame time at 16 marks.
5. [x] **Preview, place and remove a saved drawing on both maps.** Blackbook kept the original seven strokes. A separate premade mark survived removal of the custom work. [Coverage, fidelity and timing](MILESTONE_4.md)
6. [x] **Draw directly on a wall in each test map.** Freehand waves stayed on the San Vansterdam kiosk and an arcade wall after closing the brush. Both were removed, and neighbouring kiosk artwork survived. [Wall Paint test record](MILESTONE_5.md)
7. [ ] Investigate multiplayer sharing. Test joining late and missing artwork before defining a network feature.
