--[[
RothBlizzPlates
Retail 12.1.5 presentation layer for Blizzard-owned nameplates.

Blizzard owns unit state, protected layout, health/cast progress, threat, target
state, and lifecycle. This addon creates only its own decorative regions and
changes fonts. It never derives gameplay state.
--]]

local ADDON_NAME = ...

local EXPECTED_INTERFACE = 120105
local SCHEMA_VERSION = 4
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
    offsetX = 0,
    offsetY = 0.5,
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
  if previousSchema > SCHEMA_VERSION then
    return db, false, previousSchema
  end

  -- Schema 3: cast-border coordinates became offsets relative to the native
  -- cast bar. Preserve old tuning before deleting the obsolete cast geometry.
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

  -- Schema 4: plate coordinates are offsets relative to the native health bar.
  -- Earlier builds retained the old unit-frame coordinates after removing the
  -- health-bar geometry owner, shifting the artwork by the legacy bar offset.
  if previousSchema < 4 then
    if type(db.plate) ~= "table" then
      db.plate = {}
    end
    local healthBar = type(db.healthBar) == "table" and db.healthBar or nil
    local healthX = healthBar and type(healthBar.x) == "number" and healthBar.x or 6
    local healthY = healthBar and type(healthBar.y) == "number" and healthBar.y or 3.5

    if type(db.plate.offsetX) ~= "number" then
      local plateX = type(db.plate.x) == "number" and db.plate.x or 6
      db.plate.offsetX = plateX - healthX
    end
    if type(db.plate.offsetY) ~= "number" then
      local plateY = type(db.plate.y) == "number" and db.plate.y or 4
      db.plate.offsetY = plateY - healthY
    end
  end

  MergeDefaults(db, DEFAULTS)

  db.healthBar = nil
  db.layout = nil
  db.name = nil
  db.plate.x = nil
  db.plate.y = nil
  db.castBar.width = nil
  db.castBar.height = nil
  db.castBar.x = nil
  db.castBar.y = nil
  db.castBorder.x = nil
  db.castBorder.y = nil
  db.font.inherit = nil

  db.plate.width = ClampNumber(db.plate.width, DEFAULTS.plate.width, 20, 800)
  db.plate.height = ClampNumber(db.plate.height, DEFAULTS.plate.height, 8, 300)
  db.plate.offsetX = ClampNumber(db.plate.offsetX, DEFAULTS.plate.offsetX, -500, 500)
  db.plate.offsetY = ClampNumber(db.plate.offsetY, DEFAULTS.plate.offsetY, -500, 500)
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
  return db, true, SCHEMA_VERSION
end

local DB, DatabaseSupported, DatabaseSchemaVersion = InitializeDatabase()

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

local function IsUsableUnitToken(unit)
  return IsAccessible(unit) and type(unit) == "string"
end

local interfaceVersion = select(4, GetBuildInfo())
local InterfaceSupported = interfaceVersion == EXPECTED_INTERFACE
local RuntimeSupported = InterfaceSupported and DatabaseSupported

local StateByFrame = setmetatable({}, { __mode = "k" })
local PendingByFrame = setmetatable({}, { __mode = "k" })
local FrameByUnit = {}
local RefreshAfterCombat = false
local RefreshScheduled = false
local HooksInstalled = false
local SettingsRegistered = false

local function GetState(unitFrame, create)
  local state = StateByFrame[unitFrame]
  if not state and create then
    state = {
      generation = 0,
      active = false,
      prepared = false,
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
  if state and IsUsableRegion(state.plate) then
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
  plate:SetPoint("CENTER", healthBar, "CENTER", DB.plate.offsetX, DB.plate.offsetY)
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
    PendingByFrame[unitFrame] = nil
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
  if unitFrame == nil or not IsAccessible(unitFrame) then
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

local function PrepareAssignment(unitFrame)
  if not IsUsableRegion(unitFrame) then
    return false
  end

  local state = GetState(unitFrame, true)
  if state.unit then
    FrameByUnit[state.unit] = nil
  end

  state.unit = nil
  state.generation = state.generation + 1
  state.active = false
  state.prepared = true
  PendingByFrame[unitFrame] = nil
  HideOwnedRegions(state)

  local castModule = _G.RothBlizzPlates_CastBar
  if RuntimeSupported and castModule and type(castModule.Prepare) == "function" then
    castModule.Prepare(unitFrame)
  end

  return true
end

local function ActivatePreparedFrame(unitFrame, unit)
  if not IsUsableRegion(unitFrame) then
    return false
  end

  local state = GetState(unitFrame, true)
  if not state.prepared and not PrepareAssignment(unitFrame) then
    return false
  end

  state = GetState(unitFrame, false)
  state.prepared = false
  state.active = true

  if IsUsableUnitToken(unit) then
    state.unit = unit
    FrameByUnit[unit] = unitFrame
  end

  RequestApply(unitFrame)
  return true
end

local function ReleaseFrame(unitFrame)
  if unitFrame == nil or not IsAccessible(unitFrame) then
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
  state.prepared = false
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

  local state = GetState(unitFrame, false)
  if state and state.active then
    if state.unit and state.unit ~= unit then
      FrameByUnit[state.unit] = nil
    end
    state.unit = unit
    FrameByUnit[unit] = unitFrame
    RequestApply(unitFrame)
    return
  end

  ActivatePreparedFrame(unitFrame, unit)
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

  for _, namePlate in pairs(plates) do
    if IsUsableRegion(namePlate) then
      local unitFrame = namePlate.UnitFrame
      if IsUsableRegion(unitFrame) then
        local state = GetState(unitFrame, false)
        if state and state.active then
          RequestApply(unitFrame)
        else
          ActivatePreparedFrame(unitFrame)
        end
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

local function RegisterBooleanSetting(category, variable, key, tableRef, label, defaultValue, tooltip)
  local setting = Settings.RegisterAddOnSetting(
    category,
    variable,
    key,
    tableRef,
    Settings.VarType.Boolean,
    label,
    defaultValue
  )
  Settings.CreateCheckbox(category, setting, tooltip)
  setting:SetValueChangedCallback(ScheduleRefresh)
end

local function InitializeSettings()
  if SettingsRegistered or not DatabaseSupported or not Settings
    or type(Settings.RegisterVerticalLayoutCategory) ~= "function"
    or type(Settings.RegisterAddOnSetting) ~= "function"
    or type(Settings.CreateCheckbox) ~= "function"
    or type(Settings.RegisterAddOnCategory) ~= "function" then
    return false
  end

  local category = Settings.RegisterVerticalLayoutCategory("Roth Blizzard Plates")
  RegisterBooleanSetting(
    category,
    "ROTHBLIZZPLATES_PLATE_ENABLED",
    "enabled",
    DB.plate,
    "Roth plate artwork",
    DEFAULTS.plate.enabled,
    "Show the addon-owned Roth frame around Blizzard health bars."
  )
  RegisterBooleanSetting(
    category,
    "ROTHBLIZZPLATES_CASTBAR_ENABLED",
    "enabled",
    DB.castBar,
    "Roth cast border",
    DEFAULTS.castBar.enabled,
    "Show addon-owned interruptible and non-interruptible cast borders."
  )
  RegisterBooleanSetting(
    category,
    "ROTHBLIZZPLATES_GLOBAL_FONT",
    "useGlobal",
    DB.font,
    "Use Blizzard font",
    DEFAULTS.font.useGlobal,
    "Use the standard game font instead of the bundled Diablo-style font."
  )
  RegisterBooleanSetting(
    category,
    "ROTHBLIZZPLATES_FONT_SHADOW",
    "shadow",
    DB.font,
    "Font shadow",
    DEFAULTS.font.shadow,
    "Apply a one-pixel shadow to nameplate text."
  )

  Settings.RegisterAddOnCategory(category)
  SettingsRegistered = true
  return true
end

local function InstallNamePlateHooks()
  if HooksInstalled or type(hooksecurefunc) ~= "function"
    or type(NamePlateBaseMixin) ~= "table"
    or type(NamePlateUnitFrameMixin) ~= "table" then
    return false
  end
  if type(NamePlateBaseMixin.AcquireUnitFrame) ~= "function"
    or type(NamePlateUnitFrameMixin.ApplyFrameOptions) ~= "function"
    or type(NamePlateUnitFrameMixin.OnUnitSet) ~= "function"
    or type(NamePlateUnitFrameMixin.OnUnitCleared) ~= "function" then
    return false
  end

  hooksecurefunc(NamePlateBaseMixin, "AcquireUnitFrame", function(namePlateBase)
    if IsUsableRegion(namePlateBase) then
      PrepareAssignment(namePlateBase.UnitFrame)
    end
  end)
  hooksecurefunc(NamePlateUnitFrameMixin, "ApplyFrameOptions", function(unitFrame)
    RequestApply(unitFrame)
  end)
  hooksecurefunc(NamePlateUnitFrameMixin, "OnUnitSet", function(unitFrame)
    ActivatePreparedFrame(unitFrame)
  end)
  hooksecurefunc(NamePlateUnitFrameMixin, "OnUnitCleared", function(unitFrame)
    ReleaseFrame(unitFrame)
  end)

  HooksInstalled = true
  return true
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "NAME_PLATE_UNIT_ADDED" then
    ResolveNamePlateUnit(...)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    ReleaseNamePlateUnit(...)
  elseif event == "PLAYER_LOGIN" then
    if not DatabaseSupported then
      print(("RothBlizzPlates: SavedVariables schema %s is newer than supported schema %d; presentation is disabled to prevent downgrade."):format(
        tostring(DatabaseSchemaVersion), SCHEMA_VERSION
      ))
    else
      InitializeSettings()
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    InstallNamePlateHooks()
    ScheduleRefresh()
  elseif event == "PLAYER_REGEN_ENABLED" then
    FlushPending()
  end
end)

InstallNamePlateHooks()
if not HooksInstalled and EventUtil and type(EventUtil.ContinueOnAddOnLoaded) == "function" then
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
    print(("RothBlizzPlates: interface=%s interfaceSupported=%s dbSchema=%s dbSupported=%s active=%d pending=%d"):format(
      tostring(interfaceVersion), tostring(InterfaceSupported), tostring(DatabaseSchemaVersion),
      tostring(DatabaseSupported), active, pending
    ))
  else
    print("RothBlizzPlates: /rbp status | /rbp refresh")
  end
end

_G.RothBlizzPlates = {
  RequestApply = RequestApply,
  Refresh = ScheduleRefresh,
  Release = ReleaseFrame,
  Prepare = PrepareAssignment,
  Activate = ActivatePreparedFrame,
  IsRuntimeSupported = function()
    return RuntimeSupported
  end,
  GetCompatibilityStatus = function()
    return InterfaceSupported, DatabaseSupported, DatabaseSchemaVersion
  end,
  GetStateCounts = CountState,
}
