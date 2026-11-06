# Agent guide

Before changing runtime code:

1. Read `RothBlizzPlates.toc`, `ARCHITECTURE.md`, and both Lua files.
2. Read the current `wow-addon-engineering-kb` index, Nameplates node, and 12.1.5 overlays.
3. Preserve the selected source pin: build `12.1.5.70688`, commit `d07eb00237d8891f153215db98a5df880a26cfe5`, unless a source review deliberately updates it.
4. Keep Blizzard ownership of native geometry and gameplay state.
5. Gate object-security returns before Lua boolean operations.
6. Send secret interruptibility only to the documented `SetAlphaFromBoolean` sink.
7. Keep assignment work generation-scoped; acquisition prepares, `OnUnitSet` activates, `OnUnitCleared` releases.
8. Treat `NamePlateCastingBarMixin` as a copied owner: hook it directly after creation, or hook the source once before `CreateFromMixins`; never assume later base-table changes propagate.
9. Snapshot ordinary native font presentation before mutation, restore it on disable/release, defer restoration in combat, and never overwrite a newer foreign-owner update.
10. Accept only missing or finite non-negative whole numeric SavedVariables schema versions; unsupported values must remain untouched and disable presentation.
11. Do not add polling, recursive child scans, color inference, raw unit-data reads, guessed hooks, or unbounded retries.
12. Run every command in `README.md`; report live-client checks as `NOT-RUN` unless actually captured.
