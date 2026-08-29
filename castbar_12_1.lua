-- RothBlizzPlates castbar compatibility owner for Retail 12.1.
-- Blizzard owns cast state and progress. This module changes presentation only,
-- never creates or reanchors regions during combat, and does not scan frame trees.

local ADDON_NAME = ...
local MEDIA_PATH = ("Interface\\AddOns\\%s\\media\\"):format(ADDON_NAME)
local CAST_FILL = MEDIA_PATH .. "CastFill"
local CAST_STOP = MEDIA_PATH .. "CastStop"
local CAST_NOSTOP = MEDIA_PATH .. "CastNoStop"

local Pending = setmetatable({}, { __mode = "k" })
local HookedFunctions = {}
local Apply

local function CanAccess(value)
  if type(canaccessvalue) == "function" then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret ~= true
  end
  return true
end

local function IsBoolean(value)
  return CanAccess(value) and type(value) == "boolean"
end

local function IsNumber(value)
  return CanAccess(value) and type(value) == "number"
end

local function IsString(value)
  return CanAccess(value) and type(value) == "string"
end

local function CanUse(object)
  if not object then return false end

  if type(object.CanBeAccessedInContext) == "function" then
    local ok, accessible = pcall(object.CanBeAccessedInContext, object)
    if not ok or not IsBoolean(accessible) or not accessible then return false end
  end

  if type(object.IsForbidden) == "function" then
    local ok, forbidden = pcall(object.IsForbidden, object)
    if not ok or not IsBoolean(forbidden) or forbidden then return false end
  end

  return true
end

local function Call(object, methodName, ...)
  if not CanUse(object) then return false end
  local method = object[methodName]
  if type(method) ~= "function" then return false end
  return pcall(method, object, ...)
end

local function Get(object, methodName, ...)
  if not CanUse(object) then return nil end
  local method = object[methodName]
  if type(method) ~= "function" then return nil end
  local ok, value = pcall(method, object, ...)
  if ok then return value end
  return nil
end

local function Get4(object, methodName, ...)
  if not CanUse(object) then return nil end
  local method = object[methodName]
  if type(method) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(method, object, ...)
  if ok then return a, b, c, d end
  return nil
end

local function IsStatusBar(object)
  if not CanUse(object) then return false end
  local objectType = Get(object, "GetObjectType")
  if IsString(objectType) and objectType == "StatusBar" then return true end
  return type(object.SetStatusBarTexture) == "function"
    and type(object.SetMinMaxValues) == "function"
    and type(object.SetValue) == "function"
end

local function FindContainer(unitFrame)
  if not CanUse(unitFrame) then return nil end

  local cached = unitFrame.__RothCastContainer
  if CanUse(cached) then return cached end

  local candidates = {
    unitFrame.castBar,
    unitFrame.CastBar,
    unitFrame.CastingBar,
    unitFrame.castingBar,
    unitFrame.CastBarFrame,
    unitFrame.CastBarContainer,
  }

  for _, candidate in ipairs(candidates) do
    if CanUse(candidate) then
      unitFrame.__RothCastContainer = candidate
      return candidate
    end
  end
  return nil
end

local function FindStatusBar(container)
  if IsStatusBar(container) then return container end

  local candidates = {
    container and container.Bar,
    container and container.bar,
    container and container.StatusBar,
    container and container.statusBar,
    container and container.ProgressBar,
    container and container.progressBar,
  }
  for _, candidate in ipairs(candidates) do
    if IsStatusBar(candidate) then return candidate end
  end
  return nil
end

local function FindIcon(container, statusBar)
  local candidates = {
    container and container.Icon,
    container and container.icon,
    container and container.IconTexture,
    container and container.iconTexture,
    statusBar and statusBar.Icon,
    statusBar and statusBar.icon,
  }
  for _, icon in ipairs(candidates) do
    if CanUse(icon) and type(icon.SetTexture) == "function" then return icon end
  end
  return nil
end

local function Snapshot(region)
  if not CanUse(region) or region.__RothCastOriginal then return end

  local width = Get(region, "GetWidth")
  local height = Get(region, "GetHeight")
  local ok, point, relativeTo, relativePoint, x, y = pcall(region.GetPoint, region, 1)
  if not ok or not IsString(point) or not IsString(relativePoint)
    or not IsNumber(x) or not IsNumber(y) then
    return
  end

  region.__RothCastOriginal = {
    width = IsNumber(width) and width or nil,
    height = IsNumber(height) and height or nil,
    point = point,
    relativeTo = relativeTo,
    relativePoint = relativePoint,
    x = x,
    y = y,
  }
end

local function Restore(region)
  if not CanUse(region) then return end
  local state = region.__RothCastOriginal
  if type(state) ~= "table" then return end

  Call(region, "ClearAllPoints")
  Call(region, "SetPoint", state.point, state.relativeTo, state.relativePoint, state.x, state.y)
  if IsNumber(state.width) and IsNumber(state.height) then
    Call(region, "SetSize", state.width, state.height)
  end
  region.__RothCastOriginal = nil
end

local function SetGeometry(region, parent, width, height, x, y)
  if not CanUse(region) or not CanUse(parent) then return false end
  if not IsNumber(width) or not IsNumber(height) or not IsNumber(x) or not IsNumber(y) then
    return false
  end

  Snapshot(region)
  if not Call(region, "ClearAllPoints") then return false end
  if not Call(region, "SetPoint", "CENTER", parent, "CENTER", x, y) then return false end
  return Call(region, "SetSize", width, height)
end

local function ExplicitNotInterruptible(object)
  if not object then return nil end
  if IsBoolean(object.notInterruptible) then return object.notInterruptible end
  if IsBoolean(object.interruptible) then return not object.interruptible end
  if IsBoolean(object.isInterruptible) then return not object.isInterruptible end
  return nil
end

local function ResolveNotInterruptible(container, statusBar)
  local result = ExplicitNotInterruptible(container)
  if result == nil then result = ExplicitNotInterruptible(statusBar) end
  if result ~= nil then return result end

  local texture = Get(statusBar, "GetStatusBarTexture")
  local r, g, b = Get4(texture, "GetVertexColor")
  if not (IsNumber(r) and IsNumber(g) and IsNumber(b)) then
    r, g, b = Get4(statusBar, "GetStatusBarColor")
  end

  if IsNumber(r) and IsNumber(g) and IsNumber(b) then
    if r > 0.92 or g > 0.92 or b > 0.92 then return false end
    if math.abs(r - g) < 0.06 and math.abs(g - b) < 0.06 then return true end
    return false
  end

  -- Unknown state must not be advertised as safely interruptible.
  return true
end

local function RestorePresentation(unitFrame)
  if InCombatLockdown() then Pending[unitFrame] = true return false end

  local container = FindContainer(unitFrame)
  local statusBar = container and FindStatusBar(container)
  if not container or not statusBar then return false end

  local texture = Get(statusBar, "GetStatusBarTexture")
  if CanUse(texture) and texture.__RothCastTextureCaptured then
    Call(texture, "SetTexture", texture.__RothCastTexture)
    texture.__RothCastTexture = nil
    texture.__RothCastTextureCaptured = nil
  end

  Restore(container)
  if statusBar ~= container then Restore(statusBar) end
  Restore(FindIcon(container, statusBar))

  local border = container.__RothCastBorder
  if CanUse(border) then Call(border, "Hide") end
  Pending[unitFrame] = nil
  return true
end

Apply = function(unitFrame, scaleX, scaleY)
  if InCombatLockdown() then Pending[unitFrame] = true return false end
  if not CanUse(unitFrame) then return false end

  local db = RothBlizzPlatesDB
  if type(db) ~= "table" or type(db.castBar) ~= "table" then return false end
  if not db.castBar.enabled then return RestorePresentation(unitFrame) end

  local container = FindContainer(unitFrame)
  local statusBar = container and FindStatusBar(container)
  if not container or not statusBar then return false end

  scaleX = IsNumber(scaleX) and scaleX or unitFrame.__RothScaleX or 1
  scaleY = IsNumber(scaleY) and scaleY or unitFrame.__RothScaleY or 1
  if not IsNumber(scaleX) or scaleX < 0.2 or scaleX > 5 then scaleX = 1 end
  if not IsNumber(scaleY) or scaleY < 0.2 or scaleY > 5 then scaleY = 1 end

  local width = db.castBar.width * scaleX
  local height = db.castBar.height * scaleY
  if not SetGeometry(container, unitFrame, width, height, db.castBar.x * scaleX, db.castBar.y * scaleY) then
    Pending[unitFrame] = true
    return false
  end

  if statusBar ~= container then
    Snapshot(statusBar)
    Call(statusBar, "ClearAllPoints")
    Call(statusBar, "SetAllPoints", container)
  end

  local texture = Get(statusBar, "GetStatusBarTexture")
  if CanUse(texture) then
    if not texture.__RothCastTextureCaptured then
      local original = Get(texture, "GetTexture")
      if CanAccess(original) then
        texture.__RothCastTexture = original
        texture.__RothCastTextureCaptured = true
      end
    end
    Call(texture, "SetTexture", CAST_FILL)
  else
    Call(statusBar, "SetStatusBarTexture", CAST_FILL)
  end

  local border = container.__RothCastBorder
  if not CanUse(border) then
    local ok, created = pcall(container.CreateTexture, container, nil, "OVERLAY", nil, 3)
    if ok and CanUse(created) then
      border = created
      container.__RothCastBorder = border
    end
  end

  if CanUse(border) then
    local borderWidth = db.castBorder.width * scaleX
    local borderHeight = db.castBorder.height * scaleY
    local notInterruptible = ResolveNotInterruptible(container, statusBar)
    Call(border, "SetTexture", notInterruptible and CAST_NOSTOP or CAST_STOP)
    Call(border, "SetDrawLayer", "OVERLAY", 3)
    SetGeometry(
      border,
      container,
      borderWidth,
      borderHeight,
      (db.castBorder.x - db.castBar.x) * scaleX,
      (db.castBorder.y - db.castBar.y) * scaleY
    )
    Call(border, "Show")

    local icon = FindIcon(container, statusBar)
    if CanUse(icon) then
      local iconSize = math.max(6, math.min(borderHeight * 0.29, borderWidth * 0.18))
      SetGeometry(
        icon,
        border,
        iconSize,
        iconSize,
        (0.875 - 0.5) * borderWidth,
        (0.455 - 0.5) * borderHeight + 1
      )
      Call(icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93)
      Call(icon, "SetAlpha", 1)
      Call(icon, "Show")
    end
  end

  container.__RothOwnerUF = unitFrame
  Pending[unitFrame] = nil
  return true
end

local function RequestApply(unitFrame, scaleX, scaleY)
  if InCombatLockdown() then Pending[unitFrame] = true return false end
  local ok, result = pcall(Apply, unitFrame, scaleX, scaleY)
  if not ok then Pending[unitFrame] = true return false end
  return result
end

local function ResolveUnitFrame(candidate)
  if not CanUse(candidate) then return nil end
  if CanUse(candidate.__RothOwnerUF) then return candidate.__RothOwnerUF end
  local unitFrame = candidate.UnitFrame or candidate.unitFrame
  if CanUse(unitFrame) then return unitFrame end
  if candidate.castBar or candidate.CastBar or candidate.CastingBar or candidate.healthBar or candidate.HealthBar then
    return candidate
  end
  return nil
end

local function HookFunction(functionName)
  if HookedFunctions[functionName] or not hooksecurefunc or type(_G[functionName]) ~= "function" then
    return false
  end
  hooksecurefunc(functionName, function(firstArgument)
    local unitFrame = ResolveUnitFrame(firstArgument)
    if unitFrame then RequestApply(unitFrame) end
  end)
  HookedFunctions[functionName] = true
  return true
end

local function InstallHooks()
  local installed = false
  for _, name in ipairs({
    "CompactUnitFrame_UpdateCastBar",
    "DefaultCompactNamePlateFrame_UpdateCastBar",
    "CompactNamePlateFrame_UpdateCastBar",
    "NamePlate_UpdateCastBar",
  }) do
    if HookFunction(name) then installed = true end
  end

  if CastingBarMixin and hooksecurefunc and not CastingBarMixin.__RothBlizzPlatesHooked then
    CastingBarMixin.__RothBlizzPlatesHooked = true
    for _, methodName in ipairs({ "OnShow", "UpdateInterruptibleState", "UpdateIconShown" }) do
      if type(CastingBarMixin[methodName]) == "function" then
        hooksecurefunc(CastingBarMixin, methodName, function(self)
          local unitFrame = ResolveUnitFrame(self)
          if unitFrame then RequestApply(unitFrame) end
        end)
        installed = true
      end
    end
  end
  return installed
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:SetScript("OnEvent", function()
  for unitFrame in pairs(Pending) do RequestApply(unitFrame) end
end)

if not InstallHooks() and EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", InstallHooks)
end

SLASH_RBPCAST1 = "/rbpcast"
SlashCmdList.RBPCAST = function(message)
  message = IsString(message) and message:lower() or ""
  if message == "status" or message == "dump" then
    local count = 0
    for _ in pairs(Pending) do count = count + 1 end
    print("RothBlizzPlates castbar pending:", count)
  else
    print("RBP castbar: /rbpcast status")
  end
end

_G.RothBlizzPlates_CastBar = _G.RothBlizzPlates_CastBar or {}
_G.RothBlizzPlates_CastBar.Apply = RequestApply
_G.RothBlizzPlates_CastBar.GetPendingCount = function()
  local count = 0
  for _ in pairs(Pending) do count = count + 1 end
  return count
end
