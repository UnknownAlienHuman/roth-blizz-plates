# Roth Blizzard Plates agent guide

## Start here

The complete load contract is [`RothBlizzPlates.toc`](RothBlizzPlates.toc): `core.lua` is loaded before `castbar.lua`; there is no XML and no bundled library. `core.lua` creates/normalizes `RothBlizzPlatesDB`, then owns nameplate discovery, layout, font/media, settings, and lifecycle hooks. `castbar.lua` is a second layer over Blizzard cast widgets and installs its own debug slash command.

## Runtime and state flow

`core.lua` handles `PLAYER_LOGIN`, `NAME_PLATE_UNIT_ADDED`, `CVAR_UPDATE`, `UI_SCALE_CHANGED`, and `PLAYER_REGEN_ENABLED`. Login registers Settings and calls `RestyleAllVisible`; a newly added plate goes through `StyleNamePlateUnit` -> `ApplySkin` -> `ApplyLayout`. `ApplySkin` only marks/stylizes the existing Blizzard unit frame and records blocked layouts in `PendingLayout`; regen-enabled retries those layouts.

`InstallNamePlateLifecycleHooks` post-hooks `NamePlateUnitFrameMixin:UpdateAnchors`, `ApplyFrameOptions`, and `NamePlateBaseMixin:ApplyFrameOptions` when available, with `EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", ...)` as the late-load path. `CompactUnitFrame_UpdateSelectionHighlight` is also post-hooked to re-disable target highlight.

`castbar.lua` finds the cast container with `FindCastContainer`, chooses the visible primary StatusBar, creates a Roth fill/border overlay, mirrors min/max/value/color via post-hooks, and applies `ApplyCastBar`. It hooks possible Blizzard update functions (`CompactUnitFrame_UpdateCastBar`, `DefaultCompactNamePlateFrame_UpdateCastBar`, `CompactNamePlateFrame_UpdateCastBar`, `NamePlate_UpdateCastBar`) and relevant `CastingBarMixin` methods. `HookScript("OnShow")` is used only on the discovered cast container to reapply after template rebuilds.

## State, surfaces, dependencies

`RothBlizzPlatesDB` contains `enabled`, `plate`, `healthBar`, `castBar`, `castBorder`, `layout`, `name`, `font`, and the cast debug flag. Settings in `core.lua` expose `font.useGlobal` and `castBar.enabled`; `/rbpcast debug` toggles `debugCast`, and `/rbpcast dump` dumps target castbar regions. There are no declared external dependencies; Blizzard nameplate/castbar mixins are runtime boundaries, not addon dependencies.

## Invariants and risks

- This addon skins existing Blizzard frames and must not replace their lifecycle or read UnitHealth/UnitName/UnitGUID as logic inputs.
- `CanTouchAnchors`, `IsPlainNumber`, `IsPlainBoolean`, and `pcall` guards protect against forbidden/secret values. Do not introduce arithmetic on secret anchors or unit data.
- Anchor/size operations can be blocked in combat; preserve `PendingLayout` and the regen retry.
- Blizzard template recreation can invalidate child regions; change `ApplyCastBar` and its hooks together.
- `CVAR_UPDATE` and scale/nameplate lifecycle hooks can restyle many visible plates; keep work idempotent and avoid new per-frame loops.

## Change routing

- Plate geometry/font/health texture: `core.lua` (`ApplyLayout`, `ApplyFont`, `ApplySkin`).
- Nameplate lifecycle/target highlight: `core.lua` (`RestyleAllVisible`, `InstallNamePlateLifecycleHooks`, event frame).
- Castbar discovery, overlays, colors, and update hooks: `castbar.lua` (`FindCastContainer`, `ApplyCastBar`, `InstallCastbarHooks`).
- Settings/default migration: `core.lua` DB initialization and `InitializeSettings`; preserve old-layout migration predicates.
- Debug output: `castbar.lua` (`DebugPrint`, `DumpCastForUnit`) and `/rbpcast` handler.

## Verification

Static: validate TOC references, parse both Lua files, and run `git diff --check`. In game, enable/disable the addon, enter/leave combat with visible nameplates, change UI scale/nameplate CVars, toggle both Settings controls, and run `/rbpcast debug` then `/rbpcast dump` on a target. Verify no forbidden/secret Lua errors and that late Blizzard_NamePlates loading still installs hooks. Current audit does not claim a live client run or current patch mixin availability.
