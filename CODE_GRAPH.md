# Code graph

```text
NAME_PLATE_UNIT_ADDED(unit)
  -> C_NamePlate.GetNamePlateForUnit(unit)
  -> ActivateFrame(unitFrame)
  -> RequestApply(unitFrame)
  -> ApplyFrame(unitFrame, generation)
     -> ConfigurePlate(owned texture)
     -> ApplyFonts()
     -> CastBar.Apply(unitFrame)
        -> CastBarsContainer.castBar
        -> EnsureState(two owned textures)
        -> conservative initial border

CastingBarMixin:GetEffectiveType(..., notInterruptible, ...)
  -> UpdateFromNotInterruptible()
  -> SetAlphaFromBoolean()

NAME_PLATE_UNIT_REMOVED(unit) / OnUnitCleared(unitFrame)
  -> ReleaseFrame(unitFrame)
     -> generation++
     -> drop pending work
     -> hide owned plate
     -> CastBar.Release(unitFrame)

combat acquisition / layout callback
  -> PendingByFrame[unitFrame] = generation
PLAYER_REGEN_ENABLED
  -> one bounded flush
  -> stale generations discarded
```
