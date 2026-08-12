--[[
RothBlizzPlates (Midnight / 12.0)

Goal
  * Keep Blizzard nameplate logic (required under Midnight restrictions)
  * Replace visuals (textures/fonts) with Roth theme art assets

Design constraints (Midnight)
  * Do not branch/compute on combat state data that may be Secret.
  * Avoid SetPoint/ClearAllPoints on frames that may be "Secret Anchors" during combat.
  * Prefer skinning existing Blizzard widgets instead of replacing nameplates.

This file intentionally:
  * never reads UnitName/UnitGUID
  * never does arithmetic on UnitHealth/UnitHealthMax/etc.
  * only sets textures/fonts and creates static overlays
--]]

local ADDON_NAME = ...

-- -----------------------------------------------------------------------------
-- Media
-- -----------------------------------------------------------------------------

local MEDIA_PATH = ("Interface\\AddOns\\%s\\media\\"):format(ADDON_NAME)

local MEDIA = {
  FONT = MEDIA_PATH .. "Diablo-Light.ttf",
  STATUSBAR = MEDIA_PATH .. "StatusBar",
  PLATE_NORMAL = MEDIA_PATH .. "NormalPlate",
  PLATE_ELITE = MEDIA_PATH .. "ElitePlate",
  HIGHLIGHT = MEDIA_PATH .. "Highlight",
  HIGHLIGHT_ELITE = MEDIA_PATH .. "HighlightElite",
  THREAT = MEDIA_PATH .. "ThreatBar",
  CASTBAR = MEDIA_PATH .. "CastBar",
  CAST_STOP = MEDIA_PATH .. "CastStop",
  CAST_NOSTOP = MEDIA_PATH .. "CastNoStop",
}

local NON_LATIN = {
  koKR = true,
  zhCN = true,
  zhTW = true,
}

local function GetThemeFont()
  if RothBlizzPlatesDB.font.useGlobal then
    return STANDARD_TEXT_FONT
  end
  if NON_LATIN[GetLocale()] then
    return STANDARD_TEXT_FONT
  end
  return MEDIA.FONT
end

-- -----------------------------------------------------------------------------
-- Saved variables (minimal; expandable later)
-- -----------------------------------------------------------------------------

RothBlizzPlatesDB = RothBlizzPlatesDB or {
  enabled = true,

  -- Layout matches the original TidyPlates_Roth defaults.
  plate = {
    width = 180,
    height = 60,
    x = 6,
    y = 4,
    anchor = "CENTER",
  },

  healthBar = {
    width = 108,
    height = 9,
    x = 6,
    y = 3.5,
  },

  castBar = {
    -- Updated defaults for the Diablo-style cast frames.
    enabled = true,
    width = 67,
    height = 7.1,
    x = 1,
    y = -19,
  },

  castBorder = {
    width = 220,
    height = 66,
    x = 0,
    y = -28,
  },

  layout = {
    inheritScale = true,
  },

  -- Reserved (not used). Name positioning is kept Blizzard-default.
  name = {
    center = false,
    width = 160,
    x = 0,
    y = 18,
  },

  font = {
    useGlobal = false,
    size = 8,
    outline = "OUTLINE",
    shadow = true,
    inherit = true,
  },
}

-- Fill missing defaults when SavedVariables already exist (upgrade-safe).
do
  local db = RothBlizzPlatesDB

  if db.enabled == nil then db.enabled = true end

  db.plate = db.plate or { width = 180, height = 60, x = 6, y = 4, anchor = "CENTER" }
  db.plate.width  = db.plate.width  or 180
  db.plate.height = db.plate.height or 60
  if db.plate.x == nil then db.plate.x = 6 end
  if db.plate.y == nil then db.plate.y = 4 end
  db.plate.anchor = db.plate.anchor or "CENTER"

  db.healthBar = db.healthBar or { width = 108, height = 9, x = 6, y = 3.5 }
  db.healthBar.width  = db.healthBar.width  or 108
  db.healthBar.height = db.healthBar.height or 9
  if db.healthBar.x == nil then db.healthBar.x = 6 end
  if db.healthBar.y == nil then db.healthBar.y = 3.5 end

  db.castBar = db.castBar or { enabled = true, width = 67, height = 7.1, x = 1, y = -19 }
  if db.castBar.enabled == nil then db.castBar.enabled = true end
  db.castBar.width  = db.castBar.width  or 67
  db.castBar.height = db.castBar.height or 7.1
  if db.castBar.x == nil then db.castBar.x = 1 end
  if db.castBar.y == nil then db.castBar.y = -19 end

  -- CastBar tuning migration (visual tweaks between iterations)
  -- If user still has old defaults, bump to the new tuned values.
  if db.castBar.width == 65 and db.castBar.height == 7 and db.castBar.x == 0 and db.castBar.y == -19 then
    db.castBar.width = 67
    db.castBar.height = 7.1
    db.castBar.x = 1
    db.castBar.y = -19
  end
  db.castBorder = db.castBorder or { width = 220, height = 66, x = 0, y = -28 }
  db.castBorder.width  = db.castBorder.width  or 220
  db.castBorder.height = db.castBorder.height or 66
  if db.castBorder.x == nil then db.castBorder.x = 0 end
  if db.castBorder.y == nil then db.castBorder.y = -28 end

  db.layout = db.layout or { inheritScale = true }
  if db.layout.inheritScale == nil then db.layout.inheritScale = true end

  db.name = db.name or { center = false, width = 160, x = 0, y = 18 }
  if db.name.center == nil then db.name.center = false end
  db.name.width = db.name.width or 160
  if db.name.x == nil then db.name.x = 0 end
  if db.name.y == nil then db.name.y = 18 end

  db.font = db.font or { useGlobal = false, size = 8, outline = "OUTLINE", shadow = true, inherit = true }
  if db.font.useGlobal == nil then db.font.useGlobal = false end
  db.font.size = db.font.size or 8
  db.font.outline = db.font.outline or "OUTLINE"
  if db.font.shadow == nil then db.font.shadow = true end
  if db.font.inherit == nil then db.font.inherit = true end
end

-- -----------------------------------------------------------------------------
-- Utility
-- -----------------------------------------------------------------------------

local function SafeCall(obj, method, ...)
  if not obj then return false end
  local fn = obj[method]
  if type(fn) ~= "function" then return false end
  local ok = pcall(fn, obj, ...)
  return ok
end

local function IsPlainBoolean(v)
  if type(v) ~= "boolean" then return false end
  if type(issecretvalue) == "function" then
    local ok, isSecret = pcall(issecretvalue, v)
    if ok and isSecret then return false end
  end
  return true
end

local function CanTouchAnchors(frame)
  -- In Midnight, some frames become "Secret Anchors" and SetPoint/ClearAllPoints are forbidden.
  -- We conservatively avoid anchor operations in combat if we can detect this.
  if not frame then return false end

  if InCombatLockdown and InCombatLockdown() then
    if type(IsAnchoringSecret) == "function" then
      local ok, isSecret = pcall(IsAnchoringSecret, frame)
      if ok and IsPlainBoolean(isSecret) and isSecret then
        return false
      end
      if ok and not IsPlainBoolean(isSecret) then
        return false
      end
    end
  end

  return true
end

local function EnsureTexture(parent, key, layer, subLevel)
  local t = parent[key]
  if t then return t end
  t = parent:CreateTexture(nil, layer or "ARTWORK", nil, subLevel)
  parent[key] = t
  return t
end

local function IsPlainNumber(v)
  if type(v) ~= "number" then return false end
  if type(issecretvalue) == "function" then
    local ok, isSecret = pcall(issecretvalue, v)
    if ok and isSecret then return false end
  end
  return true
end

local function GetRegionSize(region)
  if not region then return end
  local okW, w = pcall(region.GetWidth, region)
  local okH, h = pcall(region.GetHeight, region)
  if okW and okH and IsPlainNumber(w) and IsPlainNumber(h) then
    return w, h
  end
end

local function GetScaleXYFrom(region, baseW, baseH)
  local sx, sy = 1, 1
  local w, h = GetRegionSize(region)
  if IsPlainNumber(w) and IsPlainNumber(baseW) and baseW > 0 then
    sx = w / baseW
  end
  if IsPlainNumber(h) and IsPlainNumber(baseH) and baseH > 0 then
    sy = h / baseH
  end
  return sx, sy
end

local SCALE_MIN = 0.2
local SCALE_MAX = 5

local function NormalizeScale(v)
  if not IsPlainNumber(v) then return nil end
  if v < SCALE_MIN or v > SCALE_MAX then return nil end
  return math.floor(v * 1000 + 0.5) / 1000
end

local function ResolveInheritedScale(unitFrame, sourceRegion, baseW, baseH)
  local sx, sy = GetScaleXYFrom(sourceRegion, baseW, baseH)
  sx = NormalizeScale(sx) or unitFrame.__RothScaleX or 1
  sy = NormalizeScale(sy) or unitFrame.__RothScaleY or 1
  unitFrame.__RothScaleX = sx
  unitFrame.__RothScaleY = sy
  return sx, sy
end

local function IsNearlyEqual(a, b, epsilon)
  if not (IsPlainNumber(a) and IsPlainNumber(b)) then return false end
  return math.abs(a - b) <= (epsilon or 0.05)
end

local function SetSizeIfNeeded(region, width, height)
  if not region then return end
  if not (IsPlainNumber(width) and IsPlainNumber(height)) then return end

  local curW, curH = GetRegionSize(region)
  if IsNearlyEqual(curW, width) and IsNearlyEqual(curH, height) then
    return
  end

  SafeCall(region, "SetSize", width, height)
end

local function SetCenterPointIfNeeded(region, parent, x, y)
  if not (region and parent) then return true end
  if not (IsPlainNumber(x) and IsPlainNumber(y)) then return true end

  if region.GetPoint then
    local ok, point, rel, relPoint, offX, offY = pcall(region.GetPoint, region, 1)
    if ok and point == "CENTER" and rel == parent and relPoint == "CENTER" and IsNearlyEqual(offX, x, 0.5) and IsNearlyEqual(offY, y, 0.5) then
      return true
    end
  end

  if not (CanTouchAnchors(region) and CanTouchAnchors(parent)) then
    return false
  end

  SafeCall(region, "ClearAllPoints")
  SafeCall(region, "SetPoint", "CENTER", parent, "CENTER", x, y)
  return true
end

local function ApplyFont(fontString)
  if not fontString or not fontString.SetFont then return end

  local db = RothBlizzPlatesDB.font or {}
  local size = db.size or 8
  local flags = db.outline or ""

  -- Inherit Blizzard sizes/flags so the addon follows the game's nameplate sizing options.
  if db.inherit and fontString.GetFont then
    local ok, _, curSize, curFlags = pcall(fontString.GetFont, fontString)
    if ok then
      if IsPlainNumber(curSize) then size = curSize end
      if type(curFlags) == "string" and curFlags ~= "" then flags = curFlags end
    end
  end

  SafeCall(fontString, "SetFont", GetThemeFont(), size, flags)

  if db.shadow then
    SafeCall(fontString, "SetShadowOffset", 1, -1)
    SafeCall(fontString, "SetShadowColor", 0, 0, 0, 1)
  else
    SafeCall(fontString, "SetShadowOffset", 0, 0)
  end
end

-- -----------------------------------------------------------------------------
local function DisableTargetHighlight(unitFrame)
  if not unitFrame or (unitFrame.IsForbidden and unitFrame:IsForbidden()) then return end

  -- Blizzard selectionHighlight is used for current target. We disable it entirely.
  local sel = unitFrame.selectionHighlight or unitFrame.SelectionHighlight
  if sel then
    SafeCall(sel, "SetTexture", nil)
    SafeCall(sel, "SetAtlas", nil)
    SafeCall(sel, "SetAlpha", 0)
    SafeCall(sel, "Hide")
  end

  -- Cleanup: older fallback overlay (never toggled by Blizzard)
  local target = unitFrame.__RothTarget
  if target then
    SafeCall(target, "SetAlpha", 0)
    SafeCall(target, "Hide")
  end
end

-- Name positioning is kept Blizzard-default (no overrides).

-- Styling
-- -----------------------------------------------------------------------------

local PendingLayout = setmetatable({}, { __mode = "k" })

local function ApplyLayout(unitFrame)
  if not unitFrame or unitFrame:IsForbidden() then return end

  local db = RothBlizzPlatesDB
  local plateCfg = db.plate
  local hbCfg = db.healthBar
  local healthBar = unitFrame.healthBar or unitFrame.HealthBar

  -- Inherit Blizzard nameplate sizing (e.g., UI options) by deriving a per-plate scale from the current bar size.
  local sx, sy = 1, 1
  if healthBar and RothBlizzPlatesDB.layout and RothBlizzPlatesDB.layout.inheritScale then
    sx, sy = ResolveInheritedScale(unitFrame, healthBar, hbCfg.width, hbCfg.height)
  end

  local hbX = (hbCfg.x or 0) * sx
  local hbY = (hbCfg.y or 0) * sy
  local hbW = (hbCfg.width or 0) * sx
  local hbH = (hbCfg.height or 0) * sy

  if healthBar then
    if not SetCenterPointIfNeeded(healthBar, unitFrame, hbX, hbY) then
      PendingLayout[unitFrame] = true
    end
    SetSizeIfNeeded(healthBar, hbW, hbH)
  end

  -- Plate art must render ABOVE the statusbar.
  -- If attached to UnitFrame, it renders under child frames (healthBar).
  -- Attach to the healthBar (when present) and use an OVERLAY layer.
  local anchor = healthBar or unitFrame
  local plateParent = healthBar or unitFrame

  -- Legacy cleanup: older versions created the texture on UnitFrame (always behind bars).
  local plate = unitFrame.__RothPlate
  if plate and plate.GetParent and plate:GetParent() ~= plateParent then
    plate:Hide()
    plate = nil
    unitFrame.__RothPlate = nil
  end

  if not plate then
    plate = EnsureTexture(plateParent, "__RothPlate", "OVERLAY", 0)
    unitFrame.__RothPlate = plate
  end

  plate:SetTexture(MEDIA.PLATE_NORMAL)
  SetSizeIfNeeded(plate, (plateCfg.width or 0) * sx, (plateCfg.height or 0) * sy)  -- Avoid double-applying offsets: plateCfg and hbCfg are both relative to unitFrame in our layout,
  -- so when anchoring plate to healthBar we use their delta.
  local dx, dy = plateCfg.x or 0, plateCfg.y or 0
  if healthBar then
    dx = ((plateCfg.x or 0) - (hbCfg.x or 0)) * sx
    dy = ((plateCfg.y or 0) - (hbCfg.y or 0)) * sy
  else
    dx = (plateCfg.x or 0) * sx
    dy = (plateCfg.y or 0) * sy
  end

  if not SetCenterPointIfNeeded(plate, anchor, dx, dy) then
    PendingLayout[unitFrame] = true
  end
  plate:Show()

  -- Target highlight: disabled
  DisableTargetHighlight(unitFrame)

  -- Threat glow: if Blizzard provides a glow texture, swap its asset; keep Blizzard-driven coloring.
  local threat = unitFrame.aggroGlow or unitFrame.AggroGlow or unitFrame.threatGlow
  if threat and threat.SetTexture then
    threat:SetTexture(MEDIA.THREAT)
  end

  -- Cast bar sizing/position (best effort).
  -- Cast bar is skinned by the CastBar module (castbar.lua)
  if db.castBar.enabled and _G.RothBlizzPlates_CastBar and _G.RothBlizzPlates_CastBar.Apply then
    _G.RothBlizzPlates_CastBar.Apply(unitFrame, sx, sy)
  end


  -- Fonts
  ApplyFont(unitFrame.name or unitFrame.Name)
  ApplyFont(unitFrame.level or unitFrame.Level)

  -- Optional: center the name text to match Roth theme.
  -- Name positioning: keep Blizzard default.

  -- Some templates use these
  ApplyFont(unitFrame.healthText or unitFrame.HealthText)
  ApplyFont(unitFrame.castBar and (unitFrame.castBar.Text or unitFrame.castBar.text))

  PendingLayout[unitFrame] = nil
end

local function ApplySkin(unitFrame)
  if not unitFrame or unitFrame:IsForbidden() then return end
  if unitFrame.__RothBlizzPlatesStyled then
    -- Ensure target highlight stays disabled even if Blizzard toggles it.
    DisableTargetHighlight(unitFrame)
    -- Still refresh layout (Blizzard can rebuild templates).
    ApplyLayout(unitFrame)
    return
  end

  unitFrame.__RothBlizzPlatesStyled = true

  -- Ensure target highlight is disabled on first style.
  DisableTargetHighlight(unitFrame)

  -- Statusbar textures (safe even in combat, no reads).
  local healthBar = unitFrame.healthBar or unitFrame.HealthBar
  if healthBar and healthBar.SetStatusBarTexture then
    healthBar:SetStatusBarTexture(MEDIA.STATUSBAR)
  end

  -- Defer layout if anchoring is forbidden.
  local ok = pcall(ApplyLayout, unitFrame)
  if not ok then
    PendingLayout[unitFrame] = true
  end
end

local function StyleNamePlateUnit(unit)
  if not RothBlizzPlatesDB.enabled then return end
  if not unit then return end

  local namePlate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
  if not namePlate then return end

  -- Nameplates in Retail+ typically expose UnitFrame.
  local unitFrame = namePlate.UnitFrame or namePlate.unitFrame
  if unitFrame then
    ApplySkin(unitFrame)
  end
end

local function RestyleAllVisible()
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
  for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
    local unitFrame = plate and (plate.UnitFrame or plate.unitFrame)
    if unitFrame then
      ApplySkin(unitFrame)
    end
  end
end

local function RetryPendingLayout()
  for unitFrame in pairs(PendingLayout) do
    pcall(ApplyLayout, unitFrame)
  end
end

-- -----------------------------------------------------------------------------
-- Settings Panel (Blizzard Settings API 11.0+)
-- -----------------------------------------------------------------------------

local function InitializeSettings()
  if not Settings or not Settings.RegisterVerticalLayoutCategory then return end

  local category, layout = Settings.RegisterVerticalLayoutCategory("Roth Blizzard Plates")

  -- Use Global Font
  local fontSetting = Settings.RegisterAddOnSetting(category, "RothBlizzPlates_UseGlobalFont", "useGlobal", RothBlizzPlatesDB.font, Settings.VarType.Boolean, "Использовать глобальный шрифт", false)
  Settings.CreateCheckbox(category, fontSetting, "Если включено, будет использоваться стандартный шрифт игры вместо Diablo-шрифта.")
  fontSetting:SetValueChangedCallback(function()
    RestyleAllVisible()
  end)

  -- Enable Castbar Replacement
  local castSetting = Settings.RegisterAddOnSetting(category, "RothBlizzPlates_EnableCastbar", "enabled", RothBlizzPlatesDB.castBar, Settings.VarType.Boolean, "Включить замену Castbar", true)
  Settings.CreateCheckbox(category, castSetting, "Если включено, полоса применения заклинаний будет заменена на Roth-стиль.")
  castSetting:SetValueChangedCallback(function()
    -- Some changes might require reload or at least target toggle, but we force restyle
    RestyleAllVisible()
  end)

  Settings.RegisterAddOnCategory(category)
end

-- -----------------------------------------------------------------------------
-- Event wiring
-- -----------------------------------------------------------------------------

local f = CreateFrame("Frame")

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CVAR_UPDATE")
f:RegisterEvent("UI_SCALE_CHANGED")

f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    InitializeSettings()
    RestyleAllVisible()

  elseif event == "NAME_PLATE_UNIT_ADDED" then
    local unit = ...
    StyleNamePlateUnit(unit)

  elseif event == "CVAR_UPDATE" then
    local cvar = ...
    if type(cvar) == "string" and (cvar:find("nameplate", 1, true) == 1 or cvar == "uiScale") then
      RestyleAllVisible()
    end

  elseif event == "UI_SCALE_CHANGED" then
    RestyleAllVisible()


  elseif event == "PLAYER_REGEN_ENABLED" then
    -- If any layout ops were blocked in combat due to secret anchors, try again out of combat.
    RetryPendingLayout()
    -- Also re-skin visible plates in case Blizzard recreated frames during combat.
    RestyleAllVisible()
  end
end)

-- Optional: keep target highlight disabled if Blizzard updates selection highlight.
if hooksecurefunc and type(CompactUnitFrame_UpdateSelectionHighlight) == "function" then
  hooksecurefunc("CompactUnitFrame_UpdateSelectionHighlight", function(unitFrame)
    if not unitFrame or unitFrame:IsForbidden() then return end
    if unitFrame.__RothBlizzPlatesStyled then
      DisableTargetHighlight(unitFrame)
    end
  end)
end

local NamePlateHooksInstalled = false
local function InstallNamePlateLifecycleHooks()
  if NamePlateHooksInstalled or not hooksecurefunc then return end

  local installed = false

  if NamePlateUnitFrameMixin and type(NamePlateUnitFrameMixin.UpdateAnchors) == "function" then
    hooksecurefunc(NamePlateUnitFrameMixin, "UpdateAnchors", function(unitFrame)
      if not unitFrame or unitFrame:IsForbidden() then return end
      if unitFrame.__RothBlizzPlatesStyled then
        ApplyLayout(unitFrame)
      end
    end)
    installed = true
  end

  if NamePlateUnitFrameMixin and type(NamePlateUnitFrameMixin.ApplyFrameOptions) == "function" then
    hooksecurefunc(NamePlateUnitFrameMixin, "ApplyFrameOptions", function(unitFrame)
      if not unitFrame or unitFrame:IsForbidden() then return end
      if unitFrame.__RothBlizzPlatesStyled then
        ApplyLayout(unitFrame)
      end
    end)
    installed = true
  end

  if NamePlateBaseMixin and type(NamePlateBaseMixin.ApplyFrameOptions) == "function" then
    hooksecurefunc(NamePlateBaseMixin, "ApplyFrameOptions", function(namePlateBase)
      if not namePlateBase then return end
      local unitFrame = namePlateBase.UnitFrame
      if unitFrame and unitFrame.__RothBlizzPlatesStyled then
        ApplyLayout(unitFrame)
      end
    end)
    installed = true
  end

  NamePlateHooksInstalled = installed
end

InstallNamePlateLifecycleHooks()
if not NamePlateHooksInstalled and EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", InstallNamePlateLifecycleHooks)
end
