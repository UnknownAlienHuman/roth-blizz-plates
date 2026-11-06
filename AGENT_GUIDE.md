# Agent guide

Before changing runtime code:

1. Read `RothBlizzPlates.toc`, `ARCHITECTURE.md`, and both Lua files.
2. Read the current `wow-addon-engineering-kb` index plus the Nameplates and 12.1.5 contract nodes.
3. Pin every Blizzard-source claim to a build and commit.
4. Preserve Blizzard ownership. Addon-owned regions are preferred over native geometry changes.
5. Treat cast interruptibility as potentially secret. It may only flow into an approved native sink.
6. Use exact lifecycle events. Do not add polling, recursive child scans, guessed hooks, or unbounded retries.
7. Run all checks documented in `README.md`.
8. Report live-client validation as `NOT-RUN` unless it was actually performed.

Current source pin: build `12.1.5.70688`, commit `d07eb00237d8891f153215db98a5df880a26cfe5`.
