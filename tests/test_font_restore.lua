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
local plates = {}
local plateByUnit = {}

function canaccessvalue() return true end
function GetBuildInfo() return "12.1.5", "70783", "Nov 2026", 120105 end
function GetLocale() return "enUS" end
function InCombatLockdown() return combat end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SlashCmdList = {}
Settings = nil

C_Timer = { After = function(_, callback) callback() end }
EventUtil = { ContinueOnAddOnLoaded = function(_, callback) callback() end }

local function NewRegion(kind)
  local region = {
    kind = kind or "Frame",
    shown = true,
    accessResult = true,
    forbiddenResult = false,
  }

  function region:CanBeAccessedInContext() return self.accessResult end
  function region:IsForbidden() return self.forbiddenResult end
  function region:CreateTexture()
    local texture = NewRegion("Texture")
    self.textures = self.textures or {}
    self.textures[#self.textures + 1] = texture
    return texture
  end
  function region:SetTexture(value) self.texture = value end
  function region:ClearAllPoints() end
  function region:SetPoint(...) self.point = { ... } end
  function region:SetSize(width, height) self.width, self.height = width, height end
  function region:SetAlpha(alpha) self.alpha = alpha end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end

  return region
end

local function NewFontObject(name, height, flags, shadowX, shadowY, shadowR, shadowG, shadowB, shadowA)
  return {
    fontFile = name,
    fontHeight = height,
    fontFlags = flags,
    shadowX = shadowX,
    shadowY = shadowY,
    shadowR = shadowR,
    shadowG = shadowG,
    shadowB = shadowB,
    shadowA = shadowA,
  }
end

local function NewFontString(name, height, flags, shadowX, shadowY, shadowR, shadowG, shadowB, shadowA)
  local fontString = NewRegion("FontString")
  local initialFontObject = NewFontObject(
    name, height, flags, shadowX, shadowY, shadowR, shadowG, shadowB, shadowA
  )
  fontString.initialFontObject = initialFontObject

  function fontString:SetFontObject(fontObject)
    self.fontObject = fontObject
    self.fontFile = fontObject.fontFile
    self.fontHeight = fontObject.fontHeight
    self.fontFlags = fontObject.fontFlags
    self.shadowX = fontObject.shadowX
    self.shadowY = fontObject.shadowY
    self.shadowR = fontObject.shadowR
    self.shadowG = fontObject.shadowG
    self.shadowB = fontObject.shadowB
    self.shadowA = fontObject.shadowA
  end
  function fontString:GetFontObject()
    return self.fontObject
  end
  function fontString:GetFont()
    return self.fontFile, self.fontHeight, self.fontFlags
  end
  function fontString:SetFont(fontFile, fontHeight, fontFlags)
    self.fontObject = nil
    self.fontFile = fontFile
    self.fontHeight = fontHeight
    self.fontFlags = fontFlags
  end
  function fontString:GetShadowOffset()
    return self.shadowX, self.shadowY
  end
  function fontString:SetShadowOffset(x, y)
    self.shadowX = x
    self.shadowY = y
  end
  function fontString:GetShadowColor()
    return self.shadowR, self.shadowG, self.shadowB, self.shadowA
  end
  function fontString:SetShadowColor(r, g, b, a)
    self.shadowR = r
    self.shadowG = g
    self.shadowB = b
    self.shadowA = a
  end

  fontString:SetFontObject(initialFontObject)
  return fontString
end

function CreateFrame()
  local frame = NewRegion("Frame")
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

local function NewUnitFrame(prefix)
  local healthBar = NewRegion("StatusBar")
  healthBar.Text = NewFontString(prefix .. "-health", 10, "", 0, 0, 0.2, 0.3, 0.4, 0.5)
  healthBar.LeftText = NewFontString(prefix .. "-left", 11, "OUTLINE", 2, -2, 0.1, 0.2, 0.3, 0.4)
  healthBar.RightText = NewFontString(prefix .. "-right", 12, "THICKOUTLINE", 3, -3, 0.4, 0.3, 0.2, 0.1)

  local castBar = NewRegion("StatusBar")
  castBar.Text = NewFontString(prefix .. "-cast", 13, "", 0, 0, 0.6, 0.5, 0.4, 0.3)
  castBar.CastTargetNameText = NewFontString(prefix .. "-target", 14, "OUTLINE", 4, -4, 0.7, 0.6, 0.5, 0.4)

  local unitFrame = NewRegion("Frame")
  unitFrame.name = NewFontString(prefix .. "-name", 15, "THICKOUTLINE", 5, -5, 0.8, 0.7, 0.6, 0.5)
  unitFrame.HealthBarsContainer = NewRegion("Frame")
  unitFrame.HealthBarsContainer.healthBar = healthBar
  unitFrame.CastBarsContainer = NewRegion("Frame")
  unitFrame.CastBarsContainer.castBar = castBar

  local plate = NewRegion("Frame")
  plate.UnitFrame = unitFrame
  return plate, unitFrame, healthBar, castBar
end

local function assertFont(fontString, file, height, flags, shadowX, shadowY, shadowR, shadowG, shadowB, shadowA, label)
  assertEqual(fontString.fontFile, file, label .. " file")
  assertEqual(fontString.fontHeight, height, label .. " height")
  assertEqual(fontString.fontFlags, flags, label .. " flags")
  assertEqual(fontString.shadowX, shadowX, label .. " shadow X")
  assertEqual(fontString.shadowY, shadowY, label .. " shadow Y")
  assertEqual(fontString.shadowR, shadowR, label .. " shadow R")
  assertEqual(fontString.shadowG, shadowG, label .. " shadow G")
  assertEqual(fontString.shadowB, shadowB, label .. " shadow B")
  assertEqual(fontString.shadowA, shadowA, label .. " shadow A")
end

C_NamePlate = {
  GetNamePlateForUnit = function(unit) return plateByUnit[unit] end,
  GetNamePlates = function() return plates end,
}

RothBlizzPlatesDB = {
  schemaVersion = 4,
  enabled = true,
  plate = { enabled = true, width = 180, height = 60, offsetX = 0, offsetY = 0.5, alpha = 1 },
  castBar = { enabled = false },
  castBorder = { width = 220, height = 66, offsetX = -1, offsetY = -9, alpha = 1 },
  font = { enabled = true, useGlobal = false, size = 9, outline = "OUTLINE", shadow = true },
}

assert(loadfile(ROOT .. "/core.lua"))("RothBlizzPlates")

local eventFrame = eventFrames[1]
assertTrue(eventFrame ~= nil, "event frame exists")

local plate, unitFrame, healthBar, castBar = NewUnitFrame("initial")
plates[1] = plate
plateByUnit.nameplate1 = plate

NamePlateBaseMixin.AcquireUnitFrame(plate)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame)
eventFrame:Trigger("NAME_PLATE_UNIT_ADDED", "nameplate1")

local rothFont = "Interface\\AddOns\\RothBlizzPlates\\media\\Diablo-Light.ttf"
assertFont(unitFrame.name, rothFont, 9, "OUTLINE", 1, -1, 0, 0, 0, 1, "applied name")
assertFont(healthBar.Text, rothFont, 9, "OUTLINE", 1, -1, 0, 0, 0, 1, "applied health")
assertFont(castBar.Text, rothFont, 9, "OUTLINE", 1, -1, 0, 0, 0, 1, "applied cast")
assertEqual(unitFrame.name.fontObject, nil, "direct Roth font detaches native object")

-- A settings refresh during combat is deferred before any native font mutation.
combat = true
RothBlizzPlatesDB.font.enabled = false
RothBlizzPlates.Refresh()
assertEqual(unitFrame.name.fontFile, rothFont, "combat disable deferred")
combat = false
eventFrame:Trigger("PLAYER_REGEN_ENABLED")

-- Disabling the font feature restores both the exact presentation and the
-- original Blizzard FontObject relationship.
assertFont(unitFrame.name, "initial-name", 15, "THICKOUTLINE", 5, -5, 0.8, 0.7, 0.6, 0.5, "disabled name")
assertFont(healthBar.Text, "initial-health", 10, "", 0, 0, 0.2, 0.3, 0.4, 0.5, "disabled health")
assertFont(castBar.Text, "initial-cast", 13, "", 0, 0, 0.6, 0.5, 0.4, 0.3, "disabled cast")
assertEqual(unitFrame.name.fontObject, unitFrame.name.initialFontObject, "native name FontObject restored")
assertEqual(healthBar.Text.fontObject, healthBar.Text.initialFontObject, "native health FontObject restored")

-- A later direct Blizzard refresh becomes the new restoration baseline.
RothBlizzPlatesDB.font.enabled = true
RothBlizzPlates.Refresh()
unitFrame.name:SetFont("blizzard-refreshed", 17, "MONOCHROME")
unitFrame.name:SetShadowOffset(7, -7)
unitFrame.name:SetShadowColor(0.11, 0.22, 0.33, 0.44)
NamePlateUnitFrameMixin.ApplyFrameOptions(unitFrame)
assertFont(unitFrame.name, rothFont, 9, "OUTLINE", 1, -1, 0, 0, 0, 1, "reapplied name")
NamePlateUnitFrameMixin.OnUnitCleared(unitFrame)
assertFont(unitFrame.name, "blizzard-refreshed", 17, "MONOCHROME", 7, -7, 0.11, 0.22, 0.33, 0.44, "release baseline")
assertEqual(unitFrame.name.fontObject, nil, "direct baseline remains direct")

-- Combat release cannot mutate native font strings; restoration is deferred.
NamePlateBaseMixin.AcquireUnitFrame(plate)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame)
assertEqual(unitFrame.name.fontFile, rothFont, "custom font reapplied")
combat = true
NamePlateUnitFrameMixin.OnUnitCleared(unitFrame)
assertEqual(unitFrame.name.fontFile, rothFont, "combat release deferred")
combat = false
eventFrame:Trigger("PLAYER_REGEN_ENABLED")
assertFont(unitFrame.name, "blizzard-refreshed", 17, "MONOCHROME", 7, -7, 0.11, 0.22, 0.33, 0.44, "deferred restore")

-- Reassignment before regen cancels stale restore and captures the recycled baseline.
NamePlateBaseMixin.AcquireUnitFrame(plate)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame)
combat = true
NamePlateUnitFrameMixin.OnUnitCleared(unitFrame)
unitFrame.name:SetFont("blizzard-recycled", 18, "")
unitFrame.name:SetShadowOffset(8, -8)
unitFrame.name:SetShadowColor(0.9, 0.8, 0.7, 0.6)
NamePlateBaseMixin.AcquireUnitFrame(plate)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame)
combat = false
eventFrame:Trigger("PLAYER_REGEN_ENABLED")
assertFont(unitFrame.name, rothFont, 9, "OUTLINE", 1, -1, 0, 0, 0, 1, "recycled apply")
NamePlateUnitFrameMixin.OnUnitCleared(unitFrame)
assertFont(unitFrame.name, "blizzard-recycled", 18, "", 8, -8, 0.9, 0.8, 0.7, 0.6, "recycled restore")

-- Do not overwrite a newer foreign presentation that appeared after our apply.
NamePlateBaseMixin.AcquireUnitFrame(plate)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame)
unitFrame.name:SetFont("foreign-owner", 19, "MONOCHROME")
unitFrame.name:SetShadowOffset(9, -9)
unitFrame.name:SetShadowColor(0.12, 0.23, 0.34, 0.45)
NamePlateUnitFrameMixin.OnUnitCleared(unitFrame)
assertFont(unitFrame.name, "foreign-owner", 19, "MONOCHROME", 9, -9, 0.12, 0.23, 0.34, 0.45, "foreign owner preserved")

-- A Blizzard refresh through SetFontObject must restore the object itself, not
-- only a copied file/height/flags snapshot.
local refreshedObject = NewFontObject(
  "blizzard-object", 20, "OUTLINE", 10, -10, 0.21, 0.32, 0.43, 0.54
)
unitFrame.name:SetFontObject(refreshedObject)
NamePlateBaseMixin.AcquireUnitFrame(plate)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame)
assertEqual(unitFrame.name.fontObject, nil, "Roth apply overrides object locally")
NamePlateUnitFrameMixin.OnUnitCleared(unitFrame)
assertEqual(unitFrame.name.fontObject, refreshedObject, "release restores refreshed FontObject")
assertFont(unitFrame.name, "blizzard-object", 20, "OUTLINE", 10, -10, 0.21, 0.32, 0.43, 0.54, "object restore")

-- If shadow state cannot be read, the addon must not write an irreversible
-- shadow override even though it can still apply and restore the font object.
local shadowPlate, shadowFrame = NewUnitFrame("shadow-opaque")
shadowFrame.name.GetShadowOffset = nil
shadowFrame.name.GetShadowColor = nil
local originalShadowX, originalShadowY = shadowFrame.name.shadowX, shadowFrame.name.shadowY
local originalShadowR, originalShadowA = shadowFrame.name.shadowR, shadowFrame.name.shadowA
NamePlateBaseMixin.AcquireUnitFrame(shadowPlate)
NamePlateUnitFrameMixin.OnUnitSet(shadowFrame)
assertEqual(shadowFrame.name.shadowX, originalShadowX, "opaque shadow offset untouched")
assertEqual(shadowFrame.name.shadowY, originalShadowY, "opaque shadow Y untouched")
assertEqual(shadowFrame.name.shadowR, originalShadowR, "opaque shadow color untouched")
assertEqual(shadowFrame.name.shadowA, originalShadowA, "opaque shadow alpha untouched")
NamePlateUnitFrameMixin.OnUnitCleared(shadowFrame)
assertEqual(shadowFrame.name.fontObject, shadowFrame.name.initialFontObject, "opaque-shadow FontObject restored")

print("test_font_restore.lua: ok")
