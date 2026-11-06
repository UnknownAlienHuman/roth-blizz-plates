# Roth Blizzard Plates

Roth-style presentation for Blizzard-owned nameplates and cast bars on World of Warcraft Retail 12.1.5.

![Roth Blizzard Plates nameplate and cast bar](https://media.forgecdn.net/attachments/1569/250/screenshot-2026-03-06-085056-png.png)

## Compatibility

- Retail interface: `120105`
- Addon version: `0.3.4`
- Selected Blizzard source baseline: `12.1.5.70688`
- Source commit: `d07eb00237d8891f153215db98a5df880a26cfe5`
- External libraries: none

## Runtime model

- Blizzard owns unit assignment, health/cast progress, geometry, target/threat state, icon/text, visibility, and pooled-frame lifecycle.
- The addon creates only its own plate and cast-border textures; native font presentation is snapshotted before modification.
- Canonical paths are `HealthBarsContainer.healthBar` and `CastBarsContainer.castBar`.
- `AcquireUnitFrame` prepares the cast owner before Blizzard computes the first cast type; `OnUnitSet` activates presentation; `OnUnitCleared` invalidates and restores assignment-scoped state.
- The cast hook prefers the exact copied `NamePlateCastingBarMixin`; before that mixin exists, it hooks the source method once so `CreateFromMixins` copies the wrapped function.
- Secret-capable object-security results are gated before Lua boolean operations.
- Potentially secret `notInterruptible` flows directly into `SetAlphaFromBoolean` without comparison, negation, logging, or persistence.
- Combat-deferred work is weak-keyed and generation-checked, so recycled frames cannot receive stale work.

## Changes in 0.3.4

- Snapshot and restore the exact ordinary Blizzard font, flags, shadow offset, and shadow color when font styling is disabled or a pooled frame is released.
- Defer native font restoration during combat and discard stale restore work when the frame is reassigned.
- Detect a newer Blizzard/foreign font presentation and relinquish ownership instead of overwriting it during cleanup.
- Reject malformed SavedVariables schema values (`string`, boolean, NaN, negative, or fractional) without partially migrating or deleting fields.
- Report `newer` and `invalid` database incompatibility separately.

## Changes in 0.3.3

- Fix cast interruptibility updates when `NamePlateCastingBarMixin` already copied `CastingBarMixin:GetEffectiveType` before this addon installed its hook.
- Prefer the exact nameplate mixin and use the base mixin only as a pre-load source hook.
- Add separate regressions for both Blizzard load orders and verify generic cast bars stay isolated when the exact owner exists.

## Commands

- `/rbp status` — interface, database compatibility, and active/deferred frame counts.
- `/rbp refresh` — one coalesced, bounded pass over visible nameplates.

## Validation

```bash
texlua --luaconly core.lua
texlua --luaconly castbar_12_1.lua
texlua tests/test_combat_deferral.lua .
texlua tests/test_future_schema.lua .
texlua tests/test_invalid_schema.lua .
texlua tests/test_font_restore.lua .
texlua tests/test_castbar_hook_owner.lua .
texlua tests/test_castbar_hook_preload.lua .
python3 tests/static_check.py
```

The new targeted regressions cover exact font restoration, combat-deferred cleanup, pooled reassignment, foreign-owner coexistence, and malformed schema rejection. Existing lifecycle and cast-owner regressions remain part of the full suite.

Live Retail validation remains required for visual alignment, real cast/channel transitions, UI-scale/nameplate-setting combinations, non-Latin fonts, coexistence with other nameplate/font addons, and taint/forbidden-action logs.

## Installation

Copy `RothBlizzPlates` to `_retail_/Interface/AddOns/`, enable it, and reload the UI.

## License

MIT.
