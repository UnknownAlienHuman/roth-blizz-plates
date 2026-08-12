# Roth Blizzard Plates architecture

`core.lua` owns media paths, SavedVariables, nameplate discovery and visual policy. `castbar.lua` applies the Roth cast-bar layer. The addon deliberately skins existing Blizzard widgets rather than replacing their lifecycle or combat logic.

The main safety boundary is visual-only mutation: textures, fonts and static overlays are changed, while unit identity, health values and secret-anchor arithmetic are not used by the implementation.
