# Architecture

## Ownership

Blizzard owns nameplate creation, pooled unit frames, unit assignment, protected geometry, health/cast progress, icon/text, visibility, target/threat state, cast-state derivation, and the `nameplateSize` CVar.

RothBlizzPlates owns only:

- one decorative plate texture per pooled unit frame;
- two decorative cast-border textures per pooled cast bar;
- SavedVariables and standard Settings controls;
- reversible font presentation;
- generation-tagged deferred presentation/restoration work.

## Source contract

Target: Retail `12.1.5`, interface `120105`.

Selected source: build `12.1.5.70783`, commit `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`.

The reviewed `12.1.5.70688 -> 12.1.5.70783` delta does not modify the selected nameplate, castbar, Settings, region, font, or curve implementation. Its only shared Unit API change relevant to the addon's security review marks `UNIT_COMBAT.amount` as secret. RothBlizzPlates does not register `UNIT_COMBAT` or consume that payload, so no runtime adapter changed.

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
  -> reset assignment generation and stale layout scale
  -> capture current global setup scale as a late-attach fallback
  -> cast module creates/reuses hidden owned layers
  -> OwnerByCastBar is installed before SetUnit

Blizzard ApplyFrameOptions(setupOptions)
  -> validate ordinary horizontalScale / verticalScale
  -> retain exact current native size scale
  -> active assignment: reapply owned presentation once

Blizzard SetUnit / NamePlateCastingBarMixin:GetEffectiveType
  -> secret-capable notInterruptible
  -> direct SetAlphaFromBoolean sinks

OnUnitSet
  -> activate prepared generation
  -> apply scaled plate, reversible fonts, and scaled cast art

OnUnitCleared / NAME_PLATE_UNIT_REMOVED fallback
  -> generation++
  -> discard pending apply work
  -> hide owned regions
  -> clear cast ownership
  -> restore native fonts now or after combat
```

`NAME_PLATE_UNIT_ADDED` remains a bounded fallback and unit-token map owner. Normal correctness no longer depends on event-handler ordering.

## Native size integration

Blizzard's `nameplateSize` setting selects a source-owned scale record. The driver writes its `horizontal` and `vertical` values into `NamePlateSetupOptions`, then passes that table to `NamePlateUnitFrameMixin:ApplyFrameOptions`.

RothBlizzPlates consumes only those ordinary setup values:

- plate width and X offset use `horizontalScale`;
- plate height and Y offset use `verticalScale`;
- cast-border width/X and height/Y use the same axes;
- custom font height follows `verticalScale`.

The addon never reads native region geometry to infer scale and never writes the CVar or native frame size. Missing, inaccessible, NaN, or implausible scale values leave the last valid assignment scale intact. A late-attach fallback uses the current selected-source `NamePlateSetupOptions` table once; the exact post-hook remains authoritative.

## Cast hook and current-state recovery

One `GetEffectiveType` hook is installed, selected by load order:

- if `NamePlateCastingBarMixin` already exists, hook its copied method directly;
- before Blizzard creates that mixin, hook the source method once so `CreateFromMixins` copies the wrapped function;
- never hook both owners in the same session.

A late attach or combat-deferred apply can miss the hook signal. In that case, `castBar:IsInterruptable()` supplies Blizzard's current ordinary-or-secret boolean. The addon routes it directly into two complementary `SetAlphaFromBoolean` calls. The result is never inspected or inverted in Lua. If the method is unavailable, the presentation fails closed to non-interruptible art.

## Font ownership and restoration

Before the first font mutation, the addon snapshots font file, height, flags, shadow offset, and shadow color. A later Blizzard refresh observed through `ApplyFrameOptions` replaces the baseline before the Roth style is reapplied.

The Roth font's configured medium-size height is multiplied by Blizzard's current vertical nameplate scale. Disable/release restores the current native baseline outside combat. Combat release queues one generation-tagged restore. Reassignment invalidates stale restore work. If the current presentation no longer matches the last Roth-applied presentation, cleanup treats it as a newer foreign-owner update and relinquishes ownership without overwriting it.

## Security boundary

- Object-security returns are gated before Lua type checks or comparisons.
- Secret interruptibility is never compared, negated, keyed, formatted, logged, stored, or deferred.
- `SetAlphaFromBoolean` is the only secret conditional presentation sink.
- Accessible unknown `notInterruptible`, including documented `nil`, fails closed.
- Scale fields are consumed only after table/value access gates and strict numeric bounds.
- `UNIT_COMBAT` payloads are outside the addon contract; the current source explicitly marks its `amount` field secret.
- No child-tree scans, color inference, raw unit-data reads, broad guessed hooks, or retry loops exist.

## Geometry boundary

Native health bars, cast bars, icons, text, and parent frames are never resized, moved, reparented, hidden, or assigned a replacement status-bar texture. Geometry calls target only addon-owned textures.

## Persistence compatibility

A missing schema is treated as legacy schema 0. Only finite non-negative whole numeric schemas `0..4` are migrated. Numeric schemas above 4 and malformed schema values remain untouched; Settings and presentation stay disabled, and diagnostics distinguish `newer` from `invalid`.

## Evidence ceiling

Offline tests prove the mocked lifecycle, persistence, hook-owner, current-state, restoration, and native-size integration policies. The `70783` source review proves only that the selected source contracts did not change; it does not prove visual alignment, current-client taint behavior, restricted encounter behavior, or live performance.
