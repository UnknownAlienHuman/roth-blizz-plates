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

local SECRET = {}

function canaccessvalue(value)
  return value ~= SECRET
end

function InCombatLockdown()
  return false
end

EventUtil = nil

local function NewRegion()
  local region = {
    shown = true,
    accessResult = true,
    forbiddenResult = false,
  }

  function region:CanBeAccessedInContext() return self.accessResult end
  function region:IsForbidden() return self.forbiddenResult end
  function region:CreateTexture()
    local texture = NewRegion()
    self.textures = self.textures or {}
    self.textures[#self.textures + 1] = texture
    return texture
  end
  function region:SetTexture(value) self.texture = value end
  function region:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
  function region:ClearAllPoints() end
  function region:SetPoint(...) self.point = { ... } end
  function region:SetSize(width, height) self.width, self.height = width, height end
  function region:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
  function region:SetAlphaFromBoolean(value, alphaIfTrue, alphaIfFalse)
    self.alphaSignal = value
    self.alphaIfTrue = alphaIfTrue
    self.alphaIfFalse = alphaIfFalse
  end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end

  return region
end

function hooksecurefunc(target, methodName, callback)
  local original = target[methodName]
  target[methodName] = function(...)
    local result = original(...)
    callback(...)
    return result
  end
end

CastingBarMixin = {
  GetEffectiveType = function(_, _, notInterruptible)
    if notInterruptible then
      return "uninterruptable"
    end
    return "standard"
  end,
}

-- Blizzard uses CreateFromMixins, which copies the function into a distinct
-- owner table before third-party addons normally install their hooks.
NamePlateCastingBarMixin = {
  GetEffectiveType = CastingBarMixin.GetEffectiveType,
  IsInterruptable = function()
    return SECRET
  end,
}

local baseMethodBeforeLoad = CastingBarMixin.GetEffectiveType
local nameplateMethodBeforeLoad = NamePlateCastingBarMixin.GetEffectiveType

local castBar = NewRegion()
setmetatable(castBar, { __index = NamePlateCastingBarMixin })
local container = NewRegion()
container.castBar = castBar
local unitFrame = NewRegion()
unitFrame.CastBarsContainer = container

RothBlizzPlatesDB = {
  enabled = true,
  castBar = { enabled = true },
  castBorder = {
    width = 220,
    height = 66,
    offsetX = -1,
    offsetY = -9,
    alpha = 1,
  },
}

assert(loadfile(ROOT .. "/castbar_12_1.lua"))("RothBlizzPlates")

assertEqual(CastingBarMixin.GetEffectiveType, baseMethodBeforeLoad, "generic CastingBarMixin must remain unhooked")
assertTrue(NamePlateCastingBarMixin.GetEffectiveType ~= nameplateMethodBeforeLoad, "exact nameplate mixin must be hooked")
assertEqual(RothBlizzPlates_CastBar.Prepare(unitFrame), true, "castbar preparation")
assertEqual(#castBar.textures, 2, "two owned border layers")

NamePlateCastingBarMixin.GetEffectiveType(castBar, false, SECRET, false, false)
assertEqual(castBar.textures[1].alphaSignal, SECRET, "exact copied mixin forwards secret signal")
assertEqual(castBar.textures[2].alphaSignal, SECRET, "blocked layer receives secret signal")

CastingBarMixin.GetEffectiveType(castBar, false, false, false, false)
assertEqual(castBar.textures[1].alphaSignal, SECRET, "generic castbar calls must not affect nameplates")
assertEqual(castBar.textures[2].alphaSignal, SECRET, "generic owner stays isolated")


-- Late attachment or combat deferral can miss the hook signal. The apply path
-- reads Blizzard's current possibly-secret interruptible boolean and sends it
-- directly to complementary native sinks.
local currentCastBar = NewRegion()
setmetatable(currentCastBar, { __index = NamePlateCastingBarMixin })
local currentContainer = NewRegion()
currentContainer.castBar = currentCastBar
local currentUnitFrame = NewRegion()
currentUnitFrame.CastBarsContainer = currentContainer
assertEqual(RothBlizzPlates_CastBar.Prepare(currentUnitFrame), true, "current-state preparation")
assertEqual(RothBlizzPlates_CastBar.Apply(currentUnitFrame), true, "current-state apply")
assertEqual(currentCastBar.textures[1].alphaSignal, SECRET, "native interruptible signal reaches interruptible layer")
assertEqual(currentCastBar.textures[1].alphaIfTrue, 255, "interruptible layer shown when native boolean is true")
assertEqual(currentCastBar.textures[1].alphaIfFalse, 0, "interruptible layer hidden when native boolean is false")
assertEqual(currentCastBar.textures[2].alphaSignal, SECRET, "native interruptible signal reaches blocked layer")
assertEqual(currentCastBar.textures[2].alphaIfTrue, 0, "blocked layer hidden when native boolean is true")
assertEqual(currentCastBar.textures[2].alphaIfFalse, 255, "blocked layer shown when native boolean is false")

print("test_castbar_hook_owner.lua: ok")
