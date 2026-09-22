# Ground vehicle controls and power

Click the driver's seat or its full-size dashboard monitor from inside in non-combat mode.
Buckling into the driver's seat also opens the controls automatically (without duplicating an
already open menu for that user). Nearby passengers can also reach the controls while the driver
is seated, but cannot take an occupied seat. The monitor stays on the cabin tile and follows rotation.
The input menu repeats after toggles;
Drive switches on ignition, attempts a battery-powered start, and buckles you in. Engine toggle
starts/stops without buckling (ignition must already be on). Exit closes the menu; Unbuckle leaves
the seat without applying the brakes. The horn has a one-second cooldown.

Forward/reverse input selects successive speed bands; opposite input brakes, even without power. The
brakes shed one band per `brake_delay` (0.6 s), with `brake_sound`, so a vehicle at speed has to brake
down before it stops or reverses. Stop brakes to a halt the same way; from a crawl it stops at once.
Stopping the engine (including fuel loss) sheds one speed band per movement tick until stopped.
Releasing the controls or leaving the seat preserves powered momentum. Brakes mode brakes to a stop,
then uses input-only steps, at most one tile per second: release the key to stop. Gear delays are divided by the controller's `speed_multiplier` (1.25 by default, so 25%
faster than the gearbox's raw delays) - set that per vehicle to make one faster or slower.
Turning can reduce speed; an obstacle that survives a ram stops it. Impacts use speed squared and
the actual leading panel's blunt armor, falling back to the frame on exposed edges. Objects and
turfs use their normal integrity/armor/destruction behavior; indestructible terrain stays intact.
This is deliberately arcade physics, not a mass simulation.

Prone/unbuckled mobs are run over instead of repeatedly shoved. Each tile-step over them deals
damage without explicit gibbing. They remain under the floor and cannot stand until uncovered;
dead basic/simple-animal NPCs skip damage processing entirely.
Destroying a frame tile leaves ten scrap-steel sheets; administrative deletion does not create salvage.

Each engine installation includes a non-dense battery housing at the pivot. It contains a standard
high-capacity cell: screwdriver to remove, insert another cell to replace. Ignition enables the
electrical bus; turning it off also stops the engine. Starting costs 100 cell charge. Running engines
burn 0.01 fuel/second at idle plus the existing fuel-per-tile consumption, and charge 20 units/second.
Instruments use 1 unit/second, each enabled cabin light/camera 1, each exterior lamp 2. Autocannons
use 25 units/shot; tank guns 50. Hand-operated machine guns do not need battery power.

M113 and armored truck constructors fit front lamps, a rear work lamp, and side/rear cameras.
The jeep has a headlamp; Civ96 vehicles have paired front/rear lamps. Accessories are independently
damageable exterior images, hidden from the cabin like existing wheels. Exterior lamps have no
local toggle; each casts a directional beam the way it faces.

Cabin masks hang from the frame each occupant stands on, so they glide with the hull; they are only
redrawn when the occupant changes tile, the vehicle turns, or a panel opens, closes or breaks.

Each camera sees a cone ahead of it, `field_of_view` tiles to either side per tile ahead (1 is a
right angle). From the cabin, the driver alone sees whatever a working camera's cone takes in; it
is not a physical window and does not expose occupants to NPC vision. A camera's kind only applies
inside its own cone: a `night_vision` camera lights its cone green, and a `thermal` camera shows
the mobs in its cone glowing and through walls, while mobs elsewhere stay hidden unless plainly in
sight. "Camera view" at the driver's controls steps the buckled driver's view through each working
camera and back to the cabin, widened by `view_bonus` and pushed out by `view_reach`: `wide` takes in
more, `zoom` reaches far ahead in a narrow cone. Losing power, the camera switch, the camera or the
seat returns the driver to the cabin.

Add-on armor (`/obj/item/ms13_vehicle_armor`, steel appliqué, and `/ceramic`) bolts over an outer hull
panel: use it on the panel, and a crowbar prises it off. A round has to get through the plate and
then the panel. Every hit lands on the plate first, with the plate's own armor; only what it cannot
hold passes to the panel, and a wrecked plate falls away.

Variants set cameras and add-on armor on the same hulls. The M113 (`front_left`) has plain cameras;
`/night` night vision, `/a3` ceramic armor with zoom and thermal cameras, `/uparmored` steel plate.
Civ96 variants take `cameras` as `"tile:edge" = camera type` and `addon_armor`: `btr80/btr82`,
`mtlb/scout`, `bmd2/night`, `t34/uparmored`, `t34/modernised`, `is3/modernised`.

Rail cars cannot be driven by hand. The route terminal at the front of the car shows a line map of the
connected rails; pick a stop on the map or the list and the car runs there, either end first, turning
only at corners. Stops are `/obj/structure/ms13_rail/station` rails, named after the area they sit in,
so give each station its own named area. "Route terminal" at the driver's controls opens the same
screen. A terminal spawned or mapped onto a rail car fits itself to that car. Cars board through a
door in each side at mid-length, with that row kept clear of seats. Lines run up and down levels over
`/obj/structure/ms13_rail/ramp` inclines and over region edges; see `wip_systems/RAIL_VEHICLES.md`.

On a route a car keeps a smooth speed rather than a gear: it reaches its top gear's speed over
`time_to_top_speed`, and plans its braking to slow for corners and stop at the end on brakes that take
`time_to_stop` from top speed. The brakes bite up to `braking_variance` harder or softer than planned
each tile, so it may creep the last tiles in or stop with a jolt. The emergency stop brakes harder,
still along the line.

Soviet armed vehicles come with stocked racks: 30mm boxes, 7.62 boxes, or mixed shell crates for the
tanks. Load a gun by using ammunition on the gunner's seat; any round of the gun's caliber loads, and
the last kind loaded goes in the breech. Alt-click the turret controls to switch kinds. Tank shells
come as AP, HE (bursts on contact), HEAT (slow; on contact its shaped charge fires the same jet as
crafted charges and anti-armor bombs), sabot (a fast dart for the heaviest armor) and canister (a spread
of heavy balls), for both the 76mm and 122mm guns.

Regression checks: `ms13_vehicle_electrical`, `ms13_vehicle_obstacle_impact`, the existing ground
vehicle tests and Civ96 assembly tests under `code/modules/unit_tests/`.
