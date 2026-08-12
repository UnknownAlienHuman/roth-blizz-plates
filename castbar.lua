--[[
RothBlizzPlates - CastBar module (Midnight / 12.0)

Goal
  * Skin Blizzard nameplate castbars to match Roth art (border + right icon slot).
  * Keep Blizzard logic (we do not compute cast progress ourselves).
  * Best-effort anchoring: avoid SetPoint/ClearAllPoints on secret-anchored frames during combat.

Fixes
  * Some 12.0 nameplate templates expose multiple cast "bars" (a container frame + a nested StatusBar).
    If only the border is reskinned, the real Blizzard bar can remain at a larger default size behind our art.
    This module finds all StatusBars under the cast container and normalizes/hides extra fills.
--]]

local ADDON_NAME = ...

local MEDIA_PATH = ("Interface\\AddOns\\%s\\media\\"):format(ADDON_NAME)

local MEDIA = {
  CAST_STOP   = MEDIA_PATH .. "CastStop",
  CAST_NOSTOP = MEDIA_PATH .. "CastNoStop",
  CAST_FILL   = MEDIA_PATH .. "CastFill",
}

-- Slot geometry in our current CastStop/CastNoStop textures.
-- These are normalized coordinates in texture space (0..1).
-- NOTE: Positive Y in SetPoint is up; to push the icon down, reduce SLOT_CY.
-- Fine tuned by in-game pixel alignment against the castframe art.
-- Slightly right and slightly up (previously the icon sat a bit down/left).
local SLOT_CX = 0.875
local SLOT_CY = 0.455

-- Pixel nudges for final alignment in-game.
local ICON_NUDGE_X = 0
local ICON_NUDGE_Y = 1

-- Icon size is defined in UI pixels relative to the border height.
-- In earlier iterations the icon was intentionally oversized; keep it noticeably
-- smaller than the slot so it doesn't dominate the plate.
-- Smaller icon: the slot is intentionally large, but the icon should not dominate.
local ICON_SIZE_FACTOR = 0.29

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

local function SafeCall(obj, method, ...)
  if not obj then return false end
  local fn = obj[method]
  if type(fn) ~= "function" then return false end
  return pcall(fn, obj, ...)
end

local function SafeGet(obj, method, ...)
  if not obj then return nil end
  local fn = obj[method]
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, obj, ...)
  if ok then return v end
  return nil
end

-- Some WoW API getters return multiple values (e.g. GetStatusBarColor/GetVertexColor).
-- Use a dedicated helper so we don't accidentally drop G/B/A.
local function SafeGet4(obj, method, ...)
  if not obj then return nil end
  local fn = obj[method]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, obj, ...)
  if ok then return a, b, c, d end
  return nil
end

-- Safe GetChildren() that never throws and always returns a table.
local function SafeChildren(obj)
  if not obj or type(obj.GetChildren) ~= 'function' then return {} end
  local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(obj.GetChildren, obj)
  if not ok then return {} end
  return {a,b,c,d,e,f,g,h,i,j,k,l}
end

-- Debug (off by default)
local DEBUG_CAST = false
local function DebugPrint(...)
  if not DEBUG_CAST then return end
  if print then
    print("|cffb200ffRBP Cast|r", ...)
  end
end

local function SyncDebugFlag()
  local db = RothBlizzPlatesDB
  DEBUG_CAST = (db and db.debugCast) and true or false
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
  local w = SafeGet(region, "GetWidth")
  local h = SafeGet(region, "GetHeight")
  if IsPlainNumber(w) and IsPlainNumber(h) then
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

local function SetAllPointsIfNeeded(region, parent)
  if not (region and parent) then return true end

  if not (CanTouchAnchors(region) and CanTouchAnchors(parent)) then
    return false
  end

  SafeCall(region, "ClearAllPoints")
  SafeCall(region, "SetAllPoints", parent)
  return true
end

local function HideRegion(region)
  if not region then return end
  SafeCall(region, "SetAlpha", 0)
  SafeCall(region, "Hide")
end

local function HideIfTexture(region)
  if not region then return end
  local t = SafeGet(region, "GetObjectType")
  if t == "Texture" then
    HideRegion(region)
  end
end


-- Blank a texture without changing its shown/alpha state (useful for keeping Blizzard state signals).
local function BlankIfTexture(region)
  if not region then return end
  local t = SafeGet(region, "GetObjectType")
  if t == "Texture" and region.SetTexture then
    SafeCall(region, "SetTexture", nil)
  end
end

-- Keep the region "shown" (so IsShown() can be used as a state signal),
-- but make it invisible. This is useful for the uninterruptible shield art:
-- some templates only expose interruptibility via shield visibility.
local function GhostIfTexture(region)
  if not region then return end
  local t = SafeGet(region, "GetObjectType")
  if t == "Texture" then
    SafeCall(region, "SetAlpha", 0)
  end
end

local function IsStatusBar(obj)
  if not obj then return false end
  local t = SafeGet(obj, "GetObjectType")
  if t == "StatusBar" then return true end
  -- Fallback: StatusBar API signature
  return (type(obj.SetStatusBarTexture) == "function")
     and (type(obj.SetMinMaxValues) == "function")
     and (type(obj.SetValue) == "function")
end

local function UniqueInsert(list, obj)
  for _, v in ipairs(list) do
    if v == obj then return end
  end
  table.insert(list, obj)
end

local function CfgEquals(cfg, ref)
  if type(cfg) ~= "table" or type(ref) ~= "table" then return false end
  for k, v in pairs(ref) do
    if cfg[k] ~= v then return false end
  end
  return true
end

local function CollectStatusBars(castContainer)
  local bars = {}
  if not castContainer then return bars end

  local function scan(obj)
    if not obj then return end

    -- Container itself might be a StatusBar.
    if IsStatusBar(obj) then
      UniqueInsert(bars, obj)
    end

    -- Common fields used by different templates.
    local keys = {
      "Bar","bar",
      "StatusBar","statusBar",
      "Progress","progress",
      "ProgressBar","progressBar",
      "CastBar","castBar",
      "Fill","fill",
      "ArtFrame","artFrame",
      "Container","container",
    }

    for _, k in ipairs(keys) do
      local v = obj[k]
      if IsStatusBar(v) then
        UniqueInsert(bars, v)
      end
    end

    -- Scan children (some templates build the actual StatusBar as a child during casting).
	for _, child in ipairs(SafeChildren(obj)) do
		if child and child ~= obj then
			if IsStatusBar(child) then
				UniqueInsert(bars, child)
			end
			-- One more level deep is enough for nameplate castbars.
			for _, gk in ipairs(SafeChildren(child)) do
				if gk and IsStatusBar(gk) then
					UniqueInsert(bars, gk)
				end
			end
		end
	end
  end

  scan(castContainer)

  return bars
end


local function ScoreCastContainer(obj)
  if not obj then return -1 end
  local score = 0
  -- The "real" Blizzard cast container usually has these fields.
  if obj.Text or obj.CastTargetNameText then score = score + 3 end
  if obj.Icon then score = score + 3 end
  if obj.BorderShield or obj.Shield or obj.NotInterruptible then score = score + 2 end
  if obj.Background then score = score + 1 end
  if type(obj.showShield) == "boolean" or obj.showShield ~= nil then score = score + 1 end
  return score
end

local function FindCastContainer(unitFrame)
  if not unitFrame then return nil end

  -- Cached instance (some templates recreate castbars; validate minimally).
  local cached = unitFrame.__RothCastContainer
  if cached and (not (cached.IsForbidden and cached:IsForbidden())) then
    return cached
  end

  local best, bestScore

  local function consider(obj)
    if not obj or (obj.IsForbidden and obj:IsForbidden()) then return end
    local sc = ScoreCastContainer(obj)
    if not best or sc > bestScore then
      best, bestScore = obj, sc
    end
  end

  -- Common direct fields.
  consider(unitFrame.castBar)
  consider(unitFrame.CastBar)
  consider(unitFrame.CastingBar)
  consider(unitFrame.castingBar)
  consider(unitFrame.CastBarFrame)
  consider(unitFrame.CastBarContainer)

  -- Scan children: the real container is often a StatusBar with Icon/Text/Shield.
  for _, child in ipairs(SafeChildren(unitFrame)) do
    consider(child)
    for _, gk in ipairs(SafeChildren(child)) do
      consider(gk)
    end
  end

  -- Require at least some signal; otherwise return nil.
  if best and (bestScore or 0) >= 2 then
    unitFrame.__RothCastContainer = best
    return best
  end

  unitFrame.__RothCastContainer = nil
  return nil
end

-- ------------------------------------------------------------
-- Cast fill mirroring
--
-- Problem: some Midnight templates tint the cast bar by directly
-- changing VertexColor on the current StatusBarTexture. Replacing
-- the texture file can reset that tint, and in some cases Blizzard
-- may tint a different internal texture than the one we modified.
--
-- Solution: keep Blizzard's original StatusBarTexture (hidden), and
-- render our own CastFill on an overlay StatusBar that mirrors value
-- and tint via hooks. The tint remains 'from Blizzard' because we
-- only forward the same arguments Blizzard uses.
-- ------------------------------------------------------------

local function EnsureCastFillOverlay(castContainer, primary)
  if not castContainer or not primary or not CreateFrame then return nil end

  local overlay = castContainer.__RothCastFillOverlay
  if not overlay then
    overlay = CreateFrame('StatusBar', nil, castContainer)
    castContainer.__RothCastFillOverlay = overlay

	    -- The Blizzard cast container is itself a StatusBar.
	    -- If our overlay is below it, it becomes fully hidden.
	    -- So we place the overlay ABOVE the container and move Blizzard
	    -- text/indicators to a higher-level host frame.
    local lvl = 0
    if castContainer.GetFrameLevel then
      local ok, v = pcall(castContainer.GetFrameLevel, castContainer)
      if ok and type(v) == 'number' then lvl = v end
    end
	    if overlay.SetFrameLevel then overlay:SetFrameLevel(lvl + 1) end
    if castContainer.GetFrameStrata and overlay.SetFrameStrata then
      local ok, s = pcall(castContainer.GetFrameStrata, castContainer)
      if ok and type(s) == 'string' then overlay:SetFrameStrata(s) end
    end

	    -- Host frame for Blizzard regions that must remain above the overlay.
	    local top = CreateFrame('Frame', nil, castContainer)
	    castContainer.__RothCastTop = top
	    top:SetAllPoints(castContainer)
	    if castContainer.GetFrameStrata and top.SetFrameStrata then
	      local ok, s = pcall(castContainer.GetFrameStrata, castContainer)
	      if ok and type(s) == 'string' then top:SetFrameStrata(s) end
	    end
	    if top.SetFrameLevel and overlay.GetFrameLevel then
	      local ok, ovl = pcall(overlay.GetFrameLevel, overlay)
	      if ok and type(ovl) == 'number' then top:SetFrameLevel(ovl + 1) end
	    end
	    local function Reparent(r)
	      if r and r.SetParent then pcall(r.SetParent, r, top) end
	    end
	    Reparent(castContainer.Text)
	    Reparent(castContainer.CastTargetNameText)
	    Reparent(castContainer.CastTargetIndicator)
	    Reparent(castContainer.ImportantCastIndicator)
	    Reparent(castContainer.Flash)
	    Reparent(castContainer.Spark)
	    Reparent(castContainer.Icon)

    -- Geometry and texture
    overlay:SetAllPoints(castContainer)
    overlay:SetStatusBarTexture(MEDIA.CAST_FILL)
	    local otex = overlay.GetStatusBarTexture and overlay:GetStatusBarTexture() or nil
	    if otex and otex.SetAlpha then SafeCall(otex, 'SetAlpha', 1) end
    overlay:SetMinMaxValues(0, 1)
    overlay:SetValue(0)
	    SafeCall(overlay, 'SetAlpha', 1)
    overlay:Show()
  end

  -- Bind overlay to primary so hooks can find it.
  primary.__RothCastFillOverlay = overlay

  -- Hide Blizzard fill (but keep it alive for Blizzard to tint).
  local ptex = SafeGet(primary, 'GetStatusBarTexture')
  if ptex and ptex.SetAlpha then
    SafeCall(ptex, 'SetAlpha', 0)
  end

  -- Initialize value/minmax from primary without arithmetic.
  local minv, maxv = SafeGet4(primary, 'GetMinMaxValues')
  if minv ~= nil and maxv ~= nil then
    SafeCall(overlay, 'SetMinMaxValues', minv, maxv)
  end
  local val = SafeGet(primary, 'GetValue')
  if val ~= nil then
    SafeCall(overlay, 'SetValue', val)
  end

  -- Initialize tint: prefer VertexColor on Blizzard's current texture.
  local vr, vg, vb, va
  if ptex and ptex.GetVertexColor then
    vr, vg, vb, va = SafeGet4(ptex, 'GetVertexColor')
  end
  if not (IsPlainNumber(vr) and IsPlainNumber(vg) and IsPlainNumber(vb)) then
    vr, vg, vb, va = SafeGet4(primary, 'GetStatusBarColor')
  end
  if IsPlainNumber(vr) and IsPlainNumber(vg) and IsPlainNumber(vb) then
    SafeCall(overlay, 'SetStatusBarColor', vr, vg, vb, (IsPlainNumber(va) and va or 1))
  end

  -- Hook mirroring once per primary instance.
  if hooksecurefunc and not primary.__RothCastMirrorHooked then
    primary.__RothCastMirrorHooked = true

    hooksecurefunc(primary, 'SetMinMaxValues', function(self, a, b)
      local o = self.__RothCastFillOverlay
      if o then SafeCall(o, 'SetMinMaxValues', a, b) end
    end)

    hooksecurefunc(primary, 'SetValue', function(self, v)
      local o = self.__RothCastFillOverlay
      if o then SafeCall(o, 'SetValue', v) end
    end)

    hooksecurefunc(primary, 'SetStatusBarColor', function(self, r, g, b, a)
      local o = self.__RothCastFillOverlay
      if o then SafeCall(o, 'SetStatusBarColor', r, g, b, a) end
    end)
  end

  -- Hook Blizzard texture tint (VertexColor) to forward it to overlay,
  -- but only for the current texture instance.
  local ptex = SafeGet(primary, 'GetStatusBarTexture')
  if hooksecurefunc and ptex and not ptex.__RothCastVertexHooked then
    ptex.__RothCastVertexHooked = true
    ptex.__RothOwnerPrimary = primary
    hooksecurefunc(ptex, 'SetVertexColor', function(tex, r, g, b, a)
	      if a == nil then a = 1 end
      local prim = tex.__RothOwnerPrimary
      local o = prim and prim.__RothCastFillOverlay
      if o and o.GetStatusBarTexture then
        local otex = o:GetStatusBarTexture()
        if otex and otex.SetVertexColor then
	          SafeCall(otex, 'SetVertexColor', r, g, b, a)
        end
      end
    end)
  end

  return overlay
end


local function IsNotInterruptible(castObj, primary)
  local function from(obj)
    if not obj then return nil end

    -- These fields may become Secret Booleans in 12.0.1+. Never branch on them unless they are plain.
    if obj.notInterruptible ~= nil then
      if IsPlainBoolean(obj.notInterruptible) then
        return obj.notInterruptible
      end
      return nil
    end
    if obj.interruptible ~= nil then
      if IsPlainBoolean(obj.interruptible) then
        return (not obj.interruptible)
      end
      return nil
    end
    if obj.isInterruptible ~= nil then
      if IsPlainBoolean(obj.isInterruptible) then
        return (not obj.isInterruptible)
      end
      return nil
    end

    -- Some templates signal non-interruptible casts by hiding the icon.
    if obj.HideIconWhenNotInterruptible and obj.Icon and obj.Icon.IsShown then
      local ok, shown = pcall(obj.Icon.IsShown, obj.Icon)
      if ok and IsPlainBoolean(shown) and (not shown) then
        return true
      end
    end

    return nil
  end

local v = from(castObj)
  if v ~= nil then return v end
  v = from(primary)
  if v ~= nil then return v end

  -- Heuristic: shield/"not interruptible" texture shown.
  local function shieldShown(obj)
    local shield = obj and (obj.BorderShield or obj.Shield or obj.NotInterruptible)
    if not shield then return false end

    -- In 12.0.1+ Blizzard may mark visibility state as Secret (IsShown returns a Secret Bool).
    -- We must not branch on Secret values; treat as "unknown" and fall back to other heuristics.
    if shield.IsShown then
      local ok, v = pcall(shield.IsShown, shield)
      if not ok then
        return false
      end
      if not IsPlainBoolean(v) then
        return nil
      end
      if not v then
        return false
      end
    else
      return false
    end

    -- Some templates keep the shield shown but fade it via alpha.
    if shield.GetAlpha then
      local ok, a = pcall(shield.GetAlpha, shield)
      if ok then
        if not IsPlainNumber(a) then
          return nil
        end
        return a > 0.15
      end
    end

    return true
  end



  if shieldShown(castObj) or shieldShown(primary) then
    return true
  end

  return nil
end

local function IsColorRedish(r, g, b)
  return IsPlainNumber(r) and IsPlainNumber(g) and IsPlainNumber(b)
     and r > 0.75 and g < 0.35 and b < 0.35
end

local function IsColorGreyish(r, g, b)
  if not (IsPlainNumber(r) and IsPlainNumber(g) and IsPlainNumber(b)) then
    return false
  end
  -- Avoid treating an uninitialized/uncolored bar (often near-white) as "grey/uninterruptible".
  -- Blizzard's non-interruptible tint is usually a mid-grey, not pure white.
  if r > 0.92 or g > 0.92 or b > 0.92 then
    return false
  end
  return math.abs(r - g) < 0.06 and math.abs(g - b) < 0.06
end

local function GetCastBarIcon(castObj)
  if not castObj then return end

  local icon =
    castObj.Icon or castObj.icon or
    castObj.IconTexture or castObj.iconTexture or
    castObj.SpellIcon or castObj.spellIcon

  -- Some templates wrap the texture inside a frame (Icon.Icon)
  if icon and type(icon) == "table" and (not icon.SetTexture) then
    if icon.Icon and icon.Icon.SetTexture then
      icon = icon.Icon
    elseif icon.texture and icon.texture.SetTexture then
      icon = icon.texture
    end
  end

  if icon and icon.SetTexture then
    return icon
  end
end

local function PickPrimaryStatusBar(statusBars)
  if not statusBars or #statusBars == 0 then return nil end

  local best, bestScore = nil, -1
  for _, sb in ipairs(statusBars) do
    local score = 0

    local shown = false
    if sb.IsShown then
      local ok, v = pcall(sb.IsShown, sb)
      if ok and IsPlainBoolean(v) then
        shown = v
      end
    end
    if shown then score = score + 5 end


    local w, h = GetRegionSize(sb)
    if IsPlainNumber(w) and IsPlainNumber(h) then
      -- Prefer the largest StatusBar: that's almost always the real cast fill.
      score = score + (w * h) / 1000
    end

    if sb.Spark or sb.spark then score = score + 2 end
    if sb.Text or sb.text then score = score + 1 end

    if score > bestScore then
      best, bestScore = sb, score
    end
  end

  return best or statusBars[1]
end

local function HideOversizedTextures(frame, maxW, maxH, keep)
  if not frame or not keep then return end
  if not (IsPlainNumber(maxW) and IsPlainNumber(maxH)) then return end

  local regions = { frame:GetRegions() }
  for _, r in ipairs(regions) do
    if r and not keep[r] then
      local t = SafeGet(r, "GetObjectType")
      if t == "Texture" then
        local w, h = GetRegionSize(r)
        if (IsPlainNumber(w) and w > maxW * 1.15) or (IsPlainNumber(h) and h > maxH * 1.15) then
          HideRegion(r)
        end
      end
    end
  end
end


local function ComputeInheritedScale(unitFrame, passedSx, passedSy)
  local sx, sy = NormalizeScale(passedSx), NormalizeScale(passedSy)
  if sx and sy then
    unitFrame.__RothScaleX = sx
    unitFrame.__RothScaleY = sy
    return sx, sy
  end

  local db = RothBlizzPlatesDB or {}
  if not (db.layout and db.layout.inheritScale) then
    sx = unitFrame.__RothScaleX or 1
    sy = unitFrame.__RothScaleY or 1
    return sx, sy
  end

  local hbCfg = db.healthBar or {}
  local healthBar = unitFrame and (unitFrame.healthBar or unitFrame.HealthBar)
  if healthBar and hbCfg.width and hbCfg.height then
    local rawX, rawY = GetScaleXYFrom(healthBar, hbCfg.width, hbCfg.height)
    sx = NormalizeScale(rawX) or unitFrame.__RothScaleX or 1
    sy = NormalizeScale(rawY) or unitFrame.__RothScaleY or 1
    unitFrame.__RothScaleX = sx
    unitFrame.__RothScaleY = sy
    return sx, sy
  end

  sx = unitFrame.__RothScaleX or 1
  sy = unitFrame.__RothScaleY or 1
  return sx, sy
end

-- ------------------------------------------------------------
-- Main
-- ------------------------------------------------------------

local function ApplyCastBar(unitFrame, passedSx, passedSy)
  if not unitFrame or (unitFrame.IsForbidden and unitFrame:IsForbidden()) then return end

  local castContainer = FindCastContainer(unitFrame)
  if not castContainer then return end

  local db = RothBlizzPlatesDB or {}

  -- If disabled, hide our custom additions.
  -- Note: we don't fully "un-skin" everything (textures, size) without a reload,
  -- but we can at least hide our custom border and overlay fills.
  if not db.castBar.enabled then
    if castContainer.__RothCastBorder then castContainer.__RothCastBorder:Hide() end
    if castContainer.Border then castContainer.Border:Hide() end
    if castContainer.__RothCastFillOverlay then castContainer.__RothCastFillOverlay:Hide() end
    return
  end
  SyncDebugFlag()

  -- Cast layout defaults.

  -- v2 introduced a large frame for iteration; v3 scales it down to better match
  -- the health plate. v4 scales it down ~3x (per user request) while keeping the top edge
  -- at the same screen Y by adjusting the center offset.
  -- We only migrate if the user is still on known defaults.

  local V2_CB  = { width = 140, height = 7, x = 0,  y = -28 }
  local V2_CBB = { width = 220, height = 66, x = 0,  y = -28 }

  local V3_CB  = { width = 124, height = 6, x = 0,  y = -28 }
  local V3_CBB = { width = 190, height = 54, x = 0,  y = -28 }

  -- v4: ~3x smaller than v3
  local V4_CB  = { width = 41,  height = 2, x = 0,  y = -10 }
  local V4_CBB = { width = 63,  height = 18, x = 0,  y = -10 }

  -- v5: ~1.5x smaller than v3 (previous target size)
  local V5_CB_OLD  = { width = 83,  height = 4, x = 0,  y = -19 }
  local V5_CBB     = { width = 127, height = 36, x = 0,  y = -19 }

  -- v6: make the *fill* thicker and a bit shorter.
  -- This changes only the cast "texture" (Blizzard StatusBar) geometry; the frame art stays the same.
  local V6_CB      = { width = 72,  height = 6, x = 0,  y = -19 }
  local V7_CB_OLD  = { width = 65,  height = 7,   x = 0,  y = -19 }
  local V8_CB_OLD  = { width = 70,  height = 7.2, x = 3,  y = -20 }
  -- v8: user-tuned fill geometry
  local V8_CB      = { width = 70,  height = 7.3, x = 3,  y = -20 }

  local OLD_CB_A   = { width = 86,  height = 8, x = 2,  y = -22 }
  local OLD_CBB_A = { width = 128, height = 64, x = -5, y = -8 }
  local OLD_CBB_B = { width = 190, height = 64, x = -5, y = -8 }

  db.castBar = db.castBar or {}
  -- Migrate older defaults to current fill geometry.
  local V9_CB      = { width = 67,  height = 7.1, x = 1,  y = -19 }
  local V9_1_CB    = { width = 67,  height = 7.1, x = 1,  y = -19 }
  if CfgEquals(db.castBar, V8_CB_OLD) or CfgEquals(db.castBar, V7_CB_OLD) or CfgEquals(db.castBar, V9_CB) or CfgEquals(db.castBar, V9_1_CB) then
    for k, v in pairs(V8_CB) do db.castBar[k] = v end
  end

  -- Migrate older fill defaults to current.
  if CfgEquals(db.castBar, V6_CB) then
    for k, v in pairs(V8_CB) do db.castBar[k] = v end
  end

  if CfgEquals(db.castBar, OLD_CB_A) then
    for k, v in pairs(V8_CB) do db.castBar[k] = v end
  elseif CfgEquals(db.castBar, V2_CB) then
    for k, v in pairs(V8_CB) do db.castBar[k] = v end
  elseif CfgEquals(db.castBar, V3_CB) then
    for k, v in pairs(V8_CB) do db.castBar[k] = v end
  elseif CfgEquals(db.castBar, V4_CB) then
    for k, v in pairs(V8_CB) do db.castBar[k] = v end
  elseif CfgEquals(db.castBar, V5_CB_OLD) then
    for k, v in pairs(V8_CB) do db.castBar[k] = v end
  end

  db.castBorder = db.castBorder or {}
  if CfgEquals(db.castBorder, OLD_CBB_A) or CfgEquals(db.castBorder, OLD_CBB_B) then
    for k, v in pairs(V5_CBB) do db.castBorder[k] = v end
  elseif CfgEquals(db.castBorder, V2_CBB) then
    for k, v in pairs(V5_CBB) do db.castBorder[k] = v end
  elseif CfgEquals(db.castBorder, V3_CBB) then
    for k, v in pairs(V5_CBB) do db.castBorder[k] = v end
  elseif CfgEquals(db.castBorder, V4_CBB) then
    for k, v in pairs(V5_CBB) do db.castBorder[k] = v end
  end

  local cbCfg  = db.castBar
  local cbbCfg = db.castBorder

  local sx, sy = ComputeInheritedScale(unitFrame, passedSx, passedSy)

  -- Hook OnShow once: when a cast starts, some templates rebuild regions.
  if castContainer.HookScript and not castContainer.__RothOnShowHooked then
    castContainer.__RothOnShowHooked = true
    castContainer:HookScript("OnShow", function(self)
      local owner = self.__RothOwnerUF
      if owner then
        ApplyCastBar(owner)
      end
    end)
  end
  castContainer.__RothOwnerUF = unitFrame

  -- 1) Normalize the cast container geometry.
  SetCenterPointIfNeeded(castContainer, unitFrame, (cbCfg.x or 0) * sx, (cbCfg.y or 0) * sy)
  SetSizeIfNeeded(castContainer, (cbCfg.width or 0) * sx, (cbCfg.height or 0) * sy)

  local containerW, containerH = GetRegionSize(castContainer)

  -- 2) Find all StatusBars under the cast container.
  local statusBars = CollectStatusBars(castContainer)

  -- IMPORTANT: some 12.0 templates expose a hidden placeholder StatusBar as the container,
  -- while the *real* visible cast fill is a nested/child StatusBar created on demand.
  -- Always pick the best visible/largest StatusBar as primary.
  local primary = PickPrimaryStatusBar(statusBars)
  if not primary then
    primary = castContainer
  end

  -- 3) Ensure the primary StatusBar is the one visible and matches container size.
  if primary and IsStatusBar(primary) then

    -- If the primary is nested, force it to occupy the container.
    if primary ~= castContainer then
      SetAllPointsIfNeeded(primary, castContainer)
    end

    -- Defensive size (in case SetAllPoints is blocked).
    if IsPlainNumber(containerW) and IsPlainNumber(containerH) then
      SetSizeIfNeeded(primary, containerW, containerH)
    end
  end
  -- Keep Blizzard progress rendering. We only swap the *existing* StatusBarTexture file (no overlay), so no secret values are needed.

  local primaryTex
  if primary and primary.GetStatusBarTexture then
    primaryTex = SafeGet(primary, 'GetStatusBarTexture')
  end

  -- Apply custom fill texture on the *current* Blizzard StatusBarTexture instance.
  -- IMPORTANT: do NOT call StatusBar:SetStatusBarTexture() here: some templates tint a different
  -- internal texture object. Instead we replace the file on the existing texture object once.
  if primaryTex and primaryTex.SetTexture and (not primaryTex.__RothCastFillApplied) then
    local vr, vg, vb, va = SafeGet4(primaryTex, 'GetVertexColor')
    SafeCall(primaryTex, 'SetTexture', MEDIA.CAST_FILL)
    if IsPlainNumber(vr) and IsPlainNumber(vg) and IsPlainNumber(vb) and primaryTex.SetVertexColor then
      SafeCall(primaryTex, 'SetVertexColor', vr, vg, vb, (IsPlainNumber(va) and va or 1))
    end
    primaryTex.__RothCastFillApplied = true
  end

-- Determine interruptibility:

  -- Prefer explicit flags set by Blizzard; otherwise infer from Blizzard bar color (grey = uninterruptible).
  local notInterruptible = IsNotInterruptible(castContainer, primary)

    -- Fallback: if the explicit interruptible flags are unavailable, infer from the *visible* bar tint.
  -- Some templates do not update StatusBarColor but do update VertexColor on the StatusBarTexture.
  local cr, cg, cb
  if primaryTex and primaryTex.GetVertexColor then
    cr, cg, cb = SafeGet4(primaryTex, "GetVertexColor")
  end
  if not (IsPlainNumber(cr) and IsPlainNumber(cg) and IsPlainNumber(cb)) and primary and primary.GetStatusBarColor then
    cr, cg, cb = SafeGet(primary, "GetStatusBarColor")
  end

  if IsColorRedish(cr, cg, cb) then
    -- If the cast just got interrupted/failed, keep the previous interruptibility state.
    if notInterruptible == nil then
      notInterruptible = castContainer.__RothNotInterruptible
    end
  elseif notInterruptible == nil then
    notInterruptible = IsColorGreyish(cr, cg, cb) and true or false
  end

  if notInterruptible == nil then
    notInterruptible = false
  end
  castContainer.__RothNotInterruptible = notInterruptible

  -- 4) Hide / neutralize any extra StatusBar fills so they cannot show behind our border.
  for _, sb in ipairs(statusBars) do
    if sb ~= primary and IsStatusBar(sb) then
      local tex = SafeGet(sb, "GetStatusBarTexture")
      if tex then
        HideRegion(tex)
      end

      -- Also hide obvious wrapper textures.
      HideRegion(sb.BarTexture or sb.barTexture)
      HideRegion(sb.Fill or sb.fill)
    end
  end

  -- 5) Hide Blizzard layers that can appear behind our art.
  HideIfTexture(castContainer.Background or castContainer.background or castContainer.BG or castContainer.bg)

  -- Hide Blizzard's shield art visually, but keep its shown/alpha state for interruptibility detection.
  BlankIfTexture(castContainer.BorderShield or castContainer.Shield or castContainer.NotInterruptible)

  -- 6) Border (CastStop.tga includes the right-side icon slot).
  local borderW = (cbbCfg.width or 0) * sx
  local borderH = (cbbCfg.height or 0) * sy
  local bdx = ((cbbCfg.x or 0) - (cbCfg.x or 0)) * sx
  local bdy = ((cbbCfg.y or 0) - (cbCfg.y or 0)) * sy

  local border = castContainer.Border or castContainer.border
  if not (border and border.SetTexture) and primary then
    border = primary.Border or primary.border
  end

  local borderTex = notInterruptible and MEDIA.CAST_NOSTOP or MEDIA.CAST_STOP

  if border and border.SetTexture then
    SafeCall(border, "SetTexture", borderTex)
    SafeCall(border, "SetDrawLayer", "BACKGROUND", -8)
    SetSizeIfNeeded(border, borderW, borderH)

    SetCenterPointIfNeeded(border, castContainer, bdx, bdy)

    SafeCall(border, "Show")
  else
    -- Create a custom border if the template doesn't expose one.
    local custom = castContainer.__RothCastBorder
    if not custom then
      custom = castContainer:CreateTexture(nil, "BACKGROUND", nil, -8)
      castContainer.__RothCastBorder = custom
    end

    custom:SetTexture(borderTex)
    SetSizeIfNeeded(custom, borderW, borderH)

    SetCenterPointIfNeeded(custom, castContainer, bdx, bdy)

    custom:Show()
    border = custom
  end

  -- 7) Icon: move Blizzard-provided icon into the right slot.
  local icon = GetCastBarIcon(castContainer) or (primary and GetCastBarIcon(primary))
  if icon and border and borderW > 0 and borderH > 0 then
    -- Size the icon in UI pixels (not in "texture pixels"). This keeps it stable across
    -- different texture resolutions and makes it easy to tune.
    local iconSize = borderH * ICON_SIZE_FACTOR
    -- Safety clamps: keep within the slot area.
    if IsPlainNumber(borderW) then
      -- Keep the icon clearly inside the slot region.
      iconSize = math.min(iconSize, borderW * 0.18)
    end
    iconSize = math.max(6, iconSize)
    local offX = (SLOT_CX - 0.5) * borderW + ICON_NUDGE_X
    local offY = (SLOT_CY - 0.5) * borderH + ICON_NUDGE_Y

    SafeCall(icon, "SetDrawLayer", "OVERLAY", 2)
    SafeCall(icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93)
    SetSizeIfNeeded(icon, iconSize, iconSize)

    SetCenterPointIfNeeded(icon, border, offX, offY)

    SafeCall(icon, "SetAlpha", 1)
    SafeCall(icon, "Show")
  end
end

-- Export for core.lua.
_G.RothBlizzPlates_CastBar = _G.RothBlizzPlates_CastBar or {}
_G.RothBlizzPlates_CastBar.Apply = ApplyCastBar

-- ------------------------------------------------------------
-- Hooks: ensure we restyle AFTER Blizzard updates the castbar.
-- ------------------------------------------------------------

local function ResolveUnitFrame(arg1)
  if not arg1 then return nil end
  if arg1.__RothOwnerUF then
    return arg1.__RothOwnerUF
  end
  if arg1.UnitFrame or arg1.unitFrame then
    return arg1.UnitFrame or arg1.unitFrame
  end
  if arg1.GetParent then
    local parent = SafeGet(arg1, "GetParent")
    if parent and (parent.castBar == arg1 or parent.CastBar == arg1 or parent.CastingBar == arg1 or parent.castingBar == arg1) then
      return parent
    end
  end
  if arg1.castBar or arg1.CastBar or arg1.healthBar or arg1.HealthBar or arg1.name or arg1.Name then
    return arg1
  end
  return nil
end

local HookedUpdateFunctions = {}

local function HookUpdateFunction(fnName)
  if HookedUpdateFunctions[fnName] then
    return false
  end

  local fn = _G[fnName]
  if type(fn) ~= "function" or not hooksecurefunc then return false end

  hooksecurefunc(fnName, function(a1)
    local uf = ResolveUnitFrame(a1)
    if uf then
      ApplyCastBar(uf)
    end
  end)

  HookedUpdateFunctions[fnName] = true
  return true
end

-- Multiple possible names across versions/templates.
local UPDATE_FUNCS = {
  "CompactUnitFrame_UpdateCastBar",
  "DefaultCompactNamePlateFrame_UpdateCastBar",
  "CompactNamePlateFrame_UpdateCastBar",
  "NamePlate_UpdateCastBar",
}

local function InstallCastbarHooks()
  if not hooksecurefunc then return false end

  local installedAny = false
  for _, fnName in ipairs(UPDATE_FUNCS) do
    if HookUpdateFunction(fnName) then
      installedAny = true
    end
  end

  if CastingBarMixin and not CastingBarMixin.__RothBlizzPlatesHooked then
    CastingBarMixin.__RothBlizzPlatesHooked = true

    local function HookMixinMethod(methodName)
      if type(CastingBarMixin[methodName]) ~= "function" then return end
      hooksecurefunc(CastingBarMixin, methodName, function(self)
        local uf = ResolveUnitFrame(self)
        if uf then
          ApplyCastBar(uf)
        end
      end)
      installedAny = true
    end

    HookMixinMethod("OnShow")
    HookMixinMethod("OnEvent")
    HookMixinMethod("UpdateInterruptibleState")
    HookMixinMethod("UpdateIconShown")
  end

  return installedAny
end

local castbarHooksReady = InstallCastbarHooks()
if (not castbarHooksReady) and EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_NamePlates", InstallCastbarHooks)
  EventUtil.ContinueOnAddOnLoaded("Blizzard_UIPanels_Game", InstallCastbarHooks)
end


-- ------------------------------------------------------------
-- Debug helpers (disabled by default)
-- ------------------------------------------------------------
local function DebugPrint(...)
  if RothBlizzPlatesDB and RothBlizzPlatesDB.debugCast then
    print("|cff99ccffRBP Cast|r", ...)
  end
end

local function DumpRegion(reg, indent)
  indent = indent or ""
  if not reg then return end
  local okT, t = pcall(reg.GetObjectType, reg)
  local okS, shown = pcall(reg.IsShown, reg)
  local okN, name = pcall(reg.GetName, reg)
  local line = string.format("%s- %s %s shown=%s", indent, tostring(okT and t or "?"), tostring(okN and name or ""), tostring(okS and shown))
  DebugPrint(line)

  if okT and t == "Texture" and reg.GetTexture then
    local okTex, tex = pcall(reg.GetTexture, reg)
    if okTex then DebugPrint(indent .. "  tex=", tostring(tex)) end
    local okVC, r,g,b,a = pcall(reg.GetVertexColor, reg)
    if okVC then DebugPrint(indent .. string.format("  vc=%.2f %.2f %.2f %.2f", r or 0, g or 0, b or 0, a or 0)) end
  elseif okT and t == "FontString" and reg.GetText then
    local okTxt, txt = pcall(reg.GetText, reg)
    if okTxt then DebugPrint(indent .. "  text=", tostring(txt)) end
  end
end

local function DumpCastForUnit(unit)
  local okNP, np = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not okNP or not np then
    DebugPrint("No nameplate for unit:", unit)
    return
  end
  local uf = np.UnitFrame
  if not uf then
    DebugPrint("No UnitFrame for unit:", unit)
    return
  end
  local cc = FindCastContainer(uf)
  if not cc then
    DebugPrint("No cast container on UnitFrame for unit:", unit)
    return
  end

  DebugPrint("=== Dump castBar for unit:", unit, "===")
  DumpRegion(cc, "")
  local children = SafeChildren(cc)
  DebugPrint("children:", #children)
  for i=1, math.min(#children, 30) do
    DumpRegion(children[i], "  ")
    local regs = { children[i]:GetRegions() }
    for j=1, math.min(#regs, 30) do
      DumpRegion(regs[j], "    ")
    end
  end
end

SLASH_RBPCAST1 = "/rbpcast"
SlashCmdList.RBPCAST = function(msg)
  msg = (msg or ""):lower()
  if msg == "debug" then
    RothBlizzPlatesDB = RothBlizzPlatesDB or {}
    RothBlizzPlatesDB.debugCast = not RothBlizzPlatesDB.debugCast
    SyncDebugFlag()
    print("RothBlizzPlates cast debug:", RothBlizzPlatesDB.debugCast and "ON" or "OFF")
    return
  end
  if msg == "dump" then
    DumpCastForUnit("target")
    return
  end
  print("RBP castbar debug commands:")
  print("  /rbpcast debug  - toggle verbose logging")
  print("  /rbpcast dump   - dump target nameplate castbar regions")
end
