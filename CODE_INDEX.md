# Roth Blizzard Plates code index

| File | Responsibility |
|---|---|
| `RothBlizzPlates.toc` | Retail 12.1 metadata, SavedVariables declaration, and definitive load order |
| `core.lua` | Database defaults/sanitization, accessibility gates, nameplate presentation, Settings, lifecycle hooks, and nameplate combat-deferral queue |
| `castbar_12_1.lua` | Direct-field castbar discovery, texture/border/icon presentation, conservative interruptibility, restore behavior, hooks, and castbar combat-deferral queue |
| `tests/test_combat_deferral.lua` | Mocked regression for no geometry mutation in combat, deferred apply, fail-closed interruptibility, and Blizzard presentation restore |
| `media/` | Roth font, plate, castbar, icon-slot, and threat textures |

Detailed ownership and state routing are in [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`AGENT_GUIDE.md`](AGENT_GUIDE.md).
