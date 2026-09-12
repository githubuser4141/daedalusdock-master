#define GENERATOR_ON "on"
#define GENERATOR_OFF "off"
#define GENERATOR_BROKEN "broken"

/**
 * A house-scale power source that feeds real cables, not a direct object link - wire it to an
 * /obj/machinery/power/apc/ms13's terminal (mojave/code/modules/power/apc_ms13.dm) like any other
 * generator, and that APC draws power from the grid completely normally. Mappers set
 * generator_state per-instance (on/off/broken) to decide whether a given house's generator is
 * currently working. The sprite only has the one "running" frame, so off/broken are conveyed with
 * color tinting instead of separate icon_states.
 *
 * fusion_generator is /obj/machinery/ms13, not /obj/machinery/power (renaming it would orphan every
 * existing map placement - it's already used across Mammoth/Drought/Mammoth_Mini), so the handful
 * of powernet procs it needs (connect_to_network/disconnect_from_network/add_avail) are copied
 * directly from code/modules/power/power.dm rather than inherited - same "can't multiple-inherit,
 * so copy the few procs actually needed" workaround already used elsewhere in this codebase
 * (see /turf/closed/mineral/Initialize()'s own comment about this).
 */
/obj/machinery/ms13/fusion_generator
	name = "fusion generator"
	desc = "A generator that runs on fusion cells. Can power an entire neighborhood by itself! The fusion cell seems to be jammed in hard, but it remains running for now."
	icon = 'mojave/icons/structure/64x64_machinery.dmi'
	icon_state = "generator_on"
	anchored = TRUE
	density = TRUE
	max_integrity = 5000
	flags_1 = INDESTRUCTIBLE
	use_power = NO_POWER_USE
	/// Mapper-set starting state. Set this per-instance in the map editor to decide whether a
	/// given house's generator is working, switched off, or broken down.
	var/generator_state = GENERATOR_ON
	/// Wattage added to the powernet each tick while generator_state is "on".
	var/power_gen = 5000
	var/datum/powernet/powernet

/obj/machinery/ms13/fusion_generator/Initialize(mapload)
	. = ..()
	connect_to_network()
	update_appearance()

/obj/machinery/ms13/fusion_generator/Destroy()
	disconnect_from_network()
	return ..()

/obj/machinery/ms13/fusion_generator/process(seconds_per_tick)
	if(generator_state == GENERATOR_ON)
		add_avail(power_gen)

/obj/machinery/ms13/fusion_generator/proc/connect_to_network()
	var/turf/generator_turf = loc
	if(!istype(generator_turf))
		return FALSE
	var/obj/structure/cable/node = generator_turf.get_cable_node()
	if(!node || !node.powernet)
		var/obj/machinery/power/terminal/term = locate(/obj/machinery/power/terminal) in generator_turf
		if(!term || !term.powernet)
			return FALSE
		term.powernet.add_machine(src)
		return TRUE
	node.powernet.add_machine(src)
	return TRUE

/obj/machinery/ms13/fusion_generator/proc/disconnect_from_network()
	if(!powernet)
		return FALSE
	powernet.remove_machine(src)
	return TRUE

/obj/machinery/ms13/fusion_generator/proc/add_avail(amount)
	if(!powernet)
		return FALSE
	powernet.newavail += amount
	return TRUE

/obj/machinery/ms13/fusion_generator/update_icon_state()
	. = ..()
	switch(generator_state)
		if(GENERATOR_ON)
			color = null
		if(GENERATOR_OFF)
			color = "#606060"
		if(GENERATOR_BROKEN)
			color = "#4a3030"

/obj/machinery/ms13/fusion_generator/proc/set_generator_state(new_state)
	if(generator_state == new_state)
		return
	generator_state = new_state
	update_appearance()
	if(generator_state == GENERATOR_BROKEN)
		do_sparks(2, FALSE, src)

/obj/machinery/ms13/fusion_generator/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	if(generator_state == GENERATOR_BROKEN)
		to_chat(user, span_warning("[src] is broken down and needs repairs before it'll run."))
		return
	set_generator_state(generator_state == GENERATOR_ON ? GENERATOR_OFF : GENERATOR_ON)
	to_chat(user, span_notice("You switch [src] [generator_state == GENERATOR_ON ? "on" : "off"]."))
	playsound(src, 'sound/machines/lightswitch.ogg', 50, TRUE)

/obj/machinery/ms13/fusion_generator/welder_act(mob/living/user, obj/item/tool)
	if(generator_state != GENERATOR_BROKEN)
		to_chat(user, span_notice("[src] doesn't need repairs."))
		return TRUE
	if(!tool.use_tool(src, user, 5 SECONDS, volume = 50))
		return TRUE
	user.visible_message(span_notice("[user] repairs [src]."), span_notice("You repair [src]."))
	set_generator_state(GENERATOR_OFF) // repaired, but still needs to be switched on manually
	return TRUE

#undef GENERATOR_ON
#undef GENERATOR_OFF
#undef GENERATOR_BROKEN

/obj/machinery/ms13/substation
	name = "power substation"
	desc = "A power distribution node. It helps store and redirect power through the networks... You think."
	icon = 'mojave/icons/structure/32x48_machinery.dmi'
	icon_state = "substation"
	anchored = TRUE
	density = TRUE
	max_integrity = 5000
	flags_1 = INDESTRUCTIBLE
	var/zap_flags = ZAP_MOB_DAMAGE | ZAP_MOB_STUN

/obj/machinery/ms13/substation/Bump(atom/movable/bumped_atom)
	. = ..()
	tesla_zap(src, 3, 100, zap_flags)

/obj/machinery/ms13/substation/take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	. = ..()
	do_sparks(1, FALSE, src)
	tesla_zap(src, 5, 200, zap_flags)

/obj/machinery/ms13/substation/rusty
	icon_state = "substation_rust"
	anchored = TRUE

/obj/machinery/ms13/substation/discharge
	name = "substation capacitor unit"
	desc = "A large capacitor, it stores energy for rapid use. Has a tendency to discharge when overclocked, be wary."
	icon_state = "generator"

/obj/machinery/ms13/substation/discharge/rusty
	icon_state = "generator_rust"
