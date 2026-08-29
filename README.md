# Roth Blizzard Plates

Roth-style visual skin for Blizzard-owned nameplates and cast bars on World of Warcraft Retail 12.1. The addon keeps Blizzard's nameplate and cast-state lifecycle and changes presentation only.

## Preview

![Roth Blizzard Plates nameplate and cast bar](https://media.forgecdn.net/attachments/1569/250/screenshot-2026-03-06-085056-png.png)

Screenshot from the [CurseForge gallery](https://www.curseforge.com/wow/addons/roth-blizz-plates).

## Compatibility

- Game: World of Warcraft Retail / Midnight 12.1.0
- Interface: `120100`
- Version: `0.2.0`
- Verified Blizzard source baseline: `12.1.0.69497`
- Author: Iurii
- External libraries: none
- CurseForge reference: [Roth Blizzard Plates](https://www.curseforge.com/wow/addons/roth-blizz-plates)

## Installation

Copy `RothBlizzPlates` into `World of Warcraft/_retail_/Interface/AddOns/`, enable it in the AddOns list, and reload the UI.

## Retail 12.1 safety model

- Blizzard remains the owner of nameplate creation, unit state, cast state, progress, and update timing.
- The addon does not read `UnitName`, `UnitGUID`, `UnitHealth`, auras, or combat-log payloads to derive presentation state.
- `canaccessvalue`, `CanBeAccessedInContext`, and `IsForbidden` checks gate values and objects before Lua inspection.
- Frame creation, font changes, size changes, and anchor changes are deferred while `InCombatLockdown()` is true.
- Deferred nameplate and castbar work is held in weak-key queues and retried on `PLAYER_REGEN_ENABLED`.
- Castbar discovery uses known Blizzard fields only; it does not sweep child frame trees.
- Unknown interruptibility is rendered conservatively as non-interruptible rather than being inferred from inaccessible state.
- Disabling the castbar option restores the original Blizzard status-bar texture and captured geometry when accessible.

## Commands

`/rbpcast status` reports the number of castbar frames awaiting an out-of-combat presentation pass. It does not dump unit, spell, or restricted frame data.

## Validation status

The two runtime Lua files pass `texlua --luaconly`. `tests/test_combat_deferral.lua` verifies that core and castbar geometry is not mutated in combat, deferred work applies afterward, inaccessible interruptibility fails closed, and Blizzard castbar presentation is restored when the option is disabled.

A live Retail client smoke test is still required for target changes, elite/threat states, cast/channel transitions, interruptibility, UI scale/nameplate CVars, non-Latin font fallback, and taint/forbidden-action logging.

## Developer documentation

- [Architecture](ARCHITECTURE.md)
- [Agent guide](AGENT_GUIDE.md)
- [Code index](CODE_INDEX.md)
- [Code graph](CODE_GRAPH.md)
- [WoW addon engineering knowledge base](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb)

## License

Licensed under the [MIT License](LICENSE).
