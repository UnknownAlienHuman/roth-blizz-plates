# Roth Blizzard Plates

Roth-style presentation for Blizzard-owned nameplates and cast bars on World of Warcraft Retail 12.1.5.

![Roth Blizzard Plates nameplate and cast bar](https://media.forgecdn.net/attachments/1569/250/screenshot-2026-03-06-085056-png.png)

## Compatibility

- Retail interface: `120105`
- Addon version: `0.3.0`
- Selected Blizzard source baseline: `12.1.5.70688`
- Source commit: `d07eb00237d8891f153215db98a5df880a26cfe5`
- External libraries: none

## What changed in 0.3.0

- Uses the 12.1.5 canonical castbar path: `UnitFrame.CastBarsContainer.castBar`.
- Stops resizing, moving, reparenting, or hiding Blizzard-owned nameplate regions.
- Removes child-tree scans, color inference, broad hook guesses, and retry loops.
- Creates only addon-owned plate and cast-border textures.
- Routes potentially secret interruptibility directly into `SetAlphaFromBoolean`; inaccessible values are never compared, negated, stringified, or logged, while documented `nil` fails closed.
- Uses exact add/remove lifecycle events, generation-checked combat deferral, and recycle cleanup.
- Migrates and clamps existing SavedVariables in place.
- Fails closed outside interface `120105`.

## Commands

- `/rbp status` — interface support plus active/deferred frame counts.
- `/rbp refresh` — one coalesced, bounded pass over visible nameplates.

## Validation

Offline checks:

```bash
texlua --luaconly core.lua
texlua --luaconly castbar_12_1.lua
texlua tests/test_combat_deferral.lua .
python3 tests/static_check.py
```

These checks cover syntax, canonical ownership paths, no native geometry writes, exact lifecycle cleanup, stale deferred-work rejection, SavedVariables migration, and secret-boolean passthrough.

Live Retail validation is still required for visual alignment, cast/channel transitions, target/threat combinations, UI-scale/nameplate-setting changes, non-Latin fonts, and taint/forbidden-action logs. Offline checks are not presented as live-client proof.

## Installation

Copy `RothBlizzPlates` to `_retail_/Interface/AddOns/`, enable it, and reload the UI.

## License

MIT.
