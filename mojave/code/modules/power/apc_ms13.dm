//MOJAVE SUN UTILITY BOX - an old-style fusebox standing in for a real APC.
//No electronics lock, no backup cell - just a breaker and a cover, wired to real cables/generators
//like any other power machine (mojave/machinery/generators.dm's fusion_generator), plus
//(obj_defines.dm) an optional physical padlock like any other MS13 door.

/obj/machinery/power/apc/ms13
	name = "utility box"
	desc = "A crude, unshielded fusebox wired straight to whatever's feeding it. No fancy electronics, no backup cell - just a breaker and a cover."
	cell_type = null // no cell is ever installed - see process() below for what that changes
	locked = FALSE
	coverlocked = FALSE
	req_access = null
	ms13_flags_1 = LOCKABLE_1
	can_have_lock = TRUE
	/// Runs off pre-war grid power that somehow still works: powered with nothing wired to it.
	var/always_powered = FALSE
	/// Browned out: held off until then, rather than blinking on and off every tick while the line is short.
	var/brownout_until = 0
	/// Already took a surge of plant voltage: its bulbs are gone, only the box itself is left to burn out.
	var/surged = FALSE

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/power/apc/ms13, APC_PIXEL_OFFSET)

// Old fuseboxes don't have an ID scanner to swipe in the first place.
/obj/machinery/power/apc/ms13/togglelock(mob/living/user)
	to_chat(user, span_notice("[src] has no electronic lock to toggle - it's just a breaker box."))
	locked = FALSE

/obj/machinery/power/apc/ms13/ui_data(mob/user)
	. = ..()
	.["utilityBox"] = TRUE

/// The base APC refuses every non-off channel setting when no cell is installed.
/obj/machinery/power/apc/ms13/setsubsystem(val)
	switch(val)
		if(1)
			return APC_CHANNEL_OFF
		if(2)
			return APC_CHANNEL_ON
		if(3)
			return has_incoming_power() ? APC_CHANNEL_AUTO_ON : APC_CHANNEL_AUTO_OFF
	return APC_CHANNEL_OFF

/**
 * Replaces the base APC's cell-charge simulation entirely - this box has no cell to manage, so
 * there's nothing to draw down, recharge, or run low on. Channels are just on or off depending on
 * has_incoming_power(), same three checks (broken/maint, unpowered area, EMP failure timer) the
 * base process() bails out on first.
 */
/obj/machinery/power/apc/ms13/process(seconds_per_tick)
	if(icon_update_needed)
		update_appearance()
	if(machine_stat & (BROKEN|MAINT))
		return
	if(!area || !area.requires_power)
		return
	if(failure_timer)
		failure_timer--
		force_update = TRUE
		return
	if(!always_powered && terminal?.powernet && suffer_grid(terminal.powernet))
		return

	lastused_light = APC_CHANNEL_IS_ON(lighting) ? area.power_usage[AREA_USAGE_LIGHT] + area.power_usage[AREA_USAGE_STATIC_LIGHT] : 0
	lastused_equip = APC_CHANNEL_IS_ON(equipment) ? area.power_usage[AREA_USAGE_EQUIP] + area.power_usage[AREA_USAGE_STATIC_EQUIP] : 0
	lastused_environ = APC_CHANNEL_IS_ON(environ) ? area.power_usage[AREA_USAGE_ENVIRON] + area.power_usage[AREA_USAGE_STATIC_ENVIRON] : 0
	lastused_total = lastused_light + lastused_equip + lastused_environ
	area.clear_usage()

	var/last_lt = lighting
	var/last_eq = equipment
	var/last_en = environ
	var/last_main = main_status
	var/incoming_power = has_incoming_power()
	main_status = incoming_power ? APC_HAS_POWER : APC_NO_POWER

	if(operating && !shorted && incoming_power)
		add_load(lastused_total)
		equipment = autoset(equipment, AUTOSET_ON)
		lighting = autoset(lighting, AUTOSET_ON)
		environ = autoset(environ, AUTOSET_ON)
	else
		equipment = autoset(equipment, AUTOSET_FORCE_OFF)
		lighting = autoset(lighting, AUTOSET_FORCE_OFF)
		environ = autoset(environ, AUTOSET_FORCE_OFF)

	var/area_state_changed = area.power_light != (operating && !shorted && APC_CHANNEL_IS_ON(lighting)) \
		|| area.power_equip != (operating && !shorted && APC_CHANNEL_IS_ON(equipment)) \
		|| area.power_environ != (operating && !shorted && APC_CHANNEL_IS_ON(environ))
	if(last_lt != lighting || last_eq != equipment || last_en != environ || last_main != main_status || area_state_changed || force_update)
		force_update = FALSE
		queue_icon_update()
		update()

/// Is enough current reaching this box? Real wiring by default - fed by whatever's add_avail()-ing onto the powernet
/// its terminal is connected to (a fusion_generator or a substation). It needs enough to spare for its own draw, after
/// whatever else on the line drew first; short of that it browns out for a while.
/obj/machinery/power/apc/ms13/proc/has_incoming_power()
	if(always_powered)
		return TRUE
	if(world.time < brownout_until)
		return FALSE
	if(surplus() >= max(lastused_total, 1))
		return TRUE
	if(avail(0))
		brownout_until = world.time + 6 SECONDS
	return FALSE

/**
 * What the line does to a box on it (mojave/code/modules/power/grid.dm). Plant voltage blows its lights and can burn it
 * out; a rippling supply flickers them, and a bad ripple pops bulbs. TRUE if it burnt the box out.
 */
/obj/machinery/power/apc/ms13/proc/suffer_grid(datum/powernet/line)
	if(line.ms13_voltage >= MS13_VOLTAGE_HIGH)
		if(!surged)
			surged = TRUE
			visible_message(span_danger("[src] bangs and sparks as plant voltage surges through it!"))
			do_sparks(3, TRUE, src)
			INVOKE_ASYNC(src, PROC_REF(break_lights))
		if(prob(25))
			set_broken()
			return TRUE
		return FALSE
	surged = FALSE
	if(!line.ms13_ripple || !prob(line.ms13_ripple * 40))
		return FALSE
	for(var/obj/machinery/light/lamp as anything in INSTANCES_OF(/obj/machinery/light))
		if(get_area(lamp) != area)
			continue
		if(line.ms13_ripple > 0.3 && prob((line.ms13_ripple - 0.3) * 50))
			lamp.break_light_tube()
		else
			lamp.flicker()
	return FALSE

/// A fusebox that just works, with no generator or cabling.
/obj/machinery/power/apc/ms13/always_on
	always_powered = TRUE
