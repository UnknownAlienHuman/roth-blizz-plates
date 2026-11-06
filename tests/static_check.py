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
assert "local EXPECTED_INTERFACE = 120105" in core
assert "d07eb00237d8891f153215db98a5df880a26cfe5" in toc
assert core.count("C_NamePlate.GetNamePlates()") == 1
assert "NAME_PLATE_UNIT_REMOVED" in core
assert "OnUnitCleared" in core
assert ":SetAlpha(" not in cast

# Native frame geometry is not changed. Geometry calls are confined to addon-owned
# textures named plate/texture/state.*.
for line in all_lua.splitlines():
    stripped = line.strip()
    if any(token in stripped for token in (":ClearAllPoints()", ":SetPoint(", ":SetSize(")):
        assert stripped.startswith(("plate:", "texture:")), f"unexpected geometry write: {stripped}"

print("static_check.py: ok")
