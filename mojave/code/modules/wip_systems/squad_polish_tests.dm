// Included only by squad_npcs_tests.dm in UNIT_TESTS builds.
/datum/unit_test/ms13_squad_movement_cleanup/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	for(var/path_type in list(/datum/move_loop/has_target/jps, /datum/move_loop/has_target/astar))
		var/obj/item/wrench/mover = allocate(/obj/item/wrench, site)
		for(var/cancel in list(TRUE, FALSE))
			var/turf/destination = get_step(mover, EAST)
			var/datum/move_loop/route = SSmove_manager.add_to_loop(mover, SSmovement, path_type, MOVEMENT_DEFAULT_PRIORITY, NONE, null, 1, INFINITY, destination, 0.5 SECONDS, 30, 0, null, TRUE, null, TRUE, list(destination))
			if(cancel)
				RegisterSignal(mover, COMSIG_MOVABLE_MOVED, PROC_REF(cancel_route))
			route.process()
			SQUAD_ASSERT_EQUAL(get_turf(mover), destination, "[path_type] failed to move before or after route cancellation")
			if(cancel)
				SQUAD_ASSERT(QDELETED(route) && !mover.move_packet, "Cancelled route retained its movement packet")
				UnregisterSignal(mover, COMSIG_MOVABLE_MOVED)
			else
				qdel(route)

/datum/unit_test/ms13_squad_movement_cleanup/proc/cancel_route(atom/movable/mover)
	SIGNAL_HANDLER
	SSmove_manager.stop_looping(mover)

/datum/unit_test/ms13_squad_recruit_recovery/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, site)
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human, site)
	var/mob/living/carbon/human/ms13_squad/leader = allocate(/mob/living/carbon/human/ms13_squad, get_step(site, EAST))
	leader.ai_controller.set_ai_status(AI_STATUS_OFF)
	leader.squad_id = "Leaderless mapped squad"
	SQUAD_ASSERT_EQUAL(leader.recruit(user), leader, "An assigned squad without a leader could not be recruited")
	leader.open_commands(user)
	var/datum/action/cooldown/ms13_squad_command/old_action = leader.command_action.resolve()
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, get_step(site, NORTH))
	unit.ai_controller.set_ai_status(AI_STATUS_OFF)
	unit.squad_id = leader.squad_id
	unit.is_squad_leader = TRUE
	SQUAD_ASSERT(!unit.claim_command(stranger), "A duplicate mapper leader allowed a second commander to steal squad members")
	unit.is_squad_leader = FALSE
	leader.death()
	SQUAD_ASSERT(!unit.recruit(stranger), "Losing the NPC leader let a stranger steal a living commander's squad")
	SQUAD_ASSERT_EQUAL(unit.recruit(user), unit, "The commander could not appoint a surviving recruit after losing the leader")
	SQUAD_ASSERT(QDELETED(old_action), "Succession left the dead leader's command action attached")
	leader.revive(TRUE, TRUE)
	SQUAD_ASSERT_EQUAL(leader.squad_leader(), unit, "Reviving the old leader displaced the replacement")
	SQUAD_ASSERT(unit.issue_order(user, "Hold"), "Replacement leader could not relay orders")
	SQUAD_ASSERT_EQUAL(leader.squad_order, "Hold", "Revived former leader no longer obeyed its squad")

/datum/unit_test/ms13_squad_selection/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, site)
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, site)
	unit.ai_controller.set_ai_status(AI_STATUS_OFF)
	SQUAD_ASSERT(unit.claim_command(user), "Could not claim selection test recruit")
	unit.open_commands(user)
	var/datum/action/cooldown/ms13_squad_command/action = unit.command_action.resolve()
	world.push_usr(user, CALLBACK(action, "Topic", "", list("unit" = REF(unit))))
	world.push_usr(user, CALLBACK(action, "Topic", "", list("unit" = REF(user))))
	SQUAD_ASSERT_EQUAL(action.selected_ref?.resolve(), unit, "Invalid unit selection silently became an order to the entire squad")
	world.push_usr(user, CALLBACK(action, "Topic", "", list("order" = "Pick up")))
	SQUAD_ASSERT_EQUAL(user.click_intercept, action, "Pick-up designation did not arm")
	world.push_usr(user, CALLBACK(action, "Topic", "", list("unit" = "all")))
	SQUAD_ASSERT(!user.click_intercept, "Changing the recipient left the old designation armed")
	SQUAD_ASSERT(!action.selected_ref, "Explicit entire-squad selection failed")

/datum/unit_test/ms13_squad_delivery/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/turf/destination = get_step(site, EAST)
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, site)
	var/obj/item/wrench/item = allocate(/obj/item/wrench, site)
	unit.put_in_hands(item)
	unit.cargo = WEAKREF(item)
	unit.set_order("Deliver", destination)
	unit.act_on_order()
	SQUAD_ASSERT(item in unit.held_items, "Delivery dropped cargo one tile short of its destination")
	var/deadline = world.time + 15 SECONDS
	while(item.loc == unit && world.time < deadline)
		unit.ai_controller.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT_EQUAL(item.loc, destination, "Delivery failed to put cargo on the designated tile")
	SQUAD_ASSERT(!unit.cargo && unit.squad_order == "Guard", "Delivery did not release its cargo and resume guarding")
	unit.next_move = 0
	unit.set_order("Deliver", site)
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(unit.order_status, "No carried item to deliver", "Empty-handed delivery falsely reported success")
	unit.pickup_item(item)
	unit.cargo = WEAKREF(item)
	ADD_TRAIT(item, TRAIT_NODROP, TRAIT_GENERIC)
	unit.next_move = 0
	unit.set_order("Deliver", destination)
	unit.act_on_order()
	SQUAD_ASSERT(item in unit.held_items, "Delivery bypassed an item's no-drop restriction")
	SQUAD_ASSERT_EQUAL(unit.order_status, "Cannot release cargo", "Failed drop falsely reported a completed delivery")
	REMOVE_TRAIT(item, TRAIT_NODROP, TRAIT_GENERIC)
	unit.dropItemToGround(item)
	var/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm/gun = allocate(/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm, destination)
	unit.pickup_item(gun)
	unit.service_weapon = WEAKREF(gun)
	unit.cargo = WEAKREF(gun)
	unit.next_move = 0
	unit.set_order("Deliver", destination)
	unit.act_on_order()
	unit.next_move = 0
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(gun.loc, destination, "Automatic weapon recovery undid an explicit delivery order")

/datum/unit_test/ms13_squad_reload/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/ms13_squad/sidearm/unit = allocate(/mob/living/carbon/human/ms13_squad/sidearm, site)
	unit.ai_controller.set_ai_status(AI_STATUS_OFF)
	unit.see_in_dark = 8
	var/obj/item/gun/ballistic/gun = unit.service_weapon.resolve()
	// Empty the original magazine without touching the supplied spares.
	QDEL_NULL(gun.chambered)
	while(gun.magazine.ammo_count())
		qdel(gun.magazine.get_round())
	var/obj/item/ammo_box/magazine/empty = gun.magazine
	var/obj/item/ammo_box/magazine/spare = locate() in unit.back.contents
	var/rounds = spare.ammo_count()
	unit.back.atom_storage.locked = TRUE
	unit.set_order("Fire at area", get_ranged_target_turf(site, EAST, 4))
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(gun.magazine, empty, "Reload bypassed locked storage")
	SQUAD_ASSERT_EQUAL(spare.loc, unit.back, "Failed reload took ammunition out of locked storage")
	unit.back.atom_storage.locked = FALSE
	unit.next_move = 0
	unit.act_on_order()
	SQUAD_ASSERT(gun.magazine == spare && gun.can_fire(), "NPC ignored compatible spare magazines or failed to chamber a round")
	SQUAD_ASSERT_EQUAL(empty.loc, site, "Reload deleted the empty magazine or left it inside the firearm")
	SQUAD_ASSERT_EQUAL(gun.get_ammo(), rounds, "Reload created or lost live ammunition")
	unit.next_move = 0
	unit.next_click = 0
	unit.act_on_order()
	SQUAD_ASSERT(gun.get_ammo() < rounds, "NPC did not resume firing after reloading")
	gun.is_jammed = TRUE
	unit.next_move = 0
	unit.act_on_order()
	SQUAD_ASSERT(!gun.is_jammed && gun.can_fire(), "NPC did not clear its jam through the normal timed gun interaction")

/datum/unit_test/ms13_squad_blocked_stairs/Run()
	var/datum/space_level/lower = SSmapping.add_new_zlevel("Blocked squad stairs lower", list(ZTRAIT_UP = 1))
	var/datum/space_level/upper = SSmapping.add_new_zlevel("Blocked squad stairs upper", list(ZTRAIT_DOWN = -1))
	SSzcopy.calculate_zstack_limits()
	var/area/test_area = get_area(run_loc_floor_bottom_left)
	for(var/z in list(lower.z_value, upper.z_value))
		for(var/turf/site in block(locate(15, 15, z), locate(25, 25, z)))
			site = site.ChangeTurf(/turf/open/floor/plating)
			site.change_area(site.loc, test_area)
	var/obj/structure/stairs/blocked = allocate(/obj/structure/stairs/north, locate(18, 20, lower.z_value))
	var/obj/structure/stairs/clear = allocate(/obj/structure/stairs/north, locate(22, 20, lower.z_value))
	var/turf/opening = GetAbove(clear)
	opening.ChangeTurf(/turf/open/openspace)
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, locate(18, 18, lower.z_value))
	SQUAD_ASSERT(unit.has_gravity(), "Stair routing fixture has no gravity for walking")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, locate(22, 24, upper.z_value))
	var/datum/ai_controller/ms13_squad/brain = unit.ai_controller
	brain.set_ai_status(AI_STATUS_OFF)
	unit.set_order("Follow", user)
	brain.approach_stairs(user)
	SQUAD_ASSERT(brain.route_stairs != blocked, "Follower selected stairs sealed by an upper floor")
	var/deadline = world.time + 20 SECONDS
	while(unit.z != user.z && world.time < deadline)
		brain.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT_EQUAL(unit.z, user.z, "Follower did not take the usable alternative staircase: [unit.order_status], at [unit.x],[unit.y],[unit.z], stat [unit.stat], route [brain.route_stairs]")
	// Obstruct a cached route, then require a newly opened staircase to take over.
	unit.forceMove(locate(22, 18, lower.z_value))
	brain.route_stairs = clear
	var/obj/structure/closet/crate/blocker = allocate(/obj/structure/closet/crate, get_step_multiz(clear, NORTH | UP))
	opening = GetAbove(blocked)
	opening.ChangeTurf(/turf/open/openspace)
	brain.next_stair_search = 0
	deadline = world.time + 20 SECONDS
	while(unit.z != user.z && world.time < deadline)
		brain.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT_EQUAL(unit.z, user.z, "Follower kept retrying a blocked cached landing instead of rerouting")
	SQUAD_ASSERT(blocker.density, "Stair navigation bypassed the landing obstacle")
	qdel(blocker)
	allocate(/obj/structure/closet/crate, get_step_multiz(blocked, NORTH | UP))
	// Three closer, enclosed stair entries must not starve the fourth usable route.
	for(var/x in list(17, 19, 21))
		var/obj/structure/stairs/enclosed = allocate(/obj/structure/stairs/south, locate(x, 18, lower.z_value))
		opening = GetAbove(enclosed)
		opening.ChangeTurf(/turf/open/openspace)
		for(var/direction in GLOB.cardinals)
			allocate(/obj/structure/closet/crate, get_step(enclosed, direction))
	unit.forceMove(locate(18, 16, lower.z_value))
	unit.set_order("Follow", user)
	brain.approach_stairs(user)
	SQUAD_ASSERT_EQUAL(brain.route_stairs, clear, "Three unreachable stairs hid a fourth reachable staircase")
	deadline = world.time + 20 SECONDS
	while(unit.z != user.z && world.time < deadline)
		brain.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT_EQUAL(unit.z, user.z, "Follower did not use the fourth route after rejecting inaccessible stairs")

/datum/unit_test/ms13_squad_polish/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/ms13_squad/sidearm/unit = allocate(/mob/living/carbon/human/ms13_squad/sidearm, site)
	unit.ai_controller.set_ai_status(AI_STATUS_OFF)
	unit.see_in_dark = 8
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, site)
	user.see_in_dark = 8
	SQUAD_ASSERT(unit.claim_command(user), "Could not claim test recruit")
	unit.open_commands(user)
	var/datum/action/cooldown/ms13_squad_command/action = unit.command_action.resolve()
	world.push_usr(user, CALLBACK(action, "Topic", "", list("unit" = REF(unit))))
	world.push_usr(user, CALLBACK(action, "Topic", "", list("order" = "Pick up")))
	var/obj/item/wrench/item = allocate(/obj/item/wrench, get_step(site, EAST))
	SQUAD_ASSERT(user.click_intercept == action, "Pick-up mode did not arm")
	action.InterceptClickOn(user, "left=1", item)
	SQUAD_ASSERT(!user.click_intercept, "Accepted designation retained the click interceptor")
	SQUAD_ASSERT_EQUAL(unit.order_target?.resolve(), item, "Selected recruit rejected a visible ground item")
	unit.act_on_order()
	SQUAD_ASSERT(item in unit.held_items, "Designated pick-up did not acquire the item")
	unit.dropItemToGround(item)
	action.set_click_ability(user)
	var/atom/movable/screen/movable/action_button/button = allocate(/atom/movable/screen/movable/action_button)
	action.InterceptClickOn(user, "left=1", button)
	SQUAD_ASSERT(!user.click_intercept, "HUD click left designation stuck")
	var/obj/machinery/ms13/terminal/terminal = allocate(/obj/machinery/ms13/terminal, get_step(site, NORTH))
	terminal.squad_id = unit.squad_id
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	action.terminal_ref = WEAKREF(terminal)
	action.set_click_ability(user)
	user.forceMove(run_loc_floor_top_right)
	action.process()
	SQUAD_ASSERT(!user.click_intercept, "Walking away from the terminal retained command mode")
	user.forceMove(site)
	action.Trigger()
	SQUAD_ASSERT(!action.terminal_ref && action.IsAvailable(), "HUD command did not recover after terminal use")
	var/obj/item/gun/ballistic/gun = unit.service_weapon.resolve()
	unit.dropItemToGround(gun)
	unit.next_move = 0
	unit.set_order("Guard", site)
	unit.act_on_order()
	SQUAD_ASSERT(gun in unit.held_items, "Recruit did not recover its dropped firearm")
	var/mob/living/basic/ms13/raider/enemy = allocate(/mob/living/basic/ms13/raider, get_ranged_target_turf(site, EAST, 4))
	enemy.ai_controller.set_ai_status(AI_STATUS_OFF)
	user.forceMove(get_step(site, NORTH))
	unit.next_move = 0
	unit.next_click = 0
	unit.next_enemy_scan = 0
	unit.threat = null
	var/ammo = gun.get_ammo()
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(unit.threat?.resolve(), enemy, "Guard did not acquire a hostile on its own")
	SQUAD_ASSERT(gun.get_ammo() < ammo, "Automatic hostile engagement did not shoot")
	qdel(enemy)
	unit.threat = null
	var/obj/item/flashlight/light = locate() in unit.contents
	light.on = FALSE
	var/old_lumcount = site.dynamic_lumcount
	if(!site.lighting_object)
		site.lighting_build_overlay()
	site.dynamic_lumcount = -1000
	unit.next_move = 0
	unit.act_on_order()
	site.dynamic_lumcount = old_lumcount
	SQUAD_ASSERT(light.on, "Recruit left its flashlight off in darkness")
	var/obj/structure/railing/ms13/rail = allocate(/obj/structure/railing/ms13, site)
	rail.setDir(EAST)
	var/turf/destination = get_step(site, EAST)
	var/list/path = astar_path_to(unit, destination, max_steps = 60, mintargetdist = 0, use_diagonals = FALSE)
	SQUAD_ASSERT(length(path) > 1, "A* failed to route around a border guardrail")
	for(var/turf/step as anything in path)
		if(step == get_turf(unit))
			continue
		SQUAD_ASSERT(unit.Move(step, get_dir(unit, step)), "A* produced an impassable guardrail step")
	SQUAD_ASSERT_EQUAL(get_turf(unit), destination, "Guardrail route stopped short of the target")
	var/list/panel = terminal.ui_data(user)
	SQUAD_ASSERT(panel["command"] && length(panel["recruits"]), "Terminal omitted its embedded squad controls")
	var/obj/item/ms13/bodycam/camera = allocate(/obj/item/ms13/bodycam, site)
	var/icon/camera_icon = icon(camera.icon, camera.icon_state, SOUTH)
	var/visible_pixel = FALSE
	for(var/x in 1 to camera_icon.Width())
		for(var/y in 1 to camera_icon.Height())
			if(camera_icon.GetPixel(x, y))
				visible_pixel = TRUE
	SQUAD_ASSERT(visible_pixel, "Bodycam's actual native icon frame is empty")

/datum/unit_test/ms13_squad_pursuit/Run()
	var/turf/site = locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/ms13_squad/sidearm/unit = allocate(/mob/living/carbon/human/ms13_squad/sidearm, site)
	unit.see_in_dark = 8
	var/obj/item/gun/ballistic/gun = unit.service_weapon.resolve()
	var/mob/living/carbon/human/enemy = allocate(/mob/living/carbon/human, get_ranged_target_turf(site, EAST, 4))
	for(var/dy in -1 to 1)
		var/obj/structure/closet/crate/cover = allocate(/obj/structure/closet/crate, locate(site.x + 2, site.y + dy, site.z))
		cover.set_opacity(TRUE)
	SQUAD_ASSERT(isfloorturf(get_turf(enemy)), "Pursuit target must be inside the test room")
	SQUAD_ASSERT(length(astar_path_to(unit, enemy, max_steps = 60, mintargetdist = 0, use_diagonals = FALSE)), "Pursuit fixture has no route around cover")
	SQUAD_ASSERT(!unit.safe_shot(enemy), "Pursuit fixture did not obstruct the firing lane")
	unit.set_order("Attack", enemy)
	var/ammo = gun.get_ammo()
	var/deadline = world.time + 20 SECONDS
	while(gun.get_ammo() == ammo && world.time < deadline)
		unit.ai_controller.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT(gun.get_ammo() < ammo, "NPC did not move around cover and resume firing: [unit.order_status], position [unit.x],[unit.y], quality [ms13_shot_quality(unit, enemy)], visible [get_turf(enemy) in view(7, unit)]")
	qdel(enemy)
	unit.next_move = 0
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(unit.squad_order, "Guard", "Lost target left combat stuck")
	unit.dropItemToGround(gun)
	gun.forceMove(site)
	unit.weapon_recovery_deadline = world.time - 1
	unit.next_move = 0
	unit.set_order("Move", get_step(get_turf(unit), NORTH))
	unit.act_on_order()
	SQUAD_ASSERT(unit.next_weapon_recovery > world.time, "Failed weapon recovery did not yield to the outstanding order")

/datum/unit_test/ms13_squad_stairs/Run()
	var/datum/space_level/lower = SSmapping.add_new_zlevel("Squad stair lower", list(ZTRAIT_UP = 1))
	var/datum/space_level/upper = SSmapping.add_new_zlevel("Squad stair upper", list(ZTRAIT_DOWN = -1))
	SSzcopy.calculate_zstack_limits()
	var/area/test_area = get_area(run_loc_floor_bottom_left)
	for(var/z in list(lower.z_value, upper.z_value))
		for(var/turf/site in block(locate(15, 15, z), locate(25, 25, z)))
			site = site.ChangeTurf(/turf/open/floor/plating)
			site.change_area(site.loc, test_area)
	var/turf/bottom = locate(20, 20, lower.z_value)
	var/turf/opening = GetAbove(bottom)
	opening.ChangeTurf(/turf/open/openspace)
	allocate(/obj/structure/stairs/north, bottom)
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, get_step(bottom, SOUTH))
	var/mob/living/carbon/human/leader = allocate(/mob/living/carbon/human, locate(20, 24, upper.z_value))
	unit.set_order("Follow", leader)
	var/deadline = world.time + 20 SECONDS
	while(unit.z != leader.z && world.time < deadline)
		unit.ai_controller.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT_EQUAL(unit.z, leader.z, "Follower could not ascend the real stairs")
	leader.forceMove(get_step(bottom, SOUTH))
	deadline = world.time + 20 SECONDS
	while(unit.z != leader.z && world.time < deadline)
		unit.ai_controller.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT_EQUAL(unit.z, leader.z, "Follower could not descend the real stairs: [unit.order_status], at [unit.x],[unit.y],[unit.z], gravity [unit.has_gravity()]")

/datum/unit_test/ms13_heal_bleeding/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/item/bodypart/limb = patient.get_bodypart(BODY_ZONE_L_ARM)
	limb.receive_damage(40, 0, sharpness = SHARP_EDGED)
	limb.set_sever_artery(TRUE)
	limb.setBleedStacks(5)
	limb.local_blood_volume = 0
	SQUAD_ASSERT(limb.cached_bleed_rate > 0, "Bleeding fixture did not bleed")
	patient.death()
	patient.revive(TRUE, TRUE)
	SQUAD_ASSERT_EQUAL(limb.cached_bleed_rate, 0, "Admin heal retained active bleeding")
	limb.refresh_bleed_rate()
	SQUAD_ASSERT_EQUAL(limb.cached_bleed_rate, 0, "Healed bleeding returned on cache refresh")
	SQUAD_ASSERT_EQUAL(limb.local_blood_volume, limb.local_blood_volume_max, "Heal did not refill local blood")

/datum/unit_test/ms13_hive_mined_frontier/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/datum/ms13_terrain_hivemind/necromorph/network = new
	allocated += network
	network.active = TRUE
	network.resources = 100
	var/obj/structure/ms13_hivemind/terrain/growth = allocate(/obj/structure/ms13_hivemind/terrain, site, network)
	var/turf/rock = get_step(site, EAST)
	var/old_type = rock.type
	rock = rock.ChangeTurf(/turf/closed/mineral/random/ms13)
	network.frontier -= growth
	// An unrelated live frontier must not prevent this depleted edge from reopening.
	var/obj/structure/ms13_hivemind/terrain/other = allocate(/obj/structure/ms13_hivemind/terrain, get_ranged_target_turf(site, NORTH, 3), network)
	network.frontier |= other
	rock = rock.ChangeTurf(/turf/open/floor/plating)
	SQUAD_ASSERT(growth in network.frontier, "Mining did not reopen the old growth edge while another edge was active")
	SQUAD_ASSERT(network.claim_turf(rock), "Newly mined ground could not be colonized")
	rock.ChangeTurf(old_type)

/datum/unit_test/ms13_vehicle_corpse/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/obj/structure/ms13_vehicle_frame/jeep_front/front = allocate(/obj/structure/ms13_vehicle_frame/jeep_front, site)
	var/datum/ms13_ground_vehicle/vehicle = front.vehicle
	var/mob/living/simple_animal/corpse = allocate(/mob/living/simple_animal, site)
	corpse.death(FALSE)
	SQUAD_ASSERT(!corpse.simulated && vehicle.is_aboard(corpse), "Unsimulated corpse was excluded from cabin passengers")
	SQUAD_ASSERT(vehicle.do_move(EAST, TRUE), "Vehicle could not move with a corpse aboard")
	SQUAD_ASSERT_EQUAL(get_turf(corpse), get_turf(front), "Corpse aboard was left behind")
	SQUAD_ASSERT(!(corpse in vehicle.underneath), "Cabin corpse fell through the vehicle floor")
	SQUAD_ASSERT_EQUAL(front.roof.plane, GAME_PLANE, "Roof inherited the floor plane")
	SQUAD_ASSERT(front.roof.layer > corpse.layer, "Roof does not cover the passenger's layer")
	for(var/obj/structure/ms13_vehicle_part/part as anything in vehicle.parts)
		if(part.exterior_image)
			SQUAD_ASSERT(part.exterior_image.plane == front.roof.plane && part.exterior_image.layer > front.roof.layer, "Exterior hardware is hidden behind the roof")
	front.update_roof_damage()
	var/mutable_appearance/mask = front.roof.overlays[1]
	SQUAD_ASSERT_EQUAL(mask.plane, EMISSIVE_PLANE, "Roof lacks a cabin-glow mask")
	SQUAD_ASSERT(mask.icon == front.roof.icon && mask.icon_state == front.roof.icon_state, "Roof glow mask does not match the visible roof")
	front.roof_hull_breached = TRUE
	front.update_roof_damage()
	mask = front.roof.overlays[1]
	SQUAD_ASSERT(mask.icon == front.roof.icon && mask.icon_state == front.roof.icon_state, "Damaged roof retained its intact glow mask")
