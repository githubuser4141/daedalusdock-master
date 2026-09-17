/**
 * Soviet armor built from Civ13's 96x96 hull art (github.com/Civ13/Civ13 @ 0d38999, AGPLv3/CC BY-SA 3.0):
 * BTR-80, MT-LB, BMD-2, T-34 and IS-3. Place the map-placeable type on the front-left tile; the rest of the
 * hull lays itself out from tile_rows, and furnish() fits out the cabin.
 *
 * Every tile draws a 96x96 piece centered on itself (pixel -32), so neighbours overlap into one hull.
 * Outer walls follow Civ13's scheme: each edge tile carries its hull art on its main edge (front row front,
 * back row back, otherwise the side it's on) and an invisible plate on any other outer edge.
 */

/obj/structure/ms13_vehicle_frame/civ96
	name = "armored vehicle"
	desc = "A tracked or wheeled armored vehicle."
	icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96.dmi'
	icon_state = "none"
	pixel_x = -32
	pixel_y = -32
	// The floor art spills over neighbouring tiles; clicks belong to whatever is actually there.
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	roof_damaged_icon = 'mojave/icons/objects/vehicles_ground/civ_hulls96_damaged.dmi'
	segment_type = /obj/structure/ms13_vehicle_frame/civ96
	hull_color = "#4a5243"
	explosion_block = 2
	/// Art prefix in civ_hulls96.dmi.
	var/art_prefix
	/// Tile names, front row first and left to right. Floor and roof art are "[art_prefix]_frame_steel_[tile]"
	/// and "[art_prefix]_roof_steel_[tile]"; hull art is "[art_prefix]_[tile]_frame".
	var/list/tile_rows
	/// Hull art names that differ from their tile's name, tile = art name.
	var/list/wall_art_names
	/// Tiles with no roof art (the turret covers them).
	var/list/roofless_tiles
	/// Wall type per outer edge, keyed "tile:edge" (edge is front, back, left or right). The rest is plating.
	var/list/wall_overrides
	var/plating_type = /obj/structure/window/ms13_vehicle_wall/solid/civ96
	/// Built tiles by name, for furnish().
	var/list/tiles

/obj/structure/ms13_vehicle_frame/civ96/Initialize(mapload)
	. = ..()
	if(!length(tile_rows))
		return
	vehicle = new vehicle_controller_type
	vehicle.pivot = src
	vehicle.dir = dir
	vehicle.frames += src
	if(!build_hull())
		return
	furnish()
	vehicle.update_interior_lighting()

/// Lays out every tile and its outer hull. FALSE if there isn't room.
/obj/structure/ms13_vehicle_frame/civ96/proc/build_hull()
	var/row_count = length(tile_rows)
	for(var/row in 1 to row_count)
		var/list/row_tiles = tile_rows[row]
		for(var/column in 1 to length(row_tiles))
			if(row == 1 && column == 1)
				continue
			var/turf/destination = vehicle.get_relative_turf(1 - row, column - 1, dir)
			if(!destination || destination.density)
				return FALSE

	tiles = list()
	for(var/row in 1 to row_count)
		var/list/row_tiles = tile_rows[row]
		for(var/column in 1 to length(row_tiles))
			var/tile = row_tiles[column]
			var/floor_state = "[art_prefix]_frame_steel_[tile]"
			var/roof_state = (tile in roofless_tiles) ? "none" : "[art_prefix]_roof_steel_[tile]"
			var/obj/structure/ms13_vehicle_frame/frame = src
			if(row == 1 && column == 1)
				icon_state = floor_state
				roof.icon_state = roof_state
			else
				frame = add_segment(1 - row, column - 1, floor_state, roof_state)
			tiles[tile] = frame

			var/list/edges = list()
			if(row == 1)
				edges += "front"
			if(row == row_count)
				edges += "back"
			if(column == 1)
				edges += "left"
			if(column == length(row_tiles))
				edges += "right"
			if(!length(edges))
				continue
			var/main_edge = edges[1]
			var/hull_art = "[art_prefix]_[wall_art_names?[tile] || tile]_frame"
			for(var/edge in edges)
				var/wall_type = wall_overrides?["[tile]:[edge]"] || plating_type
				var/obj/structure/window/ms13_vehicle_wall/wall = frame.spawn_wall(edge_to_dir(edge), edge == main_edge ? hull_art : "none", wall_type)
				if(ispath(wall_type, /obj/structure/window/ms13_vehicle_wall/solid))
					wall.add_atom_colour(hull_color, FIXED_COLOUR_PRIORITY)
	return TRUE

/obj/structure/ms13_vehicle_frame/civ96/proc/edge_to_dir(edge)
	switch(edge)
		if("front")
			return dir
		if("back")
			return turn(dir, 180)
		if("left")
			return turn(dir, 90)
	return turn(dir, -90)

/// Fits out the cabin once the hull stands. Use tiles["name"] to reach a tile.
/obj/structure/ms13_vehicle_frame/civ96/proc/furnish()
	return

/obj/structure/ms13_vehicle_frame/civ96/proc/add_part(tile, part_type)
	var/obj/structure/ms13_vehicle_frame/frame = tiles[tile]
	return frame.spawn_part(part_type)

/obj/structure/ms13_vehicle_frame/civ96/proc/add_gear(tile, art, broken_art, gear_type = /obj/structure/ms13_vehicle_part/running_gear/civ96)
	var/obj/structure/ms13_vehicle_part/running_gear/civ96/gear = add_part(tile, gear_type)
	gear.set_art("[art_prefix]_[art]", "[art_prefix]_[broken_art || art]", hull_color)
	return gear

/// right/forward: Civ13's turret_x/turret_y, negated.
/obj/structure/ms13_vehicle_frame/civ96/proc/add_turret(tile, art, right, forward, turret_name)
	var/obj/structure/ms13_vehicle_part/turret/turret = add_part(tile, /obj/structure/ms13_vehicle_part/turret)
	turret.name = turret_name
	turret.set_art(art, right, forward, hull_color)
	return turret

/obj/structure/ms13_vehicle_frame/civ96/proc/add_seat_at(tile, relative_dir, seat_name, seat_icon_state = "commanders_seat")
	var/obj/structure/ms13_vehicle_frame/frame = tiles[tile]
	return frame.add_seat(relative_dir, seat_name, seat_icon_state)

/obj/structure/ms13_vehicle_frame/civ96/proc/add_driver_seat(tile)
	var/obj/structure/chair/ms13_vehicle_seat/seat = add_seat_at(tile, 0, "driver's seat", "driver_tank")
	seat.is_driver_seat = TRUE
	add_part(tile, /obj/structure/ms13_vehicle_part/interior_light/instrument)
	return seat

/obj/structure/ms13_vehicle_frame/civ96/proc/add_panel(tile, relative_dir, panel_name, panel_type = /obj/structure/window/ms13_vehicle_wall/solid/door/interior)
	var/obj/structure/ms13_vehicle_frame/frame = tiles[tile]
	return frame.add_bulkhead(relative_dir, panel_name, panel_type)

// Seat facings, relative to the vehicle.
#define SEAT_FORWARD 0
#define SEAT_FACING_LEFT 90
#define SEAT_FACING_RIGHT -90
#define EDGE_FRONT 0
#define EDGE_BACK 180
#define EDGE_LEFT 90
#define EDGE_RIGHT -90

// ---------------------------------------------------------------------------------------------------------
// BTR-80: eight-wheeled APC. Driver and commander up front, gunner under the turret, squad in the middle
// between the side doors, engine and fuel at the back.
//
//   driver        | commander
//   troop seat    | gunner (turret)
//   troop seat    | troop seat          <- side doors both sides
//   engine        | fuel tank           <- access panels
// ---------------------------------------------------------------------------------------------------------

/datum/ms13_ground_vehicle/btr80
	acceleration_delay = 1.2 SECONDS
	coast_delay = 1.8 SECONDS
	turn_delay = 5
	max_turn_speed = 2
	ram_damage_base = 7
	ram_damage_per_speed = 6
	ram_knockdown_per_speed = 6
	running_gear_integrity = 220
	engine_integrity = 380
	fuel_per_tile = 0.15

/obj/structure/ms13_vehicle_part/engine/btr80
	name = "KamAZ-7403 diesel engine"
	desc = "The BTR-80's turbocharged V8 diesel."
	icon_state = "engine_static"
	static_icon_state = "engine_static"
	running_icon_state = "engine_on"
	broken_icon_state = "engine_broken"
	density = TRUE

/obj/structure/ms13_vehicle_part/gearbox/btr80
	name = "BTR-80 gearbox"
	desc = "A five-speed manual gearbox driving all eight wheels."
	density = TRUE
	max_integrity = 220
	gear_delays = list(9, 7, 5, 4)

/obj/structure/ms13_vehicle_part/fuel_tank/btr80
	name = "BTR-80 fuel tank"
	icon_state = "fueltank_incar"
	density = TRUE
	max_integrity = 200
	capacity = 300

/obj/structure/ms13_vehicle_frame/civ96/btr80
	name = "BTR-80 armored personnel carrier"
	desc = "An eight-wheeled armored personnel carrier with a small autocannon turret."
	vehicle_controller_type = /datum/ms13_ground_vehicle/btr80
	art_prefix = "btr80"
	tile_rows = list(
		list("front_left", "front_right"),
		list("middle_front_left", "middle_front_right"),
		list("middle_back_left", "middle_back_right"),
		list("back_left", "back_right"),
	)
	wall_overrides = list(
		"front_left:front" = /obj/structure/window/ms13_vehicle_wall/civ96,
		"front_right:front" = /obj/structure/window/ms13_vehicle_wall/civ96,
		"middle_front_left:left" = /obj/structure/window/ms13_vehicle_wall/civ96,
		"middle_front_right:right" = /obj/structure/window/ms13_vehicle_wall/civ96,
		"middle_back_left:left" = /obj/structure/window/ms13_vehicle_wall/solid/door/civ96,
		"middle_back_right:right" = /obj/structure/window/ms13_vehicle_wall/solid/door/civ96,
	)

/obj/structure/ms13_vehicle_frame/civ96/btr80/furnish()
	add_driver_seat("front_left")
	add_seat_at("front_right", SEAT_FORWARD, "commander's seat")
	add_part("front_right", /obj/structure/ms13_vehicle_part/stowage)
	add_turret("middle_front_right", "btr80", -16, 0, "BTR-80 turret")
	add_seat_at("middle_front_right", SEAT_FORWARD, "gunner's seat")
	add_seat_at("middle_front_left", SEAT_FACING_RIGHT, "troop seat")
	add_seat_at("middle_back_left", SEAT_FACING_RIGHT, "troop seat")
	add_seat_at("middle_back_right", SEAT_FACING_LEFT, "troop seat")
	add_part("middle_back_left", /obj/structure/ms13_vehicle_part/interior_light)

	add_panel("back_left", EDGE_FRONT, "engine access panel")
	add_panel("back_right", EDGE_FRONT, "fuel tank access panel")
	add_part("back_left", /obj/structure/ms13_vehicle_part/engine/btr80)
	add_part("back_left", /obj/structure/ms13_vehicle_part/gearbox/btr80)
	add_part("back_right", /obj/structure/ms13_vehicle_part/fuel_tank/btr80)

	add_gear("front_left", "wheels_front_left", "wheels_front_left_broken", /obj/structure/ms13_vehicle_part/running_gear/civ96/wheels)
	add_gear("front_right", "wheels_front_right", "wheels_front_right_broken", /obj/structure/ms13_vehicle_part/running_gear/civ96/wheels)
	add_gear("back_left", "wheels_back_left", "wheels_back_left_broken", /obj/structure/ms13_vehicle_part/running_gear/civ96/wheels)
	add_gear("back_right", "wheels_back_right", "wheels_back_right_broken", /obj/structure/ms13_vehicle_part/running_gear/civ96/wheels)

// ---------------------------------------------------------------------------------------------------------
// MT-LB: tracked tractor-carrier. Crew cab up front with the machine gun, engine behind the gunner, and a
// cramped troop box at the back reached through a single rear door.
//
//   driver        | gunner (MG turret)
//   aisle         | engine              <- panel from the aisle
//   troop seat    | troop seat
//   fuel tank     | troop seat          <- rear door
// ---------------------------------------------------------------------------------------------------------

/datum/ms13_ground_vehicle/mtlb
	acceleration_delay = 1.6 SECONDS
	coast_delay = 2 SECONDS
	turn_delay = 6
	max_turn_speed = 1
	ram_damage_base = 8
	ram_damage_per_speed = 6
	ram_knockdown_per_speed = 6
	running_gear_integrity = 200
	engine_integrity = 380
	fuel_per_tile = 0.18
	running_gear_soundloop_type = /datum/looping_sound/ms13/vehicle_tracks

/obj/structure/ms13_vehicle_part/engine/mtlb
	name = "YaMZ-238 diesel engine"
	desc = "The MT-LB's V8 diesel, squeezed in right behind the cab."
	icon_state = "engine_static"
	static_icon_state = "engine_static"
	running_icon_state = "engine_on"
	broken_icon_state = "engine_broken"
	density = TRUE

/obj/structure/ms13_vehicle_part/gearbox/mtlb
	name = "MT-LB gearbox"
	density = TRUE
	max_integrity = 200
	gear_delays = list(11, 8, 6)

/obj/structure/ms13_vehicle_part/fuel_tank/mtlb
	name = "MT-LB fuel cell"
	icon_state = "fueltank_incar"
	density = TRUE
	max_integrity = 180
	capacity = 260

/obj/structure/ms13_vehicle_frame/civ96/mtlb
	name = "MT-LB armored tractor"
	desc = "A low, tracked armored tractor with a troop compartment and a pintle machine gun."
	vehicle_controller_type = /datum/ms13_ground_vehicle/mtlb
	art_prefix = "mtlb"
	tile_rows = list(
		list("front_left", "front_right"),
		list("middle_front_left", "middle_front_right"),
		list("middle_back_left", "middle_back_right"),
		list("back_left", "back_right"),
	)
	wall_overrides = list(
		"front_left:front" = /obj/structure/window/ms13_vehicle_wall/civ96,
		"front_right:front" = /obj/structure/window/ms13_vehicle_wall/civ96,
		"back_right:back" = /obj/structure/window/ms13_vehicle_wall/solid/door/civ96,
	)

/obj/structure/ms13_vehicle_frame/civ96/mtlb/furnish()
	add_driver_seat("front_left")
	add_seat_at("front_right", SEAT_FORWARD, "gunner's seat")
	add_turret("front_right", "mtlb", -3, -12, "MT-LB machine gun turret")

	add_panel("middle_front_right", EDGE_FRONT, "engine bulkhead", /obj/structure/window/ms13_vehicle_wall/solid/interior)
	add_panel("middle_front_right", EDGE_LEFT, "engine access panel")
	add_part("middle_front_right", /obj/structure/ms13_vehicle_part/engine/mtlb)
	add_part("middle_front_right", /obj/structure/ms13_vehicle_part/gearbox/mtlb)
	add_part("middle_front_left", /obj/structure/ms13_vehicle_part/stowage)

	add_seat_at("middle_back_left", SEAT_FACING_RIGHT, "troop seat")
	add_seat_at("middle_back_right", SEAT_FACING_LEFT, "troop seat")
	add_seat_at("back_right", SEAT_FACING_LEFT, "troop seat")
	add_part("middle_back_right", /obj/structure/ms13_vehicle_part/interior_light)

	add_panel("back_left", EDGE_FRONT, "fuel cell bulkhead", /obj/structure/window/ms13_vehicle_wall/solid/interior)
	add_panel("back_left", EDGE_RIGHT, "fuel cell access panel")
	add_part("back_left", /obj/structure/ms13_vehicle_part/fuel_tank/mtlb)

	add_gear("front_left", "tracks_left_front")
	add_gear("front_right", "tracks_right_front")
	add_gear("back_left", "tracks_left_back")
	add_gear("back_right", "tracks_right_back")

// ---------------------------------------------------------------------------------------------------------
// BMD-2: small airborne IFV. Bow gunner and driver side by side, turret crew behind, powerpack in the back
// corner and one seat by the rear hatch.
//
//   bow gunner    | driver
//   commander     | gunner (turret)
//   troop seat    | engine + fuel       <- rear hatch on the left, panel from it
// ---------------------------------------------------------------------------------------------------------

/datum/ms13_ground_vehicle/bmd2
	acceleration_delay = 1.1 SECONDS
	coast_delay = 1.6 SECONDS
	turn_delay = 5
	max_turn_speed = 2
	ram_damage_base = 6
	ram_damage_per_speed = 5
	ram_knockdown_per_speed = 5
	running_gear_integrity = 170
	engine_integrity = 320
	fuel_per_tile = 0.14
	running_gear_soundloop_type = /datum/looping_sound/ms13/vehicle_tracks

/obj/structure/ms13_vehicle_part/engine/bmd2
	name = "5D-20 diesel engine"
	desc = "The BMD-2's compact, lightweight diesel."
	icon_state = "engine_static"
	static_icon_state = "engine_static"
	running_icon_state = "engine_on"
	broken_icon_state = "engine_broken"
	density = TRUE

/obj/structure/ms13_vehicle_part/gearbox/bmd2
	name = "BMD-2 gearbox"
	density = TRUE
	max_integrity = 180
	gear_delays = list(9, 6, 5, 4)

/obj/structure/ms13_vehicle_part/fuel_tank/bmd2
	name = "BMD-2 fuel tank"
	icon_state = "fueltank_small_tank"
	density = TRUE
	max_integrity = 150
	capacity = 200

/obj/structure/ms13_vehicle_frame/civ96/bmd2
	name = "BMD-2 airborne fighting vehicle"
	desc = "A small, light tracked fighting vehicle with an autocannon turret."
	vehicle_controller_type = /datum/ms13_ground_vehicle/bmd2
	art_prefix = "bmd2new"
	tile_rows = list(
		list("front_left", "front_right"),
		list("middle_left", "middle_right"),
		list("back_left", "back_right"),
	)
	wall_overrides = list(
		"front_left:front" = /obj/structure/window/ms13_vehicle_wall/civ96,
		"front_right:front" = /obj/structure/window/ms13_vehicle_wall/civ96,
		"back_left:back" = /obj/structure/window/ms13_vehicle_wall/solid/door/civ96,
	)

/obj/structure/ms13_vehicle_frame/civ96/bmd2/furnish()
	add_driver_seat("front_right")
	add_seat_at("front_left", SEAT_FORWARD, "bow gunner's seat")
	add_part("front_left", /obj/structure/ms13_vehicle_part/stowage)
	add_turret("middle_right", "bmd2", -16, 16, "BMD-2 turret")
	add_seat_at("middle_right", SEAT_FORWARD, "gunner's seat")
	add_seat_at("middle_left", SEAT_FORWARD, "commander's seat")
	add_part("middle_left", /obj/structure/ms13_vehicle_part/interior_light)
	add_seat_at("back_left", SEAT_FACING_RIGHT, "troop seat")

	add_panel("back_right", EDGE_LEFT, "engine access panel")
	add_panel("back_right", EDGE_FRONT, "engine bulkhead", /obj/structure/window/ms13_vehicle_wall/solid/interior)
	add_part("back_right", /obj/structure/ms13_vehicle_part/engine/bmd2)
	add_part("back_right", /obj/structure/ms13_vehicle_part/gearbox/bmd2)
	add_part("back_right", /obj/structure/ms13_vehicle_part/fuel_tank/bmd2)

	add_gear("front_left", "tracks_left_front")
	add_gear("front_right", "tracks_right_front")
	add_gear("back_left", "tracks_left_back")
	add_gear("back_right", "tracks_right_back")

// ---------------------------------------------------------------------------------------------------------
// T-34: medium tank. Driver and bow gunner in front, two-man turret, ammunition along both sides, and the
// V-2 engine, fuel and rear transmission walled off behind access panels.
//
//   driver        | ammo rack           | bow gunner
//   ammo rack     | gunner (turret)     | ammo rack
//   hatch         | loader, ammo rack   | hatch
//   fuel tank     | engine              | transmission
// ---------------------------------------------------------------------------------------------------------

/datum/ms13_ground_vehicle/t34
	acceleration_delay = 2 SECONDS
	coast_delay = 2.2 SECONDS
	turn_delay = 8
	max_turn_speed = 1
	ram_damage_base = 12
	ram_damage_per_speed = 9
	ram_knockdown_per_speed = 8
	running_gear_integrity = 320
	engine_integrity = 500
	fuel_per_tile = 0.3
	running_gear_soundloop_type = /datum/looping_sound/ms13/vehicle_tracks

/obj/structure/ms13_vehicle_part/engine/t34
	name = "V-2-34 diesel engine"
	desc = "The T-34's twelve-cylinder aluminium diesel."
	icon_state = "engine_static"
	static_icon_state = "engine_static"
	running_icon_state = "engine_on"
	broken_icon_state = "engine_broken"
	density = TRUE
	max_integrity = 450

/obj/structure/ms13_vehicle_part/gearbox/t34
	name = "T-34 transmission"
	desc = "A heavy, stubborn four-speed tank transmission."
	density = TRUE
	max_integrity = 300
	gear_delays = list(13, 10, 8)

/obj/structure/ms13_vehicle_part/fuel_tank/t34
	name = "T-34 fuel tank"
	icon_state = "fueltank_large_tank"
	density = TRUE
	max_integrity = 250
	capacity = 400

/obj/structure/ms13_vehicle_frame/civ96/t34
	name = "T-34 medium tank"
	desc = "A rugged medium tank with sloped armor."
	vehicle_controller_type = /datum/ms13_ground_vehicle/t34
	hull_color = "#3d5931"
	art_prefix = "t34"
	plating_type = /obj/structure/window/ms13_vehicle_wall/solid/civ96/tank
	explosion_block = 4
	tile_rows = list(
		list("front_left", "front_middle", "front_right"),
		list("middle_front_left", "middle_front", "middle_front_right"),
		list("middle_back_left", "middle_back", "middle_back_right"),
		list("back_left", "back", "back_right"),
	)
	wall_art_names = list("back" = "back_middle")
	wall_overrides = list(
		"front_left:front" = /obj/structure/window/ms13_vehicle_wall/civ96/tank,
		"front_right:front" = /obj/structure/window/ms13_vehicle_wall/civ96/tank,
		"middle_back_left:left" = /obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank,
		"middle_back_right:right" = /obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank,
	)

/obj/structure/ms13_vehicle_frame/civ96/t34/furnish()
	add_driver_seat("front_left")
	add_part("front_middle", /obj/structure/ms13_vehicle_part/stowage)
	add_seat_at("front_right", SEAT_FORWARD, "bow gunner's seat")
	add_turret("middle_front", "t34", 0, 0, "T-34 turret")
	add_seat_at("middle_front", SEAT_FORWARD, "gunner's seat")
	add_part("middle_front_left", /obj/structure/ms13_vehicle_part/stowage)
	add_part("middle_front_right", /obj/structure/ms13_vehicle_part/stowage)
	add_seat_at("middle_back", SEAT_FORWARD, "loader's seat")
	add_part("middle_back", /obj/structure/ms13_vehicle_part/stowage)
	add_part("middle_back", /obj/structure/ms13_vehicle_part/interior_light)

	add_panel("back_left", EDGE_FRONT, "fuel tank access panel")
	add_panel("back", EDGE_FRONT, "engine access panel")
	add_panel("back_right", EDGE_FRONT, "transmission access panel")
	add_part("back_left", /obj/structure/ms13_vehicle_part/fuel_tank/t34)
	add_part("back", /obj/structure/ms13_vehicle_part/engine/t34)
	add_part("back_right", /obj/structure/ms13_vehicle_part/gearbox/t34)

	add_gear("front_left", "tracks_left_front")
	add_gear("front_right", "tracks_right_front")
	add_gear("back_left", "tracks_left_back")
	add_gear("back_right", "tracks_right_back")

// ---------------------------------------------------------------------------------------------------------
// IS-3: heavy tank. Central driver under the pike nose, a big three-man turret, ammunition everywhere else,
// and a long engine deck at the back.
//
//   ammo rack     | driver              | ammo rack
//   ammo rack     | gunner (turret)     | ammo rack
//   hatch         | commander           | hatch
//   ammo rack     | loader              | ammo rack
//   fuel tank     | engine              | transmission
// ---------------------------------------------------------------------------------------------------------

/datum/ms13_ground_vehicle/is3
	acceleration_delay = 2.6 SECONDS
	coast_delay = 2.4 SECONDS
	turn_delay = 10
	max_turn_speed = 1
	ram_damage_base = 16
	ram_damage_per_speed = 12
	ram_knockdown_per_speed = 10
	running_gear_integrity = 420
	engine_integrity = 600
	fuel_per_tile = 0.4
	running_gear_soundloop_type = /datum/looping_sound/ms13/vehicle_tracks

/obj/structure/ms13_vehicle_part/engine/is3
	name = "V-2-IS diesel engine"
	desc = "A heavy-tank development of the V-2 twelve-cylinder diesel."
	icon_state = "engine_static"
	static_icon_state = "engine_static"
	running_icon_state = "engine_on"
	broken_icon_state = "engine_broken"
	density = TRUE
	max_integrity = 550

/obj/structure/ms13_vehicle_part/gearbox/is3
	name = "IS-3 transmission"
	desc = "A heavy planetary transmission built to move fifty tonnes."
	density = TRUE
	max_integrity = 380
	gear_delays = list(16, 12, 10)

/obj/structure/ms13_vehicle_part/fuel_tank/is3
	name = "IS-3 fuel tank"
	icon_state = "fueltank_large_tank"
	density = TRUE
	max_integrity = 300
	capacity = 500

/obj/structure/ms13_vehicle_frame/civ96/is3
	name = "IS-3 heavy tank"
	desc = "A massive heavy tank with a pike-nosed hull and a huge cast turret."
	vehicle_controller_type = /datum/ms13_ground_vehicle/is3
	art_prefix = "is3"
	plating_type = /obj/structure/window/ms13_vehicle_wall/solid/civ96/tank
	explosion_block = 4
	tile_rows = list(
		list("front_left", "front_middle", "front_right"),
		list("middle_front_left", "middle_front", "middle_front_right"),
		list("middle_left", "middle", "middle_right"),
		list("middle_back_left", "middle_back", "middle_back_right"),
		list("back_left", "back", "back_right"),
	)
	roofless_tiles = list("middle_front")
	wall_overrides = list(
		"front_middle:front" = /obj/structure/window/ms13_vehicle_wall/civ96/tank,
		"middle_left:left" = /obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank,
		"middle_right:right" = /obj/structure/window/ms13_vehicle_wall/solid/door/civ96/tank,
	)

/obj/structure/ms13_vehicle_frame/civ96/is3/furnish()
	add_driver_seat("front_middle")
	add_part("front_left", /obj/structure/ms13_vehicle_part/stowage)
	add_part("front_right", /obj/structure/ms13_vehicle_part/stowage)
	add_turret("middle_front", "is3", 0, -16, "IS-3 turret")
	add_seat_at("middle_front", SEAT_FORWARD, "gunner's seat")
	add_part("middle_front_left", /obj/structure/ms13_vehicle_part/stowage)
	add_part("middle_front_right", /obj/structure/ms13_vehicle_part/stowage)
	add_seat_at("middle", SEAT_FORWARD, "commander's seat")
	add_part("middle", /obj/structure/ms13_vehicle_part/interior_light)
	add_seat_at("middle_back", SEAT_FORWARD, "loader's seat")
	add_part("middle_back_left", /obj/structure/ms13_vehicle_part/stowage)
	add_part("middle_back_right", /obj/structure/ms13_vehicle_part/stowage)

	add_panel("back_left", EDGE_FRONT, "fuel tank access panel")
	add_panel("back", EDGE_FRONT, "engine access panel")
	add_panel("back_right", EDGE_FRONT, "transmission access panel")
	add_part("back_left", /obj/structure/ms13_vehicle_part/fuel_tank/is3)
	add_part("back", /obj/structure/ms13_vehicle_part/engine/is3)
	add_part("back_right", /obj/structure/ms13_vehicle_part/gearbox/is3)

	add_gear("front_left", "tracks_left_front", "tracks_left_front_destroyed")
	add_gear("front_right", "tracks_right_front", "tracks_right_front_destroyed")
	add_gear("back_left", "tracks_left_back")
	add_gear("back_right", "tracks_right_back")

#undef SEAT_FORWARD
#undef SEAT_FACING_LEFT
#undef SEAT_FACING_RIGHT
#undef EDGE_FRONT
#undef EDGE_BACK
#undef EDGE_LEFT
#undef EDGE_RIGHT

TYPEINFO_DEF(/obj/structure/window/ms13_vehicle_wall/civ96/tank)
	default_armor = list(BLUNT = 95, PUNCTURE = 900, SLASH = 100, LASER = 50, ENERGY = 40, BOMB = 50, BIO = 100, FIRE = 60, ACID = 50)

/// A tank's vision block is as bulletproof as the armor around it.
/obj/structure/window/ms13_vehicle_wall/civ96/tank
	max_integrity = 1500
	bullet_damage_ratio = 0.05
