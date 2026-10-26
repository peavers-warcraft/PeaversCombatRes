# PeaversCombatRes

A World of Warcraft addon that tracks the group's shared battle res charges during raid encounters and Mythic+ keys, in the Peavers bar style.

Part of the **Peavers Ultra Performance** family: addons that hold themselves to a published budget, measured on every push.

## Measured performance

The bar costs nothing until a pool exists. There is no `OnUpdate` handler
anywhere in `src/`: the pool is read on events, and a one second ticker runs
only while the bar is on screen. Every draw is diffed against the last, so a
tick where nothing moved touches no widget at all. The table below is
regenerated on every push by the
[Ultra Performance harness](https://github.com/peavers-code/peavers-warcraft-workflows/tree/master/perf-harness),
driving the real `Core` ticker. If any number goes outside `perf/budget.json`,
the build fails.

<!-- perf:begin -->

> Measured on every push by the Ultra Performance harness. The build fails if any number here exceeds the budget in `perf/budget.json`.

| Check | Measured | Budget | |
|---|---:|---:|:--:|
| Packaged size | 43.8 KB | 60 KB | pass |
| Bundled libraries | 0 | 0 | pass |
| Widget calls per frame | 0 | 0 | pass |
| Widget calls per second while idle | 0 | 0 | pass |
| Widget calls per second | 1.17 | 5 | pass |

Scenarios driven against the real addon source, outside the game:

| Scenario | Calls/frame | Calls/sec | Notes |
|---|---:|---:|---|
| key, next charge recharging, 1s ticker | 0.00 | 1.2 | 300 ticks driven; bar fill and timer text |
| key, pool at its cap | 0.00 | 0.0 | every draw is diffed; nothing moved |
| no pool (open world, between pulls) | 0.00 | - | hidden, no ticker exists |
| 100 SPELL_UPDATE_CHARGES, pool unchanged | 0.00 | - | 0.00 widget calls per event |

<sub>1,333 lines of Lua · 43.8 KB packaged · no bundled libraries</sub>

<!-- perf:end -->

## Features

<!-- peavers:features -->
- Shared battle res charges in raid encounters and Mythic+ keys, with time to the next charge
- Bar fills as the next charge recharges, coloured by charges left: green, amber on the last, red at none
- Optional icon with a cooldown swipe: any battle res spell, or dynamic (your party's res spell)
- Optional line of who in the group can battle res, greyed when dead or offline
- Show or hide per content type: Mythic+, raids, delves, dungeons, scenarios, PvP, open world
- Placed and configured in Blizzard's Edit Mode
<!-- /peavers:features -->

## What it cannot show

Since Midnight, addons cannot see other players' casts in an instance, and
cannot message each other during a key or a boss fight. So nothing can know
whose battle res has been used. The pool itself is exempt from the combat
restrictions, which is what this addon reads. The roster line says who *could*
res, not who still has theirs.

## Usage

<!-- peavers:usage -->
- `/pcr` - Preview the bar outside a fight
- `/pcr probe` - Print what this client reports about battle res (useful for bug reports)
- `/pcr config` - Open the information page
- Open Edit Mode to move and style the bar
<!-- /peavers:usage -->

## Configuration

<!-- peavers:configuration -->
Everything is in Blizzard's Edit Mode. Select the bar to change:

- Frame size, background and title bar
- Bar height, texture and the three charge colours
- Icon on or off, which spell it shows, and the countdown numbers on it
- Charges, recharge timer and the who-can-res line
- Which content it shows in, and combat or group-only visibility
<!-- /peavers:configuration -->


## Installation

### Recommended: PeaversUpdater

Download and install [PeaversUpdater](https://github.com/peavers-warcraft/PeaversUpdater/releases/latest), the desktop updater for the whole Peavers collection. It installs PeaversCombatRes together with its required dependencies and delivers updates before they reach CurseForge.

### Alternative: CurseForge

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/peaverscombatres)
2. Ensure [PeaversCommons](https://www.curseforge.com/wow/addons/peaverscommons) is also installed
3. Ensure [PeaversConfig](https://www.curseforge.com/wow/addons/peaversconfig) is also installed
4. Enable the addon on the character selection screen

---

*Part of the [Peavers](https://peavers.io) addon collection · [Report an issue](https://github.com/peavers-warcraft/PeaversCombatRes/issues) · [Support development on Patreon](https://www.patreon.com/Peavers)*
