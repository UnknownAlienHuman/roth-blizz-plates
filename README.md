# Roth Blizzard Plates

Roth-style presentation for Blizzard-owned nameplates and cast bars on World of Warcraft Retail 12.1.5.

![Roth Blizzard Plates nameplate and cast bar](https://media.forgecdn.net/attachments/1569/250/screenshot-2026-03-06-085056-png.png)

## Compatibility

- Retail interface: `120105`
- Addon version: `0.3.1`
- Selected Blizzard source baseline: `12.1.5.70688`
- Source commit: `d07eb00237d8891f153215db98a5df880a26cfe5`
- External libraries: none

## Runtime model

- Blizzard owns unit assignment, health/cast progress, geometry, target/threat state, icon/text, and visibility.
- The addon creates only its own plate and cast-border textures and applies font presentation.
- Canonical paths are `HealthBarsContainer.healthBar` and `CastBarsContainer.castBar`.
- `AcquireUnitFrame` prepares the cast owner before Blizzard computes the first cast type; `OnUnitSet` activates presentation; `OnUnitCleared` invalidates it.
- Secret-capable object-security results are gated before Lua boolean operations.
- Potentially secret `notInterruptible` flows directly into `SetAlphaFromBoolean` without comparison, negation, logging, or persistence.
- Combat-deferred work is weak-keyed and generation-checked, so recycled frames cannot receive stale work.

## Changes in 0.3.1

- Fix the first-cast race by preparing addon-owned cast layers at `AcquireUnitFrame`.
- Add exact `OnUnitSet` activation instead of depending on nameplate event ordering.
- Gate secret-capable `CanBeAccessedInContext` and `IsForbidden` returns correctly.
- Migrate plate coordinates to health-bar-relative offsets; old defaults now resolve to `(0, 0.5)` instead of the accidental `(6, 4)` shift.
- Restore a minimal Blizzard Settings category for plate art, cast borders, global font, and font shadow.
- Iterate the bounded visible-nameplate result with `pairs`, matching Blizzard's selected implementation.

## Commands

- `/rbp status` — interface support plus active/deferred frame counts.
- `/rbp refresh` — one coalesced, bounded pass over visible nameplates.

## Validation

```bash
texlua --luaconly core.lua
texlua --luaconly castbar_12_1.lua
texlua tests/test_combat_deferral.lua .
python3 tests/static_check.py
```

The regression covers migration, canonical ownership, exact acquire/set/clear lifecycle, initial secret-signal capture, secret object-security rejection, combat deferral, stale-work rejection, recycle cleanup, settings refresh, and absence of native geometry or status-bar texture writes.

Live Retail validation remains required for visual alignment, real cast/channel transitions, UI-scale/nameplate-setting combinations, non-Latin fonts, and taint/forbidden-action logs.

## Installation

Copy `RothBlizzPlates` to `_retail_/Interface/AddOns/`, enable it, and reload the UI.

## License

MIT.
