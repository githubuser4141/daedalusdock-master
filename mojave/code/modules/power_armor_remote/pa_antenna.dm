/**
 * A placeable relay antenna extending a control terminal's reach to a remote-controlled suit
 * wirelessly. Paired to a terminal/receiver by the same shared link_id string - see
 * control_computer.dm. Range/z-level checking mirrors the existing signal jammer pattern
 * (code/game/objects/items/devices/traitordevices.dm's /obj/item/jammer + GLOB.active_jammers +
 * get_dist() + same-z check in radio.dm) even though jamming itself is out of scope for now.
 */
/obj/machinery/ms13_pa_antenna
	name = "power armor relay antenna"
	desc = "Extends a control terminal's reach to a remote-controlled suit of power armor."
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "processor"
	density = TRUE
	circuit = /obj/item/circuitboard/machine/ms13_pa_antenna
	var/link_id
	var/range = 50
	var/datum/ms13_remote_link/active_link

/obj/item/circuitboard/machine/ms13_pa_antenna
	build_path = /obj/machinery/ms13_pa_antenna

/obj/machinery/ms13_pa_antenna/Initialize(mapload)
	. = ..()
	GLOB.ms13_pa_antennas += src
	begin_processing()

/obj/machinery/ms13_pa_antenna/Destroy()
	GLOB.ms13_pa_antennas -= src
	end_processing()
	if(active_link)
		active_link.sever("the relay antenna was destroyed")
	return ..()

/obj/machinery/ms13_pa_antenna/proc/pa_in_range(atom/target)
	if(!target)
		return FALSE
	var/turf/my_turf = get_turf(src)
	var/turf/their_turf = get_turf(target)
	if(!my_turf || !their_turf || my_turf.z != their_turf.z)
		return FALSE
	return get_dist(my_turf, their_turf) <= range

/obj/machinery/ms13_pa_antenna/process(seconds_per_tick)
	if(!active_link?.drone)
		return
	if(!pa_in_range(active_link.drone))
		active_link.sever("the suit moved out of relay range")
