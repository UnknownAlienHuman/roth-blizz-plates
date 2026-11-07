# Agent guide

Before changing runtime code:

1. Read `RothBlizzPlates.toc`, `ARCHITECTURE.md`, and both Lua files.
2. Read the current `wow-addon-engineering-kb` index, Nameplates node, and 12.1.5 overlays.
3. Preserve source pin build `12.1.5.70783`, commit `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`, unless a source review deliberately updates it. The audited `70688 -> 70783` delta does not change the addon's nameplate/castbar surface.
4. Keep Blizzard ownership of native geometry, `nameplateSize`, and gameplay state.
5. Gate object-security returns before Lua boolean operations.
6. Send secret interruptibility only to documented `SetAlphaFromBoolean` sinks. A missed hook signal may be recovered from `IsInterruptable()` only by routing its result directly into complementary sinks; never branch on or invert it.
7. Keep assignment work generation-scoped: acquisition prepares, `OnUnitSet` activates, `OnUnitCleared` releases/restores.
8. Treat `NamePlateCastingBarMixin` as a copied owner: hook it directly after creation, or hook the source once before `CreateFromMixins`; never assume later base-table changes propagate.
9. Snapshot ordinary native font presentation before mutation, update the baseline after Blizzard refreshes it, restore it on disable/release, and never overwrite a newer foreign-owner presentation.
10. Accept only missing or finite non-negative whole numeric SavedVariables schemas. Unsupported values remain untouched and disable presentation.
11. Keep `UNIT_COMBAT` and its secret `amount` payload outside this addon; do not add raw combat/unit-state derivation.
12. Do not add polling, recursive child scans, color inference, raw unit-data reads, guessed hooks, or unbounded retries.
13. Run every command in `README.md`; report live-client checks as `NOT-RUN` unless actually captured.
