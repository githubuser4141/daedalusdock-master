/area/shuttle_runtime_test
	requires_power = FALSE

/datum/unit_test/ms13_cargo_destinations/Run()
	var/list/original_areas = GLOB.the_station_areas
	GLOB.the_station_areas = list()
	var/datum/round_event/stray_cargo/event = new(FALSE)
	if(event.impact_area || (event in SSevents.running))
		Fail("Cargo event without a station destination remained scheduled.")
	event.announce(FALSE)
	event.start()
	qdel(event)
	var/datum/round_event_control/stray_cargo/control = new
	if(control.canSpawnEvent(100))
		Fail("Cargo event was eligible on a map without station areas.")
	qdel(control)
	var/turf/site = run_loc_floor_bottom_left
	var/area/original_area = get_area(site)
	var/area/shuttle_runtime_test/landing_area = new
	site.change_area(original_area, landing_area)
	GLOB.the_station_areas = list(landing_area.type)
	event = new(FALSE)
	if(event.impact_area != landing_area)
		Fail("Cargo event did not recover when a valid area became available.")
	// The landing floor can disappear during the announcement delay.
	site = site.ChangeTurf(/turf/closed/wall)
	event.start()
	if(locate(/obj/effect/pod_landingzone) in site)
		Fail("Cargo was sent into a newly built wall.")
	site = site.ChangeTurf(/turf/open/floor/plating)
	event.possible_pack_types = list(/datum/supply_pack/engineering/tools)
	event.start()
	var/obj/effect/pod_landingzone/zone = locate() in site
	if(!zone?.pod)
		Fail("Cargo did not resume delivering after its floor was restored.")
	else
		var/obj/structure/closet/supplypod/pod = zone.pod
		if(!(locate(/obj/structure/closet/crate) in pod))
			Fail("Cargo pod arrived without its generated supply crate.")
		zone.beginLaunch(FALSE)
		if(get_turf(pod) != site)
			Fail("Native cargo launch did not reach its valid destination.")
		qdel(zone.helper)
		qdel(zone)
		qdel(pod)
	event.kill()
	qdel(event)
	site.change_area(landing_area, original_area)
	qdel(landing_area)
	GLOB.the_station_areas = original_areas

/datum/unit_test/ms13_shuttle_destinations/Run()
	var/list/original_docks = SSshuttle.stationary_docking_ports
	var/obj/docking_port/mobile/emergency/original_shuttle = SSshuttle.emergency
	var/obj/docking_port/mobile/emergency/shuttle = new(run_loc_floor_bottom_left)
	SSshuttle.emergency = shuttle
	SSshuttle.stationary_docking_ports = list()
	if(SSshuttle.canEvac(null) == TRUE)
		Fail("Evacuation accepted a missing home dock.")
	var/old_endvote = SSshuttle.endvote_passed
	SSshuttle.autoEvac()
	SSshuttle.CheckAutoEvac()
	SSshuttle.autoEnd()
	if(SSshuttle.endvote_passed != old_endvote)
		Fail("Automatic transfer reported a shuttle call without a landing dock.")
	shuttle.request(silent = TRUE)
	if(shuttle.mode != SHUTTLE_IDLE || shuttle.timer)
		Fail("A direct shuttle request started without a destination.")
	shuttle.mode = SHUTTLE_CALL
	shuttle.setTimer(1)
	shuttle.check()
	if(shuttle.mode != SHUTTLE_IDLE || shuttle.timer)
		Fail("An orphaned shuttle call kept retrying its missing dock.")
	if(shuttle.Dock(null, force = TRUE) != DOCKING_BLOCKED || length(shuttle.ripple_area(null)))
		Fail("Missing docks passed the shared docking or ripple API.")
	var/datum/round_event_control/shuttle_catastrophe/catastrophe = new
	if(catastrophe.canSpawnEvent(100))
		Fail("Shuttle catastrophe remained eligible without a landing dock.")
	qdel(catastrophe)
	var/obj/docking_port/stationary/home = new(run_loc_floor_bottom_left)
	home.id = "emergency_home"
	shuttle.request(silent = TRUE)
	if(shuttle.mode != SHUTTLE_CALL || !shuttle.timer)
		Fail("Shuttle could not be called after restoring its home dock.")
	shuttle.setTimer(0)
	shuttle.check()
	if(shuttle.mode != SHUTTLE_DOCKED)
		Fail("Shuttle did not complete docking after destination recovery.")
	qdel(home, TRUE)
	SSshuttle.emergency = original_shuttle
	SSshuttle.stationary_docking_ports = original_docks
	shuttle.registered = TRUE // Mobile test ports are not template-registered.
	qdel(shuttle, TRUE)
