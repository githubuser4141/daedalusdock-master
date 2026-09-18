# WIP terrain hiveminds

Use the admin debug verb **MS13 - Spawn Terrain Hivemind** to choose a theme, a territory cap
(including unbounded), and either your current tile or a View Variables marked target.

Each network has one destructible core and a shared resource pool. Claimed floor growth produces
resources; expansion, walls, traps, turrets, and unit generators spend them. Units regenerate on
their own terrain. Blob and necromorph units also decay away from it, while every unit decays after
its core is destroyed. Destroyed cores stop expansion and make their terrain and structures wither.

The frontier list means normal expansion does not scan the map. `territory_limit = 0` is genuinely
unbounded, so admins should use it deliberately. This prototype only spreads across reachable open,
destructible turfs; it does not yet consume closed walls, cross z-levels, assimilate corpses or
machines, choose strategic targets, or persist between rounds.

## Imported assets

- CEV-Eris machine-hive icons are from `discordia-space/CEV-Eris` commit
  `5f7847f26585d80505500be5a62e621022a56bf7`, under that project's AGPLv3 terms.
- Necromorph corruption and swarmer icons are from `DS-13-Dev-Team/DS13-2.0` `master`, whose README
  identifies its assets as CC BY-SA 3.0 unless otherwise indicated.
- Blob and flock appearances reuse assets already present in DaedalusDock.

New themes normally only subtype `/datum/ms13_terrain_hivemind` and replace its appearance, economy,
`core_type`, `terrain_type`, `mob_type`, and `special_types`. Those types subclass the shared bases,
so custom themes can override only the behavior procs they actually need.

The shared code is intentionally independent of the original Eris and DS13 subsystems: their object
trees are incompatible with this repository, while their resource/node ideas fit this small common
controller.
