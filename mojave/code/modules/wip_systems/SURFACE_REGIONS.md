# Hand-mapped surface regions (WIP)

Inspired by [tgstation PR #91920](https://github.com/tgstation/tgstation/pull/91920):
fixed horizontal region links and ground-tile mirages, without importing Icebox generation
or making the world wrap around. Underground/roof Up/Down links remain unchanged.

Mammoth's config has `surface_level: 2` (the surface file, not an absolute BYOND z).
Four blank 240x300 single-z desert maps are provided and enabled alongside Mammoth.dmm
in `_maps/Mammoth/`. Open these in BYOND's map editor to build out each region:

```json
"surface_level": 2,
"surface_neighbors": {
  "north": "Mammoth_north.dmm",
  "east": "Mammoth_east.dmm",
  "south": "Mammoth_south.dmm",
  "west": "Mammoth_west.dmm"
}
```

Every primary map and neighbor must have the same dimensions as the central file and
exactly one z, starting at (1,1,1). Current Mammoth is 240x300. Matching dimensions avoid
silently resizing/offsetting an already-loaded map. Invalid files/configurations are rejected.
Neighbors load after the primary stack and inherit its surface traits except Up/Down/Linkage.
They do **not** become a roof or basement of the preceding region.

Each direction connects back to the center on the opposite edge. Missing links do nothing;
there are no diagonal links, corner regions, random connections, or wraparound.

## Border layout

Reserve the outer `TRANSITIONEDGE` (currently 7) tiles as a transition/visual buffer. The
crossing line is the eighth tile from the map edge. The destination is the ninth tile from
the opposite edge, preserving the coordinate along the border. Keep both lines open,
with matching roads/ground and no walls, doors, holes or dense objects in arrival lanes.
Corners clamp the arrival coordinate inside the safe rectangle. Existing cliffs/edge walls
are not removed: make an exit through them in the editor where you want travel.

Players, ordinary moving objects and NPCs can cross; carried inventory, buckled passengers
of movable objects, and grabbed bodies use the existing grouped movement system. Closed or
unsafe arrival tiles refuse passage rather than teleporting through walls. Visibility uses
the existing mirage border effect; this is not cross-z combat/pathfinding/atmos simulation.
The movement link is coordinate-based and survives floor replacement; changing a border
turf may remove its mirage until restart.

Multi-tile ground vehicles cross as a single formation. The complete hull and its manifest
are checked before anything moves; no walls, other vehicles, standing mobs, or unsafe ground
may occupy the arrival footprint. The whole vehicle lands beyond the transition strip, so
long trucks do not bounce back. Speed, heading, drift, driver/gunner seats, cargo, component
integrity, ammunition, battery, lights and engine state are retained. A crossing consumes
one normal movement step of fuel. All four blank neighbors load with Mammoth's config.
Rail lines cross the same way: run the rail onto the crossing line on both maps, lined up.

## Dodgy crossings (WIP)

Map `/obj/structure/ms13_dodgy_crossing` on the crossing line. It is a visible rusty-plating
placeholder; change its art for the road. Only vehicles whose next frame tiles touch it are
affected, and only after a successful crossing. There is no risk on ordinary crossings.

Mapper variables: `damage_chance` (35%), `component_damage` (150), `components_hit` (2),
`sever_chance` (15%, conditional on the damage roll). Damage uses normal component integrity
and armor. A sever tears away one outermost non-pivot frame tile and its seats, walls and
mounted parts through normal destruction; passengers are unbuckled and cargo remains on
the wreck tile. Frame destruction drops the existing steel scrap and stops the vehicle.
This is deliberate structural damage, not a broken cross-z formation. WIP limitation: it
removes a chassis tile, not two independently drivable front/rear vehicle controllers.

Regression: `/datum/unit_test/ms13_surface_regions` exercises fixed bidirectional links,
rectangular offsets, no wrapping, blocked arrivals, actual ground-tile crossings, whole trucks
in all four directions, driver/cargo/state preservation, blocked departures, and a forced
chassis tear with real scrap and no orphaned components.
