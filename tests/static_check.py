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
):
    assert forbidden not in all_lua, f"forbidden pattern present: {forbidden}"

assert "unitFrame.CastBarsContainer" in cast
assert "container.castBar" in cast
assert "SetAlphaFromBoolean" in cast
assert "NormalizeNotInterruptible" in cast
assert "notInterruptible and" not in cast
assert "not notInterruptible" not in cast
assert "## Interface: 120105" in toc
assert "## Version: 0.3.2" in toc
assert "local EXPECTED_INTERFACE = 120105" in core
assert "local SCHEMA_VERSION = 4" in core
assert "if previousSchema > SCHEMA_VERSION then" in core
assert "return db, false, previousSchema" in core
assert "InterfaceSupported and DatabaseSupported" in core
assert "not DatabaseSupported or not Settings" in core
assert "RuntimeSupported and castModule" in core
assert "d07eb00237d8891f153215db98a5df880a26cfe5" in toc
assert core.count("C_NamePlate.GetNamePlates()") == 1
assert "NamePlateBaseMixin, \"AcquireUnitFrame\"" in core
assert "NamePlateUnitFrameMixin, \"OnUnitSet\"" in core
assert "NamePlateUnitFrameMixin, \"OnUnitCleared\"" in core
assert "castModule.Prepare(unitFrame)" in core
assert "plate.offsetX" in core and "plate.offsetY" in core
assert "for _, namePlate in pairs(plates)" in core
assert ":SetAlpha(" not in cast

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
