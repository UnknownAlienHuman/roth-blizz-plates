--[[
RothBlizzPlates
Retail 12.1.5 presentation layer for Blizzard-owned nameplates.

Blizzard owns unit state, protected layout, health/cast progress, threat, target
state, and lifecycle. This addon only creates its own decorative regions and
changes fonts. It never derives gameplay state.
--]]

local ADDON_NAME = ...

local EXPECTED_INTERFACE = 120105
local SCHEMA_VERSION = 3
local MEDIA_PATH = ("Interface\\AddOns\\%s\\media\\"):format(ADDON_NAME)
local MEDIA = {
  FONT = MEDIA_PATH .. "Diablo-Light.ttf",
  PLATE = MEDIA_PATH .. "NormalPlate",
}

local NON_LATIN_LOCALES = {
  koKR = true,
  zhCN = true,
  zhTW = true,
}

local VALID_FONT_FLAGS = {
  [""] = true,
  OUTLINE = true,
  THICKOUTLINE = true,
  MONOCHROME = true,
  ["OUTLINE,MONOCHROME"] = true,
  ["THICKOUTLINE,MONOCHROME"] = true,
}

local DEFAULTS = {
  schemaVersion = SCHEMA_VERSION,
  enabled = true,
  plate = {
    enabled = true,
    width = 180,
    height = 60,
    x = 6,
    y = 4,
    alpha = 1,
  },
  castBar = {
    enabled = true,
  },
  castBorder = {
    width = 220,
    height = 66,
    offsetX = -1,
    offsetY = -9,
    alpha = 1,
  },
  font = {
    enabled = true,
    useGlobal = false,
    size = 9,
    outline = "OUTLINE",
    shadow = true,
  },
}

local function ClampNumber(value, fallback, minimum, maximum)
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

local function MergeDefaults(target, defaults)
  for key, defaultValue in pairs(defaults) do
    if type(defaultValue) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = {}
      end
      MergeDefaults(target[key], defaultValue)
    elseif type(target[key]) ~= type(defaultValue) then
      target[key] = defaultValue
    end
  end
end

local function InitializeDatabase()
  local db = _G.RothBlizzPlatesDB
  if type(db) ~= "table" then
    db = {}
    _G.RothBlizzPlatesDB = db
  end

  local previousSchema = type(db.schemaVersion) == "number" and db.schemaVersion or 0

  -- Version 2 stored cast-border offsets in unit-frame coordinates. Convert
  -- once to offsets relative to Blizzard's cast bar and keep user tuning.
  if previousSchema < 3 and type(db.castBorder) == "table" then
    local castBar = type(db.castBar) == "table" and db.castBar or nil
    if type(db.castBorder.offsetX) ~= "number" then
      local borderX = type(db.castBorder.x) == "number" and db.castBorder.x or 0
      local castX = castBar and type(castBar.x) == "number" and castBar.x or 1
      db.castBorder.offsetX = borderX - castX
    end
    if type(db.castBorder.offsetY) ~= "number" then
      local borderY = type(db.castBorder.y) == "number" and db.castBorder.y or -28
      local castY = castBar and type(castBar.y) == "number" and castBar.y or -19
      db.castBorder.offsetY = borderY - castY
    end
  end

  MergeDefaults(db, DEFAULTS)

  db.healthBar = nil
  db.layout = nil
  db.name = nil
  db.castBar.width = nil
  db.castBar.height = nil
  db.castBar.x = nil
  db.castBar.y = nil
  db.castBorder.x = nil
  db.castBorder.y = nil
  db.font.inherit = nil

  db.plate.width = ClampNumber(db.plate.width, DEFAULTS.plate.width, 20, 800)
  db.plate.height = ClampNumber(db.plate.height, DEFAULTS.plate.height, 8, 300)
  db.plate.x = ClampNumber(db.plate.x, DEFAULTS.plate.x, -500, 500)
  db.plate.y = ClampNumber(db.plate.y, DEFAULTS.plate.y, -500, 500)
  db.plate.alpha = ClampNumber(db.plate.alpha, DEFAULTS.plate.alpha, 0, 1)

  db.castBorder.width = ClampNumber(db.castBorder.width, DEFAULTS.castBorder.width, 20, 800)
  db.castBorder.height = ClampNumber(db.castBorder.height, DEFAULTS.castBorder.height, 8, 300)
  db.castBorder.offsetX = ClampNumber(db.castBorder.offsetX, DEFAULTS.castBorder.offsetX, -500, 500)
  db.castBorder.offsetY = ClampNumber(db.castBorder.offsetY, DEFAULTS.castBorder.offsetY, -500, 500)
  db.castBorder.alpha = ClampNumber(db.castBorder.alpha, DEFAULTS.castBorder.alpha, 0, 1)

  db.font.size = ClampNumber(db.font.size, DEFAULTS.font.size, 5, 72)
  if type(db.font.outline) ~= "string" or not VALID_FONT_FLAGS[db.font.outline] then
    db.font.outline = DEFAULTS.font.outline
  end

  db.schemaVersion = SCHEMA_VERSION
  return db
end

local DB = InitializeDatabase()

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

local function IsUsableUnitToken(unit)
  return IsAccessible(unit) and type(unit) == "string"
end

local interfaceVersion = select(4, GetBuildInfo())
local RuntimeSupported = interfaceVersion == EXPECTED_INTERFACE

local StateByFrame = setmetatable({}, { __mode = "k" })
local PendingByFrame = setmetatable({}, { __mode = "k" })
local FrameByUnit = {}
local RefreshAfterCombat = false
local RefreshScheduled = false
local HooksInstalled = false

local function GetState(unitFrame, create)
  local state = StateByFrame[unitFrame]
  if not state and create then
    state = {
      generation = 0,
      active = false,
    }
    StateByFrame[unitFrame] = state
  end
  return state
end

local function GetHealthBar(unitFrame)
  if not IsUsableRegion(unitFrame) then
    return nil
  end

  local container = unitFrame.HealthBarsContainer
  if not IsUsableRegion(container) then
    return nil
  end

  local healthBar = container.healthBar
  if not IsUsableRegion(healthBar) then
    return nil
  end

  return healthBar
end

local function HideOwnedRegions(state)
  if not state then
    return
  end
  if IsUsableRegion(state.plate) then
    state.plate:Hide()
  end
end

local function ApplyFont(fontString)
  if not DB.font.enabled or not IsUsableRegion(fontString) or type(fontString.SetFont) ~= "function" then
    return
  end

  local fontPath = MEDIA.FONT
  if DB.font.useGlobal or NON_LATIN_LOCALES[GetLocale()] then
    fontPath = STANDARD_TEXT_FONT
  end

  fontString:SetFont(fontPath, DB.font.size, DB.font.outline)
  if type(fontString.SetShadowOffset) == "function" then
    if DB.font.shadow then
      fontString:SetShadowOffset(1, -1)
      if type(fontString.SetShadowColor) == "function" then
        fontString:SetShadowColor(0, 0, 0, 1)
      end
    else
      fontString:SetShadowOffset(0, 0)
    end
  end
end

local function ApplyFonts(unitFrame, healthBar)
  ApplyFont(unitFrame.name)
  ApplyFont(healthBar.Text)
  ApplyFont(healthBar.LeftText)
  ApplyFont(healthBar.RightText)

  local castContainer = unitFrame.CastBarsContainer
  local castBar = IsUsableRegion(castContainer) and castContainer.castBar or nil
  if IsUsableRegion(castBar) then
    ApplyFont(castBar.Text)
    ApplyFont(castBar.CastTargetNameText)
  end
end

local function EnsurePlate(state, healthBar)
  if IsUsableRegion(state.plate) then
    return state.plate
  end
  if type(healthBar.CreateTexture) ~= "function" then
    return nil
  end

  local plate = healthBar:CreateTexture(nil, "ARTWORK", nil, -7)
  if not IsUsableRegion(plate) then
    return nil
  end

  state.plate = plate
  return plate
end

local function ConfigurePlate(state, healthBar)
  if not DB.plate.enabled then
    HideOwnedRegions(state)
    return true
  end

  local plate = EnsurePlate(state, healthBar)
  if not plate then
    return false
  end

  plate:SetTexture(MEDIA.PLATE)
  plate:ClearAllPoints()
  plate:SetPoint("CENTER", healthBar, "CENTER", DB.plate.x, DB.plate.y)
  plate:SetSize(DB.plate.width, DB.plate.height)
  plate:SetAlpha(DB.plate.alpha)
  plate:Show()
  return true
end

local function ApplyFrame(unitFrame, expectedGeneration)
  local state = GetState(unitFrame, false)
  if not state or not state.active or state.generation ~= expectedGeneration then
    return false
  end
  if not RuntimeSupported or not DB.enabled then
    HideOwnedRegions(state)
    local castModule = _G.RothBlizzPlates_CastBar
    if castModule and type(castModule.Release) == "function" then
      castModule.Release(unitFrame)
    end
    return false
  end
  if InCombatLockdown() then
    PendingByFrame[unitFrame] = expectedGeneration
    return false
  end

  local healthBar = GetHealthBar(unitFrame)
  if not healthBar then
    return false
  end

  if not ConfigurePlate(state, healthBar) then
    return false
  end
  ApplyFonts(unitFrame, healthBar)

  local castModule = _G.RothBlizzPlates_CastBar
  if castModule and type(castModule.Apply) == "function" then
    castModule.Apply(unitFrame)
  end

  PendingByFrame[unitFrame] = nil
  return true
end

local function RequestApply(unitFrame)
  if not IsAccessible(unitFrame) then
    return false
  end
  local state = GetState(unitFrame, false)
  if not state or not state.active then
    return false
  end
  if InCombatLockdown() then
    PendingByFrame[unitFrame] = state.generation
    return false
  end
  if not IsUsableRegion(unitFrame) then
    return false
  end
  return ApplyFrame(unitFrame, state.generation)
end

local function ActivateFrame(unitFrame, unit)
  if not IsUsableRegion(unitFrame) then
    return
  end

  local state = GetState(unitFrame, true)
  if not state.active then
    state.generation = state.generation + 1
    state.active = true
  end

  if IsUsableUnitToken(unit) then
    if state.unit and state.unit ~= unit then
      FrameByUnit[state.unit] = nil
    end
    state.unit = unit
    FrameByUnit[unit] = unitFrame
  end

  RequestApply(unitFrame)
end

local function ReleaseFrame(unitFrame)
  if not IsAccessible(unitFrame) then
    return
  end
  local state = GetState(unitFrame, false)
  if not state then
    return
  end

  if state.unit then
    FrameByUnit[state.unit] = nil
  end
  state.unit = nil
  state.active = false
  state.generation = state.generation + 1
  PendingByFrame[unitFrame] = nil
  HideOwnedRegions(state)

  local castModule = _G.RothBlizzPlates_CastBar
  if castModule and type(castModule.Release) == "function" then
    castModule.Release(unitFrame)
  end
end

local function ResolveNamePlateUnit(unit)
  if not RuntimeSupported or not IsUsableUnitToken(unit) then
    return
  end
  if not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
    return
  end

  local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
  if not IsUsableRegion(namePlate) then
    if InCombatLockdown() then
      RefreshAfterCombat = true
    end
    return
  end

  local unitFrame = namePlate.UnitFrame
  if not IsUsableRegion(unitFrame) then
    if InCombatLockdown() then
      RefreshAfterCombat = true
    end
    return
  end

  ActivateFrame(unitFrame, unit)
end

local function ReleaseNamePlateUnit(unit)
  if not IsUsableUnitToken(unit) then
    return
  end

  local unitFrame = FrameByUnit[unit]
  FrameByUnit[unit] = nil
  if unitFrame then
    ReleaseFrame(unitFrame)
  end
end

local function HideAllOwnedRegions()
  local castModule = _G.RothBlizzPlates_CastBar
  for unitFrame, state in pairs(StateByFrame) do
    HideOwnedRegions(state)
    if castModule and type(castModule.Release) == "function" then
      castModule.Release(unitFrame)
    end
  end
end

local function RefreshVisible()
  RefreshScheduled = false

  if not RuntimeSupported or not DB.enabled then
    HideAllOwnedRegions()
    return
  end
  if InCombatLockdown() then
    RefreshAfterCombat = true
    return
  end
  if not C_NamePlate or type(C_NamePlate.GetNamePlates) ~= "function" then
    return
  end

  local plates = C_NamePlate.GetNamePlates()
  if not IsAccessible(plates) or type(plates) ~= "table" then
    return
  end

  for index = 1, #plates do
    local namePlate = plates[index]
    if IsUsableRegion(namePlate) then
      local unitFrame = namePlate.UnitFrame
      if IsUsableRegion(unitFrame) then
        ActivateFrame(unitFrame)
      end
    end
  end
end

local function ScheduleRefresh()
  if RefreshScheduled then
    return
  end
  RefreshScheduled = true

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0, RefreshVisible)
  else
    RefreshVisible()
  end
end

local function FlushPending()
  if InCombatLockdown() then
    return
  end

  for unitFrame, generation in pairs(PendingByFrame) do
    PendingByFrame[unitFrame] = nil
    local state = GetState(unitFrame, false)
    if state and state.active and state.generation == generation then
      ApplyFrame(unitFrame, generation)
    end
  end

  if RefreshAfterCombat then
    RefreshAfterCombat = false
    ScheduleRefresh()
  end
end

local function InstallNamePlateHooks()
  if HooksInstalled or type(hooksecurefunc) ~= "function" or type(NamePlateUnitFrameMixin) ~= "table" then
    return false
  end
  if type(NamePlateUnitFrameMixin.ApplyFrameOptions) ~= "function"
    or type(NamePlateUnitFrameMixin.OnUnitCleared) ~= "function" then
    return false
  end

  hooksecurefunc(NamePlateUnitFrameMixin, "ApplyFrameOptions", function(unitFrame)
    RequestApply(unitFrame)
  end)
  hooksecurefunc(NamePlateUnitFrameMixin, "OnUnitCleared", function(unitFrame)
    ReleaseFrame(unitFrame)
  end)

  HooksInstalled = true
  return true
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local loadedAddon = ...
    if loadedAddon == "Blizzard_NamePlates" then
      InstallNamePlateHooks()
      local castModule = _G.RothBlizzPlates_CastBar
      if castModule and type(castModule.InstallHooks) == "function" then
        castModule.InstallHooks()
      end
      if HooksInstalled and type(EventFrame.UnregisterEvent) == "function" then
        EventFrame:UnregisterEvent("ADDON_LOADED")
      end
    end
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    ResolveNamePlateUnit(...)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    ReleaseNamePlateUnit(...)
  elseif event == "PLAYER_ENTERING_WORLD" then
    InstallNamePlateHooks()
    ScheduleRefresh()
  elseif event == "PLAYER_REGEN_ENABLED" then
    FlushPending()
  end
end)

InstallNamePlateHooks()
if HooksInstalled and type(EventFrame.UnregisterEvent) == "function" then
  EventFrame:UnregisterEvent("ADDON_LOADED")
elseif EventUtil and type(EventUtil.ContinueOnAddOnLoaded) == "function" then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", InstallNamePlateHooks)
end

local function CountState()
  local active = 0
  local pending = 0
  for _, state in pairs(StateByFrame) do
    if state.active then
      active = active + 1
    end
  end
  for _ in pairs(PendingByFrame) do
    pending = pending + 1
  end
  return active, pending
end

SLASH_ROTHBLIZZPLATES1 = "/rbp"
SlashCmdList.ROTHBLIZZPLATES = function(message)
  if not IsAccessible(message) or type(message) ~= "string" then
    message = ""
  end
  message = message:lower():match("^%s*(.-)%s*$")

  if message == "refresh" then
    ScheduleRefresh()
    print("RothBlizzPlates: refresh scheduled.")
  elseif message == "status" then
    local active, pending = CountState()
    print(("RothBlizzPlates: interface=%s supported=%s active=%d pending=%d"):format(
      tostring(interfaceVersion), tostring(RuntimeSupported), active, pending
    ))
  else
    print("RothBlizzPlates: /rbp status | /rbp refresh")
  end
end

_G.RothBlizzPlates = {
  RequestApply = RequestApply,
  Refresh = ScheduleRefresh,
  Release = ReleaseFrame,
  IsRuntimeSupported = function()
    return RuntimeSupported
  end,
  GetStateCounts = CountState,
}
