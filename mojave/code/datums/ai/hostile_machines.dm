/// Turrets and mechs, the only machines mob AI treats as targets. Tracked here so target searches don't
/// have to scan every atom in range() just to find the handful that exist.
GLOBAL_LIST_EMPTY(ai_hostile_machines)

/obj/machinery/porta_turret/Initialize(mapload)
	. = ..()
	GLOB.ai_hostile_machines += src

/obj/machinery/porta_turret/Destroy()
	GLOB.ai_hostile_machines -= src
	return ..()

/obj/vehicle/sealed/mecha/Initialize(mapload)
	. = ..()
	GLOB.ai_hostile_machines += src

/obj/vehicle/sealed/mecha/Destroy()
	GLOB.ai_hostile_machines -= src
	return ..()

/// Hostile machines within range that viewer can see.
/proc/visible_hostile_machines(atom/viewer, range)
	. = list()
	for(var/atom/machine as anything in GLOB.ai_hostile_machines)
		if(machine.z == viewer.z && get_dist(viewer, machine) <= range && can_see(viewer, machine, range))
			. += machine
