/// The mount owns an ordinary terminal, keeping its documents, pairings and controls when removed.
/obj/structure/ms13_vehicle_part/terminal
	name = "vehicle terminal"
	desc = "A RobCo terminal fitted to the vehicle's electrical bus. Switch on the ignition to use it. A wrench removes the whole assembly."
	icon = 'mojave/icons/structure/terminals.dmi'
	icon_state = "terminal"
	pixel_y = 8
	layer = BELOW_OBJ_LAYER
	max_integrity = 100
	fits_itself = TRUE
	var/obj/machinery/ms13/terminal/vehicle/terminal
	var/squad_id = ""
	var/cryo_network = ""
	var/camera_network = ""
	/// Charge per second while powered.
	var/power_draw = 1

/obj/structure/ms13_vehicle_part/terminal/Initialize(mapload)
	. = ..()
	terminal = new(src)
	terminal.squad_id = squad_id
	terminal.cryo_network = cryo_network
	terminal.camera_network = camera_network

/obj/structure/ms13_vehicle_part/terminal/Destroy()
	QDEL_NULL(terminal)
	return ..()

/obj/structure/ms13_vehicle_part/terminal/configure_from_vehicle()
	power_changed()

/obj/structure/ms13_vehicle_part/terminal/detach()
	. = ..()
	power_changed()

/obj/structure/ms13_vehicle_part/terminal/atom_break(damage_flag)
	. = ..()
	power_changed()

/obj/structure/ms13_vehicle_part/terminal/atom_fix()
	. = ..()
	power_changed()

/obj/structure/ms13_vehicle_part/terminal/proc/power_changed()
	terminal?.power_change()
	update_appearance()

/obj/structure/ms13_vehicle_part/terminal/update_overlays()
	. = ..()
	if(terminal?.active && terminal.powered())
		. += mutable_appearance(icon, "terminal_screen")
		. += emissive_appearance(icon, "terminal_screen", alpha = 180)

/obj/structure/ms13_vehicle_part/terminal/IsContainedAtomAccessible(atom/contained, atom/movable/user)
	return contained == terminal

/obj/structure/ms13_vehicle_part/terminal/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	terminal?.power_change()
	terminal?.attack_hand(user, modifiers)
	return TRUE

/obj/structure/ms13_vehicle_part/terminal/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/ms13/bodycam))
		terminal?.power_change()
		return tool.interact_with_atom(terminal, user, modifiers)
	return ..()

/obj/machinery/ms13/terminal/vehicle
	name = "vehicle terminal"
	use_power = NO_POWER_USE
	flags_1 = NODECONSTRUCT_1
	remote_capability = TRUE
	riggable = FALSE

/obj/machinery/ms13/terminal/vehicle/powered(chan = power_channel, ignore_use_power = FALSE)
	var/obj/structure/ms13_vehicle_part/terminal/mount = loc
	return istype(mount) && mount.is_operational() && mount.vehicle?.has_electrical_power()

/obj/machinery/ms13/terminal/vehicle/terminal_available(mob/user)
	power_change()
	return ..()

/// Existing terminal peripherals measure reach from the physical mount.
/obj/machinery/ms13/terminal/vehicle/Adjacent(atom/neighbor, atom/target, atom/movable/mover)
	return loc?.Adjacent(neighbor, target, mover)

/obj/item/ms13_vehicle_part_kit/terminal
	part_type = /obj/structure/ms13_vehicle_part/terminal

/datum/crafting_recipe/ms13_vehicle_terminal
	name = "vehicle terminal"
	result = /obj/item/ms13_vehicle_part_kit/terminal
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 3, /obj/item/stack/sheet/ms13/scrap_electronics = 4, /obj/item/stack/sheet/ms13/glass = 2, /obj/item/stack/sheet/ms13/plastic = 2)
	category = CAT_VEHICLES
	crafting_interface = CRAFTING_BENCH_ELECTRIC

#include "vehicle_terminal_tests.dm"
