/// A real, fully-functional human body (breathes, bleeds, dies normally) that a remote-control
/// operator's mind is transferred into while piloting an unoccupied power armor suit. Deliberately
/// NOT /mob/living/carbon/human/dummy - that type is a GODMODE, Life()-disabled preview-only mob used
/// for character prefs, not a real interactive body (see code/modules/mob/living/carbon/human/
/// dummy.dm). Built on /consistent rather than a plain human so it always spawns as a standard,
/// power-armor-compatible body instead of a random species that might be equip-restricted from
/// wearing it at all. Equipping the suit onto it reuses every bit of existing PA wearer gameplay
/// (subarmor interception, attack, item pickup) for free.
/mob/living/carbon/human/consistent/ms13_pa_drone
	real_name = "power armor unit"

/mob/living/carbon/human/consistent/ms13_pa_drone/Destroy()
	var/datum/ms13_remote_link/link = GLOB.ms13_remote_links_by_drone[src]
	if(link)
		link.sever("the armor was destroyed")
	return ..()

/**
 * Owns one active remote-control session: the operator's real body, the drone body standing in for
 * them, and the module/computer/hardware involved. sever() is the ONLY way this link ever ends, and
 * every possible teardown trigger (drone destroyed, module/suit/computer/antenna destroyed, cable cut,
 * out of radio range, manual disconnect) must route through it - see the callers below and in
 * pa_module_remote.dm / control_computer.dm / pa_antenna.dm.
 */
/datum/ms13_remote_link
	var/mob/living/carbon/human/real_body
	var/mob/living/carbon/human/consistent/ms13_pa_drone/drone
	var/obj/item/ms13/pa_module/remote_receiver/module
	var/obj/machinery/computer/ms13_pa_control/computer
	var/link_type // MS13_PA_LINK_CABLE or MS13_PA_LINK_RADIO
	var/obj/machinery/ms13_pa_antenna/antenna
	/// Ordered trail of cable segments laid behind the drone, cable link only - see lay_or_reel_cable().
	var/list/obj/structure/ms13_pa_cable/cable_trail = list()

/datum/ms13_remote_link/New(mob/living/carbon/human/operator, obj/item/ms13/pa_module/remote_receiver/new_module, obj/machinery/computer/ms13_pa_control/new_computer, new_link_type)
	. = ..()
	real_body = operator
	module = new_module
	computer = new_computer
	link_type = new_link_type

	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/suit = module.part_pa.frame
	drone = new(get_turf(suit))
	drone.equip_to_slot_or_del(suit, ITEM_SLOT_OCLOTHING, TRUE)

	GLOB.ms13_remote_links_by_drone[drone] = src
	GLOB.ms13_remote_links_by_module[module] = src
	RegisterSignal(drone, COMSIG_PARENT_QDELETING, PROC_REF(on_drone_deleted))
	RegisterSignal(real_body, COMSIG_PARENT_QDELETING, PROC_REF(on_real_body_deleted))
	if(link_type == MS13_PA_LINK_CABLE)
		RegisterSignal(drone, COMSIG_MOVABLE_MOVED, PROC_REF(on_drone_moved))

	operator.mind.transfer_to(drone)
	to_chat(real_body, span_notice("Your consciousness floods into the power armor's systems."))
	to_chat(drone, span_notice("You are now remote-piloting this power armor. Disconnect at the controlling terminal to return."))

/datum/ms13_remote_link/proc/on_drone_deleted()
	SIGNAL_HANDLER
	sever("the armor was destroyed")

/datum/ms13_remote_link/proc/on_real_body_deleted()
	SIGNAL_HANDLER
	// Nothing to transfer back to - let the drone's own mind handling ghost the operator out normally,
	// same as any other mob whose body is destroyed. Just tear down the link's bookkeeping.
	real_body = null
	sever("your body no longer exists")

/// Called on every drone step while cable-linked. Lays a new segment behind it, or reels one in if
/// it's retracing its own trail - see the plan's cable design (mojave/__DEFINES doesn't own this var,
/// this is purely mojave code so no core-file tracking needed).
/datum/ms13_remote_link/proc/on_drone_moved(atom/movable/mover, atom/oldloc)
	SIGNAL_HANDLER
	if(!oldloc)
		return
	var/turf/old_turf = get_turf(oldloc)
	if(!old_turf)
		return

	if(length(cable_trail) && cable_trail[length(cable_trail)].loc == drone.loc)
		// Stepped back onto the tile our last-laid segment sits on - reel it in.
		qdel(cable_trail[length(cable_trail)])
		cable_trail.len--
		return

	var/obj/structure/ms13_pa_cable/segment = new(old_turf)
	cable_trail += segment
	RegisterSignal(segment, COMSIG_PARENT_QDELETING, PROC_REF(on_cable_cut))

/datum/ms13_remote_link/proc/on_cable_cut(obj/structure/ms13_pa_cable/segment)
	SIGNAL_HANDLER
	if(!(segment in cable_trail))
		return
	sever("the cable was cut")

/// The only path off this link. Always transfers the operator back if their body still exists,
/// always cleans up every piece of hardware state, and can be called more than once safely.
/datum/ms13_remote_link/proc/sever(reason)
	if(!drone)
		return // already severed

	var/mob/living/carbon/human/consistent/ms13_pa_drone/leaving = drone
	drone = null
	UnregisterSignal(leaving, list(COMSIG_PARENT_QDELETING, COMSIG_MOVABLE_MOVED))
	GLOB.ms13_remote_links_by_drone -= leaving

	if(real_body && !QDELETED(real_body) && leaving.mind)
		UnregisterSignal(real_body, COMSIG_PARENT_QDELETING)
		leaving.mind.transfer_to(real_body)
		to_chat(real_body, span_warning("The remote link drops: [reason]."))

	for(var/obj/item/held in leaving.held_items)
		leaving.dropItemToGround(held)
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/suit = leaving.get_item_by_slot(ITEM_SLOT_OCLOTHING)
	if(suit)
		leaving.dropItemToGround(suit)
	qdel(leaving)

	for(var/obj/structure/ms13_pa_cable/segment as anything in cable_trail)
		UnregisterSignal(segment, COMSIG_PARENT_QDELETING)
		qdel(segment)
	cable_trail = list()

	if(module)
		GLOB.ms13_remote_links_by_module -= module
		module.active_link = null
		module = null
	if(computer)
		computer.active_link = null
		computer = null
	if(antenna)
		antenna.active_link = null
		antenna = null

/// One physical cable segment left on the ground behind a cable-linked drone. Destroying it (cut,
/// explosion, whatever) severs the link the instant it's noticed via on_cable_cut() above.
///
/// Deliberately NOT /obj/structure/cable - that's the real underfloor power-grid wiring system
/// (code/modules/power/cable.dm), with its own network/connection logic, T-ray-only visibility via
/// the undertile element, and WIRE_LAYER placement. None of that applies to a plain visible trail
/// prop sitting on top of open floor, so this is its own standalone structure instead.
/obj/structure/ms13_pa_cable
	name = "power armor tether cable"
	desc = "A thick cable, paying out from a remote-controlled suit of power armor."
	icon = 'icons/obj/power_cond/cable.dmi'
	icon_state = "cable_0"
	density = FALSE
	anchored = TRUE
	max_integrity = 20

GLOBAL_LIST_EMPTY(ms13_remote_links_by_drone)
GLOBAL_LIST_EMPTY(ms13_remote_links_by_module)
