# ImproveAI

**Advanced AI behaviour and command system for Cortex Command Community Project (CCCP).**

ImproveAI adds specialised AI behaviours while reusing native CCCP AI modes, navigation, equipment and engine facilities wherever possible.

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
├── Base/Devices/Tools/Constructor/
├── GUIs/PieMenus.ini
├── Icons/
├── Documentation/
├── Index.ini
└── changelog.txt
```

`CONTRIBUTOR.md` is the generic development and review guide, including CCCP source references, Constructor details and Lua/C++ optimisation rules.

## Miner

### Classic

`Miner.lua` is intentionally a thin wrapper around the native CCCP `HumanBehaviors.GoldDig` behaviour. It does not implement a second mining algorithm.

### Optimized

`MinerOptimized.lua` is the structured mining behaviour intended for a Constructor-equipped unit.

The current design uses:

- a 12 px medium Constructor block as the reference unit;
- six reference blocks of tunnel height (72 px);
- a finite bottom-of-map safety margin;
- an explicit Anchor for origin and left/right direction;
- periodic Constructor equipment/resource checks;
- native equipment lookup and native navigation whenever possible;
- one section target at a time to avoid rebuilding path orders every frame.

The planned network uses a shared gallery floor/ceiling between adjacent levels and controlled vertical access. Automatic repair, logistics patrol and multi-miner resource/section sharing remain future extensions.

Constructor resources are finite. The optimized miner does not assume resources refill automatically; material collection must come from terrain through the Constructor's native digging behaviour.

## Anchor

`Anchor.lua` stores one mining origin and one horizontal direction per actor. Choosing **Anchor Left** or **Anchor Right** replaces the actor's previous anchor, so one actor cannot have two active mining anchors.

The two-button direction system is a temporary replacement for a verified rotate-anchor keyboard action. If CCCP later provides a reliable user-configurable binding for rotation, the intended design is to replace the two direction commands with one Anchor command plus rotation.

The Anchor is deliberately separate from `MinerOptimized.lua`: the player can define the origin explicitly instead of making the miner infer a nearby wall/floor junction.

## Sentry

ImproveAI separates Sentry dispatch, passive/active behaviour and target acquisition:

```text
Sentry
├── Sentry.lua
├── SentryPassive.lua
├── SentryActive.lua
└── SentryTargeting.lua
```

`SentryTargeting.lua` handles target validation, team filtering, LOS and weapon-dependent search/target selection independently from the two Sentry profiles.

The Pie Menu exposes the Sentry profiles as a dedicated submenu:

```text
Sentry
├── Sentry Passive
└── Sentry Active
```

Selecting either profile sets the actor's Sentry mode and enters the native `AIMODE_SENTRY` path. `Sentry.lua` dispatches the resulting native Sentry coroutine to the selected ImproveAI profile.

- **Passive:** remains at the sentry position and engages visible targets without pursuing them.
- **Active:** may move toward a valid target within its engagement limit and returns to the sentry position when the engagement ends.

## Constructor integration

ImproveAI carries a Constructor implementation under:

`ImproveAI.rte/Base/Devices/Tools/Constructor/`

The path mirrors the native CCCP Constructor path so the mod can provide a compatible modified implementation.

The native reference is:

`Data/Base.rte/Devices/Tools/Constructor/`

Important files are `Constructor.lua`, `Constructor.ini`, `ConstructorPie.lua` and `ConstructorCollect.lua`.

For optimized mining, the 12 px medium block is the reference unit. The optimized system must not intentionally select the 24 px large block.

## Pie Menu

ImproveAI uses CCCP's Pie Menu system. Immediate commands such as Anchor placement are PieSlice callbacks; long-running coroutine behaviours such as Miner and Sentry must not be registered directly as PieSlice callbacks.

The command groups are:

```text
Mining
├── Mining
├── Mining Optimized
└── Anchor
    ├── Anchor Left
    └── Anchor Right

Sentry
├── Sentry Passive
└── Sentry Active
```

The left/right Anchor commands are mutually exclusive and replace the previous anchor for the actor.

## Technical philosophy

ImproveAI deliberately avoids adding new C++ AIModes unless an engine limitation makes it necessary.

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

## Squads and future logistics

Specialised behaviours must coexist with native Squad orders. A future logistics layer may allow several optimized miners to share section ownership, resource status and repair responsibilities. This is not yet treated as a completed feature.

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

The Sentry profiles, target acquisition, classic Miner wrapper, optimized mining planner and explicit Anchor system are implemented incrementally. Automatic repair patrol, multi-miner coordination, complete Constructor build sequencing and a verified keyboard rotate-anchor binding remain active development areas.

## Licence

Original ImproveAI material is distributed under **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**. See `Licence.txt` for details.

## Links

- Cortex Command Community Project: https://github.com/cortex-command-community/Cortex-Command-Community-Project
- CCCP Wiki: https://github.com/cortex-command-community/Cortex-Command-Community-Project/wiki
- CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/
