# Rail vehicles (WIP)

Place `/obj/structure/ms13_vehicle_frame/tram` for a tram, or its `/train` subtype for
a wider train (`car_length` x `car_width`). The placed frame is the front-left pivot; rotate it in
the editor before placement and leave room behind it and to its right.

Place `/obj/structure/ms13_rail` on each tile of the guide route. Cardinal neighbors
connect automatically, including corners, loops and junctions. These use visible
cable sprites as placeholders but are separate, destructible objects, not power wires.
Place the `/station` subtype at stops, inside an area named for the station: stops are
listed by their area's name. Part of the car must start on a rail. Use the route terminal
(or "Route terminal" at the dashboard) and pick a stop; **Emergency stop** brakes to a halt.
The front row is the driver's cabin, behind a bulkhead and cabin door.

The controller finds a shortest connected rail route, speeds up smoothly, and brakes
ahead of corners and the destination (`time_to_top_speed`, `time_to_stop`,
`braking_variance`). Motors, fuel, wheels, battery, hull damage, collisions and passengers
are the ordinary vehicle systems. Destroyed rails or blocked turns halt the trip; pick a
stop again after clearing the obstruction. Rail cars cannot be driven by hand.

These are rigid cars, not articulated multi-car trains: the front-left pivot follows
the guide rail and the rest of the hull uses the normal vehicle rotation. Leave a
clear turning apron around each bend (at least the full car length in each direction).
Do not lay tracks through tight doorways or expect the rear wheels to follow a curved
rail individually. Searches are capped at 4096 expanded tiles. Automatic junction
reservations/signalling are not implemented. Other trains are physical obstacles.

## Up and down a level

Place `/obj/structure/ms13_rail/ramp` (a rail incline) on each level on the same tile, facing
opposite ways: the lower one faces the way the line climbs, the upper one the way it drops.
Run the lower line up to its incline, and start the upper line on the tile past the upper
incline. A car running onto either incline the way it faces comes out whole on the other level,
its tail on the first tile past the far incline, so leave a car's length of clear line there.
The approach must be as wide as the car. If anything blocks the far end, the car stops short.

## Across a region's edge

Run the line onto the crossing line (the eighth tile from the map edge) on both maps, lined
up, as for any other vehicle crossing (see `SURFACE_REGIONS.md`). The car comes out whole
beyond the far map's transition strip and runs on. Stops in other regions and on other levels
show on the route board: the region beyond is drawn past its edge, and other levels dashed.

Vehicle impacts estimate mass using `mass_per_frame * frame count`. Speed increases
the ability to displace another vehicle; brakes double shove resistance. A successful
shove moves the entire struck formation one clear tile and costs the striking vehicle
one speed band. Blocked shoves become normal damage collisions; push chains are disabled.
Collision checks stay inside the swept frame footprint, so an exact-width corridor is passable.
Remaining side panels take frontal impacts when the front panel is missing; adjacent walls do not
artificially widen the vehicle. In-path windows and low walls are processed as structure impacts.

Attached parts block vehicle collisions even when players can walk over them. Breaching or destroying
a hull panel breaks off the cameras/lights mounted on that edge. Destroying a frame destroys its
supported hardware and hull panels, removes its seats, and releases passengers onto the ground;
loose cargo stays there. Broken-off hardware leaves MS steel scrap rather than working orphan parts.

Obstacle impacts use `E = 50 * (mass / 1000) * speed_band^2`: twice the mass gives
twice the impact budget, twice the speed gives four times the budget. Contact armor
sets transfer efficiency to `0.35 + 0.0065 * blunt_armor` (armor clamped to 0–100).
The obstacle receives `E * efficiency` before its normal damage protection. Only
the energy needed to damage/break it is spent; a chair does not absorb a wall's
worth. Poor contact armor increases recoil, which also goes through normal armor.
Budget loss includes obstacle work plus 1.5 times actual self-damage. Remaining
energy determines the new speed band, with fractional losses retained across
successive impacts. Changing the driving speed band resets the estimate to that
band; this is an arcade model, not kilograms/metres-per-second rigid-body physics.

Regression check: `/datum/unit_test/ms13_rail_vehicles` covers shoves, blocked/heavy
targets, exact-width corridors in all four orientations, stacked windows/low walls,
mounting failures, connected routes, a full four-turn loop, cargo, fuel and stopping,
and a car running up and down an incline and both ways over a region's edge.
