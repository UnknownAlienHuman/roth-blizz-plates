local ROOT = (... and ... ~= "" and ...) or "."

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assertTrue(value, message)
  if not value then
    error(message or "expected true", 2)
  end
end

local combat = false
local eventFrames = {}
local settingsRegistrations = 0
local printed = {}

function canaccessvalue() return true end
function GetBuildInfo() return "12.1.5", "70688", "Oct 2026", 120105 end
function GetLocale() return "enUS" end
function InCombatLockdown() return combat end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SlashCmdList = {}

local originalPrint = print
print = function(...)
  local values = {}
  for index = 1, select("#", ...) do
    values[index] = tostring(select(index, ...))
  end
  printed[#printed + 1] = table.concat(values, " ")
end

C_Timer = { After = function(_, callback) callback() end }
EventUtil = { ContinueOnAddOnLoaded = function(_, callback) callback() end }
Settings = {
  VarType = { Boolean = "Boolean" },
  RegisterVerticalLayoutCategory = function() settingsRegistrations = settingsRegistrations + 1 return {} end,
  RegisterAddOnSetting = function() error("future schema must not register settings") end,
  CreateCheckbox = function() error("future schema must not create settings controls") end,
  RegisterAddOnCategory = function() error("future schema must not register a category") end,
}

local function NewRegion()
  local region = {
    shown = true,
    accessResult = true,
    forbiddenResult = false,
  }
  function region:CanBeAccessedInContext() return self.accessResult end
  function region:IsForbidden() return self.forbiddenResult end
  function region:CreateTexture()
    self.createdTextures = (self.createdTextures or 0) + 1
    local texture = NewRegion()
    function texture:SetTexture(value) self.texture = value end
    function texture:SetDrawLayer() end
    function texture:ClearAllPoints() end
    function texture:SetPoint() end
    function texture:SetSize() end
    function texture:SetAlpha() end
    function texture:SetAlphaFromBoolean() end
    function texture:SetVertexColor() end
    return texture
  end
  function region:Hide() self.shown = false end
  function region:Show() self.shown = true end
  function region:SetFont() end
  function region:SetShadowOffset() end
  function region:SetShadowColor() end
  return region
end

function CreateFrame()
  local frame = NewRegion()
  frame.events = {}
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(script, callback) self[script] = callback end
  function frame:Trigger(event, ...)
    if self.events[event] and self.OnEvent then
      self:OnEvent(event, ...)
    end
  end
  eventFrames[#eventFrames + 1] = frame
  return frame
end

local function pack(...)
  return { n = select("#", ...), ... }
end

function hooksecurefunc(target, methodName, callback)
  local original = target[methodName]
  target[methodName] = function(...)
    local results = pack(original(...))
    callback(...)
    return table.unpack(results, 1, results.n)
  end
end

NamePlateBaseMixin = { AcquireUnitFrame = function() end }
NamePlateUnitFrameMixin = {
  ApplyFrameOptions = function() end,
  OnUnitSet = function() end,
  OnUnitCleared = function() end,
}
CastingBarMixin = { GetEffectiveType = function() return "secure-result" end }

local healthBar = NewRegion()
healthBar.Text = NewRegion()
healthBar.LeftText = NewRegion()
healthBar.RightText = NewRegion()
local castBar = NewRegion()
castBar.Text = NewRegion()
castBar.CastTargetNameText = NewRegion()
setmetatable(castBar, { __index = CastingBarMixin })
local unitFrame = NewRegion()
unitFrame.HealthBarsContainer = NewRegion()
unitFrame.HealthBarsContainer.healthBar = healthBar
unitFrame.CastBarsContainer = NewRegion()
unitFrame.CastBarsContainer.castBar = castBar
unitFrame.name = NewRegion()
local namePlate = NewRegion()
namePlate.UnitFrame = unitFrame

C_NamePlate = {
  GetNamePlateForUnit = function() return namePlate end,
  GetNamePlates = function() return { namePlate } end,
}

local futureDB = {
  schemaVersion = 99,
  enabled = true,
  plate = { enabled = true, width = 321, futureField = "keep" },
  castBar = { enabled = true, futureCast = "keep" },
  castBorder = { width = 222, height = 77, offsetX = 5, offsetY = 6, alpha = 0.7 },
  font = { enabled = true, useGlobal = false, size = 13, outline = "OUTLINE", shadow = true },
  healthBar = { futureHealth = "keep" },
  futureRoot = { token = "keep" },
}
RothBlizzPlatesDB = futureDB

assert(loadfile(ROOT .. "/core.lua"))("RothBlizzPlates")
assert(loadfile(ROOT .. "/castbar_12_1.lua"))("RothBlizzPlates")

assertEqual(RothBlizzPlatesDB, futureDB, "database identity preserved")
assertEqual(RothBlizzPlatesDB.schemaVersion, 99, "future schema preserved")
assertEqual(RothBlizzPlatesDB.plate.offsetX, nil, "future plate not partially migrated")
assertEqual(RothBlizzPlatesDB.plate.futureField, "keep", "future plate field preserved")
assertEqual(RothBlizzPlatesDB.healthBar.futureHealth, "keep", "future legacy-looking field preserved")
assertEqual(RothBlizzPlatesDB.futureRoot.token, "keep", "future root field preserved")
assertEqual(RothBlizzPlates.IsRuntimeSupported(), false, "runtime disabled for future schema")

local interfaceSupported, databaseSupported, schemaVersion = RothBlizzPlates.GetCompatibilityStatus()
assertEqual(interfaceSupported, true, "interface remains supported")
assertEqual(databaseSupported, false, "future database rejected")
assertEqual(schemaVersion, 99, "reported schema preserved")

local eventFrame = eventFrames[1]
assertTrue(eventFrame ~= nil, "event frame exists")
eventFrame:Trigger("PLAYER_LOGIN")
assertEqual(settingsRegistrations, 0, "settings not registered for future schema")
assertEqual(#printed, 1, "one downgrade warning printed")
assertTrue(printed[1]:find("newer than supported schema", 1, true) ~= nil, "warning explains downgrade guard")

NamePlateBaseMixin.AcquireUnitFrame(namePlate)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame)
eventFrame:Trigger("NAME_PLATE_UNIT_ADDED", "nameplate1")
eventFrame:Trigger("PLAYER_ENTERING_WORLD")
assertEqual(healthBar.createdTextures, nil, "future schema creates no plate texture")
assertEqual(castBar.createdTextures, nil, "future schema creates no cast texture")

print = originalPrint
originalPrint("test_future_schema.lua: ok")
