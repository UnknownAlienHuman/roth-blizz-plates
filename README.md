# Roth Blizzard Plates

Roth-style presentation for Blizzard-owned nameplates and cast bars on World of Warcraft Retail 12.1.5.

![Roth Blizzard Plates nameplate and cast bar](https://media.forgecdn.net/attachments/1569/250/screenshot-2026-03-06-085056-png.png)

## Compatibility

- Retail interface: `120105`
- Addon version: `0.3.7`
- Selected Blizzard source baseline: `12.1.5.70783`
- Source commit: `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`
- External libraries: none

## Runtime model

- Blizzard owns unit assignment, health/cast progress, geometry, target/threat state, icon/text, visibility, and pooled-frame lifecycle.
- The addon creates only its own plate and cast-border textures; native font presentation is snapshotted before modification and restored on disable/release.
- Canonical paths are `HealthBarsContainer.healthBar` and `CastBarsContainer.castBar`.
- `AcquireUnitFrame` prepares the cast owner before Blizzard computes the first cast type; `OnUnitSet` activates presentation; `OnUnitCleared` invalidates and restores assignment-scoped state.
- `ApplyFrameOptions` supplies Blizzard's current horizontal and vertical nameplate scale. Roth plate art, cast borders, offsets, and custom font height follow those values without writing the `nameplateSize` CVar or changing native geometry.
- The cast hook prefers the exact copied `NamePlateCastingBarMixin`; before that mixin exists, it hooks the source method once so `CreateFromMixins` copies the wrapped function.
- Potentially secret interruptibility flows directly into complementary `SetAlphaFromBoolean` sinks without comparison, negation, logging, or persistence.
- Combat-deferred work is weak-keyed and generation-checked, so recycled frames cannot receive stale work.

## Changes in 0.3.7

- Re-audit the addon against Retail build `12.1.5.70783` and source commit `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`.
- Confirm that the `70688 -> 70783` delta does not change Blizzard nameplate, castbar, Settings, region, or font implementation used by the addon.
- Record the only relevant shared API delta: `UNIT_COMBAT.amount` is now explicitly secret; RothBlizzPlates does not consume `UNIT_COMBAT` or that payload.
- Keep runtime code unchanged because the selected ownership and security contracts remain valid.

## Changes in 0.3.6

- Scale addon-owned plate and cast-border art with Blizzard's native `nameplateSize` layout.
- Capture `horizontalScale` and `verticalScale` from the exact `ApplyFrameOptions` lifecycle boundary.
- Scale artwork offsets and custom font height proportionally for Small through Huge nameplates.
- Reject inaccessible, non-numeric, NaN, or out-of-contract scale values without replacing the last valid layout.
- Keep Blizzard as the only owner of the `nameplateSize` CVar and all native frame geometry.
- Add a focused regression covering Small, Huge, late-attach fallback, secret-scale rejection, texture reuse, and zero native geometry writes.

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
texlua tests/test_native_scale.lua .
python3 tests/static_check.py
```

The 0.3.7 source audit found no nameplate/castbar contract delta requiring runtime changes. Live Retail validation is still required for real cast/channel transitions, visual alignment across nameplate styles and sizes, UI scale, locale rendering, coexistence, and taint/forbidden-action logs.

## Installation

Copy `RothBlizzPlates` to `_retail_/Interface/AddOns/`, enable it, and reload the UI.

## License

MIT.
