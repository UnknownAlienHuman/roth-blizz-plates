# Code index

| File | Owner |
|---|---|
| `RothBlizzPlates.toc` | Retail 12.1.5 metadata, SavedVariables, load order, source pin |
| `core.lua` | Schema migration, Settings, object-security gates, exact nameplate lifecycle, plate/font presentation, combat deferral |
| `castbar_12_1.lua` | Canonical castbar owner, load-order-safe exact/source hook selection, secret boolean sinks, cast-layer cleanup |
| `tests/test_combat_deferral.lua` | Supported-schema migration plus lifecycle, secret/recycle/combat/settings regression |
| `tests/test_future_schema.lua` | Downgrade guard: preserve and reject unknown newer SavedVariables schemas |
| `tests/test_castbar_hook_owner.lua` | Post-load path: hook the copied nameplate mixin and isolate generic cast bars |
| `tests/test_castbar_hook_preload.lua` | Pre-load path: hook the source before `CreateFromMixins` copies it |
| `tests/static_check.py` | Ownership and forbidden-pattern policy checks |
| `media/` | One font, one plate texture, and two cast-border textures |
