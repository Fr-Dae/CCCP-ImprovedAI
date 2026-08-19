# ImproveAI contributor guide

## Project

ImproveAI is a Lua-first mod for **Cortex Command Community Project (CCCP)**. It adds specialised AI behaviours while deliberately reusing native CCCP AI, navigation, equipment and engine systems whenever possible.

Target: CCCP `7.0.0`.

## Architecture

```text
ImproveAI.rte/
├── AI/
│   ├── AI.ini
│   ├── Sentry.lua
│   ├── SentryPassive.lua
│   ├── SentryActive.lua
│   ├── SentryTargeting.lua
│   ├── Miner.lua
│   ├── MinerOptimized.lua
│   └── Anchor.lua
├── Base/Devices/Tools/Constructor/
├── GUIs/
├── Icons/
├── Documentation/
├── Index.ini
└── changelog.txt
```

## Lua / C++ execution rules

Lua runs through CCCP's C++ bindings. Treat engine calls as more expensive than ordinary Lua operations.

Preferred practices:

- cache stable module tables and constants locally;
- keep hot-loop allocations to a minimum;
- avoid repeated `SceneMan` and `MovableMan` scans;
- use `Timer` for periodic work rather than artificial frame counters;
- yield from long-running behaviours;
- validate `MovableMan` objects again after a yield;
- reuse native navigation, equipment and AI behaviour where possible;
- keep debug drawing disabled unless explicitly enabled;
- avoid creating a new C++ AIMode when Lua state can solve the problem.

CCCP optimisation references:

- https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki/Lua-Optimisation-Notes
- https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki/Lua-Optimization-and-Organization-Tips-and-Tricks

## Native CCCP sources

Primary source repository:

https://github.com/cortex-command-community/Cortex-Command-Community-Project

Important engine areas for this project:

- `Source/Entities/Actor.*`
- `Source/Entities/AHuman.*`
- `Source/Entities/MovableObject.*`
- `Source/Entities/PieMenu.*`
- `Source/Lua/LuaBindingsEntities.cpp`
- `Source/Managers/SettingsMan.*`

Important data-side AI references:

- `Data/Base.rte/AI/NativeHumanAI.lua`
- `Data/Base.rte/AI/HumanBehaviors.lua`
- `Data/Base.rte/AI/SharedBehaviors.lua`

## Constructor reference

Native Constructor source:

`Data/Base.rte/Devices/Tools/Constructor/`

Important files:

- `Constructor.ini`
- `Constructor.lua`
- `ConstructorPie.lua`
- `ConstructorCollect.lua`

The native Constructor defines `buildCost = 10` per 3x3 px construction piece, a 24 px default build size, a 12 px minimum build size, and a finite `resource` reserve. Its standard 12 px medium block therefore costs 200 resource units; the 24 px block costs 640. Optimized mining uses 12 px as its reference unit and must never intentionally select the 24 px block.

The Constructor also belongs to `Tools - Constructors`, which is the native equipment group used by the improved miner when looking for a Constructor.

Constructor-generated terrain uses presets named `Constructor Tile 1` through `Constructor Tile 16` and `Constructor Border Tile 1` through `Constructor Border Tile 4`.

## ImproveAI behaviours

### Miner

`Miner.lua` delegates directly to the native `HumanBehaviors.GoldDig` behaviour. It is deliberately not a second mining algorithm.

### MinerOptimized

`MinerOptimized.lua` plans structured tunnel sections from an explicit Anchor. The reference geometry is a 12 px medium block and six blocks of vertical tunnel height. It tracks finite map depth and Constructor resources, while delegating equipment selection and movement to native CCCP mechanisms where possible.

### Anchor

`Anchor.lua` stores one mining origin and one horizontal direction per actor. Selecting the left or right anchor replaces the previous anchor; there are never two active anchors for one actor.

The two-direction system is intentionally a temporary workaround. It exists because a reliable user-configurable keyboard binding for a rotate-anchor action has not yet been established. If CCCP exposes a verified binding mechanism for this action, replace the two commands with one anchor plus rotation rather than maintaining duplicate anchors.

### Sentry

`Sentry.lua` dispatches to `SentryPassive.lua` and `SentryActive.lua`. `SentryTargeting.lua` is kept separate so weapon range, LOS, team filtering and target scoring can evolve independently.

## Pie Menu rules

PieSlice callbacks must be short immediate actions. Do not register a coroutine behaviour such as Miner or Sentry directly as a PieSlice callback.

Anchor callbacks only store anchor state; the long-running MinerOptimized coroutine consumes that state.

## Testing checklist

Test in the actual targeted CCCP build:

- Constructor already equipped;
- Constructor in inventory but not equipped;
- missing/destroyed Constructor;
- low and empty Constructor resources;
- 12 px versus 24 px Constructor selection;
- existing Constructor terrain versus natural terrain;
- anchor replacement left/right;
- scene wrapping;
- bottom-of-map safety;
- multiple miners near the same anchor/network;
- squad orders interrupting a specialised behaviour;
- explosions, death and equipment destruction;
- player-controlled Constructor behaviour after Constructor changes.

Never claim an engine feature is supported merely because a Lua property or method name looks plausible. Verify it in the CCCP source or with an in-game test.

## Git workflow

Never commit directly to `Main`.

```text
Issue
  -> issue-named branch
  -> commits on that branch
  -> Pull Request
  -> PR closes the issue
  -> maintainer performs the release manually
```

PRs should include a concise summary, implementation details, risks/compatibility notes, testing status, and `Closes #N` when applicable.
