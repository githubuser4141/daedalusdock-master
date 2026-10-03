// Station services are optional on planetary maps. Check live docks so adding one enables them.
/datum/controller/subsystem/shuttle/canEvac(mob/user)
	if(!emergency || !getDock("emergency_home", silent = TRUE))
		return "This map has no available emergency shuttle landing dock."
	return ..()

/datum/controller/subsystem/shuttle/autoEvac()
	if(!emergency || !getDock("emergency_home", silent = TRUE))
		return
	return ..()

/datum/controller/subsystem/shuttle/CheckAutoEvac()
	if(!getDock("emergency_home", silent = TRUE))
		return
	return ..()

/datum/controller/subsystem/shuttle/autoEnd()
	if(!emergency || !getDock("emergency_home", silent = TRUE))
		return
	return ..()

/obj/docking_port/mobile/emergency/request(obj/docking_port/stationary/S, area/signalOrigin, reason, redAlert, set_coefficient = null, silent = FALSE)
	if(!SSshuttle.getDock("emergency_home", silent = TRUE))
		return
	return ..()

/obj/docking_port/mobile/emergency/check()
	if(mode == SHUTTLE_CALL && !SSshuttle.getDock("emergency_home", silent = TRUE))
		mode = SHUTTLE_IDLE
		timer = 0
		destination = null
		remove_ripples()
		log_shuttle("Emergency shuttle call cancelled: its landing dock is missing.")
		return
	return ..()

/datum/round_event_control/shuttle_catastrophe/canSpawnEvent(players)
	return SSshuttle.emergency && SSshuttle.getDock("emergency_home", silent = TRUE) && ..()

/datum/round_event_control/shuttle_insurance/canSpawnEvent(players)
	return SSshuttle.emergency && SSshuttle.getDock("emergency_home", silent = TRUE) && ..()

/datum/round_event_control/shuttle_loan/canSpawnEvent(players)
	return SSshuttle.supply && SSshuttle.getDock("supply_home", silent = TRUE) && ..()

/datum/round_event/shuttle_loan/loan_shuttle()
	if(!SSshuttle.supply || !SSshuttle.getDock("supply_home", silent = TRUE))
		return
	return ..()

#ifdef UNIT_TESTS
#include "shuttle_compat_tests.dm"
#endif
