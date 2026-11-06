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
     -> fonts
     -> cast.Apply

ApplyFrameOptions / explicit refresh
  -> idempotent RequestApply

OnUnitCleared / removal fallback
  -> ReleaseFrame
  -> invalidate generation
  -> hide owned regions
  -> clear cast owner

PLAYER_REGEN_ENABLED
  -> one bounded generation-checked flush
```
