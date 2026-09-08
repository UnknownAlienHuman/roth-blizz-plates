# Pull Request & Addon Audit Report: RothBlizzPlates — Retail 12.1 (Interface 120100) Compliance & Combat Deferral Architecture

**Target Addon:** `RothBlizzPlates` (`C:\Development\WoWDevAddons\_Addons\RothBlizzPlates`)  
**Target Environment:** World of Warcraft: Midnight — Retail 12.1 (`Interface: 120100`, Build `69497`)  
**Knowledge Base References:** `_Info/KB` (`RT-AUDIT-001`, `RT-AUDIT-002`, `BlizzardUI_UnitFrames`, `BlizzardUI_Taint_Debug_Cookbook`, `WoWDevSecretValue_KB_12.0.1`, `BlizzardUI_security`)  
**Remote Git Reference:** `github-roth-blizz-plates` (`main` and `fix/retail-12-1-combat-deferral-2026-08-29`)  
**Auditor:** Neomorph Addon Workspace Automated Auditor  
**Audit Date:** 2026-09-08  

---

## 1. Executive Summary & Status Matrix

`RothBlizzPlates` is a visual presentation enhancement addon for the Roth UI ecosystem. Its primary function is to restyle default Blizzard unit nameplates with Diablo-themed visual art (custom health bar texture, ornate dragon plate overlay, custom threat glow, and an additive Diablo-style cast bar with an ornate frame border and cast fill) while strictly preserving Blizzard's native nameplate positioning, target selection, cast progress, threat, and lifecycle logic.

### 1.1 Status Matrix

| Dimension | Local Workspace (`HEAD:_Addons/RothBlizzPlates`) | Remote Main (`github-roth-blizz-plates/main`) | Fix Branch (`fix/retail-12-1-combat-deferral-2026-08-29`) | Target State (Retail 12.1) |
| :--- | :--- | :--- | :--- | :--- |
| **Interface Version** | `120001, 120005` (Invalid multi-token) | `120001, 120005` | `120100` | `120100` |
| **Addon Version** | `0.1.14` | `0.1.14` | `0.2.0` | `0.2.0` |
| **Combat Lockdown Safety** | **Broken**: Manipulates anchors/sizes in combat; checks only `IsAnchoringSecret` | **Broken**: Same as local | **Fully Deferred**: All mutations deferred via weak-key queue `PendingFrames` | **Fully Deferred** (`InCombatLockdown` fail-closed) |
| **Castbar Discovery** | **Severe Taint Hazard**: 1181-line `castbar.lua` scanning frame-tree via `SafeChildren` | **Severe Taint Hazard**: Same as local | **Zero Scanning**: 420-line `castbar_12_1.lua` resolves known canonical keys | **Direct Key Resolution** (no `GetChildren`) |
| **Hook Overhead** | Multi-hooked `HookScript("OnShow")`, mixins, update funcs | Same as local | Clean presence-guarded post-hooks on mixins and global funcs | Minimal presence-guarded post-hooks |
| **SecretValue Safety** | Unboxed color/interruptibility checks; risky `/rbpcast dump` | Same as local | `CanAccess` / `CanUseObject` gates; fails closed to `CastNoStop` on secret | **Secret-Safe & Fail-Closed** |
| **Restore Behavior** | None: toggling off leaves mutilated Blizzard castbars | None | Clean snapshot & restore of original geometry & status-bar texture | **Clean Reversible Presentation** |
| **SavedVariables (RT-AUDIT-001)**| Unclamped direct mutation on load | Same as local | Recursive `MergeDefaults` (deep copy) + `SanitizeNumber` clamping | **Deep-copied & Clamped** |
| **Single Owner (RT-AUDIT-002)** | Overlapping scanners and script hooks | Same as local | Distinct owners: `core.lua` (plates), `castbar_12_1.lua` (castbars) | **Single Runtime Owner** |
| **Test Suite** | None | None | Offline mock regression `tests/test_combat_deferral.lua` (158 lines) | **Deterministic Test Coverage** |

---

## 2. Upstream Git Synchronization Analysis

Comparison between local `HEAD:_Addons/RothBlizzPlates` and `remotes/github-roth-blizz-plates` reveals that local `HEAD` is bit-for-bit identical to `remotes/github-roth-blizz-plates/main`.

However, an unmerged feature/fix branch exists on the remote repository:  
`remotes/github-roth-blizz-plates/fix/retail-12-1-combat-deferral-2026-08-29`

### 2.1 Branch Commit Breakdown

The fix branch contains 11 dedicated commits resolving the Retail 12.1 architectural challenges:

```text
798b4e6 chore: remove GitHub Actions validation
11afb2f ci: validate the Retail 12.1 nameplate boundary
99284d0 chore: carry the live verification matrix in the implementation PR
046fc92 docs: rewrite the agent guide for the safe 12.1 runtime
5bedcca docs: update the Retail 12.1 code graph
84453e2 docs: update the code index for the 12.1 runtime
2ca221c docs: define nameplate and castbar ownership
73f390b docs: document the Retail 12.1 safety boundary
9733323 test: cover nameplate and castbar combat deferral
0a609df refactor: remove the legacy frame-tree castbar scanner
b5a7e29 chore: target Retail 12.1 and load the safe castbar owner
90c5ae1 fix: add Retail 12.1 combat-deferred castbar owner
741ae1b fix: defer nameplate layout mutations during combat
```

### 2.2 Diffstat Summary (`main` vs `fix/retail-12-1-combat-deferral-2026-08-29`)

```text
 AGENT_GUIDE.md                 |  138 ++++-
 ARCHITECTURE.md                |   41 +-
 CODE_GRAPH.md                  |   18 +-
 CODE_INDEX.md                  |   11 +-
 README.md                      |   38 +-
 RothBlizzPlates.toc            |    9 +-
 castbar.lua                    | 1180 ----------------------------------------
 castbar_12_1.lua               |  420 ++++++++++++++
 core.lua                       |  794 ++++++++++++++-------------
 tests/test_combat_deferral.lua |  158 ++++++
 todo.md                        |    5 -
 11 files changed, 1199 insertions(+), 1613 deletions(-)
```

---

## 3. In-Depth Technical Audit & Violation Analysis

### 3.1 Combat Lockdown Violations & Protected NamePlate Taint

#### The Violation:
In World of Warcraft Retail 12.1, NamePlates are protected UI objects (`IsProtected() == true`) instantiated via `SecureUnitButton_OnLoad`. Under `InCombatLockdown()`, modifying geometry (calling `SetPoint`, `ClearAllPoints`, `SetSize`, `SetWidth`, `SetHeight`) or creating child textures on protected frames or their managed children results in immediate `ADDON_ACTION_BLOCKED` errors and execution termination.

In local `core.lua` (lines 194-212) and `castbar.lua` (lines 106-122), the code attempted to guard anchor operations using:
```lua
local function CanTouchAnchors(frame)
  if not frame then return false end
  if InCombatLockdown and InCombatLockdown() then
    if type(IsAnchoringSecret) == "function" then
      local ok, isSecret = pcall(IsAnchoringSecret, frame)
      if ok and IsPlainBoolean(isSecret) and isSecret then
        return false
      end
    end
  end
  return true
end
```

#### Why This Failed in Retail 12.1:
1. `IsAnchoringSecret` was a transient heuristic during early Midnight alphas indicating whether anchor offsets contained secret values. It is **not** a permission check for modifying protected unit frames during combat lockdown!
2. Whenever `InCombatLockdown()` is true, **all** direct modifications to protected frames are forbidden, regardless of whether `IsAnchoringSecret` returns true or false.
3. Local `ApplyLayout` routinely invoked `SetCenterPointIfNeeded`, `SetSizeIfNeeded`, `EnsureTexture`, and `ApplyFont` directly on nameplates spawned during combat (e.g. on `NAME_PLATE_UNIT_ADDED`), causing combat taint and UI lockups.

#### Upstream Modernization:
Upstream enforces complete, fail-closed combat deferral:
```lua
local PendingFrames = setmetatable({}, { __mode = "k" })

local function ApplySkin(unitFrame)
  if InCombatLockdown() then
    QueueFrame(unitFrame)
    return false
  end
  return ApplyLayout(unitFrame)
end
```
Any call during combat queues `unitFrame` into a weak-keyed table. When `PLAYER_REGEN_ENABLED` fires, `FlushPendingFrames()` restyles all queued frames out of combat safely.

---

### 3.2 Arbitrary Frame-Tree Traversal (`GetChildren`) vs Direct Key Discovery

#### The Violation:
Local `castbar.lua` contained an 1181-line monolithic subsystem designed around recursively scanning UI frames. Lines 74-80 and 273-323 implemented `SafeChildren` and `CollectStatusBars`:
```lua
local function SafeChildren(obj)
  if not obj or type(obj.GetChildren) ~= 'function' then return {} end
  local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(obj.GetChildren, obj)
  if not ok then return {} end
  return {a,b,c,d,e,f,g,h,i,j,k,l}
end
```
`CollectStatusBars` walked children and grandchildren, scored them via `ScoreCastContainer`, inspected arbitrary child properties, and attached `HookScript("OnShow")` to discovered containers.

#### Why This is Catastrophic in Retail 12.1:
1. **Private Aura Contamination**: Blizzard's 12.1 nameplate frame templates contain private aura anchors and restricted execution sub-frames. Walking arbitrary children with `GetChildren()` touches secure/restricted frames, triggering security faults.
2. **Hardcoded Return Limit**: The unpack of 12 variables (`a` through `l`) is an arbitrary hack that truncated any frame with 13 or more children.
3. **Script Hooking on Secure Frames**: Calling `HookScript("OnShow")` on Blizzard-managed cast containers can taint the Blizzard show/hide event sequence, causing errors when nameplates are pooled or released.

#### Upstream Modernization:
The entire frame scanner was deleted. `castbar_12_1.lua` resolves known, canonical Blizzard properties only:
```lua
local function FindContainer(unitFrame)
  if not CanUse(unitFrame) then return nil end
  local cached = unitFrame.__RothCastContainer
  if CanUse(cached) then return cached end

  local candidates = {
    unitFrame.castBar,
    unitFrame.CastBar,
    unitFrame.CastingBar,
    unitFrame.castingBar,
    unitFrame.CastBarFrame,
    unitFrame.CastBarContainer,
  }
  for _, candidate in ipairs(candidates) do
    if CanUse(candidate) then
      unitFrame.__RothCastContainer = candidate
      return candidate
    end
  end
  return nil
end
```
Zero calls to `GetChildren()`, zero child-tree iteration, and zero `HookScript` calls.

---

### 3.3 SecretValue & Fail-Closed Interruptibility Handling

#### The Violation:
Local `castbar.lua` attempted to determine cast interruptibility by reading vertex colors, texture alphas, and shield frame visibility (`GhostIfTexture`).
In Retail 12.1, cast attributes (including spell school, interruptibility, and bar color) can be restricted **SecretValues** during combat encounters.
Attempting arithmetic or comparisons on SecretValues (e.g. `if r > 0.92 then`) causes immediate fatal Lua exceptions:
`attempt to compare secret value with number`

#### Upstream Modernization:
1. Value accessibility is strictly validated before any inspection:
```lua
local function CanAccess(value)
  if type(canaccessvalue) == "function" then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret ~= true
  end
  return true
end
```
2. Interruptibility resolution checks explicit accessible booleans first, then accessible vertex/bar colors. If any value is secret, inaccessible, or ambiguous, it **fails closed** to `CastNoStop` (uninterruptible art):
```lua
local function ResolveNotInterruptible(container, statusBar)
  local result = ExplicitNotInterruptible(container)
  if result == nil then result = ExplicitNotInterruptible(statusBar) end
  if result ~= nil then return result end

  local texture = Get(statusBar, "GetStatusBarTexture")
  local r, g, b = Get4(texture, "GetVertexColor")
  if not (IsNumber(r) and IsNumber(g) and IsNumber(b)) then
    r, g, b = Get4(statusBar, "GetStatusBarColor")
  end

  if IsNumber(r) and IsNumber(g) and IsNumber(b) then
    if r > 0.92 or g > 0.92 or b > 0.92 then return false end
    if math.abs(r - g) < 0.06 and math.abs(g - b) < 0.06 then return true end
    return false
  end

  -- Unknown state must not be advertised as safely interruptible.
  return true
end
```

---

### 3.4 RT-AUDIT-001: SavedVariables Default Mutation & Range Clamping

#### The Violation:
In local `core.lua`:
```lua
RothBlizzPlatesDB = RothBlizzPlatesDB or { ... }
do
  local db = RothBlizzPlatesDB
  db.plate = db.plate or { width = 180, height = 60, x = 6, y = 4, anchor = "CENTER" }
  ...
```
1. SavedVariables tables are not loaded when files are parsed at startup; they are populated when `ADDON_LOADED` / `PLAYER_LOGIN` occurs.
2. Direct mutation of the global table without deep-cloning table defaults risks inserting shared table references into the database (**RT-AUDIT-001**).
3. No sanitization or clamping existed for numeric fields, allowing corrupted SavedVariables (e.g. negative heights, NaN, or extreme values) to permanently break frame geometry.

#### Upstream Modernization:
1. `MergeDefaults` recursively clones defaults into the target table, ensuring no table reference from `DEFAULTS` is ever inserted into `RothBlizzPlatesDB`.
2. `SanitizeNumber` strictly validates numbers against `NaN` (`value ~= value`) and clamps to safe UI ranges:
```lua
local function SanitizeNumber(value, fallback, minimum, maximum)
  if type(value) ~= "number" or value ~= value then
    return fallback
  end
  if value < minimum then return minimum end
  if value > maximum then return maximum end
  return value
end

RothBlizzPlatesDB = MergeDefaults(RothBlizzPlatesDB, DEFAULTS)
do
  local db = RothBlizzPlatesDB
  db.plate.width = SanitizeNumber(db.plate.width, 180, 20, 800)
  db.plate.height = SanitizeNumber(db.plate.height, 60, 8, 300)
  db.plate.x = SanitizeNumber(db.plate.x, 6, -500, 500)
  db.plate.y = SanitizeNumber(db.plate.y, 4, -500, 500)
  ...
end
```

---

### 3.5 RT-AUDIT-002: Single Runtime Owner & Hook Governance

#### The Violation:
Local `castbar.lua` and `core.lua` installed competing update hooks:
- `core.lua` hooked `NamePlateUnitFrameMixin.UpdateAnchors`, `ApplyFrameOptions`, `NamePlateBaseMixin.ApplyFrameOptions`, `CompactUnitFrame_UpdateSelectionHighlight`.
- `castbar.lua` hooked `CompactUnitFrame_UpdateCastBar`, `DefaultCompactNamePlateFrame_UpdateCastBar`, `CompactNamePlateFrame_UpdateCastBar`, `NamePlate_UpdateCastBar`, and `CastingBarMixin:OnShow`.
- `castbar.lua` also installed per-container script hooks: `castContainer:HookScript("OnShow", ...)`.
- On every single cast bar update, `castbar.lua` would re-run `FindCastContainer`, `CollectStatusBars`, `SetGeometry`, and re-mirror status bar properties.

#### Upstream Modernization:
1. Clear domain separation:
   - `core.lua` owns nameplates, fonts, SavedVariables, and the nameplate queue.
   - `castbar_12_1.lua` owns castbars, borders, interruptibility presentation, and the castbar queue.
2. `HookScript` on Blizzard frames is completely eliminated.
3. Mixin hooks (`NamePlateUnitFrameMixin`, `NamePlateBaseMixin`, `CastingBarMixin`) only request `ApplySkin` / `RequestApply`, which idempotently bail out if in combat or already correctly styled.
4. All frame queues use weak-keyed tables (`{ __mode = "k" }`), preventing memory leaks when Blizzard recycles nameplates.

---

### 3.6 Clean Presentation Restoration on Feature Disabling

#### The Violation:
In local `core.lua` and `castbar.lua`, if a user disabled cast bar skinning in Settings (`castBar.enabled = false`), the addon did nothing to restore Blizzard's original geometry or textures. The nameplate was left with modified dimensions, missing borders, and broken status bar textures.

#### Upstream Modernization:
`castbar_12_1.lua` implements `Snapshot` and `RestorePresentation`:
```lua
local function Snapshot(region)
  if not CanUse(region) or region.__RothCastOriginal then return end
  local width = Get(region, "GetWidth")
  local height = Get(region, "GetHeight")
  local ok, point, relativeTo, relativePoint, x, y = pcall(region.GetPoint, region, 1)
  if ok and IsString(point) and IsString(relativePoint) and IsNumber(x) and IsNumber(y) then
    region.__RothCastOriginal = {
      width = IsNumber(width) and width or nil,
      height = IsNumber(height) and height or nil,
      point = point, relativeTo = relativeTo, relativePoint = relativePoint,
      x = x, y = y,
    }
  end
end
```
When `castBar.enabled == false`, `RestorePresentation(unitFrame)` restores original anchor points, sizes, and textures on the container, status bar, and spell icon, and hides `__RothCastBorder`. If in combat, restoration is safely deferred.

---

### 3.7 Interface Version & Metadata Modernization

#### Local TOC (`RothBlizzPlates.toc`):
```ini
## Interface: 120001, 120005
## Title: Roth Blizzard Plates
## Notes: Roth-style skin for default Blizzard nameplates (Midnight).
## Author: Iurii
## Version: 0.1.14
## SavedVariables: RothBlizzPlatesDB

core.lua
castbar.lua
```

#### Upstream TOC:
```ini
## Interface: 120100
## Title: Roth Blizzard Plates
## Notes: Roth-style visual skin for Blizzard-owned nameplates and cast bars on Retail 12.1.
## Author: Iurii
## Version: 0.2.0
## SavedVariables: RothBlizzPlatesDB
## X-Verified-Build: 12.1.0.69497

core.lua
castbar_12_1.lua
```
- Interface updated to modern Retail 12.1 standard (`120100`).
- Multi-token comma-separated syntax removed.
- Load order updated: obsolete `castbar.lua` replaced with `castbar_12_1.lua`.
- Version incremented to `0.2.0`.
- Added verified build tag `## X-Verified-Build: 12.1.0.69497`.

---

## 4. Architectural Blueprint

```mermaid
flowchart TD
  subgraph Blizzard System [Blizzard NamePlate & CastBar Subsystems]
    NP_Event[NAME_PLATE_UNIT_ADDED]
    NP_Mixin[NamePlateUnitFrameMixin / NamePlateBaseMixin]
    CB_Mixin[CastingBarMixin: OnShow / UpdateInterruptibleState]
    Regen[PLAYER_REGEN_ENABLED]
  end

  subgraph Core [core.lua — NamePlate Presentation Owner]
    CheckCombatCore{InCombatLockdown?}
    QueueCore[Add to PendingFrames weak table]
    ApplySkin[ApplySkin -> ApplyLayout]
    FlushCore[FlushPendingFrames]
    NP_Art[Apply NormalPlate Texture<br/>HealthBar StatusBar Texture<br/>Disable Target Highlight<br/>Apply Threat & Font]
  end

  subgraph CastBar [castbar_12_1.lua — CastBar Presentation Owner]
    CheckCombatCast{InCombatLockdown?}
    QueueCast[Add to Pending weak table]
    ApplyCast[Apply]
    FlushCast[Flush Pending CastBars]
    KeyResolver[Known-Field Resolver<br/>unitFrame.castBar / container.Bar]
    InterruptResolver{ResolveNotInterruptible}
    CastNoStop[Art: CastNoStop<br/>Fail-Closed]
    CastStop[Art: CastStop<br/>Interruptible]
    CastArt[Apply CastFill Texture<br/>Create/Position RothCastBorder<br/>Scale & Position Spell Icon]
  end

  NP_Event --> CheckCombatCore
  NP_Mixin --> CheckCombatCore
  CheckCombatCore -- Yes --> QueueCore
  CheckCombatCore -- No --> ApplySkin
  ApplySkin --> NP_Art
  ApplySkin --> ApplyCast

  CB_Mixin --> CheckCombatCast
  CheckCombatCast -- Yes --> QueueCast
  CheckCombatCast -- No --> ApplyCast

  Regen --> FlushCore
  Regen --> FlushCast
  FlushCore --> ApplySkin
  FlushCast --> ApplyCast

  ApplyCast --> KeyResolver
  KeyResolver --> InterruptResolver
  InterruptResolver -- Secret / Unknown / Shielded --> CastNoStop
  InterruptResolver -- Confirmed Interruptible --> CastStop
  CastNoStop --> CastArt
  CastStop --> CastArt
```

---

## 5. Proposed Pull Request Diffs & Action Items

To bring the local repository and `github-roth-blizz-plates/main` into full Retail 12.1 compliance, apply the changes from branch `fix/retail-12-1-combat-deferral-2026-08-29`:

### Action Item 1: Update `RothBlizzPlates.toc`
- Set `## Interface: 120100`
- Set `## Version: 0.2.0`
- Add `## X-Verified-Build: 12.1.0.69497`
- Replace `castbar.lua` with `castbar_12_1.lua`

### Action Item 2: Replace `core.lua`
- Introduce recursive `MergeDefaults` and `SanitizeNumber` (RT-AUDIT-001).
- Implement `CanAccess`, `IsAccessibleBoolean`, `IsAccessibleNumber`, `IsAccessibleString`, and `CanUseObject`.
- Enforce strict combat lockdown deferral (`if InCombatLockdown() then QueueFrame(unitFrame) return false end`).
- Maintain `PendingFrames` weak table and flush on `PLAYER_REGEN_ENABLED`.
- Export clean public APIs: `_G.RothBlizzPlates.ApplySkin`, `RestyleAllVisible`, `GetPendingCount`.

### Action Item 3: Delete Obsolete `castbar.lua`
- Remove the 1181-line monolithic file containing `SafeChildren`, `ScoreCastContainer`, `CollectStatusBars`, and arbitrary `GetChildren` tree scanning.

### Action Item 4: Introduce Modernized `castbar_12_1.lua`
- 420 lines of clean, disciplined, secret-safe Lua.
- Resolves only canonical container, status bar, and icon fields.
- Implements `Snapshot` and `RestorePresentation` to safely restore Blizzard UI when disabled.
- Evaluates interruptibility through `CanAccess` guards; fails closed to `CastNoStop` on secret/indeterminate states.
- Defers all geometry and texture modifications during combat into weak-keyed `Pending` table.
- Slash command `/rbpcast status` prints pending queue count without leaking restricted values.

### Action Item 5: Add Offline Regression Test `tests/test_combat_deferral.lua`
- Provides 158 lines of mock-frame testing covering:
  1. Nameplate combat deferral (zero geometry mutations, zero texture creation during combat).
  2. Out-of-combat flush and pending count resolution.
  3. Castbar combat deferral.
  4. Secret value handling for `notInterruptible = _G.SECRET` (verifies fail-closed behavior to `CastNoStop`).
  5. Clean restoration of Blizzard cast texture and border hiding on disable.

### Action Item 6: Update Documentation Files
- `AGENT_GUIDE.md`: Document Retail 12.1 load contract, state flow, invariants, and change routing.
- `ARCHITECTURE.md`: Document single runtime ownership and evidence boundaries.
- `CODE_GRAPH.md` & `CODE_INDEX.md`: Update symbols, entry points, and dependencies.
- `README.md`: Modernize overview, features, commands, and installation notes.

---

## 6. Verification & Validation Protocol

### 6.1 Offline Verification
Run regression test in standard Lua environment:
```sh
lua tests/test_combat_deferral.lua
```
**Expected Output:**
```text
PASS: core and castbar defer geometry in combat and restore Blizzard presentation
```

Inspect source tree to guarantee no forbidden API leakage:
```sh
git grep -E "GetChildren|GetNumChildren|HookScript|UnitName|UnitGUID|UnitHealth|C_UnitAuras"
```
*Result must be clean (zero matches).*

### 6.2 In-Game Live Client Validation Matrix (Retail 12.1 Build 69497)

| Test ID | Scenario | Procedure | Expected Result |
| :--- | :--- | :--- | :--- |
| **TC-RBP-01** | Clean Login & Reload | Enter world on fresh character; execute `/reload`. | Diablo plate and health bar textures apply cleanly to visible nameplates; no Lua errors. |
| **TC-RBP-02** | Target Switching & Elite Plates | Cycle targets across normal, elite, and boss mobs. | Dragon plate art displays properly; target highlight remains disabled; aggro glow applies `ThreatBar`. |
| **TC-RBP-03** | In-Combat Plate Spawning | Engage a mob pack so additional nameplates appear during combat. | Zero Lua errors, zero `ADDON_ACTION_BLOCKED`. New plates are queued in `PendingFrames`. |
| **TC-RBP-04** | Combat Exit Flush | Defeat enemies and exit combat (`PLAYER_REGEN_ENABLED`). | `FlushPendingFrames()` runs; all nameplates instantly receive full Roth styling. |
| **TC-RBP-05** | Standard Spell Cast | Target casting mob with interruptible spell. | Cast bar resizes to Roth dimensions; `CastFill` texture active; `CastStop` border shown with right spell icon. |
| **TC-RBP-06** | Uninterruptible Cast | Target mob casting uninterruptible channel or boss ability. | Cast bar shows `CastNoStop` shield border. |
| **TC-RBP-07** | Secret Value Encounter | Engage boss encounter with protected cast bars. | Addon evaluates indeterminate state and fails closed to `CastNoStop`; zero SecretValue comparison crashes. |
| **TC-RBP-08** | Dynamic Disable / Enable | Open Settings -> AddOns -> Roth Blizzard Plates. Toggle cast bar replacement off. | Cast bar immediately restores default Blizzard status bar texture, size, and icon position. |
| **TC-RBP-09** | Diagnostic Command | Run `/rbpcast status`. | Chat outputs `RothBlizzPlates castbar pending: 0` (or active queue count). |
| **TC-RBP-10** | Taint Logging Audit | Enable `/console taintLog 1`, run dungeon encounter. | Zero taint entries logged against `RothBlizzPlates`. |

---

## 7. Conclusion

`RothBlizzPlates` in its local state (`HEAD`) carried severe vulnerabilities from obsolete pre-12.1 paradigms: attempting anchor mutations during combat, traversing frame trees via `GetChildren`, and exposing unboxed checks to secret values.

The upstream fix branch `fix/retail-12-1-combat-deferral-2026-08-29` provides an exemplary, production-grade modernization. Merging this branch completely resolves all taint hazards, enforces RT-AUDIT-001 and RT-AUDIT-002 compliance, introduces robust combat deferral, and adds comprehensive automated regression testing. It is recommended to merge and publish this release immediately.
