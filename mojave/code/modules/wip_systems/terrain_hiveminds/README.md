# WIP terrain hiveminds

Use the admin debug verb **MS13 - Spawn Terrain Hivemind** to choose a theme, a territory cap
(including unbounded), and either your current tile or a View Variables marked target.

Each network has one destructible core and a shared resource pool. Claimed floor growth produces
resources; expansion, walls, traps, turrets, and unit generators spend them. Units regenerate on
their own terrain. Blob and necromorph units also decay away from it, while every unit decays after
its core is destroyed. Generators begin with scouts and footsoldiers, then unlock ranged units at 24
claimed tiles and wall-smashing heavies at 55. Destroyed cores stop expansion and make their terrain
and structures wither.

The five shared unit roles carry behavior rather than a theme: scouts move quickly, dodge, see
farther, and take long patrols; footsoldiers fight and haul bodies; ranged units fire three-shot
volleys while keeping their distance; heavies are slow, durable linebreakers which smash walls; and
infectors are costly corpse specialists. Themes provide a distinct name, sprite, and projectile for
each role. Idle units deliberately pick distant destinations beyond hive terrain, destroy obstructing
doors or structures on the way, and periodically retarget, so a mature hive disperses instead of
remaining piled around its generator.

Corpses are shared work targets rather than private AI targets. Any unit which sees a body reports it
to the network; one worker claims it, so the other units do not all chase the same corpse. Owned
terrain slowly converts unattended bodies, dedicated converter structures process bodies dragged
within one tile very quickly, and generators may spend extra resources on one dedicated converter
unit once the network is mature and has a reported body. Corpse reports, claims, and progress use
weak references, and terrain checks a rotating fixed-size slice instead of scanning the whole map.

The themes deliberately use that shared machinery differently:

- necromorph slashers drag bodies back to a nest or converter; brutes and the costly infector can
  convert bodies in the field, while lurkers provide ranged support;
- flockbits report bodies for a costly reclaimer, while flock terrain and structures do the actual
  conversion;
- blob units and terrain digest bodies in place, with harvesters and resource blobs accelerating it;
- Eris units recover bodies to machine recyclers, while a costly mobile recycler handles remote
  finds.

Flock and necromorph terrain use their native connected bitmask icon states. Connections are scoped
to one network, so two rival hives touching each other do not visually join. Blob retains its native
full-tile appearance; Eris wireweed uses the source sheet's complete wire-bed state rather than one
of the quarter-tile component states, so adjacent machine-hive growth no longer leaves checkerboard
gaps.

The frontier list means normal expansion does not scan the map. `territory_limit = 0` is genuinely
unbounded, so admins should use it deliberately. This prototype only spreads across reachable open,
destructible turfs; it does not yet consume closed walls, cross z-levels, assimilate machines,
choose strategic targets, or persist between rounds.

## Imported assets

- CEV-Eris machine-hive icons are from `discordia-space/CEV-Eris` commit
  `5f7847f26585d80505500be5a62e621022a56bf7`, under that project's AGPLv3 terms.
- Necromorph corruption and swarmer icons are from `DS-13-Dev-Team/DS13-2.0` `master`, whose README
  identifies its assets as CC BY-SA 3.0 unless otherwise indicated. The slasher, lurker, infector,
  and combined 64px brute sheets are imported from the same source.
- Blob and flock appearances reuse assets already present in DaedalusDock.

New themes normally only subtype `/datum/ms13_terrain_hivemind` and replace its appearance, economy,
`core_type`, `terrain_type`, role-keyed `unit_appearances`, tiered `mob_types` lists, projectile, and
`special_types`. The shared role paths provide the AI behavior, so themes do not need parallel mob
trees just to reskin scouts, soldiers, ranged units, heavies, and infectors.

The shared code is intentionally independent of the original Eris and DS13 subsystems: their object
trees are incompatible with this repository, while their resource/node ideas fit this small common
controller.
