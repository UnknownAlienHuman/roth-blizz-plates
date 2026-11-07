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

function canaccessvalue() return true end
function InCombatLockdown() return false end
EventUtil = nil

local runtimeSupported = false
RothBlizzPlates = {
  IsRuntimeSupported = function()
    return runtimeSupported
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

NamePlateCastingBarMixin = {
  GetEffectiveType = function(_, _, notInterruptible)
    return notInterruptible and "uninterruptable" or "standard"
  end,
  IsInterruptable = function()
    return true
  end,
}

local originalMethod = NamePlateCastingBarMixin.GetEffectiveType

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

local castBar = NewRegion()
setmetatable(castBar, { __index = NamePlateCastingBarMixin })
local container = NewRegion()
container.castBar = castBar
local unitFrame = NewRegion()
unitFrame.CastBarsContainer = container

assert(loadfile(ROOT .. "/castbar_12_1.lua"))("RothBlizzPlates")

assertEqual(NamePlateCastingBarMixin.GetEffectiveType, originalMethod, "unsupported runtime installs no hook")
assertEqual(RothBlizzPlates_CastBar.Prepare(unitFrame), false, "unsupported runtime rejects prepare")
assertEqual(RothBlizzPlates_CastBar.Apply(unitFrame), false, "unsupported runtime rejects apply")
assertEqual(castBar.textures, nil, "unsupported runtime creates no textures")

runtimeSupported = true
assertEqual(RothBlizzPlates_CastBar.InstallHooks(), true, "supported runtime installs exact hook")
assertTrue(NamePlateCastingBarMixin.GetEffectiveType ~= originalMethod, "exact method hooked after support")
assertEqual(RothBlizzPlates_CastBar.Prepare(unitFrame), true, "supported runtime prepares")
assertEqual(#castBar.textures, 2, "supported runtime creates owned layers")

print("test_castbar_runtime_gate.lua: ok")
