# Agent guide

Before changing runtime code:

1. Read `RothBlizzPlates.toc`, `ARCHITECTURE.md`, and both Lua files.
2. Read the current `wow-addon-engineering-kb` index, Nameplates node, and 12.1.5 overlays.
3. Preserve the selected source pin: build `12.1.5.70688`, commit `d07eb00237d8891f153215db98a5df880a26cfe5`, unless a source review deliberately updates it.
4. Keep Blizzard ownership of native geometry and gameplay state.
5. Gate object-security returns before Lua boolean operations.
6. Send secret interruptibility only to the documented `SetAlphaFromBoolean` sink.
7. Keep assignment work generation-scoped; acquisition prepares, `OnUnitSet` activates, `OnUnitCleared` releases.
8. Do not add polling, recursive child scans, color inference, raw unit-data reads, guessed hooks, or unbounded retries.
9. Run every command in `README.md`; report live-client checks as `NOT-RUN` unless actually captured.
