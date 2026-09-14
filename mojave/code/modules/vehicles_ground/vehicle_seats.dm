/**
 * A seat mounted on one of a vehicle's frame tiles. Extends the normal chair type for its buckle
 * mechanics - the only thing added is that the driver seat relays its buckled occupant's movement
 * input into actually driving the vehicle (see _vehicle_base.dm) via the same buckled.relaymove()
 * hook every "can't walk while buckled" chair already uses; passenger seats are just normal chairs
 * along for the ride.
 *
 * Pressing the vehicle's current forward/backward direction drives it; pressing either perpendicular
 * direction turns it to face that way instead of sliding sideways - holding a direction key therefore
 * first turns the vehicle onto that heading, then drives it once already facing that way, matching
 * ordinary top-down vehicle controls.
 */
/obj/structure/chair/ms13_vehicle_seat
	name = "vehicle seat"
	desc = "A seat bolted to a vehicle frame."
	icon = 'mojave/icons/objects/vehicles_ground/vehicleparts.dmi'
	icon_state = "driver_car"
	var/obj/structure/ms13_vehicle_frame/parent_frame
	var/is_driver_seat = FALSE

/obj/structure/chair/ms13_vehicle_seat/Destroy()
	if(is_driver_seat && parent_frame?.vehicle?.driver)
		parent_frame.vehicle.driver = null
	parent_frame = null
	return ..()

/obj/structure/chair/ms13_vehicle_seat/post_buckle_mob(mob/living/M)
	. = ..()
	// /mob/living/forceMove() auto-unbuckles its target unconditionally (living.dm) - without this,
	// the very first time do_move()/do_rotate() forceMoves a buckled occupant along with the rest of
	// the vehicle, they'd be silently dropped. Same trait, same BUCKLED_TRAIT source, industrial lifts
	// already rely on it for exactly this reason (industrial_lift.dm's AddItemOnLift()).
	ADD_TRAIT(M, TRAIT_CANNOT_BE_UNBUCKLED, BUCKLED_TRAIT)
	if(is_driver_seat && parent_frame?.vehicle)
		parent_frame.vehicle.driver = M

/obj/structure/chair/ms13_vehicle_seat/post_unbuckle_mob(mob/living/M)
	. = ..()
	REMOVE_TRAIT(M, TRAIT_CANNOT_BE_UNBUCKLED, BUCKLED_TRAIT)
	if(is_driver_seat && parent_frame?.vehicle?.driver == M)
		parent_frame.vehicle.driver = null

/obj/structure/chair/ms13_vehicle_seat/relaymove(mob/living/user, direction)
	if(!is_driver_seat || !parent_frame?.vehicle || !(user in buckled_mobs))
		return ..()
	// Diagonal input (both a vertical and horizontal key held) doesn't map onto this system at all -
	// every offset/facing here is purely cardinal.
	if(!(direction in list(NORTH, SOUTH, EAST, WEST)))
		return

	parent_frame.vehicle.handle_drive_input(direction)
