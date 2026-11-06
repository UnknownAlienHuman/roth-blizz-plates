-- RothBlizzPlates castbar presentation for Retail 12.1.5.
-- Blizzard owns cast state, progress, geometry, icon, text, and visibility.
-- This module adds only two addon-owned border textures.

local ADDON_NAME = ...
local MEDIA_PATH = ("Interface\\AddOns\\%s\\media\\"):format(ADDON_NAME)
local CAST_INTERRUPTIBLE = MEDIA_PATH .. "CastStop"
local CAST_NOT_INTERRUPTIBLE = MEDIA_PATH .. "CastNoStop"

local StateByFrame = setmetatable({}, { __mode = "k" })
local OwnerByCastBar = setmetatable({}, { __mode = "k" })
local HooksInstalled = false

local function IsAccessible(value)
  if type(canaccessvalue) == "function" then
    return canaccessvalue(value)
  end
  if type(issecretvalue) == "function" then
    return not issecretvalue(value)
  end
  return true
end

local function IsUsableRegion(region)
  if not IsAccessible(region) or region == nil then
    return false
  end
  if type(region.CanBeAccessedInContext) == "function" and not region:CanBeAccessedInContext() then
    return false
  end
  if type(region.IsForbidden) == "function" and region:IsForbidden() then
    return false
  end
  return true
end

local function GetCastBar(unitFrame)
  if not IsUsableRegion(unitFrame) then
    return nil
  end

  local container = unitFrame.CastBarsContainer
  if not IsUsableRegion(container) then
    return nil
  end

  local castBar = container.castBar
  if not IsUsableRegion(castBar) then
    return nil
  end

  return castBar
end

local function HideState(state)
  if not state then
    return
  end
  if IsUsableRegion(state.interruptible) then
    state.interruptible:Hide()
  end
  if IsUsableRegion(state.notInterruptible) then
    state.notInterruptible:Hide()
  end
end

local function ConfigureTexture(texture, texturePath, castBar, width, height, offsetX, offsetY)
  texture:SetTexture(texturePath)
  texture:SetDrawLayer("OVERLAY", 5)
  texture:ClearAllPoints()
  texture:SetPoint("CENTER", castBar, "CENTER", offsetX, offsetY)
  texture:SetSize(width, height)
  texture:Show()
end

local function CreateBorderTexture(castBar)
  if type(castBar.CreateTexture) ~= "function" then
    return nil
  end
  local texture = castBar:CreateTexture(nil, "OVERLAY", nil, 5)
  if not IsUsableRegion(texture) then
    return nil
  end
  return texture
end

local function EnsureState(unitFrame, castBar)
  local state = StateByFrame[unitFrame]
  if state and state.castBar == castBar
    and IsUsableRegion(state.interruptible)
    and IsUsableRegion(state.notInterruptible) then
    OwnerByCastBar[castBar] = unitFrame
    return state
  end

  if state then
    HideState(state)
    if state.castBar then
      OwnerByCastBar[state.castBar] = nil
    end
  end

  local interruptible = CreateBorderTexture(castBar)
  local blockedTexture = CreateBorderTexture(castBar)
  if not interruptible or not blockedTexture then
    if interruptible then
      interruptible:Hide()
    end
    if blockedTexture then
      blockedTexture:Hide()
    end
    return nil
  end

  if type(interruptible.SetAlphaFromBoolean) ~= "function"
    or type(blockedTexture.SetAlphaFromBoolean) ~= "function" then
    interruptible:Hide()
    blockedTexture:Hide()
    return nil
  end

  interruptible:SetVertexColor(1, 1, 1)
  blockedTexture:SetVertexColor(1, 1, 1)

  state = {
    castBar = castBar,
    interruptible = interruptible,
    notInterruptible = blockedTexture,
    needsInitialSignal = true,
  }
  StateByFrame[unitFrame] = state
  OwnerByCastBar[castBar] = unitFrame
  return state
end

local function NormalizeNotInterruptible(value)
  -- UnitCastingInfo documents this result as nilable. Only inspect values that
  -- can be accessed normally; secret booleans pass through untouched.
  if IsAccessible(value) then
    if type(value) == "boolean" then
      return value
    end
    return true
  end
  return value
end

local function ApplyNotInterruptibleSignal(state, notInterruptible)
  -- Do not inspect, compare, negate, stringify, store, or log a secret value.
  -- Both addon-owned textures consume it through the native boolean sink.
  notInterruptible = NormalizeNotInterruptible(notInterruptible)
  local alphaOn = state.alphaOn or 255
  state.notInterruptible:SetAlphaFromBoolean(notInterruptible, alphaOn, 0)
  state.interruptible:SetAlphaFromBoolean(notInterruptible, 0, alphaOn)
end

local function UpdateFromNotInterruptible(castBar, notInterruptible)
  local unitFrame = OwnerByCastBar[castBar]
  local state = unitFrame and StateByFrame[unitFrame] or nil
  if not state or state.castBar ~= castBar then
    return
  end

  ApplyNotInterruptibleSignal(state, notInterruptible)
  state.needsInitialSignal = false
end

local function Apply(unitFrame)
  if not IsUsableRegion(unitFrame) then
    return false
  end

  local db = _G.RothBlizzPlatesDB
  if type(db) ~= "table" or not db.enabled or type(db.castBar) ~= "table" then
    return false
  end

  local existing = StateByFrame[unitFrame]
  if not db.castBar.enabled then
    HideState(existing)
    if existing and existing.castBar then
      OwnerByCastBar[existing.castBar] = nil
      existing.needsInitialSignal = true
    end
    return true
  end

  if InCombatLockdown() then
    local core = _G.RothBlizzPlates
    if core and type(core.RequestApply) == "function" then
      core.RequestApply(unitFrame)
    end
    return false
  end

  local castBar = GetCastBar(unitFrame)
  if not castBar then
    return false
  end

  local state = EnsureState(unitFrame, castBar)
  if not state then
    return false
  end

  local border = db.castBorder
  ConfigureTexture(
    state.interruptible,
    CAST_INTERRUPTIBLE,
    castBar,
    border.width,
    border.height,
    border.offsetX,
    border.offsetY
  )
  ConfigureTexture(
    state.notInterruptible,
    CAST_NOT_INTERRUPTIBLE,
    castBar,
    border.width,
    border.height,
    border.offsetX,
    border.offsetY
  )

  state.alphaOn = math.floor((border.alpha * 255) + 0.5)

  -- Conservative state only for a new/recycled assignment. Reconfiguration
  -- never overwrites an existing secret alpha decision.
  if state.needsInitialSignal then
    ApplyNotInterruptibleSignal(state, true)
    state.needsInitialSignal = false
  end
  return true
end

local function Release(unitFrame)
  if not IsAccessible(unitFrame) then
    return
  end
  local state = StateByFrame[unitFrame]
  if not state then
    return
  end

  HideState(state)
  if state.castBar then
    OwnerByCastBar[state.castBar] = nil
  end
  state.needsInitialSignal = true
end

local function InstallHooks()
  if HooksInstalled or type(hooksecurefunc) ~= "function" or type(CastingBarMixin) ~= "table" then
    return false
  end
  if type(CastingBarMixin.GetEffectiveType) ~= "function" then
    return false
  end

  -- GetEffectiveType receives the exact notInterruptible argument for both cast
  -- start and later interruptibility transitions. The hook forwards it without
  -- inspecting it.
  hooksecurefunc(CastingBarMixin, "GetEffectiveType", function(castBar, _, notInterruptible)
    if OwnerByCastBar[castBar] then
      UpdateFromNotInterruptible(castBar, notInterruptible)
    end
  end)

  HooksInstalled = true
  return true
end

InstallHooks()
if not HooksInstalled and EventUtil and type(EventUtil.ContinueOnAddOnLoaded) == "function" then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", InstallHooks)
end

_G.RothBlizzPlates_CastBar = {
  Apply = Apply,
  Release = Release,
  InstallHooks = InstallHooks,
}
