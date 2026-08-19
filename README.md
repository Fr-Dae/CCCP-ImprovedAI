# ImproveAI

**Advanced AI behaviour and command system for Cortex Command Community Project (CCCP).**

ImproveAI adds specialised AI behaviours while reusing native CCCP AI modes, navigation and engine facilities wherever possible.

## Current architecture

```text
ImproveAI.rte/
├── AI/
│   ├── AI.ini
│   ├── Sentry.lua
│   ├── SentryTargeting.lua
│   ├── SentryPassive.lua
│   ├── SentryActive.lua
│   ├── Miner.lua
│   ├── MinerOptimized.lua
│   └── Anchor.lua
├── Base/
│   └── Devices/Tools/Constructor/
├── GUIs/
├── Icons/
├── Documentation/
├── Index.ini
└── ...
```

`CONTRIBUTOR.md` at the repository root contains the development and review guide, including CCCP source references and Lua/C++ optimisation rules.

## Miner

### Classic

`Miner.lua` is intentionally a thin wrapper around the native CCCP mining behaviour. It does not implement a second mining algorithm.

### Optimized

`MinerOptimized.lua` is a structured mining behaviour intended for a Constructor-equipped unit.

The current design uses:

- a 12 px medium Constructor block as the reference unit;
- six reference blocks of tunnel height;
- a finite bottom-of-map safety margin;
- an explicit Anchor for origin and direction when one has been placed;
- periodic equipment checks rather than per-frame inventory scans;
- Constructor resource checks before construction;
- native navigation for movement whenever possible.

The long-term design is a connected gallery system where a floor can also serve as the ceiling of the gallery below it, with controlled vertical access.

Constructor resources are finite. The optimized miner must collect terrain material when additional construction material is required; it must not assume that resources refill automatically.

## Anchor

`Anchor.lua` stores a mining origin and a left/right direction for an actor. The Anchor is deliberately separate from `MinerOptimized.lua` so the mining geometry can be explicitly defined by the player rather than inferred from an ambiguous nearby wall.

The intended radial command is an ordinary Pie Menu callback. The coroutine behaviour itself must not be registered as a PieSlice callback.

## Constructor integration

ImproveAI carries a Constructor path under:

`ImproveAI.rte/Base/Devices/Tools/Constructor/`

This mirrors the native CCCP Constructor path so that the mod can provide a compatible modified implementation without creating a separate unrelated tool.

The optimized AI construction path uses the 12 px medium block. The 24 px large block must not be introduced into optimized mining.

The native Constructor reference is:

`Data/Base.rte/Devices/Tools/Constructor/`

Important files are `Constructor.lua`, `Constructor.ini`, `ConstructorPie.lua` and `ConstructorCollect.lua`.

## Sentry

ImproveAI separates Sentry dispatch, passive/active behaviour and target acquisition:

```text
Sentry
├── Hold
├── Passive Defence
└── Active Defence
```

Active targeting is kept separate so weapon range, LOS, team filtering and target scoring can evolve without duplicating the Sentry behaviour itself.

## Pie Menu

ImproveAI uses the CCCP Pie Menu system. Specialised coroutine behaviours such as Miner and Sentry are dispatched by the AI system; PieSlice callbacks are used only for immediate commands such as setting an Anchor or changing a stored profile.

## Technical philosophy

ImproveAI deliberately avoids adding new C++ AIModes unless an engine limitation makes it necessary.

Native modes remain the basis for specialised behaviours, for example:

```text
AIMODE_SENTRY
AIMODE_GOLDDIG
AIMODE_PATROL
AIMODE_GOTO
```

Lua code is written with CCCP's Lua/C++ execution cost in mind:

- cache stable references and constants;
- avoid allocations in hot loops;
- avoid repeated expensive `SceneMan` and `MovableMan` queries;
- use timers for periodic scans;
- yield from long-running behaviours;
- validate MOs again after yields;
- delegate navigation and native equipment behaviour when possible;
- keep debug drawing disabled by default.

The project follows the CCCP optimisation guidance:

- https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki/Lua-Optimisation-Notes
- https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki/Lua-Optimization-and-Organization-Tips-and-Tricks

## Squads

ImproveAI behaviours must coexist with native Squad orders. A specialised ImproveAI profile should not be inferred solely from the current `Actor.AIMode`, because a Squad may temporarily change an actor's native mode.

Future logistics work may allow several optimized miners to share section ownership, resource status and repair responsibilities.

## Development

Target version: **CCCP 7.0.0**.

Never commit directly to `Main`.

```text
Issue
  -> issue-specific branch
  -> commits on branch
  -> Pull Request
  -> PR closes issue
  -> manual release
```

See [`CONTRIBUTOR.md`](CONTRIBUTOR.md) before modifying engine-facing Lua code.

## Status

**Work in Progress.**

Some systems are implemented incrementally and are not yet production-complete. In particular, the optimized mining network, logistics patrol, multi-miner coordination, automatic repair and complete Anchor Pie Menu integration remain areas of active development.

## Licence

Original ImproveAI material is distributed under **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**. See `LICENSE` for details.

## Links

- Cortex Command Community Project: https://github.com/cortex-command-community/Cortex-Command-Community-Project
- CCCP Wiki: https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki
- CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/
