# ImproveAI contributor guide

## Project

ImproveAI is a Lua-first mod for **Cortex Command Community Project (CCCP)**. The project adds higher-level AI behaviours while deliberately reusing native CCCP AI modes and engine systems whenever possible.

The project currently targets CCCP `7.0.0`.

## Languages

### Lua

Lua is executed by the CCCP engine and interacts directly with C++ engine bindings. Keep per-frame work small and avoid unnecessary allocations or repeated engine calls.

Preferred practices:

- cache module tables and frequently used constants locally;
- use local functions for hot paths;
- use `Timer` rather than frame counters for periodic work;
- avoid rebuilding tables every update when state can be reused;
- avoid repeated `SceneMan` raycasts in the same frame;
- reuse native behaviours instead of duplicating their pathfinding or equipment logic;
- yield from long-running AI behaviours;
- validate `MovableMan` objects before using them after a yield;
- keep debug drawing disabled by default;
- do not create new AIModes unless a C++ engine change is genuinely required.

See the CCCP Lua optimisation documentation:

- https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki/Lua-Optimisation-Notes
- https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki/Lua-Optimization-and-Organization-Tips-and-Tricks

## C++ / engine knowledge

A contributor reviewing engine-facing changes should be familiar with:

- `Actor`, `AHuman`, `ACrab` and `MovableMan`;
- `Controller` states;
- native `AIMode` values such as `AIMODE_SENTRY`, `AIMODE_GOLDDIG`, `AIMODE_PATROL` and `AIMODE_GOTO`;
- `SceneMan` terrain queries and raycasts;
- `Vector` and scene wrapping;
- MO / RootMO relationships;
- `PieMenu`, `PieSlice` and script callbacks;
- inventories, equipment and native tool-search behaviour;
- the distinction between terrain pixels, `TerrainObject`s and movable objects;
- Lua-to-C++ bindings exposed by CCCP.

## Native-source references

The main reference repository is:

https://github.com/cortex-command-community/Cortex-Command-Community-Project

Constructor reference:

`Data/Base.rte/Devices/Tools/Constructor/`

Important files include:

- `Constructor.ini`
- `Constructor.lua`
- `ConstructorPie.lua`
- `ConstructorCollect.lua`

The native Constructor uses `Constructor.lua` for digging, material collection, build queues and terrain-object creation. Its AI construction path is coupled to `Actor.AIMODE_GOLDDIG` and controller fire state.

The native Constructor creates artificial structures as `TerrainObject`s using presets named `Constructor Tile 1` through `Constructor Tile 16` and `Constructor Border Tile 1` through `Constructor Border Tile 4`.

## ImproveAI architecture

Keep these responsibilities separate:

```text
Native AIMode
    |
    +-- ImproveAI behaviour profile
            |
            +-- targeting
            +-- movement
            +-- equipment
            +-- specialised task logic
```

Do not make a specialised behaviour depend on a fragile assumption about the current native AIMode when the profile itself can be stored separately.

### Miner

`Miner.lua` intentionally delegates to the native mining implementation.

### MinerOptimized

`MinerOptimized.lua` is the structured mining behaviour. It is responsible for planning and coordination; the Constructor remains responsible for actually creating and collecting construction material.

### Sentry

`Sentry.lua` dispatches to passive/active profiles. Target acquisition is separated into `SentryTargeting.lua`.

## Pull requests

Never commit directly to `Main`.

Workflow:

```text
Issue
  -> branch named after the issue
  -> commits on that branch
  -> Pull Request
  -> PR closes the issue
  -> manual release by maintainer
```

PRs should contain:

1. a concise summary;
2. important implementation details;
3. compatibility/risk notes;
4. testing status;
5. the issue reference, using `Closes #N` when appropriate.

## Testing

Before proposing a behavioural change, test in the actual CCCP version targeted by the mod. In particular, test:

- actors without the expected equipment;
- equipment in inventory versus currently equipped;
- equipment dropped on terrain;
- actors joining/leaving squads;
- scene wrapping;
- terrain at the bottom of the map;
- multiple AI units executing the same behaviour;
- interruption by explosions, death or destruction of equipment;
- low and empty Constructor resources;
- existing Constructor terrain objects;
- player-controlled Constructor behaviour after any Constructor change.

Do not claim a behaviour is engine-supported merely because a Lua field appears plausible. Verify it against the CCCP source or an in-game test.
