# Roth Blizzard Plates

Roth-style presentation for Blizzard-owned nameplates and cast bars on World of Warcraft Retail 12.1.5.

![Roth Blizzard Plates nameplate and cast bar](https://media.forgecdn.net/attachments/1569/250/screenshot-2026-03-06-085056-png.png)

## Compatibility

- Retail interface: `120105`
- Addon version: `0.3.8`
- Selected Blizzard source baseline: `12.1.5.70783`
- Source commit: `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`
- External libraries: none

## Runtime model

- Blizzard owns unit assignment, health/cast progress, geometry, target/threat state, icon/text, visibility, the `nameplateSize` CVar, and pooled-frame lifecycle.
- The addon creates only its own plate and cast-border textures.
- Native font presentation is snapshotted before modification. Cleanup restores the actual Blizzard `FontObject` when one existed, plus effective font and shadow state.
- Canonical paths are `HealthBarsContainer.healthBar` and `CastBarsContainer.castBar`.
- `AcquireUnitFrame` prepares assignment state; `OnUnitSet` activates presentation; `OnUnitCleared` invalidates and restores assignment-scoped state.
- `ApplyFrameOptions` supplies Blizzard's current horizontal and vertical nameplate scale. Roth plate art, cast borders, offsets, and custom font height follow those values without changing native geometry.
- The cast hook attaches only to the exact copied `NamePlateCastingBarMixin` after it exists. Initial state missed before attachment is recovered through `IsInterruptable()`.
- Potentially secret interruptibility flows directly into complementary `SetAlphaFromBoolean` sinks without comparison, negation, logging, or persistence.
- Combat-deferred work is weak-keyed and generation-checked, so recycled frames cannot receive stale work.
- Unsupported interface or SavedVariables contracts disable both core and cast presentation, including direct internal-module calls.

## Changes in 0.3.8

- Remove the unproven assumption that a secure hook on `CastingBarMixin` is copied through `CreateFromMixins`.
- Install the interruptibility hook only on the exact `NamePlateCastingBarMixin`, with load continuation plus a bounded `PLAYER_ENTERING_WORLD` retry.
- Restore Blizzard `FontObject` identity instead of restoring only copied font file/height/flags.
- Accept current generated `FontAsset` values as strings or numeric assets and fail closed when presentation cannot be read.
- Do not change shadow offset/color unless the corresponding native baseline was readable and therefore reversible.
- Gate direct cast-module prepare/apply/hook calls through core runtime compatibility.
- Gate the bounded visible-nameplate table before iteration.

## Changes in 0.3.7

- Re-audit the addon against Retail build `12.1.5.70783` and source commit `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`.
- Confirm that the `70688 -> 70783` delta does not change Blizzard nameplate, castbar, Settings, region, or font implementation used by the addon.
- Record the relevant shared API delta: `UNIT_COMBAT.amount` is explicitly secret; RothBlizzPlates does not consume that event or payload.

## Commands

- `/rbp status` — interface/database compatibility plus active/deferred frame counts.
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
texlua tests/test_castbar_runtime_gate.lua .
texlua tests/test_native_scale.lua .
python3 tests/static_check.py
```

Offline checks cover lifecycle, combat deferral, schema guards, exact hook ownership, current-state secret sinks, native-size scaling, FontObject restoration, foreign-owner coexistence, and native-geometry isolation. Live Retail validation is still required for real cast/channel transitions, visual alignment across styles and sizes, UI scale, locale rendering, coexistence, and taint/forbidden-action logs.

## Installation

Copy `RothBlizzPlates` to `_retail_/Interface/AddOns/`, enable it, and reload the UI.

## License

MIT.
