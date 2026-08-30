--[[
RothBlizzPlates (Retail 12.1)

Visual-only skin for Blizzard-owned nameplates.

Security boundary:
- no UnitName, UnitGUID, UnitHealth, aura, or combat-state derivation;
- no frame creation, size changes, anchor changes, or font mutations in combat;
- forbidden or inaccessible objects fail closed and are retried after combat;
- Blizzard remains the lifecycle and state owner.
--]]

local ADDON_NAME = ...

local MEDIA_PATH = ("Interface\\AddOns\\%s\\media\\"):format(ADDON_NAME)
local MEDIA = {
  FONT = MEDIA_PATH .. "Diablo-Light.ttf",
  STATUSBAR = MEDIA_PATH .. "StatusBar",
  PLATE_NORMAL = MEDIA_PATH .. "NormalPlate",
  THREAT = MEDIA_PATH .. "ThreatBar",
}

local NON_LATIN = {
  koKR = true,
  zhCN = true,
  zhTW = true,
}

local DEFAULTS = {
  enabled = true,
  plate = {
    width = 180,
    height = 60,
    x = 6,
    y = 4,
    anchor = "CENTER",
  },
  healthBar = {
    width = 108,
    height = 9,
    x = 6,
    y = 3.5,
  },
  castBar = {
    enabled = true,
    width = 67,
    height = 7.1,
    x = 1,
    y = -19,
  },
  castBorder = {
    width = 220,
    height = 66,
    x = 0,
    y = -28,
  },
  layout = {
    inheritScale = true,
  },
  name = {
    center = false,
    width = 160,
    x = 0,
    y = 18,
  },
  font = {
    useGlobal = false,
    size = 8,
    outline = "OUTLINE",
    shadow = true,
    inherit = true,
  },
}

local function MergeDefaults(target, defaults)
  if type(target) ~= "table" then
    target = {}
  end

  for key, defaultValue in pairs(defaults) do
    if type(defaultValue) == "table" then
      target[key] = MergeDefaults(target[key], defaultValue)
    elseif type(target[key]) ~= type(defaultValue) then
      target[key] = defaultValue
    end
  end

  return target
end

local function SanitizeNumber(value, fallback, minimum, maximum)
  if type(value) ~= "number" or value ~= value then
    return fallback
  end
  if value < minimum then
    return minimum
  end
  if value > maximum then
    return maximum
  end
  return value
end

RothBlizzPlatesDB = MergeDefaults(RothBlizzPlatesDB, DEFAULTS)
do
  local db = RothBlizzPlatesDB
  db.plate.width = SanitizeNumber(db.plate.width, 180, 20, 800)
  db.plate.height = SanitizeNumber(db.plate.height, 60, 8, 300)
  db.plate.x = SanitizeNumber(db.plate.x, 6, -500, 500)
  db.plate.y = SanitizeNumber(db.plate.y, 4, -500, 500)

  db.healthBar.width = SanitizeNumber(db.healthBar.width, 108, 10, 500)
  db.healthBar.height = SanitizeNumber(db.healthBar.height, 9, 1, 100)
  db.healthBar.x = SanitizeNumber(db.healthBar.x, 6, -500, 500)
  db.healthBar.y = SanitizeNumber(db.healthBar.y, 3.5, -500, 500)

  db.castBar.width = SanitizeNumber(db.castBar.width, 67, 10, 500)
  db.castBar.height = SanitizeNumber(db.castBar.height, 7.1, 1, 100)
  db.castBar.x = SanitizeNumber(db.castBar.x, 1, -500, 500)
  db.castBar.y = SanitizeNumber(db.castBar.y, -19, -500, 500)

  db.castBorder.width = SanitizeNumber(db.castBorder.width, 220, 10, 800)
  db.castBorder.height = SanitizeNumber(db.castBorder.height, 66, 4, 300)
  db.castBorder.x = SanitizeNumber(db.castBorder.x, 0, -500, 500)
  db.castBorder.y = SanitizeNumber(db.castBorder.y, -28, -500, 500)

  db.font.size = SanitizeNumber(db.font.size, 8, 4, 72)
  if type(db.font.outline) ~= "string" then
    db.font.outline = "OUTLINE"
  end
end

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

local function IsAccessibleBoolean(value)
  return CanAccess(value) and type(value) == "boolean"
end

local function IsAccessibleNumber(value)
  return CanAccess(value) and type(value) == "number"
end

local function IsAccessibleString(value)
  return CanAccess(value) and type(value) == "string"
end

local function CanUseObject(object)
  if not object then
    return false
  end

  if type(object.CanBeAccessedInContext) == "function" then
    local ok, accessible = pcall(object.CanBeAccessedInContext, object)
    if not ok or not IsAccessibleBoolean(accessible) or not accessible then
      return false
    end
  end

  if type(object.IsForbidden) == "function" then
    local ok, forbidden = pcall(object.IsForbidden, object)
    if not ok or not IsAccessibleBoolean(forbidden) or forbidden then
      return false
    end
  end

  return true
end

local function SafeCall(object, methodName, ...)
  if not CanUseObject(object) then
    return false
  end
  local method = object[methodName]
  if type(method) ~= "function" then
    return false
  end
  return pcall(method, object, ...)
end

local function SafeGet(object, methodName, ...)
  if not CanUseObject(object) then
    return nil
  end
  local method = object[methodName]
  if type(method) ~= "function" then
    return nil
  end
  local ok, value = pcall(method, object, ...)
  if ok then
    return value
  end
  return nil
end

local function GetThemeFont()
  local db = RothBlizzPlatesDB.font
  if db.useGlobal or NON_LATIN[GetLocale()] then
    return STANDARD_TEXT_FONT
  end
  return MEDIA.FONT
end

local function GetRegionSize(region)
  local width = SafeGet(region, "GetWidth")
  local height = SafeGet(region, "GetHeight")
  if IsAccessibleNumber(width) and IsAccessibleNumber(height) then
    return width, height
  end
  return nil, nil
end

local function NearlyEqual(a, b, epsilon)
  if not IsAccessibleNumber(a) or not IsAccessibleNumber(b) then
    return false
  end
  return math.abs(a - b) <= (epsilon or 0.05)
end

local function SetSizeIfNeeded(region, width, height)
  if not CanUseObject(region) or not IsAccessibleNumber(width) or not IsAccessibleNumber(height) then
    return false
  end

  local currentWidth, currentHeight = GetRegionSize(region)
  if NearlyEqual(currentWidth, width) and NearlyEqual(currentHeight, height) then
    return true
  end

  return SafeCall(region, "SetSize", width, height)
end

local function SetCenterPointIfNeeded(region, parent, x, y)
  if not CanUseObject(region) or not CanUseObject(parent) then
    return false
  end
  if not IsAccessibleNumber(x) or not IsAccessibleNumber(y) then
    return false
  end

  local point, relativeTo, relativePoint, offsetX, offsetY
  if type(region.GetPoint) == "function" then
    local ok
    ok, point, relativeTo, relativePoint, offsetX, offsetY = pcall(region.GetPoint, region, 1)
    if ok
      and point == "CENTER"
      and relativeTo == parent
      and relativePoint == "CENTER"
      and NearlyEqual(offsetX, x, 0.5)
      and NearlyEqual(offsetY, y, 0.5)
    then
      return true
    end
  end

  if not SafeCall(region, "ClearAllPoints") then
    return false
  end
  return SafeCall(region, "SetPoint", "CENTER", parent, "CENTER", x, y)
end

local function ApplyFont(fontString)
  if not CanUseObject(fontString) then
    return
  end

  local db = RothBlizzPlatesDB.font
  local size = db.size
  local flags = db.outline

  if db.inherit and type(fontString.GetFont) == "function" then
    local ok, _, currentSize, currentFlags = pcall(fontString.GetFont, fontString)
    if ok then
      if IsAccessibleNumber(currentSize) then
        size = currentSize
      end
      if IsAccessibleString(currentFlags) and currentFlags ~= "" then
        flags = currentFlags
      end
    end
  end

  SafeCall(fontString, "SetFont", GetThemeFont(), size, flags)
  if db.shadow then
    SafeCall(fontString, "SetShadowOffset", 1, -1)
    SafeCall(fontString, "SetShadowColor", 0, 0, 0, 1)
  else
    SafeCall(fontString, "SetShadowOffset", 0, 0)
  end
end

local PendingFrames = setmetatable({}, { __mode = "k" })

local function QueueFrame(unitFrame)
  if unitFrame then
    PendingFrames[unitFrame] = true
  end
end

local function DisableTargetHighlight(unitFrame)
  if not CanUseObject(unitFrame) then
    return
  end

  local selection = unitFrame.selectionHighlight or unitFrame.SelectionHighlight
  if CanUseObject(selection) then
    SafeCall(selection, "SetTexture", nil)
    SafeCall(selection, "SetAtlas", nil)
    SafeCall(selection, "SetAlpha", 0)
    SafeCall(selection, "Hide")
  end

  local legacy = unitFrame.__RothTarget
  if CanUseObject(legacy) then
    SafeCall(legacy, "SetAlpha", 0)
    SafeCall(legacy, "Hide")
  end
end

local function ResolveScale(unitFrame, healthBar)
  local scaleX, scaleY = 1, 1
  local db = RothBlizzPlatesDB

  if db.layout.inheritScale and CanUseObject(healthBar) then
    local width, height = GetRegionSize(healthBar)
    if IsAccessibleNumber(width) and db.healthBar.width > 0 then
      scaleX = width / db.healthBar.width
    end
    if IsAccessibleNumber(height) and db.healthBar.height > 0 then
      scaleY = height / db.healthBar.height
    end
  end

  if scaleX < 0.2 or scaleX > 5 then
    scaleX = unitFrame.__RothScaleX or 1
  end
  if scaleY < 0.2 or scaleY > 5 then
    scaleY = unitFrame.__RothScaleY or 1
  end

  unitFrame.__RothScaleX = scaleX
  unitFrame.__RothScaleY = scaleY
  return scaleX, scaleY
end

local function EnsurePlateTexture(unitFrame, parent)
  if not CanUseObject(parent) then
    return nil
  end

  local texture = unitFrame.__RothPlate
  if CanUseObject(texture) then
    local currentParent = SafeGet(texture, "GetParent")
    if currentParent ~= parent then
      SafeCall(texture, "Hide")
      texture = nil
      unitFrame.__RothPlate = nil
    end
  else
    texture = nil
  end

  if not texture then
    local ok, created = pcall(parent.CreateTexture, parent, nil, "OVERLAY", nil, 0)
    if not ok or not CanUseObject(created) then
      return nil
    end
    texture = created
    unitFrame.__RothPlate = texture
  end

  return texture
end

local function ApplyLayout(unitFrame)
  if InCombatLockdown() then
    QueueFrame(unitFrame)
    return false
  end
  if not CanUseObject(unitFrame) then
    return false
  end

  local db = RothBlizzPlatesDB
  local healthBar = unitFrame.healthBar or unitFrame.HealthBar
  if not CanUseObject(healthBar) then
    return false
  end

  local scaleX, scaleY = ResolveScale(unitFrame, healthBar)
  local healthX = db.healthBar.x * scaleX
  local healthY = db.healthBar.y * scaleY
  local healthWidth = db.healthBar.width * scaleX
  local healthHeight = db.healthBar.height * scaleY

  if not SetCenterPointIfNeeded(healthBar, unitFrame, healthX, healthY) then
    QueueFrame(unitFrame)
    return false
  end
  if not SetSizeIfNeeded(healthBar, healthWidth, healthHeight) then
    QueueFrame(unitFrame)
    return false
  end

  SafeCall(healthBar, "SetStatusBarTexture", MEDIA.STATUSBAR)

  local plate = EnsurePlateTexture(unitFrame, healthBar)
  if not plate then
    QueueFrame(unitFrame)
    return false
  end

  SafeCall(plate, "SetTexture", MEDIA.PLATE_NORMAL)
  SetSizeIfNeeded(plate, db.plate.width * scaleX, db.plate.height * scaleY)
  SetCenterPointIfNeeded(
    plate,
    healthBar,
    (db.plate.x - db.healthBar.x) * scaleX,
    (db.plate.y - db.healthBar.y) * scaleY
  )
  SafeCall(plate, "Show")

  DisableTargetHighlight(unitFrame)

  local threat = unitFrame.aggroGlow or unitFrame.AggroGlow or unitFrame.threatGlow
  if CanUseObject(threat) then
    SafeCall(threat, "SetTexture", MEDIA.THREAT)
  end

  local castModule = _G.RothBlizzPlates_CastBar
  if castModule and type(castModule.Apply) == "function" then
    pcall(castModule.Apply, unitFrame, scaleX, scaleY)
  end

  ApplyFont(unitFrame.name or unitFrame.Name)
  ApplyFont(unitFrame.level or unitFrame.Level)
  ApplyFont(unitFrame.healthText or unitFrame.HealthText)

  local castBar = unitFrame.castBar or unitFrame.CastBar or unitFrame.CastingBar
  if castBar then
    ApplyFont(castBar.Text or castBar.text)
  end

  unitFrame.__RothBlizzPlatesStyled = true
  PendingFrames[unitFrame] = nil
  return true
end

local function ApplySkin(unitFrame)
  if InCombatLockdown() then
    QueueFrame(unitFrame)
    return false
  end
  return ApplyLayout(unitFrame)
end

local function StyleNamePlateUnit(unit)
  if not RothBlizzPlatesDB.enabled or not IsAccessibleString(unit) then
    return
  end
  if not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
    return
  end

  local ok, namePlate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or not CanUseObject(namePlate) then
    return
  end

  ApplySkin(namePlate.UnitFrame or namePlate.unitFrame)
end

local function RestyleAllVisible()
  if InCombatLockdown() then
    return
  end
  if not C_NamePlate or type(C_NamePlate.GetNamePlates) ~= "function" then
    return
  end

  local ok, plates = pcall(C_NamePlate.GetNamePlates)
  if not ok or type(plates) ~= "table" then
    return
  end

  for _, namePlate in ipairs(plates) do
    if CanUseObject(namePlate) then
      ApplySkin(namePlate.UnitFrame or namePlate.unitFrame)
    end
  end
end

local function FlushPendingFrames()
  if InCombatLockdown() then
    return
  end
  for unitFrame in pairs(PendingFrames) do
    ApplySkin(unitFrame)
  end
end

local function InitializeSettings()
  if not Settings or not Settings.RegisterVerticalLayoutCategory then
    return
  end

  local category = Settings.RegisterVerticalLayoutCategory("Roth Blizzard Plates")

  local fontSetting = Settings.RegisterAddOnSetting(
    category,
    "RothBlizzPlates_UseGlobalFont",
    "useGlobal",
    RothBlizzPlatesDB.font,
    Settings.VarType.Boolean,
    "Использовать глобальный шрифт",
    false
  )
  Settings.CreateCheckbox(
    category,
    fontSetting,
    "Если включено, будет использоваться стандартный шрифт игры вместо Diablo-шрифта."
  )
  fontSetting:SetValueChangedCallback(RestyleAllVisible)

  local castSetting = Settings.RegisterAddOnSetting(
    category,
    "RothBlizzPlates_EnableCastbar",
    "enabled",
    RothBlizzPlatesDB.castBar,
    Settings.VarType.Boolean,
    "Включить замену Castbar",
    true
  )
  Settings.CreateCheckbox(
    category,
    castSetting,
    "Если включено, полоса применения заклинаний будет заменена на Roth-стиль."
  )
  castSetting:SetValueChangedCallback(RestyleAllVisible)

  Settings.RegisterAddOnCategory(category)
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("CVAR_UPDATE")
EventFrame:RegisterEvent("UI_SCALE_CHANGED")
EventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    InitializeSettings()
    RestyleAllVisible()
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    StyleNamePlateUnit(...)
  elseif event == "PLAYER_REGEN_ENABLED" then
    FlushPendingFrames()
    RestyleAllVisible()
  elseif event == "UI_SCALE_CHANGED" then
    RestyleAllVisible()
  elseif event == "CVAR_UPDATE" then
    local cvar = ...
    if IsAccessibleString(cvar)
      and (cvar == "uiScale" or cvar:find("nameplate", 1, true) == 1)
    then
      RestyleAllVisible()
    end
  end
end)

if hooksecurefunc and type(CompactUnitFrame_UpdateSelectionHighlight) == "function" then
  hooksecurefunc("CompactUnitFrame_UpdateSelectionHighlight", function(unitFrame)
    if unitFrame and unitFrame.__RothBlizzPlatesStyled then
      if InCombatLockdown() then
        QueueFrame(unitFrame)
      else
        DisableTargetHighlight(unitFrame)
      end
    end
  end)
end

local HooksInstalled = false
local function InstallNamePlateLifecycleHooks()
  if HooksInstalled or not hooksecurefunc then
    return
  end

  local installed = false
  if NamePlateUnitFrameMixin and type(NamePlateUnitFrameMixin.UpdateAnchors) == "function" then
    hooksecurefunc(NamePlateUnitFrameMixin, "UpdateAnchors", function(unitFrame)
      if unitFrame and unitFrame.__RothBlizzPlatesStyled then
        ApplySkin(unitFrame)
      end
    end)
    installed = true
  end

  if NamePlateUnitFrameMixin and type(NamePlateUnitFrameMixin.ApplyFrameOptions) == "function" then
    hooksecurefunc(NamePlateUnitFrameMixin, "ApplyFrameOptions", function(unitFrame)
      if unitFrame and unitFrame.__RothBlizzPlatesStyled then
        ApplySkin(unitFrame)
      end
    end)
    installed = true
  end

  if NamePlateBaseMixin and type(NamePlateBaseMixin.ApplyFrameOptions) == "function" then
    hooksecurefunc(NamePlateBaseMixin, "ApplyFrameOptions", function(namePlateBase)
      if CanUseObject(namePlateBase) then
        local unitFrame = namePlateBase.UnitFrame or namePlateBase.unitFrame
        if unitFrame and unitFrame.__RothBlizzPlatesStyled then
          ApplySkin(unitFrame)
        end
      end
    end)
    installed = true
  end

  HooksInstalled = installed
end

InstallNamePlateLifecycleHooks()
if not HooksInstalled and EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", InstallNamePlateLifecycleHooks)
end

_G.RothBlizzPlates = _G.RothBlizzPlates or {}
_G.RothBlizzPlates.ApplySkin = ApplySkin
_G.RothBlizzPlates.RestyleAllVisible = RestyleAllVisible
_G.RothBlizzPlates.GetPendingCount = function()
  local count = 0
  for _ in pairs(PendingFrames) do
    count = count + 1
  end
  return count
end
