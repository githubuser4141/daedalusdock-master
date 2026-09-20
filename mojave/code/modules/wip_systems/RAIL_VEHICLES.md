# Rail vehicles (WIP)

Place `/obj/structure/ms13_vehicle_frame/tram` for a **2x4 tram**, or its `/train`
subtype for a **2x6 train**. The placed frame is the front-left pivot; rotate it in
the editor before placement and leave room behind it and to its right.

Place `/obj/structure/ms13_rail` on each tile of the guide route. Cardinal neighbors
connect automatically, including corners, loops and junctions. These use visible
cable sprites as placeholders but are separate, destructible objects, not power wires.
Place the `/station` subtype instead of a normal rail at stops and set its `name`.
The pivot must start on a rail. Click the dashboard and select **Rail destination**.
Select another destination for the return trip; **Stop** cancels automatic driving.

The controller finds a shortest connected rail route and brakes before corners and
the destination. `braking_power` is speed bands shed per movement tick. Motors,
fuel, wheels, battery, hull damage, collisions and passengers are the ordinary
vehicle systems. Destroyed rails or blocked turns halt the trip; select a destination
again after clearing the obstruction. Manual driving also requires rails.

These are rigid cars, not articulated multi-car trains: the front-left pivot follows
the guide rail and the rest of the hull uses the normal vehicle rotation. Leave a
clear turning apron around each bend (at least the full car length in each direction).
Do not lay tracks through tight doorways or expect the rear wheels to follow a curved
rail individually. Searches are capped at 4096 expanded tiles. Cross-region rail links
and automatic junction reservations/signalling are not implemented; keep each route
on one z-level, away from region boundaries. Other trains are physical obstacles.

Vehicle impacts estimate mass using `mass_per_frame * frame count`. Speed increases
the ability to displace another vehicle; brakes double shove resistance. A successful
shove moves the entire struck formation one clear tile and costs the striking vehicle
one speed band. Blocked shoves become normal damage collisions; push chains are disabled.
Side plating's leading tips now collide with new solid-turf contact outside the footprint,
and remaining side panels take frontal impacts when the front panel is missing.

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
targets, side-wall damage, connected routes, a full four-turn loop, cargo, fuel and stopping.
