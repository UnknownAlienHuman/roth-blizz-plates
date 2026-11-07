# Code graph

```text
NamePlateBaseMixin:AcquireUnitFrame
  -> core.PrepareAssignment(unitFrame)
     -> generation++
     -> cast.Prepare(unitFrame)
        -> core compatibility gate
        -> CastBarsContainer.castBar
        -> create/reuse two hidden owned textures
        -> OwnerByCastBar[castBar] = unitFrame

Blizzard_NamePlates loaded
  -> cast.InstallHooks()
  -> exact NamePlateCastingBarMixin:GetEffectiveType hook
  -> generic CastingBarMixin remains untouched

NamePlateCastingBarMixin:GetEffectiveType(..., notInterruptible, ...)
  -> cast.UpdateFromNotInterruptible
  -> complementary Texture:SetAlphaFromBoolean calls

Late attachment / missed hook signal
  -> castBar:IsInterruptable()
  -> direct complementary SetAlphaFromBoolean calls

NamePlateUnitFrameMixin:OnUnitSet
  -> core.ActivatePreparedFrame
  -> core.ApplyFrame
     -> owned plate texture on HealthBarsContainer.healthBar
     -> snapshot effective font + native FontObject + readable shadow
     -> cast.Apply(unitFrame, scaleX, scaleY)

ApplyFrameOptions / explicit refresh
  -> capture native horizontalScale / verticalScale
  -> observe refreshed Blizzard font baseline
  -> idempotent RequestApply

OnUnitCleared / removal fallback
  -> ReleaseFrame
  -> invalidate generation
  -> hide owned regions
  -> clear cast owner
  -> restore FontObject/effective presentation or queue generation-tagged restore

PLAYER_ENTERING_WORLD
  -> bounded exact cast-hook retry
  -> one coalesced visible refresh

PLAYER_REGEN_ENABLED
  -> bounded apply flush
  -> bounded font-restore flush
  -> stale generations discarded
```
