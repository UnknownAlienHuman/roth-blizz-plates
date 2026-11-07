# Code index

| File | Owner |
|---|---|
| `RothBlizzPlates.toc` | Retail 12.1.5 metadata, SavedVariables, load order, source pin |
| `core.lua` | Strict schema migration, Settings, object/table access gates, exact nameplate lifecycle, native-size capture, scaled plate/font presentation, FontObject restoration, combat deferral |
| `castbar_12_1.lua` | Canonical castbar owner, exact copied-mixin hook, runtime compatibility gate, hook/current-state secret boolean sinks, scale-aware cast-border presentation, cleanup |
| `tests/test_combat_deferral.lua` | Supported-schema migration plus lifecycle, secret/recycle/combat/settings regression |
| `tests/test_future_schema.lua` | Downgrade guard for unknown newer numeric schemas |
| `tests/test_invalid_schema.lua` | Reject malformed, NaN, negative, and fractional schemas without mutation |
| `tests/test_font_restore.lua` | FontObject/effective font/shadow restoration, opaque-shadow restraint, combat deferral, pooled reuse, foreign-owner coexistence |
| `tests/test_castbar_hook_owner.lua` | Post-load exact copied-mixin hook plus native current-state recovery |
| `tests/test_castbar_hook_preload.lua` | Exact hook installation after `Blizzard_NamePlates` creates the copied owner |
| `tests/test_castbar_runtime_gate.lua` | Unsupported core contract blocks direct cast hooks, prepare, apply, and texture creation |
| `tests/test_native_scale.lua` | Small/Huge/native fallback scaling, secret-scale rejection, reuse, and native-geometry isolation |
| `tests/static_check.py` | Ownership, scaling, hook, restoration, compatibility, and forbidden-pattern checks |
| `media/` | One font, one plate texture, and two cast-border textures |
