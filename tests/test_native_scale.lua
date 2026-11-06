local ROOT = (... and ... ~= "" and ...) or "."

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assertNear(actual, expected, epsilon, message)
  if type(actual) ~= "number" or math.abs(actual - expected) > epsilon then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assertTrue(value, message)
  if not value then
    error(message or "expected true", 2)
  end
end

local SECRET_SCALE = {}
local eventFrames = {}
local combat = false

function canaccessvalue(value)
  return value ~= SECRET_SCALE
end

function canaccesstable(value)
  return type(value) == "table"
end

function GetBuildInfo()
  return "12.1.5", "70688", "Nov 2026", 120105
end

function GetLocale()
  return "enUS"
end

function InCombatLockdown()
  return combat
end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SlashCmdList = {}

C_Timer = {
  After = function(_, callback)
    callback()
  end,
}

EventUtil = {
  ContinueOnAddOnLoaded = function(_, callback)
    callback()
  end,
}

Settings = nil

local function NewRegion(native)
  local region = {
    native = native == true,
    shown = true,
    geometryWrites = 0,
    fontFile = "Fonts\\FRIZQT__.TTF",
    fontHeight = 12,
    fontFlags = "",
    shadowX = 0,
    shadowY = 0,
    shadowR = 0,
    shadowG = 0,
    shadowB = 0,
    shadowA = 0,
  }

  function region:CanBeAccessedInContext()
    return true
  end

  function region:IsForbidden()
    return false
  end

  function region:CreateTexture(_, layer, _, sublevel)
    local texture = NewRegion(false)
    texture.layer = layer
    texture.sublevel = sublevel
    self.textures = self.textures or {}
    self.textures[#self.textures + 1] = texture
    return texture
  end

  function region:SetTexture(value)
    self.texture = value
  end

  function region:SetDrawLayer(layer, sublevel)
    self.layer = layer
    self.sublevel = sublevel
  end

  function region:ClearAllPoints()
    if self.native then
      self.geometryWrites = self.geometryWrites + 1
    end
    self.point = nil
  end

  function region:SetPoint(...)
    if self.native then
      self.geometryWrites = self.geometryWrites + 1
    end
    self.point = { ... }
  end

  function region:SetSize(width, height)
    if self.native then
      self.geometryWrites = self.geometryWrites + 1
    end
    self.width = width
    self.height = height
  end

  function region:SetAlpha(alpha)
    self.alpha = alpha
  end

  function region:SetAlphaFromBoolean(value, alphaIfTrue, alphaIfFalse)
    self.alphaSignal = value
    self.alphaIfTrue = alphaIfTrue
    self.alphaIfFalse = alphaIfFalse
  end

  function region:SetVertexColor(r, g, b, a)
    self.vertexColor = { r, g, b, a }
  end

  function region:GetFont()
    return self.fontFile, self.fontHeight, self.fontFlags
  end

  function region:SetFont(path, height, flags)
    self.fontFile = path
    self.fontHeight = height
    self.fontFlags = flags
  end

  function region:GetShadowOffset()
    return self.shadowX, self.shadowY
  end

  function region:SetShadowOffset(x, y)
    self.shadowX = x
    self.shadowY = y
  end

  function region:GetShadowColor()
    return self.shadowR, self.shadowG, self.shadowB, self.shadowA
  end

  function region:SetShadowColor(r, g, b, a)
    self.shadowR = r
    self.shadowG = g
    self.shadowB = b
    self.shadowA = a
  end

  function region:Show()
    self.shown = true
  end

  function region:Hide()
    self.shown = false
  end

  return region
end

function CreateFrame()
  local frame = NewRegion(false)
  frame.events = {}

  function frame:RegisterEvent(event)
    self.events[event] = true
  end

  function frame:SetScript(scriptName, callback)
    self[scriptName] = callback
  end

  function frame:Trigger(event, ...)
    if self.events[event] and self.OnEvent then
      self:OnEvent(event, ...)
    end
  end

  eventFrames[#eventFrames + 1] = frame
  return frame
end

function hooksecurefunc(target, methodName, callback)
  local original = target[methodName]
  target[methodName] = function(...)
    local results = { original(...) }
    callback(...)
    return table.unpack(results)
  end
end

NamePlateBaseMixin = {
  AcquireUnitFrame = function() end,
}

NamePlateUnitFrameMixin = {
  ApplyFrameOptions = function() end,
  OnUnitSet = function() end,
  OnUnitCleared = function() end,
}

NamePlateCastingBarMixin = {
  GetEffectiveType = function(_, _, notInterruptible)
    return notInterruptible and "uninterruptable" or "standard"
  end,
}

local function NewUnitFrame()
  local healthBar = NewRegion(true)
  healthBar.Text = NewRegion(true)
  healthBar.LeftText = NewRegion(true)
  healthBar.RightText = NewRegion(true)

  local castBar = NewRegion(true)
  castBar.Text = NewRegion(true)
  castBar.CastTargetNameText = NewRegion(true)
  castBar.IsInterruptable = function()
    return true
  end
  setmetatable(castBar, { __index = NamePlateCastingBarMixin })

  local healthContainer = NewRegion(true)
  healthContainer.healthBar = healthBar

  local castContainer = NewRegion(true)
  castContainer.castBar = castBar

  local unitFrame = NewRegion(true)
  unitFrame.HealthBarsContainer = healthContainer
  unitFrame.CastBarsContainer = castContainer
  unitFrame.name = NewRegion(true)

  local namePlate = NewRegion(true)
  namePlate.UnitFrame = unitFrame

  return namePlate, unitFrame, healthBar, castBar
end

local plates = {}
local plateByUnit = {}

C_NamePlate = {
  GetNamePlateForUnit = function(unit)
    return plateByUnit[unit]
  end,
  GetNamePlates = function()
    return plates
  end,
}

NamePlateSetupOptions = {
  horizontalScale = 1,
  verticalScale = 1,
}

RothBlizzPlatesDB = {
  schemaVersion = 4,
  enabled = true,
  plate = {
    enabled = true,
    width = 180,
    height = 60,
    offsetX = 2,
    offsetY = 0.5,
    alpha = 1,
  },
  castBar = { enabled = true },
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

assert(loadfile(ROOT .. "/core.lua"))("RothBlizzPlates")
assert(loadfile(ROOT .. "/castbar_12_1.lua"))("RothBlizzPlates")

local plate, unitFrame, healthBar, castBar = NewUnitFrame()
plates[1] = plate
plateByUnit.nameplate1 = plate

NamePlateBaseMixin.AcquireUnitFrame(plate)
NamePlateUnitFrameMixin.ApplyFrameOptions(unitFrame, {
  horizontalScale = 0.75,
  verticalScale = 0.8,
})
NamePlateUnitFrameMixin.OnUnitSet(unitFrame)

assertEqual(#healthBar.textures, 1, "one plate texture")
assertEqual(#castBar.textures, 2, "two cast textures")

local plateTexture = healthBar.textures[1]
assertNear(plateTexture.width, 135, 0.001, "small plate width")
assertNear(plateTexture.height, 48, 0.001, "small plate height")
assertNear(plateTexture.point[4], 1.5, 0.001, "small plate X")
assertNear(plateTexture.point[5], 0.4, 0.001, "small plate Y")

local interruptible = castBar.textures[1]
local blocked = castBar.textures[2]
for _, texture in ipairs({ interruptible, blocked }) do
  assertNear(texture.width, 165, 0.001, "small cast width")
  assertNear(texture.height, 52.8, 0.001, "small cast height")
  assertNear(texture.point[4], -0.75, 0.001, "small cast X")
  assertNear(texture.point[5], -7.2, 0.001, "small cast Y")
end

assertNear(unitFrame.name.fontHeight, 7.2, 0.001, "small name font")
assertNear(healthBar.Text.fontHeight, 7.2, 0.001, "small health font")
assertNear(castBar.Text.fontHeight, 7.2, 0.001, "small cast font")

NamePlateUnitFrameMixin.ApplyFrameOptions(unitFrame, {
  horizontalScale = 1.6,
  verticalScale = 1.6,
})

assertEqual(#healthBar.textures, 1, "plate texture reused")
assertEqual(#castBar.textures, 2, "cast textures reused")
assertNear(plateTexture.width, 288, 0.001, "huge plate width")
assertNear(plateTexture.height, 96, 0.001, "huge plate height")
assertNear(plateTexture.point[4], 3.2, 0.001, "huge plate X")
assertNear(plateTexture.point[5], 0.8, 0.001, "huge plate Y")
assertNear(interruptible.width, 352, 0.001, "huge cast width")
assertNear(interruptible.height, 105.6, 0.001, "huge cast height")
assertNear(interruptible.point[4], -1.6, 0.001, "huge cast X")
assertNear(interruptible.point[5], -14.4, 0.001, "huge cast Y")
assertNear(unitFrame.name.fontHeight, 14.4, 0.001, "huge name font")

NamePlateUnitFrameMixin.ApplyFrameOptions(unitFrame, {
  horizontalScale = SECRET_SCALE,
  verticalScale = SECRET_SCALE,
})
assertNear(plateTexture.width, 288, 0.001, "secret scale ignored")
assertNear(interruptible.width, 352, 0.001, "secret cast scale ignored")

assertEqual(healthBar.geometryWrites, 0, "native health geometry untouched")
assertEqual(castBar.geometryWrites, 0, "native cast geometry untouched")
assertEqual(unitFrame.geometryWrites, 0, "native unit geometry untouched")

NamePlateSetupOptions.horizontalScale = 1.25
NamePlateSetupOptions.verticalScale = 1.25
local fallbackPlate, fallbackUnitFrame, fallbackHealthBar, fallbackCastBar = NewUnitFrame()
plateByUnit.nameplate2 = fallbackPlate
NamePlateBaseMixin.AcquireUnitFrame(fallbackPlate)
NamePlateUnitFrameMixin.OnUnitSet(fallbackUnitFrame)

assertNear(fallbackHealthBar.textures[1].width, 225, 0.001, "fallback plate width")
assertNear(fallbackHealthBar.textures[1].height, 75, 0.001, "fallback plate height")
assertNear(fallbackCastBar.textures[1].width, 275, 0.001, "fallback cast width")
assertNear(fallbackCastBar.textures[1].height, 82.5, 0.001, "fallback cast height")
assertNear(fallbackUnitFrame.name.fontHeight, 11.25, 0.001, "fallback font height")

print("test_native_scale.lua: ok")
