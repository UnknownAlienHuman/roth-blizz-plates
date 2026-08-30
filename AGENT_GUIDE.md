# Roth Blizzard Plates agent guide

## Start here

[`RothBlizzPlates.toc`](RothBlizzPlates.toc) is the definitive load contract. Retail 12.1 loads `core.lua` first and `castbar_12_1.lua` second. There is no XML, bundled library, raw unit-data subsystem, or replacement nameplate framework.

Target contract:

- Retail / Midnight `12.1.0`;
- Interface `120100`;
- verified Blizzard source baseline `12.1.0.69497`;
- no external addon dependencies.

## Runtime map

### `core.lua`

`core.lua` creates and sanitizes `RothBlizzPlatesDB`, defines value/object accessibility helpers, and owns the nameplate presentation boundary.

Event flow:

```text
PLAYER_LOGIN
  -> InitializeSettings
  -> RestyleAllVisible

NAME_PLATE_UNIT_ADDED
  -> StyleNamePlateUnit
  -> ApplySkin
  -> ApplyLayout

CVAR_UPDATE / UI_SCALE_CHANGED
  -> RestyleAllVisible outside combat

PLAYER_REGEN_ENABLED
  -> FlushPendingFrames
  -> RestyleAllVisible
```

`ApplySkin` immediately queues the frame when `InCombatLockdown()` is true. Out of combat, it styles the existing health StatusBar, creates one addon-owned plate texture on that bar, applies accessible fonts, keeps target highlight disabled, applies the threat texture, and delegates castbar presentation through `_G.RothBlizzPlates_CastBar.Apply`.

Lifecycle post-hooks on accessible Blizzard mixins only request `ApplySkin`; they do not perform an alternate state update path. The pending table is weak-keyed.

### `castbar_12_1.lua`

The castbar owner resolves known fields on the Blizzard unit frame and cast container. It does not call `GetChildren`, `GetNumChildren`, or scan arbitrary frame trees.

Presentation flow:

```text
Blizzard castbar update hook
  -> RequestApply
  -> combat? queue : Apply
  -> known container / StatusBar / icon fields
  -> snapshot accessible Blizzard texture and geometry
  -> apply Roth fill + addon-owned border + icon geometry
```

Explicit accessible `notInterruptible`, `interruptible`, or `isInterruptible` values are preferred. Accessible status-bar color is a fallback. Unknown state fails closed to non-interruptible art.

When `castBar.enabled` becomes false, the module restores the captured Blizzard status-bar texture and accessible geometry, hides the addon-owned border, and defers restoration if combat is active.

`/rbpcast status` reports only the pending queue count. It does not dump unit, spell, child-tree, or restricted values.

## State and dependencies

Durable state is `RothBlizzPlatesDB`:

- `enabled`;
- `plate`;
- `healthBar`;
- `castBar`;
- `castBorder`;
- `layout`;
- `name`;
- `font`.

Runtime-only state includes weak pending tables, frame ownership markers, scale caches, original geometry snapshots, the original cast texture, and the addon-owned border texture.

Blizzard nameplate/castbar mixins and global update functions are optional runtime boundaries. Every hook is presence-guarded. Absence is not replaced by polling or a frame-tree scan.

## Invariants

- Blizzard owns nameplate and cast lifecycle, progress, visibility, threat, target state, and secure behavior.
- Do not add `UnitName`, `UnitGUID`, `UnitHealth`, aura, combat-log, or spell-state derivation to this addon.
- Gate secret-capable values before type checks, comparisons, arithmetic, indexing, formatting, concatenation, logging, or persistence.
- Check `CanBeAccessedInContext` and `IsForbidden` before using frame objects when available.
- Do not create textures/frames or call geometry/font mutators while in combat.
- Keep pending tables weak-keyed and retry only on `PLAYER_REGEN_ENABLED`.
- Do not add `HookScript` or hook `CastingBarMixin:OnEvent` as a broad state source.
- Do not infer interruptibility from inaccessible visibility, alpha, error, focus, layout, or timing side channels.
- Do not mutate Blizzard shield/background regions merely to preserve a state signal; render addon-owned art instead.
- Keep repeated presentation passes idempotent.

## Change routing

- DB defaults, sanitization, Settings: `core.lua`.
- Value/object access gates: both runtime files; keep semantics aligned.
- Health-bar/plate/font/threat presentation: `core.lua`.
- Nameplate lifecycle and nameplate pending queue: `core.lua`.
- Cast container/status bar/icon discovery: `castbar_12_1.lua`.
- Interruptibility presentation, cast restore, cast hooks, cast pending queue: `castbar_12_1.lua`.
- Offline combat regression: `tests/test_combat_deferral.lua`.
- Metadata/load order: `RothBlizzPlates.toc`.

## Verification

From the repository root:

```sh
texlua --luaconly core.lua
texlua --luaconly castbar_12_1.lua
texlua tests/test_combat_deferral.lua
```

Expected regression output:

```text
PASS: core and castbar defer geometry in combat and restore Blizzard presentation
```

Also inspect the source for forbidden regressions:

```text
GetChildren
GetNumChildren
HookScript
UnitName
UnitGUID
UnitHealth
C_UnitAuras
AuraUtil.ForEachAura
```

In the target client, test fresh login and `/reload`; target changes; normal, elite, boss and threat states; casts, channels, interrupted casts, interruptible/non-interruptible transitions; combat entry/exit with visible plates; UI-scale/nameplate CVar changes; castbar option disable/enable; `koKR`/`zhCN`/`zhTW` font fallback; and `/console taintLog 1` plus Lua error capture.

Static tests do not prove current-client mixin availability or real secret/forbidden behavior. Record the exact build and scenario for every live result.
