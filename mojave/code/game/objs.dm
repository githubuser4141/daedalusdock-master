/obj/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION(VV_HK_SUBARMOR_MOD, "Modify subarmor values")

/obj/vv_do_topic(list/href_list)
	if(!(. = ..()))
		return
	if(href_list[VV_HK_ARMOR_MOD])
		var/list/pickerlist = list()
		var/list/armorlist = armor.getList()

		for(var/i in armorlist)
			pickerlist += list(list("value" = armorlist[i], "name" = i))

		var/list/result = presentpicker(usr, "Modify subarmor", "Modify subarmor: [src]", Button1="Save", Button2 = "Cancel", Timeout=FALSE, inputtype = "text", values = pickerlist)

		if (islist(result))
			if (result["button"] != 2) // If the user pressed the cancel button
				// text2num conveniently returns a null on invalid values
				subarmor = subarmor.setRating(subarmor_flags = text2num(result["values"][SUBARMOR_FLAGS]),\
			                  edge_protection = text2num(result["values"][EDGE_PROTECTION]),\
			                  crushing = text2num(result["values"][CRUSHING]),\
			                  cutting = text2num(result["values"][CUTTING]),\
			                  piercing = text2num(result["values"][PIERCING]),\
			                  impaling = text2num(result["values"][IMPALING]),\
							  laser = text2num(result["values"][LASER]),\
							  energy = text2num(result["values"][ENERGY]),\
			                  fire = text2num(result["values"][FIRE]),\
			                  acid = text2num(result["values"][ACID]))
				log_admin("[key_name(usr)] modified the subarmor on [src] ([type]) to subarmor_flags: [subarmor.subarmor_flags], crushing: [subarmor.crushing], cutting: [subarmor.cutting], piercing: [subarmor.piercing], impaling: [subarmor.impaling], laser: [subarmor.laser], energy: [subarmor.energy], acid: [subarmor.acid]")
				message_admins(span_notice("[key_name_admin(usr)] modified the subarmor on [src] ([type]) to subarmor_flags: [subarmor.subarmor_flags], crushing: [subarmor.crushing], cutting: [subarmor.cutting], piercing: [subarmor.piercing], impaling: [subarmor.impaling], laser: [subarmor.laser], energy: [subarmor.energy], acid: [subarmor.acid]"))

/// Already burning away (its ash landing can set a bonfire off again first): nothing left to burn.
/obj/fire_act(exposed_temperature, exposed_volume, turf/adjacent)
	if(uses_integrity && atom_integrity <= 0)
		return
	return ..()

/**
 * Heavy things to drag. Give a type heft (kilograms) and anyone strong enough can drag it, slowed by its weight (less
 * the stronger they are: get_load_mult()). At rest it stays anchored, so whatever needs it anchored (a machine running,
 * say) keeps working; it only comes loose while dragged, and walking into it won't shove it. A mapped one given
 * heft = 0 stays put.
 *
 * A heavy machine that uses power is wired in where it first stood. Anywhere else it also needs a cable knot under it
 * carrying power.
 */
/obj
	var/heft = 0
	/// Let loose to be dragged, and anchored again once let go.
	var/tmp/hauled = FALSE

/obj/machinery
	/// Where a heavy machine first stood, wired in.
	var/turf/wired_at

/// Kilograms of drag that slow the one dragging as much again as their own walk.
#define MS13_HEFT_PER_SLOWDOWN 60
/// Kilograms each point of Strength (the body's, or a power armor frame's) can drag at all.
#define MS13_HEFT_PER_STRENGTH 40

GLOBAL_LIST_EMPTY(ms13_heavy_machines)

/obj/Initialize(mapload)
	. = ..()
	if(heft)
		AddElement(/datum/element/ms13_heavy)

/datum/element/ms13_heavy
	element_flags = ELEMENT_DETACH

/datum/element/ms13_heavy/Attach(obj/target)
	. = ..()
	if(!isobj(target))
		return ELEMENT_INCOMPATIBLE
	target.drag_slowdown = target.heft / MS13_HEFT_PER_SLOWDOWN
	RegisterSignal(target, COMSIG_ATOM_CAN_BE_GRABBED, PROC_REF(check_grab))
	RegisterSignal(target, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(check_move))
	RegisterSignal(target, COMSIG_ATOM_NO_LONGER_GRABBED, PROC_REF(let_go))
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(moved))
	if(ismachinery(target))
		var/obj/machinery/machine = target
		machine.wired_at = get_turf(machine)
		GLOB.ms13_heavy_machines += machine

/datum/element/ms13_heavy/Detach(obj/source)
	UnregisterSignal(source, list(COMSIG_ATOM_CAN_BE_GRABBED, COMSIG_MOVABLE_PRE_MOVE, COMSIG_ATOM_NO_LONGER_GRABBED, COMSIG_MOVABLE_MOVED))
	GLOB.ms13_heavy_machines -= source
	return ..()

/datum/element/ms13_heavy/proc/check_grab(obj/source, mob/living/grabber)
	SIGNAL_HANDLER
	if(source.heft > grabber.get_body_strength() * MS13_HEFT_PER_STRENGTH)
		to_chat(grabber, span_warning("[source] is too heavy for you to budge."))
		return COMSIG_ATOM_NO_GRAB

/datum/element/ms13_heavy/proc/check_move(obj/source, atom/newloc)
	SIGNAL_HANDLER
	if(!LAZYLEN(source.grabbed_by))
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/datum/element/ms13_heavy/proc/let_go(obj/source)
	SIGNAL_HANDLER
	source.settle()

/// A table and the like joins up with its new neighbours and parts from the old; a machine checks its wiring.
/datum/element/ms13_heavy/proc/moved(obj/source, atom/old_loc)
	SIGNAL_HANDLER
	if(source.smoothing_flags & (SMOOTH_CORNERS|SMOOTH_BITMASK))
		QUEUE_SMOOTH(source)
		QUEUE_SMOOTH_NEIGHBORS(source)
		if(old_loc)
			QUEUE_SMOOTH_NEIGHBORS(old_loc)
	if(ismachinery(source))
		var/obj/machinery/machine = source
		machine.check_wiring()

/// Anchored again once nobody's dragging it.
/obj/proc/settle()
	if(hauled && !LAZYLEN(grabbed_by))
		hauled = FALSE
		set_anchored(TRUE)

/// Heavy things come loose to be dragged, and settle again if they can't be.
/mob/living/try_make_grab(atom/movable/target, grab_type, use_offhand)
	var/obj/heavy = target
	if(!isobj(heavy) || !heavy.heft || !heavy.anchored)
		return ..()
	heavy.hauled = TRUE
	heavy.set_anchored(FALSE)
	. = ..()
	if(!.)
		heavy.settle()

/obj/machinery/powered(chan = power_channel, ignore_use_power = FALSE)
	. = ..()
	if(!. || !heft || (!use_power && !ignore_use_power) || loc == wired_at)
		return
	return isturf(loc) && ms13_cable_net_at(loc)?.avail > 0

/// Powers a heavy machine up or down if its wiring changed.
/obj/machinery/proc/check_wiring()
	if(!(machine_stat & NOPOWER) != !!powered(power_channel))
		power_change()

/// A cable laid, cut, or gone live or dead: heavy machines check their wiring next tick, all at once.
/// ponytail: sweeps every heavy machine for any cable anywhere; keep a list per powernet if that ever shows in profiles.
/proc/ms13_rewire()
	if(length(GLOB.ms13_heavy_machines))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(ms13_check_wiring)), 1, TIMER_UNIQUE)

/proc/ms13_check_wiring()
	for(var/obj/machinery/machine as anything in GLOB.ms13_heavy_machines)
		machine.check_wiring()

/obj/structure/cable/Initialize(mapload)
	. = ..()
	ms13_rewire()

/obj/structure/cable/set_directions(new_directions, merge_connections = TRUE)
	. = ..()
	ms13_rewire()

/obj/structure/cable/Destroy()
	ms13_rewire()
	return ..()

/*
 * How heavy things are, in kilograms. Strength 5 drags up to 200, Strength 10 up to 400, a power armor frame 520.
 * heft = 0 keeps a subtype where it stands.
 */
/obj/structure/table/ms13/wood
	heft = 30
/obj/structure/table/ms13/wood/bar
	heft = 0
/obj/structure/table/ms13/metal
	heft = 45
/obj/structure/table/ms13/metal/small
	heft = 20
/obj/structure/table/ms13/metal/heavy
	heft = 90
/obj/structure/table/ms13/no_smooth/wood
	heft = 30
/obj/structure/table/ms13/no_smooth/metal
	heft = 45
/obj/structure/table/ms13/no_smooth/large
	heft = 60
/obj/structure/table/ms13/no_smooth/dice
	heft = 30
/obj/structure/table/ms13/no_smooth/cable_reel
	heft = 60
/obj/structure/table/ms13/crafting
	heft = 120

/obj/structure/chair/ms13
	heft = 10
/obj/structure/chair/comfy/ms13
	heft = 25
/obj/structure/chair/office/ms13
	heft = 15
/obj/structure/chair/sofa
	heft = 50
/obj/structure/chair/pew
	heft = 80
/obj/structure/bed/ms13
	heft = 40
/obj/structure/bed/ms13/mattress
	heft = 15
/obj/structure/bed/ms13/medical
	heft = 60
/obj/structure/bed/ms13/sleepingbag
	heft = 0

/obj/structure/closet/ms13
	heft = 60
/obj/structure/closet/ms13/enclave
	heft = 80
/obj/structure/closet/ms13/fridge
	heft = 100
/obj/structure/closet/ms13/grave
	heft = 0
/obj/structure/closet/ms13/wall
	heft = 0
/obj/structure/closet/crate/ms13
	heft = 35
/obj/structure/closet/crate/ms13/woodcrate/compact
	heft = 15
/obj/structure/closet/crate/ms13/vault_tec/compact
	heft = 15
/obj/structure/closet/crate/ms13/vault_tec/big
	heft = 60
/obj/structure/closet/crate/ms13/footlocker
	heft = 20
/obj/structure/closet/crate/ms13/cash_register
	heft = 0
/obj/structure/filingcabinet/ms13
	heft = 50
/obj/structure/dresser/ms13
	heft = 50
/obj/structure/ms13/storage/bookshelf
	heft = 40
/obj/structure/ms13/storage/large
	heft = 80
/obj/structure/ms13/storage/shelf
	heft = 30
/obj/structure/ms13/storage/store
	heft = 60
/obj/structure/ms13/storage/trashcan
	heft = 15
/obj/structure/ms13/storage/washingmachine
	heft = 70
/obj/structure/safe/ms13
	heft = 400
/obj/structure/safe/ms13/wall
	heft = 0

/obj/structure/ms13/tv
	heft = 25
/obj/structure/ms13/jukebox
	heft = 150
/obj/structure/ms13/barrel
	heft = 60
/obj/machinery/vending/ms13
	heft = 300
/obj/machinery/griddle
	heft = 90

#ifdef UNIT_TESTS
/// Heavy things drag, slowly, for the strong enough, and settle anchored again; walking into one doesn't shove it.
/datum/unit_test/ms13_heft
	name = "OBJECTS: Heavy Things Drag, Slowly, For The Strong Enough"

/datum/unit_test/ms13_heft/Run()
	var/turf/start = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_heft_test/wardrobe = allocate(/obj/structure/ms13_heft_test, start)
	var/obj/structure/ms13_heft_test/bolted/bolted = allocate(/obj/structure/ms13_heft_test/bolted, run_loc_floor_bottom_left)
	if(!wardrobe.anchored)
		Fail("Heft unanchored a thing at rest.")
	var/mob/living/carbon/human/consistent/hauler = allocate(/mob/living/carbon/human/consistent, get_step(start, WEST))
	hauler.Move(start, EAST)
	if(wardrobe.loc != start)
		Fail("Walking into something heavy shoved it along.")
	var/mob/living/carbon/human/consistent/weakling = allocate(/mob/living/carbon/human/consistent, get_step(start, SOUTH))
	weakling.set_special_base(SPECIAL_STRENGTH, 2)
	if(weakling.try_make_grab(wardrobe) || !wardrobe.anchored)
		Fail("Someone too weak got a grip on something too heavy for them, or left it loose trying.")
	if(hauler.try_make_grab(bolted))
		Fail("Someone dragged a thing given no heft.")
	var/obj/item/hand_item/grab/grip = hauler.try_make_grab(wardrobe)
	if(!grip)
		Fail("An average body couldn't get a grip on something they can drag.")
		return
	hauler.Move(get_step(hauler, WEST), WEST)
	if(wardrobe.loc == start)
		Fail("Something heavy didn't follow the one dragging it.")
	if(!hauler.has_movespeed_modifier(/datum/movespeed_modifier/grabbing))
		Fail("Dragging something heavy didn't slow the one dragging it.")
	qdel(grip)
	if(!wardrobe.anchored)
		Fail("Something heavy stayed loose once let go.")

/// A heavy machine runs where it was wired in; moved, only on a live cable knot.
/datum/unit_test/ms13_heft_wiring
	name = "OBJECTS: Heavy Machines Moved Need A Live Cable"

/datum/unit_test/ms13_heft_wiring/Run()
	var/turf/home = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/away = get_step(home, EAST)
	var/obj/machinery/ms13_heft_test/fridge = allocate(/obj/machinery/ms13_heft_test, home)
	if(!fridge.powered())
		Fail("A heavy machine wasn't powered where it was wired in.")
	fridge.forceMove(away)
	if(fridge.powered() || !(fridge.machine_stat & NOPOWER))
		Fail("A heavy machine moved off its wiring kept running.")
	var/obj/structure/cable/knot = allocate(/obj/structure/cable, away)
	knot.set_directions(GLOB.real_dirs_to_cable_dirs["[NORTH]"])
	if(!knot.powernet)
		new /datum/powernet().add_cable(knot)
	if(fridge.powered())
		Fail("A heavy machine ran on a dead cable.")
	knot.powernet.avail = 1000
	ms13_check_wiring()
	if(!fridge.powered() || (fridge.machine_stat & NOPOWER))
		Fail("A heavy machine on a live cable didn't run.")
	fridge.forceMove(home)
	if(!fridge.powered())
		Fail("A heavy machine back where it was wired in didn't run.")

/obj/structure/ms13_heft_test
	anchored = TRUE
	density = TRUE
	heft = 150

/obj/structure/ms13_heft_test/bolted
	heft = 0

/obj/machinery/ms13_heft_test
	density = TRUE
	heft = 120
#endif
