# Architecture

## Ownership

Blizzard owns nameplate creation, pooled unit frames, unit assignment, protected geometry, health/cast progress, icon/text, visibility, target/threat state, and cast-state derivation.

RothBlizzPlates owns only:

- one decorative plate texture per pooled unit frame;
- two decorative cast-border textures per pooled cast bar;
- SavedVariables and standard Settings controls;
- reversible font presentation;
- generation-tagged deferred presentation/restoration work.

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
- `CastingBarMixin:IsInterruptable()`

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

ApplyFrameOptions
  -> observe a new Blizzard font baseline
  -> reapply addon presentation

OnUnitCleared / NAME_PLATE_UNIT_REMOVED fallback
  -> generation++
  -> discard pending apply work
  -> hide owned regions
  -> clear cast ownership
  -> restore native fonts now or after combat
```

`NAME_PLATE_UNIT_ADDED` remains a bounded fallback and unit-token map owner. Normal correctness no longer depends on event-handler ordering.

## Cast hook and current-state recovery

One `GetEffectiveType` hook is installed, selected by load order:

- if `NamePlateCastingBarMixin` already exists, hook its copied method directly;
- before Blizzard creates that mixin, hook the source method once so `CreateFromMixins` copies the wrapped function;
- never hook both owners in the same session.

A late attach or combat-deferred apply can miss the hook signal. In that case, `castBar:IsInterruptable()` supplies Blizzard's current ordinary-or-secret boolean. The addon routes it directly into two complementary `SetAlphaFromBoolean` calls. The result is never inspected or inverted in Lua. If the method is unavailable, the presentation fails closed to non-interruptible art.

## Font ownership and restoration

Before the first font mutation, the addon snapshots font file, height, flags, shadow offset, and shadow color. A later Blizzard refresh observed through `ApplyFrameOptions` replaces the baseline before the Roth style is reapplied.

Disable/release restores the current baseline outside combat. Combat release queues one generation-tagged restore. Reassignment invalidates stale restore work. If the current presentation no longer matches the last Roth-applied presentation, cleanup treats it as a newer foreign-owner update and relinquishes ownership without overwriting it.

## Security boundary

- Object-security returns are gated before Lua type checks or comparisons.
- Secret interruptibility is never compared, negated, keyed, formatted, logged, stored, or deferred.
- `SetAlphaFromBoolean` is the only secret conditional presentation sink.
- Accessible unknown `notInterruptible`, including documented `nil`, fails closed.
- No child-tree scans, color inference, raw unit-data reads, broad guessed hooks, or retry loops exist.

## Geometry boundary

Native health bars, cast bars, icons, text, and parent frames are never resized, moved, reparented, hidden, or assigned a replacement status-bar texture. Geometry calls target only addon-owned textures.

## Persistence compatibility

A missing schema is treated as legacy schema 0. Only finite non-negative whole numeric schemas `0..4` are migrated. Numeric schemas above 4 and malformed schema values remain untouched; Settings and presentation stay disabled, and diagnostics distinguish `newer` from `invalid`.

## Evidence ceiling

Offline tests prove the mocked lifecycle, persistence, hook-owner, current-state, and restoration policies. They do not prove visual alignment, current-client taint behavior, restricted encounter behavior, or live performance.
