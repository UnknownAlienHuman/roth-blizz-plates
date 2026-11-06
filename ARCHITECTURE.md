# Architecture

## Ownership

Blizzard owns nameplate creation, pooled unit frames, unit assignment, protected geometry, health/cast progress, icon/text, visibility, target/threat state, and cast-state derivation.

RothBlizzPlates owns only:

- one decorative plate texture per pooled unit frame;
- two decorative cast-border textures per pooled cast bar;
- SavedVariables and standard Settings controls;
- reversible font presentation;
- generation-tagged deferred presentation work.

## Source contract

Target: Retail `12.1.5`, interface `120105`.

Selected source: build `12.1.5.70688`, commit `d07eb00237d8891f153215db98a5df880a26cfe5`.

Canonical source paths:

- `NamePlateBaseMixin:AcquireUnitFrame`
- `NamePlateUnitFrameMixin:ApplyFrameOptions`
- `NamePlateUnitFrameMixin:OnUnitSet`
- `NamePlateUnitFrameMixin:OnUnitCleared`
- `unitFrame.HealthBarsContainer.healthBar`
- `unitFrame.CastBarsContainer.castBar`
- `NamePlateCastingBarMixin:GetEffectiveType(..., notInterruptible, ...)`

`NamePlateCastingBarMixin` is created with `CreateFromMixins(CastingBarMixin, NamePlateComponentMixin)`, so its methods are copied rather than dynamically inherited.

## Assignment lifecycle

```text
AcquireUnitFrame
  -> PrepareAssignment
  -> cast module creates/reuses hidden owned layers
  -> OwnerByCastBar is installed before SetUnit

Blizzard SetUnit / NamePlateCastingBarMixin:GetEffectiveType
  -> secret-capable notInterruptible
  -> direct SetAlphaFromBoolean sinks

OnUnitSet
  -> activate prepared generation
  -> apply plate, reversible fonts, and cast art

OnUnitCleared / NAME_PLATE_UNIT_REMOVED fallback
  -> generation++
  -> discard pending apply work
  -> hide owned regions
  -> clear cast ownership
  -> restore native font presentation now or after combat
```

`NAME_PLATE_UNIT_ADDED` remains a bounded fallback and unit-token map owner. Normal correctness no longer depends on event-handler ordering.

## Cast hook installation

One hook is installed, selected by load order:

- if `NamePlateCastingBarMixin` already exists, hook its copied `GetEffectiveType` method directly;
- before `Blizzard_NamePlates` creates that mixin, hook `CastingBarMixin:GetEffectiveType` once so `CreateFromMixins` copies the wrapped method;
- never hook both owners in the same session.

## Font ownership and restoration

Native FontStrings are ordinary foreign visuals, not addon-owned regions. Before the first mutation, the addon snapshots:

- font file, height, and flags;
- shadow offset;
- shadow color.

A later Blizzard refresh observed by `ApplyFrameOptions` replaces the stored baseline before the Roth style is reapplied. Disable/release restores that baseline outside combat. A combat release queues one generation-tagged restore; reassignment cancels stale restore work. If the current presentation no longer matches the last Roth-applied state, cleanup treats it as a newer foreign-owner update and relinquishes ownership without overwriting it.

## Security boundary

- `CanBeAccessedInContext` and `IsForbidden` returns are checked with `canaccessvalue`/`issecretvalue` before type checks or comparisons.
- Secret interruptibility is never compared, negated, keyed, formatted, logged, stored, or deferred.
- `SetAlphaFromBoolean` is the only secret conditional presentation sink.
- Unknown accessible interruptibility, including documented `nil`, fails closed to non-interruptible art.
- No child-tree scans, color inference, raw unit-data reads, broad guessed hooks, or retry loops exist.

## Geometry boundary

Native health bars, cast bars, icons, text, and parent frames are never resized, moved, reparented, hidden, or assigned a replacement status-bar texture.

Geometry calls target only addon-owned textures. Plate coordinates are health-bar-relative; cast-border coordinates are cast-bar-relative.

## Deferred work

The core stores one weak-key generation per pending unit frame and per pending font restore. Combat exit applies only work whose lifecycle state and generation still match. Assignment preparation and release invalidate stale generations.

## Persistence compatibility

A missing schema is treated as legacy schema 0. Only finite, non-negative whole numeric schemas `0..4` are migrated. Numeric schemas above 4 and malformed schema values are left under user ownership without default merge, field deletion, clamping, or schema rewrite. Settings and presentation remain disabled, and `/rbp status` reports `newer` or `invalid` separately.

## Evidence ceiling

Offline tests prove the mocked lifecycle, persistence, and restoration policy. They do not prove visual alignment, current-client taint behavior, restricted encounter behavior, or performance in a live client.
