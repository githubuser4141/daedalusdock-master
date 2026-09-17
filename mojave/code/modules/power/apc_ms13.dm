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

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/power/apc/ms13, APC_PIXEL_OFFSET)

// Old fuseboxes don't have an ID scanner to swipe in the first place.
/obj/machinery/power/apc/ms13/togglelock(mob/living/user)
	to_chat(user, span_notice("[src] has no electronic lock to toggle - it's just a breaker box."))
	locked = FALSE

/**
 * Replaces the base APC's cell-charge simulation entirely - this box has no cell to manage, so
 * there's nothing to draw down, recharge, or run low on. Channels are just on or off depending on
 * has_incoming_power(), same three checks (broken/maint, unpowered area, EMP failure timer) the
 * base process() bails out on first.
 *
 * ponytail: doesn't add_load() anything, so this never registers as consumption/surplus for other
 * grid-connected machinery sharing the same powernet - fine for an isolated house circuit, would
 * need real load accounting to share a grid with other real consumers.
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

	var/last_lt = lighting
	var/last_eq = equipment
	var/last_en = environ

	if(operating && !shorted && has_incoming_power())
		main_status = APC_HAS_POWER
		equipment = autoset(equipment, AUTOSET_ON)
		lighting = autoset(lighting, AUTOSET_ON)
		environ = autoset(environ, AUTOSET_ON)
	else
		main_status = APC_NO_POWER
		equipment = autoset(equipment, AUTOSET_FORCE_OFF)
		lighting = autoset(lighting, AUTOSET_FORCE_OFF)
		environ = autoset(environ, AUTOSET_FORCE_OFF)

	if(last_lt != lighting || last_eq != equipment || last_en != environ || force_update)
		force_update = FALSE
		queue_icon_update()
		update()

/// Is real current currently reaching this box? Real wiring by default - fed by whatever's
/// add_avail()-ing onto the powernet its terminal is connected to (a fusion_generator, normally).
/obj/machinery/power/apc/ms13/proc/has_incoming_power()
	return always_powered || !!avail(0)

/// A fusebox that just works, with no generator or cabling.
/obj/machinery/power/apc/ms13/always_on
	always_powered = TRUE
