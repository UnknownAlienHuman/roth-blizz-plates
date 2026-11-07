from pathlib import Path

root = Path(__file__).resolve().parents[1]
core = (root / "core.lua").read_text(encoding="utf-8")
cast = (root / "castbar_12_1.lua").read_text(encoding="utf-8")
toc = (root / "RothBlizzPlates.toc").read_text(encoding="utf-8")
all_lua = core + "\n" + cast

for forbidden in (
    "GetChildren(",
    "HookScript(",
    "pcall(",
    "C_Timer.NewTicker(",
    "UnitCastingInfo(",
    "UnitChannelInfo(",
    "GetStatusBarColor(",
    "GetVertexColor(",
    "UnitName(",
    "UnitGUID(",
    "UnitHealth(",
    "CombatLogGetCurrentEventInfo(",
    "UNIT_COMBAT",
):
    assert forbidden not in all_lua, f"forbidden pattern present: {forbidden}"

assert "unitFrame.CastBarsContainer" in cast
assert "container.castBar" in cast
assert "SetAlphaFromBoolean" in cast
assert "NormalizeNotInterruptible" in cast
assert "ApplyInterruptibleSignal" in cast
assert "castBar:IsInterruptable()" in cast
assert "ResolveHookOwner" in cast
assert "NamePlateCastingBarMixin.GetEffectiveType" in cast
assert 'hooksecurefunc(hookOwner, "GetEffectiveType"' in cast
assert 'hooksecurefunc(CastingBarMixin, "GetEffectiveType"' not in cast
assert "return CastingBarMixin" not in cast
assert "local function IsRuntimeSupported" in cast
assert "not IsRuntimeSupported() or not IsUsableRegion(unitFrame)" in cast
assert "HooksInstalled or not IsRuntimeSupported()" in cast
assert "notInterruptible and" not in cast
assert "not notInterruptible" not in cast
assert "isInterruptible and" not in cast
assert "not isInterruptible" not in cast

assert "## Interface: 120105" in toc
assert "## Version: 0.3.8" in toc
assert "## X-Source-Build: 12.1.5.70783" in toc
assert "297d7aaaa736f346b3e036f38ee088eaf7f8c07f" in toc
assert "local EXPECTED_INTERFACE = 120105" in core
assert "local SCHEMA_VERSION = 4" in core
assert "local function ResolveSchemaVersion" in core
assert 'return nil, "invalid"' in core
assert 'return rawVersion, "newer"' in core
assert "DatabaseFailureReason" in core
assert "InterfaceSupported and DatabaseSupported" in core
assert "not DatabaseSupported or not Settings" in core
assert "RuntimeSupported and castModule" in core

assert core.count("C_NamePlate.GetNamePlates()") == 1
assert 'NamePlateBaseMixin, "AcquireUnitFrame"' in core
assert 'NamePlateUnitFrameMixin, "OnUnitSet"' in core
assert 'NamePlateUnitFrameMixin, "OnUnitCleared"' in core
assert "castModule.Prepare(unitFrame)" in core
assert "local function InstallCastHooks" in core
assert "castModule.InstallHooks()" in core
assert "plate.offsetX" in core and "plate.offsetY" in core
assert "IsReadableTable(plates)" in core
assert "for _, namePlate in pairs(plates)" in core
assert ":SetAlpha(" not in cast

# Native nameplate size is observed from Blizzard's exact frame-options pass.
# Addon-owned plate/cast art and custom font height use the same horizontal /
# vertical scale without changing native frame geometry or writing the CVar.
assert "local function CaptureFrameScale" in core
assert "local function EnsureFrameScale" in core
assert "setupOptions.horizontalScale" in core
assert "setupOptions.verticalScale" in core
assert 'NamePlateUnitFrameMixin, "ApplyFrameOptions", function(unitFrame, setupOptions)' in core
assert "DB.plate.width * scaleX" in core
assert "DB.plate.height * scaleY" in core
assert "DB.font.size * scaleY" in core
assert "castModule.Apply(unitFrame, scaleX, scaleY)" in core
assert "border.width * scaleX" in cast
assert "border.height * scaleY" in cast
assert "C_CVar.SetCVar" not in all_lua
assert "SetCVar(" not in all_lua
assert "nameplateSize" not in all_lua

# Native font presentation is snapshotted and restored, including the actual
# FontObject link, deferred release, and foreign-owner coexistence.
assert "local FontStateByString" in core
assert "local PendingFontRestoreByFrame" in core
assert "local function ReadFontObject" in core
assert "fontString:GetFontObject()" in core
assert "fontString:SetFontObject(original.fontObject)" in core
assert "left.fontObject == right.fontObject" in core
assert "local function ReadFontPresentation" in core
assert "local function RestoreFont" in core
assert "local function RestoreFrameFonts" in core
assert "PendingFontRestoreByFrame[unitFrame] = state.generation" in core
assert "state and not state.active and state.generation == generation" in core
assert "PendingFontRestoreByFrame[unitFrame] = nil" in core
assert "not SameFontPresentation(current, state.applied)" in core
assert "current.shadowX ~= nil" in core
assert "current.shadowR ~= nil" in core
assert "relinquish" in core.lower()
assert core.index("if InCombatLockdown() then", core.index("local function RefreshVisible")) < core.index("if not RuntimeSupported or not DB.enabled", core.index("local function RefreshVisible"))

# Secret-capable object-security returns are gated before boolean comparison.
assert "local canAccess = region:CanBeAccessedInContext()" in core
assert "not IsAccessible(canAccess)" in core
assert "local forbidden = region:IsForbidden()" in core
assert "not IsAccessible(forbidden)" in core
assert "and not region:CanBeAccessedInContext()" not in all_lua
assert "and region:IsForbidden()" not in all_lua

# Native frame geometry is not changed. Geometry calls are confined to
# addon-owned textures named plate/texture.
for line in all_lua.splitlines():
    stripped = line.strip()
    if any(token in stripped for token in (":ClearAllPoints()", ":SetPoint(", ":SetSize(")):
        assert stripped.startswith(("plate:", "texture:")), f"unexpected geometry write: {stripped}"

print("static_check.py: ok")
