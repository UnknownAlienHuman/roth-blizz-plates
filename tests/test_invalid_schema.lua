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

local function NewRegion()
  local region = {
    accessResult = true,
    forbiddenResult = false,
  }
  function region:CanBeAccessedInContext() return self.accessResult end
  function region:IsForbidden() return self.forbiddenResult end
  function region:CreateTexture()
    self.createdTextures = (self.createdTextures or 0) + 1
    return NewRegion()
  end
  function region:Hide() end
  function region:Show() end
  function region:SetTexture() end
  function region:ClearAllPoints() end
  function region:SetPoint() end
  function region:SetSize() end
  function region:SetAlpha() end
  function region:SetFont() end
  function region:SetShadowOffset() end
  function region:SetShadowColor() end
  return region
end

local function RunCase(label, rawSchema)
  local env = setmetatable({}, { __index = _G })
  env._G = env
  env.SlashCmdList = {}
  env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
  env.RothBlizzPlates_CastBar = nil

  local printed = {}
  env.print = function(...)
    local values = {}
    for index = 1, select("#", ...) do
      values[index] = tostring(select(index, ...))
    end
    printed[#printed + 1] = table.concat(values, " ")
  end

  env.canaccessvalue = function() return true end
  env.GetBuildInfo = function() return "12.1.5", "70688", "Oct 2026", 120105 end
  env.GetLocale = function() return "enUS" end
  env.InCombatLockdown = function() return false end
  env.C_Timer = { After = function(_, callback) callback() end }
  env.EventUtil = { ContinueOnAddOnLoaded = function(_, callback) callback() end }

  local settingsRegistrations = 0
  env.Settings = {
    VarType = { Boolean = "Boolean" },
    RegisterVerticalLayoutCategory = function()
      settingsRegistrations = settingsRegistrations + 1
      return {}
    end,
    RegisterAddOnSetting = function() error("invalid schema must not register settings") end,
    CreateCheckbox = function() error("invalid schema must not create settings") end,
    RegisterAddOnCategory = function() error("invalid schema must not register category") end,
  }

  local eventFrames = {}
  env.CreateFrame = function()
    local frame = NewRegion()
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
  env.hooksecurefunc = function(target, methodName, callback)
    local original = target[methodName]
    target[methodName] = function(...)
      local results = pack(original(...))
      callback(...)
      return table.unpack(results, 1, results.n)
    end
  end

  env.NamePlateBaseMixin = { AcquireUnitFrame = function() end }
  env.NamePlateUnitFrameMixin = {
    ApplyFrameOptions = function() end,
    OnUnitSet = function() end,
    OnUnitCleared = function() end,
  }
  env.C_NamePlate = {
    GetNamePlateForUnit = function() return nil end,
    GetNamePlates = function() return {} end,
  }

  local db = {
    schemaVersion = rawSchema,
    enabled = true,
    plate = { x = 6, y = 4, futureField = "keep" },
    healthBar = { x = 6, y = 3.5, keep = true },
    futureRoot = { token = label },
  }
  env.RothBlizzPlatesDB = db

  local chunk = assert(loadfile(ROOT .. "/core.lua", "t", env))
  chunk("RothBlizzPlates")

  assertEqual(env.RothBlizzPlatesDB, db, label .. " database identity")
  if rawSchema == rawSchema then
    assertEqual(db.schemaVersion, rawSchema, label .. " schema preserved")
  else
    assertTrue(db.schemaVersion ~= db.schemaVersion, label .. " NaN preserved")
  end
  assertEqual(db.plate.x, 6, label .. " plate X untouched")
  assertEqual(db.plate.offsetX, nil, label .. " no partial migration")
  assertEqual(db.healthBar.keep, true, label .. " legacy-looking field preserved")
  assertEqual(db.futureRoot.token, label, label .. " future field preserved")

  assertEqual(env.RothBlizzPlates.IsRuntimeSupported(), false, label .. " runtime disabled")
  local interfaceSupported, databaseSupported, schemaVersion, failureReason =
    env.RothBlizzPlates.GetCompatibilityStatus()
  assertEqual(interfaceSupported, true, label .. " interface supported")
  assertEqual(databaseSupported, false, label .. " database rejected")
  if rawSchema == rawSchema then
    assertEqual(schemaVersion, rawSchema, label .. " schema status")
  else
    assertTrue(schemaVersion ~= schemaVersion, label .. " NaN status")
  end
  assertEqual(failureReason, "invalid", label .. " failure reason")

  local eventFrame = eventFrames[1]
  assertTrue(eventFrame ~= nil, label .. " event frame")
  eventFrame:Trigger("PLAYER_LOGIN")
  assertEqual(settingsRegistrations, 0, label .. " settings not registered")
  assertEqual(#printed, 1, label .. " one warning")
  assertTrue(printed[1]:find("schema value", 1, true) ~= nil, label .. " warning mentions invalid schema")
end

RunCase("string", "99")
RunCase("boolean", true)
RunCase("fractional", 3.5)
RunCase("negative", -1)
RunCase("nan", 0 / 0)

print("test_invalid_schema.lua: ok")
