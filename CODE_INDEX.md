# Code index

| File | Owner |
|---|---|
| `RothBlizzPlates.toc` | Retail 12.1.5 metadata, SavedVariables, load order, source pin |
| `core.lua` | Strict schema migration, Settings, object-security gates, exact nameplate lifecycle, native-size capture, scaled plate/font presentation, reversible font ownership, combat deferral |
| `castbar_12_1.lua` | Canonical castbar owner, copied-mixin hook selection, hook/current-state secret boolean sinks, scale-aware cast-border presentation, cast-layer cleanup |
| `tests/test_combat_deferral.lua` | Supported-schema migration plus lifecycle, secret/recycle/combat/settings regression |
| `tests/test_future_schema.lua` | Downgrade guard for unknown newer numeric schemas |
| `tests/test_invalid_schema.lua` | Reject malformed, NaN, negative, and fractional schemas without mutation |
| `tests/test_font_restore.lua` | Exact font/shadow restoration, combat deferral, pooled reuse, foreign-owner coexistence |
| `tests/test_castbar_hook_owner.lua` | Post-load copied-mixin hook plus native current-state recovery |
| `tests/test_castbar_hook_preload.lua` | Pre-load source hook copied by `CreateFromMixins` |
| `tests/test_native_scale.lua` | Small/Huge/native fallback scaling, secret-scale rejection, reuse, and native-geometry isolation |
| `tests/static_check.py` | Ownership, scaling, and forbidden-pattern policy checks |
| `media/` | One font, one plate texture, and two cast-border textures |
