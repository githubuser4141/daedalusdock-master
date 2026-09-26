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
 * Heavy things to drag. Give a type heft (kilograms) and, instead of being bolted down, it can be dragged by anyone
 * strong enough, slowing them by its weight (and less the stronger they are: get_load_mult()). Walking into it won't
 * shove it along; it only goes where it's dragged. A mapped one given heft = 0 stays bolted down, as does one wrenched
 * down where its type anchors with a wrench.
 */
/obj
	var/heft = 0

/// Kilograms of drag that slow the one dragging as much again as their own walk.
#define MS13_HEFT_PER_SLOWDOWN 60
/// Kilograms each point of Strength (the body's, or a power armor frame's) can drag at all.
#define MS13_HEFT_PER_STRENGTH 40

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
	target.set_anchored(FALSE)
	target.drag_slowdown = target.heft / MS13_HEFT_PER_SLOWDOWN
	RegisterSignal(target, COMSIG_ATOM_CAN_BE_GRABBED, PROC_REF(check_grab))
	RegisterSignal(target, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(check_move))

/datum/element/ms13_heavy/Detach(obj/source)
	UnregisterSignal(source, list(COMSIG_ATOM_CAN_BE_GRABBED, COMSIG_MOVABLE_PRE_MOVE))
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

#ifdef UNIT_TESTS
/// Heft unbolts a thing: the strong enough drag it, slowly; the weak can't grip it; walking into it doesn't shove it.
/datum/unit_test/ms13_heft
	name = "OBJECTS: Heavy Things Drag, Slowly, For The Strong Enough"

/datum/unit_test/ms13_heft/Run()
	var/turf/start = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/ms13_heft_test/wardrobe = allocate(/obj/structure/ms13_heft_test, start)
	var/obj/structure/ms13_heft_test/bolted/bolted = allocate(/obj/structure/ms13_heft_test/bolted, run_loc_floor_bottom_left)
	if(wardrobe.anchored || !bolted.anchored)
		Fail("Heft didn't unbolt a thing, or a mapped heft of 0 didn't keep one bolted down.")
	var/mob/living/carbon/human/consistent/hauler = allocate(/mob/living/carbon/human/consistent, get_step(start, WEST))
	hauler.Move(start, EAST)
	if(wardrobe.loc != start)
		Fail("Walking into something heavy shoved it along.")
	var/mob/living/carbon/human/consistent/weakling = allocate(/mob/living/carbon/human/consistent, get_step(start, SOUTH))
	weakling.set_special_base(SPECIAL_STRENGTH, 2)
	if(weakling.try_make_grab(wardrobe))
		Fail("Someone too weak got a grip on something too heavy for them.")
	if(!hauler.try_make_grab(wardrobe))
		Fail("An average body couldn't get a grip on something they can drag.")
		return
	hauler.Move(get_step(hauler, WEST), WEST)
	if(wardrobe.loc == start)
		Fail("Something heavy didn't follow the one dragging it.")
	if(!hauler.has_movespeed_modifier(/datum/movespeed_modifier/grabbing))
		Fail("Dragging something heavy didn't slow the one dragging it.")

/obj/structure/ms13_heft_test
	anchored = TRUE
	density = TRUE
	heft = 150

/obj/structure/ms13_heft_test/bolted
	heft = 0
#endif
