local ROOT = (... and ... ~= "" and ...) or "."

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assertNear(actual, expected, epsilon, message)
  if type(actual) ~= "number" or math.abs(actual - expected) > (epsilon or 0.0001) then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assertTrue(value, message)
  if not value then
    error(message or "expected true", 2)
  end
end

local SECRET_NOT_INTERRUPTIBLE = {}
local SECRET_ACCESS = {}
local combat = false
local allFrames = {}
local plates = {}
local plateByUnit = {}
local visibleScans = 0
local registeredSettings = {}

function canaccessvalue(value)
  return value ~= SECRET_NOT_INTERRUPTIBLE and value ~= SECRET_ACCESS
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

Settings = {
  VarType = { Boolean = "Boolean" },
  RegisterVerticalLayoutCategory = function(name)
    return { name = name }
  end,
  RegisterAddOnSetting = function(category, variable, key, tableRef, variableType, label, defaultValue)
    local setting = {
      category = category,
      variable = variable,
      key = key,
      tableRef = tableRef,
      variableType = variableType,
      label = label,
      defaultValue = defaultValue,
    }
    function setting:SetValueChangedCallback(callback)
      self.callback = callback
    end
    registeredSettings[#registeredSettings + 1] = setting
    return setting
  end,
  CreateCheckbox = function() end,
  RegisterAddOnCategory = function(category)
    category.registered = true
  end,
}

local function NewRegion(kind, native)
  local region = {
    kind = kind,
    native = native,
    shown = true,
    geometryWrites = 0,
    accessResult = true,
    forbiddenResult = false,
  }

  function region:CanBeAccessedInContext() return self.accessResult end
  function region:IsForbidden() return self.forbiddenResult end
  function region:CreateTexture(_, layer, _, sublevel)
    local texture = NewRegion("Texture", false)
    texture.layer = layer
    texture.sublevel = sublevel
    texture.parent = self
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

NamePlateBaseMixin = {
  AcquireUnitFrame = function() end,
}

NamePlateUnitFrameMixin = {
  ApplyFrameOptions = function() end,
  OnUnitSet = function() end,
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
  schemaVersion = 3,
  plate = { width = 900, height = 1, x = 6, y = 4, alpha = 2 },
  castBar = { enabled = true },
  castBorder = { width = 220, height = 66, offsetX = -1, offsetY = -9, alpha = 1 },
  font = { size = 2 },
}

assert(loadfile(ROOT .. "/core.lua"))("RothBlizzPlates")
assert(loadfile(ROOT .. "/castbar_12_1.lua"))("RothBlizzPlates")

assertEqual(RothBlizzPlatesDB.schemaVersion, 4, "database migrated")
assertEqual(RothBlizzPlatesDB.plate.width, 800, "plate width clamped")
assertEqual(RothBlizzPlatesDB.plate.height, 8, "plate height clamped")
assertEqual(RothBlizzPlatesDB.plate.alpha, 1, "plate alpha clamped")
assertNear(RothBlizzPlatesDB.plate.offsetX, 0, 0.0001, "plate X converted to health-bar offset")
assertNear(RothBlizzPlatesDB.plate.offsetY, 0.5, 0.0001, "plate Y converted to health-bar offset")
assertEqual(RothBlizzPlatesDB.plate.x, nil, "obsolete plate X removed")
assertEqual(RothBlizzPlatesDB.plate.y, nil, "obsolete plate Y removed")
assertEqual(RothBlizzPlatesDB.font.size, 5, "font size clamped")

local eventFrame = allFrames[1]
assertTrue(eventFrame ~= nil, "core event frame exists")
eventFrame:Trigger("PLAYER_LOGIN")
assertEqual(#registeredSettings, 4, "four standard settings registered")

-- Acquisition happens before Blizzard assigns the unit. Preparing at this
-- boundary lets the cast hook capture the first interruptibility signal.
local plate1, unitFrame1, healthBar1, castBar1 = NewUnitFrame()
plates[1] = plate1
plateByUnit.nameplate1 = plate1
NamePlateBaseMixin.AcquireUnitFrame(plate1)
assertTrue(healthBar1.textures == nil, "plate artwork waits for assignment")
assertEqual(#castBar1.textures, 2, "cast layers prepared at acquisition")
assertEqual(castBar1.textures[1].shown, false, "prepared cast layer stays hidden")
assertEqual(castBar1.textures[2].shown, false, "second prepared layer stays hidden")

CastingBarMixin.GetEffectiveType(castBar1, false, SECRET_NOT_INTERRUPTIBLE, false, false)
NamePlateUnitFrameMixin.ApplyFrameOptions(unitFrame1)
assertTrue(healthBar1.textures == nil, "frame options do not activate before OnUnitSet")
NamePlateUnitFrameMixin.OnUnitSet(unitFrame1)
eventFrame:Trigger("NAME_PLATE_UNIT_ADDED", "nameplate1")

assertEqual(#healthBar1.textures, 1, "one owned plate texture created")
assertEqual(#castBar1.textures, 2, "prepared cast textures reused")
assertEqual(healthBar1.geometryWrites, 0, "native health geometry untouched")
assertEqual(castBar1.geometryWrites, 0, "native cast geometry untouched")
assertEqual(unitFrame1.geometryWrites, 0, "native unit-frame geometry untouched")
assertEqual(healthBar1.nativeTextureWrites or 0, 0, "native health texture untouched")
assertEqual(castBar1.nativeTextureWrites or 0, 0, "native cast texture untouched")
assertEqual(visibleScans, 0, "single acquisition does not scan all nameplates")

local plateTexture = healthBar1.textures[1]
assertEqual(plateTexture.point[1], "CENTER", "plate anchored by center")
assertEqual(plateTexture.point[2], healthBar1, "plate anchored to native health bar")
assertNear(plateTexture.point[4], 0, 0.0001, "plate X uses converted offset")
assertNear(plateTexture.point[5], 0.5, 0.0001, "plate Y uses converted offset")

local firstCastTexture = castBar1.textures[1]
local secondCastTexture = castBar1.textures[2]
assertEqual(firstCastTexture.alphaSignal, SECRET_NOT_INTERRUPTIBLE, "initial secret signal preserved")
assertEqual(secondCastTexture.alphaSignal, SECRET_NOT_INTERRUPTIBLE, "initial signal reaches both layers")
assertEqual(firstCastTexture.alphaIfTrue, 0, "interruptible layer hidden when blocked")
assertEqual(firstCastTexture.alphaIfFalse, 255, "interruptible layer shown when allowed")
assertEqual(secondCastTexture.alphaIfTrue, 255, "blocked layer shown when blocked")
assertEqual(secondCastTexture.alphaIfFalse, 0, "blocked layer hidden when allowed")

CastingBarMixin.GetEffectiveType(castBar1, false, nil, false, false)
assertEqual(firstCastTexture.alphaSignal, true, "nil interruptibility fails closed")
assertEqual(secondCastTexture.alphaSignal, true, "nil uses conservative border")
CastingBarMixin.GetEffectiveType(castBar1, false, SECRET_NOT_INTERRUPTIBLE, false, false)

NamePlateUnitFrameMixin.ApplyFrameOptions(unitFrame1)
assertEqual(firstCastTexture.alphaSignal, SECRET_NOT_INTERRUPTIBLE, "layout refresh preserves secret alpha")
assertEqual(#healthBar1.textures, 1, "layout refresh reuses plate")
assertEqual(#castBar1.textures, 2, "layout refresh reuses cast layers")

eventFrame:Trigger("PLAYER_ENTERING_WORLD")
assertEqual(visibleScans, 1, "initial refresh performs one bounded scan")
assertEqual(#healthBar1.textures, 1, "refresh does not duplicate plate")
assertEqual(#castBar1.textures, 2, "refresh does not duplicate cast layers")

-- A secret object-security predicate must fail closed before Lua branches on it.
local restrictedPlate, restrictedUnitFrame, restrictedHealthBar = NewUnitFrame()
restrictedUnitFrame.accessResult = SECRET_ACCESS
restrictedPlate.UnitFrame = restrictedUnitFrame
assertEqual(RothBlizzPlates.Prepare(restrictedUnitFrame), false, "secret access result rejected")
assertTrue(restrictedHealthBar.textures == nil, "restricted frame creates no regions")

-- Combat acquisition is generation-tagged. Released work must not apply later.
local plate2, unitFrame2, healthBar2, castBar2 = NewUnitFrame()
combat = true
NamePlateBaseMixin.AcquireUnitFrame(plate2)
CastingBarMixin.GetEffectiveType(castBar2, false, SECRET_NOT_INTERRUPTIBLE, false, false)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame2)
assertTrue(healthBar2.textures == nil, "combat acquisition defers plate creation")
assertTrue(castBar2.textures == nil, "combat acquisition defers cast creation")
NamePlateUnitFrameMixin.OnUnitCleared(unitFrame2)
combat = false
eventFrame:Trigger("PLAYER_REGEN_ENABLED")
assertTrue(healthBar2.textures == nil, "stale deferred plate is dropped")
assertTrue(castBar2.textures == nil, "stale deferred cast is dropped")

local plate3, unitFrame3, healthBar3, castBar3 = NewUnitFrame()
combat = true
NamePlateBaseMixin.AcquireUnitFrame(plate3)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame3)
combat = false
eventFrame:Trigger("PLAYER_REGEN_ENABLED")
assertEqual(#healthBar3.textures, 1, "deferred frame applies after combat")
assertEqual(#castBar3.textures, 2, "deferred cast applies after combat")
assertEqual(castBar3.textures[1].alphaSignal, true, "missed combat signal fails closed")
assertEqual(castBar3.textures[2].alphaSignal, true, "second layer also fails closed")

NamePlateUnitFrameMixin.OnUnitCleared(unitFrame3)
assertEqual(healthBar3.textures[1].shown, false, "owned plate hidden on recycle")
assertEqual(castBar3.textures[1].shown, false, "cast layer hidden on recycle")
assertEqual(castBar3.textures[2].shown, false, "second cast layer hidden on recycle")

NamePlateBaseMixin.AcquireUnitFrame(plate3)
CastingBarMixin.GetEffectiveType(castBar3, false, SECRET_NOT_INTERRUPTIBLE, false, false)
NamePlateUnitFrameMixin.OnUnitSet(unitFrame3)
assertEqual(#healthBar3.textures, 1, "recycled frame reuses plate texture")
assertEqual(#castBar3.textures, 2, "recycled frame reuses cast textures")
assertEqual(castBar3.textures[1].alphaSignal, SECRET_NOT_INTERRUPTIBLE, "recycled assignment captures initial signal")
assertEqual(castBar3.textures[2].alphaSignal, SECRET_NOT_INTERRUPTIBLE, "recycled blocked layer captures signal")

-- Event fallback still styles a fully assigned frame if the lifecycle hook was
-- unavailable during that acquisition.
local plate4, _, healthBar4, castBar4 = NewUnitFrame()
plateByUnit.nameplate4 = plate4
eventFrame:Trigger("NAME_PLATE_UNIT_ADDED", "nameplate4")
assertEqual(#healthBar4.textures, 1, "event fallback creates plate")
assertEqual(#castBar4.textures, 2, "event fallback creates cast layers")

-- Settings callbacks coalesce through the same bounded refresh path.
RothBlizzPlatesDB.castBar.enabled = false
registeredSettings[2].callback()
assertEqual(firstCastTexture.shown, false, "cast setting hides interruptible layer")
assertEqual(secondCastTexture.shown, false, "cast setting hides blocked layer")

print("test_combat_deferral.lua: ok")
