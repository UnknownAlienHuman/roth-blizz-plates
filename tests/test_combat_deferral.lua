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

local SECRET_NOT_INTERRUPTIBLE = {}
local combat = false
local allFrames = {}
local plates = {}
local plateByUnit = {}
local visibleScans = 0

function canaccessvalue(value)
  return value ~= SECRET_NOT_INTERRUPTIBLE
end

function GetBuildInfo()
  return "12.1.5", "70688", "Oct 2026", 120105
end

function GetLocale()
  return "enUS"
end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
SlashCmdList = {}

function InCombatLockdown()
  return combat
end

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

local function NewRegion(kind, native)
  local region = {
    kind = kind,
    native = native,
    shown = true,
    geometryWrites = 0,
  }

  function region:CanBeAccessedInContext() return true end
  function region:IsForbidden() return false end
  function region:CreateTexture(_, layer, _, sublevel)
    local texture = NewRegion("Texture", false)
    texture.layer = layer
    texture.sublevel = sublevel
    self.textures = self.textures or {}
    self.textures[#self.textures + 1] = texture
    return texture
  end
  function region:SetTexture(value) self.texture = value end
  function region:SetStatusBarTexture(value)
    if self.native then self.nativeTextureWrites = (self.nativeTextureWrites or 0) + 1 end
    self.statusBarTexture = value
  end
  function region:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
  function region:ClearAllPoints()
    if self.native then self.geometryWrites = self.geometryWrites + 1 end
    self.point = nil
  end
  function region:SetPoint(...)
    if self.native then self.geometryWrites = self.geometryWrites + 1 end
    self.point = { ... }
  end
  function region:SetSize(width, height)
    if self.native then self.geometryWrites = self.geometryWrites + 1 end
    self.width, self.height = width, height
  end
  function region:SetAlpha(alpha) self.alpha = alpha end
  function region:SetAlphaFromBoolean(value, alphaIfTrue, alphaIfFalse)
    self.alphaSignal = value
    self.alphaIfTrue = alphaIfTrue
    self.alphaIfFalse = alphaIfFalse
  end
  function region:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
  function region:SetFont(path, size, outline) self.font = { path, size, outline } end
  function region:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
  function region:SetShadowColor(r, g, b, a) self.shadowColor = { r, g, b, a } end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end

  return region
end

function CreateFrame()
  local frame = NewRegion("Frame", false)
  frame.events = {}
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterEvent(event) self.events[event] = nil end
  function frame:SetScript(script, callback) self[script] = callback end
  function frame:Trigger(event, ...)
    if self.events[event] and self.OnEvent then
      self:OnEvent(event, ...)
    end
  end
  allFrames[#allFrames + 1] = frame
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

NamePlateUnitFrameMixin = {
  ApplyFrameOptions = function() end,
  OnUnitCleared = function() end,
}

CastingBarMixin = {
  GetEffectiveType = function(_, _, notInterruptible)
    return notInterruptible and "uninterruptable" or "standard"
  end,
}

local function NewUnitFrame()
  local healthBar = NewRegion("StatusBar", true)
  healthBar.Text = NewRegion("FontString", true)
  healthBar.LeftText = NewRegion("FontString", true)
  healthBar.RightText = NewRegion("FontString", true)

  local castBar = NewRegion("StatusBar", true)
  castBar.Text = NewRegion("FontString", true)
  castBar.CastTargetNameText = NewRegion("FontString", true)
  setmetatable(castBar, { __index = CastingBarMixin })

  local healthContainer = NewRegion("Frame", true)
  healthContainer.healthBar = healthBar
  local castContainer = NewRegion("Frame", true)
  castContainer.castBar = castBar

  local unitFrame = NewRegion("Frame", true)
  unitFrame.HealthBarsContainer = healthContainer
  unitFrame.CastBarsContainer = castContainer
  unitFrame.name = NewRegion("FontString", true)
  unitFrame.castBar = error -- decoy: canonical path must be used

  local namePlate = NewRegion("Frame", true)
  namePlate.UnitFrame = unitFrame
  return namePlate, unitFrame, healthBar, castBar
end

C_NamePlate = {
  GetNamePlateForUnit = function(unit)
    return plateByUnit[unit]
  end,
  GetNamePlates = function()
    visibleScans = visibleScans + 1
    return plates
  end,
}

RothBlizzPlatesDB = {
  schemaVersion = 2,
  plate = { width = 900, height = 1, alpha = 2 },
  castBar = { enabled = true, x = 1, y = -19 },
  castBorder = { width = 220, height = 66, x = 0, y = -28 },
  font = { size = 2 },
}

assert(loadfile(ROOT .. "/core.lua"))("RothBlizzPlates")
assert(loadfile(ROOT .. "/castbar_12_1.lua"))("RothBlizzPlates")

assertEqual(RothBlizzPlatesDB.schemaVersion, 3, "database migrated")
assertEqual(RothBlizzPlatesDB.plate.width, 800, "plate width clamped")
assertEqual(RothBlizzPlatesDB.plate.height, 8, "plate height clamped")
assertEqual(RothBlizzPlatesDB.plate.alpha, 1, "plate alpha clamped")
assertEqual(RothBlizzPlatesDB.castBorder.offsetX, -1, "cast X migrated")
assertEqual(RothBlizzPlatesDB.castBorder.offsetY, -9, "cast Y migrated")
assertEqual(RothBlizzPlatesDB.font.size, 5, "font size clamped")

local eventFrame = allFrames[1]
assertTrue(eventFrame ~= nil, "core event frame exists")
assertTrue(not eventFrame.events.ADDON_LOADED, "resolved load hook is unregistered")

local plate1, unitFrame1, healthBar1, castBar1 = NewUnitFrame()
plates[1] = plate1
plateByUnit.nameplate1 = plate1
eventFrame:Trigger("NAME_PLATE_UNIT_ADDED", "nameplate1")

assertEqual(#healthBar1.textures, 1, "one owned plate texture created")
assertEqual(#castBar1.textures, 2, "two owned cast-border textures created")
assertEqual(healthBar1.geometryWrites, 0, "native health geometry untouched")
assertEqual(castBar1.geometryWrites, 0, "native cast geometry untouched")
assertEqual(unitFrame1.geometryWrites, 0, "native unit-frame geometry untouched")
assertEqual(healthBar1.nativeTextureWrites or 0, 0, "native health texture untouched")
assertEqual(castBar1.nativeTextureWrites or 0, 0, "native cast texture untouched")
assertEqual(visibleScans, 0, "single acquisition does not scan all nameplates")

local firstCastTexture = castBar1.textures[1]
local secondCastTexture = castBar1.textures[2]
assertEqual(firstCastTexture.alphaSignal, true, "new frames start conservatively blocked")
assertEqual(secondCastTexture.alphaSignal, true, "both layers receive the conservative state")

CastingBarMixin.GetEffectiveType(castBar1, false, SECRET_NOT_INTERRUPTIBLE, false, false)
assertEqual(firstCastTexture.alphaSignal, SECRET_NOT_INTERRUPTIBLE, "secret not-interruptible signal passed through")
assertEqual(secondCastTexture.alphaSignal, SECRET_NOT_INTERRUPTIBLE, "secret signal reaches both layers")
assertEqual(firstCastTexture.alphaIfTrue, 0, "interruptible layer hidden when blocked")
assertEqual(firstCastTexture.alphaIfFalse, 255, "interruptible layer shown when allowed")
assertEqual(secondCastTexture.alphaIfTrue, 255, "blocked layer shown when blocked")
assertEqual(secondCastTexture.alphaIfFalse, 0, "blocked layer hidden when allowed")

CastingBarMixin.GetEffectiveType(castBar1, false, nil, false, false)
assertEqual(firstCastTexture.alphaSignal, true, "nil interruptibility fails closed")
assertEqual(secondCastTexture.alphaSignal, true, "nil interruptibility uses conservative border")
CastingBarMixin.GetEffectiveType(castBar1, false, SECRET_NOT_INTERRUPTIBLE, false, false)

NamePlateUnitFrameMixin.ApplyFrameOptions(unitFrame1)
assertEqual(firstCastTexture.alphaSignal, SECRET_NOT_INTERRUPTIBLE, "layout refresh preserves secret alpha state")
assertEqual(secondCastTexture.alphaSignal, SECRET_NOT_INTERRUPTIBLE, "second layer preserves secret alpha state")
assertEqual(#healthBar1.textures, 1, "layout refresh reuses the owned plate")
assertEqual(#castBar1.textures, 2, "layout refresh reuses cast layers")

eventFrame:Trigger("PLAYER_ENTERING_WORLD")
assertEqual(visibleScans, 1, "initial refresh performs one bounded scan")
assertEqual(#healthBar1.textures, 1, "visible refresh does not duplicate plate texture")
assertEqual(#castBar1.textures, 2, "visible refresh does not duplicate cast textures")

local plate2, unitFrame2, healthBar2, castBar2 = NewUnitFrame()
plateByUnit.nameplate2 = plate2
combat = true
eventFrame:Trigger("NAME_PLATE_UNIT_ADDED", "nameplate2")
assertTrue(healthBar2.textures == nil, "combat acquisition defers region creation")
assertTrue(castBar2.textures == nil, "combat acquisition defers cast regions")
eventFrame:Trigger("NAME_PLATE_UNIT_REMOVED", "nameplate2")
combat = false
eventFrame:Trigger("PLAYER_REGEN_ENABLED")
assertTrue(healthBar2.textures == nil, "stale deferred frame is dropped")
assertTrue(castBar2.textures == nil, "stale deferred cast frame is dropped")

local plate3, unitFrame3, healthBar3, castBar3 = NewUnitFrame()
plateByUnit.nameplate3 = plate3
combat = true
eventFrame:Trigger("NAME_PLATE_UNIT_ADDED", "nameplate3")
combat = false
eventFrame:Trigger("PLAYER_REGEN_ENABLED")
assertEqual(#healthBar3.textures, 1, "deferred frame applies after combat")
assertEqual(#castBar3.textures, 2, "deferred cast frame applies after combat")

NamePlateUnitFrameMixin.OnUnitCleared(unitFrame3)
assertEqual(healthBar3.textures[1].shown, false, "owned plate hidden on recycle")
assertEqual(castBar3.textures[1].shown, false, "cast layer hidden on recycle")
assertEqual(castBar3.textures[2].shown, false, "second cast layer hidden on recycle")

plateByUnit.nameplate4 = plate3
eventFrame:Trigger("NAME_PLATE_UNIT_ADDED", "nameplate4")
assertEqual(#healthBar3.textures, 1, "recycled frame reuses plate texture")
assertEqual(#castBar3.textures, 2, "recycled frame reuses cast textures")
CastingBarMixin.GetEffectiveType(castBar3, false, SECRET_NOT_INTERRUPTIBLE, false, false)
assertEqual(castBar3.textures[1].alphaSignal, SECRET_NOT_INTERRUPTIBLE, "recycled owner mapping restored")
assertEqual(castBar3.textures[2].alphaSignal, SECRET_NOT_INTERRUPTIBLE, "recycled blocked layer receives signal")

print("test_combat_deferral.lua: ok")
