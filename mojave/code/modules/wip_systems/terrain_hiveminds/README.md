# WIP terrain hiveminds

Use the admin debug verb **MS13 - Spawn Terrain Hivemind** to choose a theme, a territory cap
(including unbounded), and either your current tile or a View Variables marked target.

The core now starts with 20 resources and buys a unit every 10 seconds when it has funds and
population space (24 units maximum). Tile income is one quarter of the theme's old rate; special
structures are attempted every 12 seconds. Separate generators still supplement core production.
Finite territory, population and structure caps still intentionally limit spending.

Movement uses the existing throttled JPS pathfinder (60-step search, three-second repath delay).
Units try existing entrances before breaching a blocked route. Idle roaming only breaches for a
cramped nest with fewer than 12 tiles and no frontier. Opened walls refresh an exhausted frontier.
Both DD and Mojave's table-derived low walls support movement and pathfinding for crossing themes,
including hauled bodies. Idle scouts, ranged units and heavies can help hauling hives when no idle
hauler is within seven tiles of the subject. Friendly nest walls are also traversable by pathfinding.

Xenomorphs subdue non-player simple/basic NPCs below 35% health (or within one melee strike of
death), using forced paralysis instead of killing them. Ranged units close in to capture wounded
NPCs and cancel subsequent burst shots. This implements the living-capture option rather than
making already-dead NPCs eligible. Carriers nest at the first friendly resin tile and briefly
restrain/stabilize hosts during transport. Each host gets its own nest, even on a shared tile.
Successful facehugger implantation drops the spent hugger and starts a 90-second incubation;
a resin nest accelerates the same progress to 25 seconds. Completed hosts cannot be reused.
Simple-animal/basic NPC hosts gib on chestburst; human hosts retain the chest-damage behavior.
Incubation currently requires a surviving network; destroyed cores stop its processing.

Recovery now persists until 80% health after a unit crosses its retreat threshold (45% normally,
40% for infectors). Reaching friendly terrain no longer immediately ends recovery. Combat can still
interrupt ordinary units; infectors share the same recovery logic.
Crossing-capable themes also traverse Mojave tables and guard rails, including hauled hosts.
Door forcing pauses movement for a two-second attempt. After eight seconds of failure, the unit
requests an adjacent wall bypass from a nearby heavy and backs off retrying that door for 30 seconds.
A completed bypass clears the request and cancels other units' active pry attempts. Vault and
Mojave mechanical airlocks remain excluded from forcing.

Performance: same-tile target scans are reused for one second, failed idle routes back off for five
seconds rather than continually replacing pathfinding loops, and units already healing on terrain
do not search the whole territory for a recovery destination. These are bounded local reductions,
not a measured whole-server speedup; the basic-mob target-search subsystem is separate from hive AI.

Each network has one destructible core and a shared resource pool. Claimed floor growth produces
resources; expansion, walls, traps, turrets, and unit generators spend them. Units regenerate on
their own terrain. Blob and necromorph units also decay away from it, although heavies are independent
and corpse specialists decay at half speed; wounded idle units will step back onto nearby growth to
recover without abandoning an active fight. Most units decay after their core is destroyed, while
xenomorphs are deliberately independent of both weeds and their core. Generators
begin with scouts and footsoldiers, then unlock ranged units at 24
claimed tiles and wall-smashing heavies at 55. Destroyed cores stop expansion and make their terrain
and structures wither. Damaged hive structures slowly regenerate. Turret projectiles pass through
their own network's core, but other friendly structures remain vulnerable and enemy-hive shots still hit.

The five foundational unit roles carry behavior rather than a theme: scouts move quickly, dodge, see
farther, and take long patrols; footsoldiers fight and haul bodies; ranged units fire three-shot
volleys while keeping their distance; heavies are slow, durable linebreakers which smash walls; and
infectors are costly conversion specialists. Optional hauler, suicide, siege, and regenerator
subtypes let a theme add behavior without growing a parallel AI tree. Themes provide a distinct name,
sprite, and projectile for each role. Idle units deliberately pick distant destinations beyond hive terrain, destroy obstructing
doors or structures on the way, and periodically retarget, so a mature hive disperses instead of
remaining piled around its generator. They recognize ground-vehicle hulls as obstacles: any exterior
panel on a light vehicle is fair game, while tank-grade vehicles draw attacks to their closed hatches.
Generators and corpse conversion relocate new units to nearby growth rather than creating them inside
a vehicle footprint or on a dense hive structure. Hive walls prefer the core's perimeter while always
leaving a usable growth tile for spawning. Blob growths flow over low walls, flock units phase across
them, necromorphs clamber over them, and xenomorphs can vault them while dragging a host.

Conversion subjects are shared work targets rather than private AI targets. A theme independently
chooses whether dead bodies, disabled living hosts, or both are eligible. Any unit which sees an
eligible body reports it to the network; one worker claims it, so the other units do not all chase the
same target. Owned terrain can slowly convert unattended bodies, dedicated converter structures
process subjects dragged within one tile very quickly, and generators may spend extra resources on
one dedicated converter unit once the network is mature and has a reported body. Reports, claims, and progress use
weak references, and terrain checks a rotating fixed-size slice instead of scanning the whole map.
Conversion starts with increasingly violent twitching and ends in theme-specific blood, slime, or
sparks. At the population cap, completed bodies become resources instead of stalling forever.

The themes deliberately use that shared machinery differently:

- necromorph slashers drag bodies back to a nest or converter; brutes and the costly infector can
  convert bodies in the field, while lurkers provide ranged support;
- flockbits report bodies for a costly reclaimer, while flock terrain and structures do the actual
  conversion;
- blob units and terrain digest bodies in place, with harvesters and resource blobs accelerating it;
- Eris units recover bodies to machine recyclers, while a costly mobile recycler handles remote
  finds;
- xenomorph warriors and evolved carriers reserve incapacitated living enemies instead of corpses,
  stop attacking knocked-down prey, and haul them onto resin. A resin nest forms around a delivered
  host, slows bleeding, stabilizes oxygen loss, and keeps the host restrained during incubation. The
  hive's one-use eggs launch facehuggers: sufficiently strong head armor stops one, while weaker gear
  is torn off before attachment. Facehuggers feed this same nest-incubation path rather than installing
  the base SS13 embryo. Birth causes catastrophic chest damage and leaves the body behind. Xenomorphs
  do not lose health away from weeds or after the core dies.

Flock and necromorph terrain use their native eight-neighbor connected bitmask icon states, while
xenomorph weeds use their native cardinal-only states. Connections are scoped
to one network, so two rival hives touching each other do not visually join. Blob retains its native
full-tile appearance; Eris wireweed uses the source sheet's complete wire-bed state rather than one
of the quarter-tile component states, so adjacent machine-hive growth no longer leaves checkerboard
gaps.

The frontier list means normal expansion does not scan the map. `territory_limit = 0` is genuinely
unbounded, so admins should use it deliberately. This prototype only spreads across reachable open,
destructible turfs; terrain growth itself does not yet consume closed walls, cross z-levels, assimilate machines,
choose strategic targets, or persist between rounds.

## Vertical movement and ambush units

`terrain_hiveminds_vertical.dm` adds bounded inter-floor routing for pursuit, hauling and returning
to the core. Units use nearby unlocked ladders (24 tiles), stairs (24 tiles), and floor openings
(7 tiles), preserving their grabbed host during vertical movement. They notice exposed prey below
nearby holes. Evolved climbers also notice prey above open ceilings and climb roof edges; ordinary
units cannot climb arbitrary walls. Evolved ambushers stay dormant until prey enters four tiles or
they are injured, and remain awake for at least 30 seconds after contact.

This is local routing, not full-map 3D pathfinding: each routing attempt checks at most three local
entrances with the existing horizontal pathfinder. Solid ceilings, locked ladders, and blocked
landings still prevent travel. Remote routes that require travelling away from the destination's
floor first are not supported. Roof/floor-hole movement needs linked map z-levels.

## Necromorph Marker (separate content pack)

All Marker-specific code is in `necromorph_marker.dm`. Spawn it through the hive admin menu's
**Necromorph Marker (power/public radio)** entry or place
`/obj/structure/ms13_hivemind/core/marker` in the map editor. It starts a necromorph network.
Existing cult pylon artwork is a placeholder, not a newly imported Marker asset.

- Its 30-tile, same-floor influence gives conscious player humans private, harmless phantom attacks,
  sometimes visually replacing another human. No actual damage or forged player attack logs.
- Every 10 seconds it examines up to 32 corpses using a rotating scan and can convert one suitable
  unclaimed corpse away from biomass. Rebirth requires resources, unit capacity and a clear spawn tile.
- A cable node beneath the Marker receives 250 kW. Destroying the Marker removes its power output
  and public-channel relay. No cell or APC bypass is involved.
- The relay carries public radio globally. Unsuppressed, it occasionally adds unsettling messages
  under a living human's name, with a 45-second cooldown. Server logs identify the Marker as source.
- It is **unsuppressed by default**. Place a
  `/obj/machinery/power/ms13_marker_suppressor` within four tiles, connect its cable node and click
  to enable it. It needs 50 kW of spare grid power. Its existing field-generator sprite lights up
  while containment is live; examine either structure for status.
- Suppression pauses growth, resource accumulation, all new unit births/corpse conversions,
  hallucination pulses and radio impersonation. Real public radio and the 250 kW feed continue.
  Existing mobs, turrets and traps remain dangerous; containment does not erase an established hive.
  Existing short-lived hallucinations finish normally. Power loss, destruction or disabling the
  projector restores the danger on the next processing tick (no permanent suppression latch).
- After **five continuous minutes** of containment, losing the last working suppression field
  releases one EMP (heavy radius 15, light radius 30, using native EMP effects). Every failure
  clears the charge, including short interruptions: cycling containment cannot bank time or spam
  pulses. Another pulse requires another uninterrupted five minutes. Examine shows charging/armed
  status; redundant projectors prevent a failure while any working field remains.

This intentionally reuses native cable accounting rather than duplicating supermatter's gas/reaction
simulation. Output, influence radius, suppression draw/radius and messages are prototype balance.

## Imported assets

- CEV-Eris machine-hive icons are from `discordia-space/CEV-Eris` commit
  `5f7847f26585d80505500be5a62e621022a56bf7`, under that project's AGPLv3 terms.
- Necromorph corruption and swarmer icons are from `DS-13-Dev-Team/DS13-2.0` `master`, whose README
  identifies its assets as CC BY-SA 3.0 unless otherwise indicated. The slasher, lurker, infector,
  combined 64px brute sheet, tripod, exploder, and hunter are imported from the same source. The new
  elite files are pinned and itemized in `DS13_ATTRIBUTION.md`.
- TGMC xenomorph sprites are from `tgstation/TerraGov-Marine-Corps` revision
  `d3131c745b25e69303d6e73b6a00eb2201259d3b` under CC BY-NC 4.0. They are isolated beneath
  `mojave/icons/by_nc/tgmc_xenomorphs/` with per-file provenance in its `ATTRIBUTION.md`; no TGMC
  source code was copied.
- Blob and flock appearances reuse assets already present in DaedalusDock.

New themes normally only subtype `/datum/ms13_terrain_hivemind` and replace its appearance, economy,
`core_type`, `terrain_type`, role-keyed `unit_appearances`, tiered `mob_types` lists, projectile, and
`special_types`. `converts_dead_hosts`, `converts_living_hosts`, terrain conversion time, orphan
damage, and conversion messages select corpse recycling or nest incubation without replacing the
shared work AI. The shared role paths provide the AI behavior, so themes do not need parallel mob
trees just to reskin scouts, soldiers, ranged units, heavies, and infectors.

The shared code is intentionally independent of the original Eris and DS13 subsystems: their object
trees are incompatible with this repository, while their resource/node ideas fit this small common
controller.
