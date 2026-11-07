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
local continueCallback

function canaccessvalue(value)
  return value ~= SECRET
end

function InCombatLockdown()
  return false
end

EventUtil = {
  ContinueOnAddOnLoaded = function(addonName, callback)
    assertEqual(addonName, "Blizzard_NamePlates", "continuation addon")
    continueCallback = callback
  end,
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
NamePlateCastingBarMixin = nil

local baseMethodBeforeLoad = CastingBarMixin.GetEffectiveType
assert(loadfile(ROOT .. "/castbar_12_1.lua"))("RothBlizzPlates")
assertEqual(CastingBarMixin.GetEffectiveType, baseMethodBeforeLoad, "generic source owner stays unhooked")
assertTrue(type(continueCallback) == "function", "exact-owner continuation registered")

-- Blizzard_NamePlates creates a distinct copied owner. The continuation hooks
-- that exact table; correctness does not depend on hooksecurefunc propagation
-- through CreateFromMixins.
NamePlateCastingBarMixin = {
  GetEffectiveType = CastingBarMixin.GetEffectiveType,
}
local exactMethodBeforeHook = NamePlateCastingBarMixin.GetEffectiveType
continueCallback()
assertTrue(NamePlateCastingBarMixin.GetEffectiveType ~= exactMethodBeforeHook, "exact copied owner hooked after load")
assertEqual(CastingBarMixin.GetEffectiveType, baseMethodBeforeLoad, "base owner still isolated")

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

assertEqual(RothBlizzPlates_CastBar.Prepare(unitFrame), true, "castbar preparation")
NamePlateCastingBarMixin.GetEffectiveType(castBar, false, SECRET, false, false)
assertEqual(castBar.textures[1].alphaSignal, SECRET, "exact post-load hook forwards secret signal")
assertEqual(castBar.textures[2].alphaSignal, SECRET, "blocked layer receives secret signal")

print("test_castbar_hook_preload.lua: ok")
