# Roth Blizzard Plates architecture

## Ownership

`core.lua` owns SavedVariables defaults, value/object accessibility gates, Blizzard nameplate discovery, addon-owned plate art, font policy, Settings registration, lifecycle hooks, and the weak-key queue for deferred nameplate presentation.

`castbar_12_1.lua` owns the additive castbar presentation layer. It resolves only known Blizzard castbar fields, swaps the existing StatusBar texture, creates one addon-owned border texture, positions the existing spell icon, snapshots/restores accessible Blizzard geometry, and maintains a separate weak-key combat-deferral queue.

Blizzard remains the authority for nameplate creation, unit state, cast/channel state, cast progress, target/threat state, visibility, and secure behavior.

## Load order

```text
RothBlizzPlates.toc
  -> core.lua
  -> castbar_12_1.lua
```

The core may run before the castbar module exists; its next lifecycle pass calls the exported castbar owner after the second file loads.

## Safety boundary

- No `UnitName`, `UnitGUID`, `UnitHealth`, aura, or combat-log state is used as a presentation input.
- Secret-capable values are checked with `canaccessvalue` or `issecretvalue` before type checks, comparisons, arithmetic, concatenation, formatting, logging, or persistence.
- Frame objects are checked through `CanBeAccessedInContext` and `IsForbidden` when those methods exist.
- No addon-owned region is created in combat.
- No `ClearAllPoints`, `SetPoint`, `SetAllPoints`, `SetSize`, or `SetFont` operation runs while `InCombatLockdown()` is true.
- Nameplate and castbar lifecycle hooks request an idempotent presentation pass; they do not mutate Blizzard state directly in combat.
- Castbar discovery does not call `GetChildren` or `GetNumChildren` and does not infer state from child-tree shape.
- Unknown interruptibility fails closed to non-interruptible art.

## State

Durable state is limited to `RothBlizzPlatesDB`. Frame references, original geometry snapshots, original status-bar textures, ownership markers, scale caches, and pending queues are runtime-only. Pending tables use weak keys so pooled or released Blizzard frames are not retained by the addon.

## Restore behavior

Disabling castbar styling restores the captured Blizzard status-bar texture and accessible geometry for the cast container, nested StatusBar, and spell icon. The addon-owned border is hidden. The addon does not attempt an unsafe restore during combat; it defers the operation.

## Evidence boundary

`texlua` syntax checks and `tests/test_combat_deferral.lua` prove the offline deferral/restore contract against mocks. They do not prove current-client mixin availability, visual alignment, taint behavior, or inaccessible-value behavior in a real restricted encounter. Those remain live-client gates.
