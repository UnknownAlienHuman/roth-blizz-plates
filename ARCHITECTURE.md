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

The reviewed `12.1.5.70688 -> 12.1.5.70783` delta does not modify the selected nameplate, castbar, Settings, region, font, or curve implementation. Its only shared Unit API change relevant to this addon marks `UNIT_COMBAT.amount` as secret. RothBlizzPlates does not register that event or consume its payload.

Canonical source paths:

- `NamePlateBaseMixin:AcquireUnitFrame`
- `NamePlateUnitFrameMixin:ApplyFrameOptions`
- `NamePlateUnitFrameMixin:OnUnitSet`
- `NamePlateUnitFrameMixin:OnUnitCleared`
- `unitFrame.HealthBarsContainer.healthBar`
- `unitFrame.CastBarsContainer.castBar`
- `NamePlateCastingBarMixin:GetEffectiveType(..., notInterruptible, ...)`
- `CastingBarMixin:IsInterruptable()`
- `SimpleFontString:GetFontObject()` / `SetFontObject()`

`NamePlateCastingBarMixin` is created with `CreateFromMixins(CastingBarMixin, NamePlateComponentMixin)`, so it is treated as the exact hook owner after creation. The addon does not assume that a secure hook attached to the source table propagates through a copied mixin.

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

The module installs one hook only on the exact `NamePlateCastingBarMixin:GetEffectiveType` owner:

- if the mixin already exists, install immediately;
- otherwise wait for `Blizzard_NamePlates` through `EventUtil.ContinueOnAddOnLoaded`;
- retry once at `PLAYER_ENTERING_WORLD` as a bounded fallback;
- never hook generic `CastingBarMixin`.

This avoids relying on undocumented `hooksecurefunc` propagation through `CreateFromMixins`. A late attach or combat-deferred apply can miss an earlier signal; `castBar:IsInterruptable()` then supplies Blizzard's current ordinary-or-secret boolean. The addon routes it directly into two complementary `SetAlphaFromBoolean` calls. The result is never inspected or inverted in Lua. If the method is unavailable, presentation fails closed to non-interruptible art.

Core runtime compatibility is authoritative. Unsupported interface or SavedVariables contracts prevent cast hook installation, preparation, and apply even if the internal cast module is called directly.

## Font ownership and restoration

Before the first font mutation, the addon snapshots:

- effective font asset, height, and flags;
- the actual Blizzard `FontObject`, when present;
- readable shadow offset and color.

A later Blizzard refresh observed through `ApplyFrameOptions` replaces that baseline before Roth styling is reapplied. Cleanup prefers `SetFontObject(original)` so the native inheritance relationship and future global font updates are restored, not merely a copied file/height/flags snapshot. A direct-font baseline falls back to `SetFont`.

The addon changes shadow offset/color only when the matching native value was readable and therefore reversible. Unreadable presentation fails closed without mutation. The Roth font's configured medium-size height is multiplied by Blizzard's current vertical nameplate scale.

Disable/release restores the current native baseline outside combat. Combat release queues one generation-tagged restore. Reassignment invalidates stale restore work. If the current presentation no longer matches the last Roth-applied presentation, cleanup treats it as a newer foreign-owner update and relinquishes ownership without overwriting it.

## Security boundary

- Object-security returns are gated before Lua type checks or comparisons.
- Secret interruptibility is never compared, negated, keyed, formatted, logged, stored, or deferred.
- `SetAlphaFromBoolean` is the only secret conditional presentation sink.
- Accessible unknown `notInterruptible`, including documented `nil`, fails closed.
- Scale fields and bounded plate tables are consumed only after table/value access gates.
- `UNIT_COMBAT` payloads are outside the addon contract; current source marks its `amount` field secret.
- No child-tree scans, color inference, raw unit-data reads, broad guessed hooks, or retry loops exist.

## Geometry boundary

Native health bars, cast bars, icons, text, and parent frames are never resized, moved, reparented, hidden, or assigned a replacement status-bar texture. Geometry calls target only addon-owned textures.

## Persistence compatibility

A missing schema is treated as legacy schema 0. Only finite non-negative whole numeric schemas `0..4` are migrated. Numeric schemas above 4 and malformed schema values remain untouched; Settings and presentation stay disabled, and diagnostics distinguish `newer` from `invalid`.

## Evidence ceiling

Offline tests prove the mocked lifecycle, persistence, exact hook owner, current-state recovery, runtime gate, FontObject restoration, foreign-owner coexistence, and native-size integration policies. The `70783` source review proves only that selected source contracts did not change; it does not prove visual alignment, current-client taint behavior, restricted encounter behavior, or live performance.
