# Roth Blizzard Plates

Roth-style presentation for Blizzard-owned nameplates and cast bars on World of Warcraft Retail 12.1.5.

![Roth Blizzard Plates nameplate and cast bar](https://media.forgecdn.net/attachments/1569/250/screenshot-2026-03-06-085056-png.png)

## Compatibility

- Retail interface: `120105`
- Addon version: `0.3.5`
- Selected Blizzard source baseline: `12.1.5.70688`
- Source commit: `d07eb00237d8891f153215db98a5df880a26cfe5`
- External libraries: none

## Runtime model

- Blizzard owns unit assignment, health/cast progress, geometry, target/threat state, icon/text, visibility, and pooled-frame lifecycle.
- The addon creates only its own plate and cast-border textures; native font presentation is snapshotted before modification and restored on disable/release.
- Canonical paths are `HealthBarsContainer.healthBar` and `CastBarsContainer.castBar`.
- `AcquireUnitFrame` prepares the cast owner before Blizzard computes the first cast type; `OnUnitSet` activates presentation; `OnUnitCleared` invalidates and restores assignment-scoped state.
- The cast hook prefers the exact copied `NamePlateCastingBarMixin`; before that mixin exists, it hooks the source method once so `CreateFromMixins` copies the wrapped function.
- Potentially secret interruptibility flows directly into complementary `SetAlphaFromBoolean` sinks without comparison, negation, logging, or persistence.
- Combat-deferred work is weak-keyed and generation-checked, so recycled frames cannot receive stale work.

## Changes in 0.3.5

- Recover the current cast interruptibility presentation after late attachment or combat deferral through Blizzard's `CastingBarMixin:IsInterruptable()` result.
- Route that ordinary-or-secret boolean directly into complementary interruptible/non-interruptible alpha sinks; no Lua inversion or branching is performed.
- Preserve an earlier hook-captured signal when available; method absence alone retains the conservative non-interruptible fallback.
- Add a regression for the native current-state path while keeping the copied-mixin hook-owner tests.

## Changes in 0.3.4

- Snapshot and restore exact Blizzard font file, flags, shadow offset, and shadow color on disable or pooled-frame release.
- Defer font restoration through combat and reject stale generations after reassignment.
- Relinquish ownership instead of overwriting a newer Blizzard/foreign font presentation.
- Reject malformed SavedVariables schema values without partial migration, deletion, clamping, or rewrite.

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
python3 tests/static_check.py
```

The targeted 0.3.5 checks cover the copied hook owner, pre-load hook path, and native current-state secret-boolean sink path. Older lifecycle and persistence regressions remain in the repository; live Retail validation is still required for real cast/channel transitions, visual alignment, UI-scale/nameplate-setting combinations, locale rendering, coexistence, and taint/forbidden-action logs.

## Installation

Copy `RothBlizzPlates` to `_retail_/Interface/AddOns/`, enable it, and reload the UI.

## License

MIT.
