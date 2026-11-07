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
  if region == nil or not IsAccessible(region) then
    return false
  end

  if type(region.CanBeAccessedInContext) == "function" then
    local canAccess = region:CanBeAccessedInContext()
    if not IsAccessible(canAccess) or type(canAccess) ~= "boolean" or canAccess ~= true then
      return false
    end
  end

  if type(region.IsForbidden) == "function" then
    local forbidden = region:IsForbidden()
    if not IsAccessible(forbidden) or type(forbidden) ~= "boolean" or forbidden ~= false then
      return false
    end
  end

  return true
end

local function IsRuntimeSupported()
  local core = _G.RothBlizzPlates
  if core == nil then
    -- Standalone regression harnesses load this module without core.lua.
    return true
  end
  if type(core.IsRuntimeSupported) ~= "function" then
    return false
  end
  return core.IsRuntimeSupported() == true
end

local function NormalizeLayoutScale(value)
  if not IsAccessible(value) or type(value) ~= "number"
    or value ~= value or value < 0.25 or value > 4 then
    return 1
  end
  return value
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
  texture:Hide()
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
    prepared = false,
    alphaOn = 255,
  }
  StateByFrame[unitFrame] = state
  OwnerByCastBar[castBar] = unitFrame
  return state
end

local function NormalizeNotInterruptible(value)
  -- UnitCastingInfo documents this result as nilable. Only inspect ordinary
  -- values; secret booleans pass through untouched to the native sink.
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
  notInterruptible = NormalizeNotInterruptible(notInterruptible)
  local alphaOn = state.alphaOn or 255
  state.notInterruptible:SetAlphaFromBoolean(notInterruptible, alphaOn, 0)
  state.interruptible:SetAlphaFromBoolean(notInterruptible, 0, alphaOn)
end

local function ApplyInterruptibleSignal(state, isInterruptible)
  -- IsInterruptable returns an ordinary or secret boolean. Route it directly
  -- into complementary native sinks without inspecting or inverting it in Lua.
  local alphaOn = state.alphaOn or 255
  state.interruptible:SetAlphaFromBoolean(isInterruptible, alphaOn, 0)
  state.notInterruptible:SetAlphaFromBoolean(isInterruptible, 0, alphaOn)
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

local function Prepare(unitFrame)
  if not IsRuntimeSupported() or not IsUsableRegion(unitFrame) or InCombatLockdown() then
    return false
  end

  local db = _G.RothBlizzPlatesDB
  if type(db) ~= "table" or not db.enabled
    or type(db.castBar) ~= "table" or not db.castBar.enabled
    or type(db.castBorder) ~= "table" then
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
  if state.prepared then
    OwnerByCastBar[castBar] = unitFrame
    return true
  end

  HideState(state)
  state.alphaOn = math.floor((db.castBorder.alpha * 255) + 0.5)
  state.needsInitialSignal = true
  state.prepared = true
  OwnerByCastBar[castBar] = unitFrame
  return true
end

local function Apply(unitFrame, scaleX, scaleY)
  if not IsRuntimeSupported() or not IsUsableRegion(unitFrame) then
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
      existing.prepared = false
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
  scaleX = NormalizeLayoutScale(scaleX)
  scaleY = NormalizeLayoutScale(scaleY)
  state.alphaOn = math.floor((border.alpha * 255) + 0.5)

  ConfigureTexture(
    state.interruptible,
    CAST_INTERRUPTIBLE,
    castBar,
    border.width * scaleX,
    border.height * scaleY,
    border.offsetX * scaleX,
    border.offsetY * scaleY
  )
  ConfigureTexture(
    state.notInterruptible,
    CAST_NOT_INTERRUPTIBLE,
    castBar,
    border.width * scaleX,
    border.height * scaleY,
    border.offsetX * scaleX,
    border.offsetY * scaleY
  )

  -- A signal captured between AcquireUnitFrame and OnUnitSet is preserved.
  -- If no hook signal arrived (late load or combat deferral), ask Blizzard for
  -- the current possibly-secret interruptible boolean and route it directly
  -- into the native sinks. Method absence alone falls back conservatively.
  if state.needsInitialSignal then
    if type(castBar.IsInterruptable) == "function" then
      ApplyInterruptibleSignal(state, castBar:IsInterruptable())
    else
      ApplyNotInterruptibleSignal(state, true)
    end
    state.needsInitialSignal = false
  end
  state.prepared = false
  return true
end

local function Release(unitFrame)
  if unitFrame == nil or not IsAccessible(unitFrame) then
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
  state.prepared = false
end

local function ResolveHookOwner()
  if type(NamePlateCastingBarMixin) == "table"
    and type(NamePlateCastingBarMixin.GetEffectiveType) == "function" then
    return NamePlateCastingBarMixin
  end
  return nil
end

local function InstallHooks()
  if HooksInstalled or not IsRuntimeSupported() or type(hooksecurefunc) ~= "function" then
    return false
  end

  local hookOwner = ResolveHookOwner()
  if not hookOwner then
    return false
  end

  hooksecurefunc(hookOwner, "GetEffectiveType", function(castBar, _, notInterruptible)
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
  Prepare = Prepare,
  Apply = Apply,
  Release = Release,
  InstallHooks = InstallHooks,
}
