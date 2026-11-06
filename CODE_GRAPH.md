# Code graph

```text
NamePlateBaseMixin:AcquireUnitFrame
  -> core.PrepareAssignment(unitFrame)
     -> generation++
     -> cast.Prepare(unitFrame)
        -> CastBarsContainer.castBar
        -> create/reuse two hidden owned textures
        -> OwnerByCastBar[castBar] = unitFrame

NamePlateCastingBarMixin:GetEffectiveType(..., notInterruptible, ...)
  -> cast.UpdateFromNotInterruptible
  -> Texture:SetAlphaFromBoolean (two complementary layers)

Hook owner selection
  -> exact NamePlateCastingBarMixin if already created
  -> otherwise source CastingBarMixin before CreateFromMixins copies it
  -> exactly one installed hook

NamePlateUnitFrameMixin:OnUnitSet
  -> core.ActivatePreparedFrame
  -> core.ApplyFrame
     -> owned plate texture on HealthBarsContainer.healthBar
     -> snapshot/apply native FontStrings
     -> cast.Apply

ApplyFrameOptions / explicit refresh
  -> detect Blizzard font refresh
  -> idempotent RequestApply

OnUnitCleared / removal fallback
  -> ReleaseFrame
  -> invalidate generation
  -> hide owned regions
  -> clear cast owner
  -> restore fonts now or queue generation-tagged restore

PLAYER_REGEN_ENABLED
  -> bounded apply flush
  -> bounded font-restore flush
  -> stale generations discarded
```
