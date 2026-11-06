# Architecture

## Ownership boundary

Blizzard owns nameplate creation, unit assignment, protected geometry, health/cast progress, cast icon/text, visibility, targeting, threat, and state derivation. RothBlizzPlates owns only its decorative textures and font choices.

The addon never reads unit health, names, GUIDs, auras, combat-log payloads, or cast payloads to derive presentation state.

## Source contract

Target: Retail `12.1.5`, interface `120105`.

Selected source: Blizzard UI build `12.1.5.70688`, commit `d07eb00237d8891f153215db98a5df880a26cfe5`.

Canonical paths used:

- health bar: `unitFrame.HealthBarsContainer.healthBar`
- cast bar: `unitFrame.CastBarsContainer.castBar`
- frame-option lifecycle: `NamePlateUnitFrameMixin:ApplyFrameOptions`
- recycle lifecycle: `NamePlateUnitFrameMixin:OnUnitCleared`
- cast start: `CastingBarMixin:GetEffectiveType(..., notInterruptible, ...)`

## Lifecycle

`NAME_PLATE_UNIT_ADDED` resolves exactly one plate. `NAME_PLATE_UNIT_REMOVED` and `OnUnitCleared` invalidate its generation, clear assignment state, hide owned regions, and discard deferred work.

Combat deferral is weak-keyed by unit frame and tagged with the current generation. `PLAYER_REGEN_ENABLED` performs one bounded flush. Inaccessible or missing objects are skipped; they are not placed in retry loops.

A visible-nameplate scan exists only for initial/explicit refresh and is coalesced.

## Secret interruptibility

The cast module maintains two addon-owned border textures. Potentially secret booleans are sent directly to `Region:SetAlphaFromBoolean`:

- Blizzard's `GetEffectiveType` receives `notInterruptible` for cast starts and later transitions.
- The secure post-hook forwards an inaccessible value unchanged.
- The documented accessible `nil` case fails closed to the blocked presentation before entering the sink.

No Lua branch, comparison, negation, format operation, log call, or color inference touches a secret value.

## Deliberate non-features

The addon does not:

- resize or reanchor Blizzard health/cast bars;
- move the native cast icon or text;
- suppress target or threat highlights;
- traverse frame children;
- infer interruptibility from colors or textures;
- hook guessed global function names;
- use `pcall` as a permissions mechanism.
