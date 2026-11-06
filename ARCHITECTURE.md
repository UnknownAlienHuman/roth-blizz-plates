# Architecture

## Ownership

Blizzard owns nameplate creation, pooled unit frames, unit assignment, protected geometry, health/cast progress, icon/text, visibility, target/threat state, and cast-state derivation.

RothBlizzPlates owns only:

- one decorative plate texture per pooled unit frame;
- two decorative cast-border textures per pooled cast bar;
- SavedVariables and standard Settings controls;
- font presentation;
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
- `CastingBarMixin:GetEffectiveType(..., notInterruptible, ...)`

## Assignment lifecycle

```text
AcquireUnitFrame
  -> PrepareAssignment
  -> cast module creates/reuses hidden owned layers
  -> OwnerByCastBar is installed before SetUnit

Blizzard SetUnit / GetEffectiveType
  -> secret-capable notInterruptible
  -> direct SetAlphaFromBoolean sinks

OnUnitSet
  -> activate prepared generation
  -> apply plate, fonts, and cast geometry

OnUnitCleared / NAME_PLATE_UNIT_REMOVED fallback
  -> generation++
  -> discard pending work
  -> hide owned regions
  -> clear cast ownership
```

`NAME_PLATE_UNIT_ADDED` remains a bounded fallback and unit-token map owner. Normal correctness no longer depends on event-handler ordering.

## Security boundary

- `CanBeAccessedInContext` and `IsForbidden` returns are checked with `canaccessvalue`/`issecretvalue` before type checks or comparisons.
- Secret interruptibility is never compared, negated, keyed, formatted, logged, stored, or deferred.
- `SetAlphaFromBoolean` is the only secret conditional presentation sink.
- Unknown accessible interruptibility, including documented `nil`, fails closed to non-interruptible art.
- No child-tree scans, color inference, raw unit-data reads, broad global hooks, or retry loops exist.

## Geometry boundary

Native health bars, cast bars, icons, text, and parent frames are never resized, moved, reparented, hidden, or assigned a replacement status-bar texture.

Geometry calls target only addon-owned textures. Plate coordinates are health-bar-relative; cast-border coordinates are cast-bar-relative.

## Deferred work

The core stores one weak-key generation per pending unit frame. Combat exit applies only work whose frame is still active and whose generation still matches. Assignment preparation and release both invalidate stale generations.

## Evidence ceiling

Offline tests prove the mocked lifecycle and static ownership policy. They do not prove visual alignment, current-client taint behavior, restricted encounter behavior, or performance in a live client.
