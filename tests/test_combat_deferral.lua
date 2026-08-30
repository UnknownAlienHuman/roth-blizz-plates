local combat = false
local createdTextures = 0
local mutationCount = 0
local eventFrames = {}

local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function newRegion(objectType, parent)
  local region = {
    objectType = objectType or "Frame",
    parent = parent,
    width = 100,
    height = 10,
    point = "CENTER",
    relativeTo = parent,
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    shown = true,
  }

  function region:CanBeAccessedInContext() return true end
  function region:IsForbidden() return false end
  function region:GetObjectType() return self.objectType end
  function region:GetParent() return self.parent end
  function region:GetWidth() return self.width end
  function region:GetHeight() return self.height end
  function region:GetPoint()
    return self.point, self.relativeTo, self.relativePoint, self.x, self.y
  end
  function region:ClearAllPoints()
    mutationCount = mutationCount + 1
    self.point, self.relativeTo, self.relativePoint, self.x, self.y = nil, nil, nil, nil, nil
  end
  function region:SetPoint(point, relativeTo, relativePoint, x, y)
    mutationCount = mutationCount + 1
    self.point, self.relativeTo, self.relativePoint, self.x, self.y = point, relativeTo, relativePoint, x, y
  end
  function region:SetAllPoints(relativeTo)
    mutationCount = mutationCount + 1
    self.point, self.relativeTo, self.relativePoint, self.x, self.y = "ALL", relativeTo, "ALL", 0, 0
  end
  function region:SetSize(width, height)
    mutationCount = mutationCount + 1
    self.width, self.height = width, height
  end
  function region:SetTexture(texture) self.texture = texture end
  function region:GetTexture() return self.texture end
  function region:SetAtlas(atlas) self.atlas = atlas end
  function region:SetAlpha(alpha) self.alpha = alpha end
  function region:SetDrawLayer(layer, subLevel) self.layer, self.subLevel = layer, subLevel end
  function region:SetTexCoord(...) self.texCoord = { ... } end
  function region:SetFont(path, size, flags) self.font = { path, size, flags } end
  function region:GetFont() return "default", 8, "OUTLINE" end
  function region:SetShadowOffset() end
  function region:SetShadowColor() end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end
  function region:IsShown() return self.shown end
  function region:CreateTexture(_, layer, _, subLevel)
    createdTextures = createdTextures + 1
    local texture = newRegion("Texture", self)
    texture.layer, texture.subLevel = layer, subLevel
    return texture
  end

  return region
end

local function newStatusBar(parent)
  local bar = newRegion("StatusBar", parent)
  local texture = newRegion("Texture", bar)
  texture.texture = "BlizzardOriginal"
  texture.vertex = { 0.4, 0.4, 0.4, 1 }
  function texture:GetVertexColor() return unpack(self.vertex) end
  function bar:SetStatusBarTexture(path) texture.texture = path end
  function bar:GetStatusBarTexture() return texture end
  function bar:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
  function bar:SetValue(value) self.value = value end
  function bar:GetStatusBarColor() return 0.4, 0.4, 0.4, 1 end
  return bar, texture
end

function InCombatLockdown() return combat end
function canaccessvalue(value) return value ~= _G.SECRET end
function issecretvalue(value) return value == _G.SECRET end
function GetLocale() return "enUS" end
STANDARD_TEXT_FONT = "standard-font"
Settings = nil
EventUtil = nil
C_NamePlate = nil
CompactUnitFrame_UpdateSelectionHighlight = nil
NamePlateUnitFrameMixin = nil
NamePlateBaseMixin = nil
CastingBarMixin = nil
SlashCmdList = {}

function CreateFrame()
  local frame = newRegion("Frame", nil)
  function frame:RegisterEvent(event) self.registeredEvent = event end
  function frame:SetScript(scriptName, callback) self[scriptName] = callback end
  eventFrames[#eventFrames + 1] = frame
  return frame
end

local coreChunk = assert(loadfile("core.lua"))
coreChunk("RothBlizzPlates")

local unitFrame = newRegion("Frame", nil)
local healthBar = newStatusBar(unitFrame)
unitFrame.healthBar = healthBar
unitFrame.name = newRegion("FontString", unitFrame)

combat = true
local beforeCombatMutations = mutationCount
assertEq(_G.RothBlizzPlates.ApplySkin(unitFrame), false, "core must defer in combat")
assertEq(mutationCount, beforeCombatMutations, "core mutated geometry in combat")
assertEq(createdTextures, 0, "core created texture in combat")
assertEq(_G.RothBlizzPlates.GetPendingCount(), 1, "core pending count")

combat = false
assertEq(_G.RothBlizzPlates.ApplySkin(unitFrame), true, "core apply after combat")
assert(createdTextures > 0, "core did not create the addon-owned plate out of combat")
assertEq(_G.RothBlizzPlates.GetPendingCount(), 0, "core pending did not clear")

RothBlizzPlatesDB.castBar.enabled = true
local castChunk = assert(loadfile("castbar_12_1.lua"))
castChunk("RothBlizzPlates")

local castContainer, castTexture = newStatusBar(unitFrame)
castContainer.Icon = newRegion("Texture", castContainer)
castContainer.notInterruptible = _G.SECRET
unitFrame.castBar = castContainer
unitFrame.__RothScaleX = 1
unitFrame.__RothScaleY = 1

combat = true
beforeCombatMutations = mutationCount
assertEq(_G.RothBlizzPlates_CastBar.Apply(unitFrame), false, "castbar must defer in combat")
assertEq(mutationCount, beforeCombatMutations, "castbar mutated geometry in combat")
assertEq(_G.RothBlizzPlates_CastBar.GetPendingCount(), 1, "castbar pending count")

combat = false
assertEq(_G.RothBlizzPlates_CastBar.Apply(unitFrame), true, "castbar apply after combat")
assertEq(castTexture.texture, "Interface\\AddOns\\RothBlizzPlates\\media\\CastFill", "cast texture")
assertEq(castContainer.__RothCastBorder.texture, "Interface\\AddOns\\RothBlizzPlates\\media\\CastNoStop", "unknown state must fail closed")
assertEq(_G.RothBlizzPlates_CastBar.GetPendingCount(), 0, "castbar pending did not clear")

RothBlizzPlatesDB.castBar.enabled = false
assertEq(_G.RothBlizzPlates_CastBar.Apply(unitFrame), true, "castbar restore")
assertEq(castTexture.texture, "BlizzardOriginal", "original cast texture was not restored")
assertEq(castContainer.__RothCastBorder.shown, false, "addon border was not hidden")

print("PASS: core and castbar defer geometry in combat and restore Blizzard presentation")
