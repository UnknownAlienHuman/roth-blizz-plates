# Code index

## `core.lua`

- SavedVariables migration, defaults, and bounds
- interface gate (`120105`)
- exact nameplate acquire/release lifecycle
- generation-checked combat deferral
- addon-owned plate texture
- font presentation
- exact Blizzard nameplate hooks
- `/rbp status` and `/rbp refresh`

## `castbar_12_1.lua`

- canonical `CastBarsContainer.castBar` resolver
- two addon-owned interruptibility border textures
- secret-safe `SetAlphaFromBoolean` routing
- exact `CastingBarMixin` hooks
- recycle cleanup

## `tests/test_combat_deferral.lua`

Mocked lifecycle and secret-signal regression test.

## `tests/static_check.py`

Source invariants and banned-pattern check.
