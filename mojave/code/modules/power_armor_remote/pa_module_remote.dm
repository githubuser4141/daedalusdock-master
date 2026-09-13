/**
 * Installed into one of a power armor suit's parts (same radial-menu install flow as any other
 * pa_module - power_armor_parts.dm attackby()) to make that suit remote-controllable at all.
 *
 * While installed, the suit CANNOT be worn by anyone - see the mob_can_equip() override below on the
 * suit itself. This sidesteps the whole "someone's already wearing it" / "it's mid-remote-session"
 * overlap question entirely: a suit is either normal personal armor, or a remote-only drone shell,
 * never both, and switching between them just means installing or pulling this one part.
 */
/obj/item/ms13/pa_module/remote_receiver
	name = "remote control receiver"
	desc = "Turns a suit of power armor into a remotely-operable shell. The suit cannot be worn while this is installed."
	class_type = MAIN_MODULE_PA
	/// The currently active piloting session, if any - see remote_link.dm's sever().
	var/datum/ms13_remote_link/active_link
	/// Shared plain-string pairing tag matched against a control terminal's link_id - see
	/// control_computer.dm's ms13_find_pa_receiver(). Set by hand via VV, same convention as the
	/// master-key lock_group grouping added earlier this session.
	var/link_id

/obj/item/ms13/pa_module/remote_receiver/Initialize(mapload)
	. = ..()
	GLOB.ms13_pa_receivers += src

/obj/item/ms13/pa_module/remote_receiver/Destroy(force)
	GLOB.ms13_pa_receivers -= src
	if(active_link)
		active_link.sever("the receiver module was removed")
	return ..()

/obj/item/ms13/pa_module/remote_receiver/removed_from_pa()
	. = ..()
	if(active_link)
		active_link.sever("the receiver module was removed")

/// mob_can_equip() below only stops NEW equip attempts - if this gets installed while a real person
/// is already wearing the suit, force it off immediately rather than leaving them in armor that's
/// supposed to be impossible to wear.
/obj/item/ms13/pa_module/remote_receiver/added_to_pa()
	. = ..()
	var/obj/item/ms13/power_armor/part = part_pa
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/frame = part?.frame
	var/mob/living/carbon/human/wearer = frame?.loc
	if(istype(wearer) && !istype(wearer, /mob/living/carbon/human/consistent/ms13_pa_drone))
		to_chat(wearer, span_warning("[frame] suddenly goes rigid and forces itself off you!"))
		wearer.dropItemToGround(frame)

/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/proc/get_remote_receiver()
	for(var/i in module_armor)
		var/obj/item/ms13/power_armor/part = module_armor[i]
		if(!istype(part))
			continue
		for(var/k in part.modules)
			var/obj/item/ms13/pa_module/candidate = part.modules[k]
			if(istype(candidate, /obj/item/ms13/pa_module/remote_receiver))
				return candidate
	return null

/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/mob_can_equip(mob/living/carbon/human/drone_check, obj/item/equip_from, slot, disable_warning, bypass_equip_delay_self)
	if(!istype(drone_check, /mob/living/carbon/human/consistent/ms13_pa_drone) && get_remote_receiver())
		if(!disable_warning)
			to_chat(drone_check, span_warning("[src] won't budge - its systems are locked out by an installed remote control receiver."))
		return FALSE
	return ..()
