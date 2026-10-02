#ifndef MS13_SQUAD_NPCS_TESTS_INCLUDED
#define MS13_SQUAD_NPCS_TESTS_INCLUDED

#ifdef UNIT_TESTS

#define SQUAD_ASSERT(condition, message) if(!(condition)) { return Fail(message); }
#define SQUAD_ASSERT_EQUAL(actual, expected, message) SQUAD_ASSERT((actual) == (expected), message)

// Focused behavioural tests are kept beside the experimental feature.
/datum/unit_test/ms13_squad_authority/Run()
	var/turf/ground = run_loc_floor_bottom_left
	var/mob/living/carbon/human/ms13_squad/leader/leader = allocate(/mob/living/carbon/human/ms13_squad/leader, ground)
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, get_step(ground, NORTH))
	leader.squad_id = "test squad"
	unit.squad_id = leader.squad_id
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, ground)
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human, ground)
	SQUAD_ASSERT(leader.claim_command(user), "Adjacent player could not claim an unassigned squad")
	SQUAD_ASSERT(!leader.claim_command(stranger), "Another player stole an assigned squad")
	SQUAD_ASSERT(!leader.issue_order(stranger, "Hold"), "Forged commander issued an order")
	SQUAD_ASSERT(leader.issue_order(user, "Hold"), "Commander could not halt the squad")
	SQUAD_ASSERT_EQUAL(unit.squad_order, "Hold", "Leader did not relay to its physical recruit")
	SQUAD_ASSERT(!leader.issue_order(user, "Attack", unit), "Commander could order fire on their own squad")
	var/atom/movable/screen/screen_target = allocate(/atom/movable/screen)
	SQUAD_ASSERT(!leader.issue_order(user, "Move", screen_target), "HUD objects were accepted as map destinations")
	SQUAD_ASSERT(unit.w_uniform && unit.shoes, "Default recruit is missing clothing")
	SQUAD_ASSERT(locate(/obj/item/flashlight/ms13) in unit.contents, "Default recruit is missing flashlight")
	SQUAD_ASSERT(locate(/obj/item/knife/ms13/combat) in unit.contents, "Default recruit is missing knife")
	SQUAD_ASSERT(!(locate(/obj/item/gun) in unit.contents), "Default recruit spawned a free gun")

	var/obj/machinery/ms13/terminal/terminal = allocate(/obj/machinery/ms13/terminal, ground)
	terminal.squad_id = leader.squad_id
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	SQUAD_ASSERT(leader.can_command(user, terminal), "Powered linked terminal rejected its commander")
	terminal.set_machine_stat(NOPOWER)
	SQUAD_ASSERT(!leader.issue_order(user, "Move", get_step(ground, EAST), unit, terminal), "Unpowered terminal accepted orders")
	terminal.set_machine_stat(NONE)
	terminal.password_needed = TRUE
	terminal.unlocked = FALSE
	SQUAD_ASSERT(!leader.can_command(user, terminal), "Locked terminal bypassed password")
	terminal.unlocked = TRUE
	SQUAD_ASSERT(leader.issue_order(user, "Move", get_step(ground, EAST), unit, terminal), "Restored terminal did not recover")
	terminal.squad_id = "other squad"
	SQUAD_ASSERT(!leader.can_command(user, terminal), "Wrong terminal network authorized a squad")
	terminal.squad_id = leader.squad_id
	user.forceMove(run_loc_floor_top_right)
	SQUAD_ASSERT(!leader.can_command(user, terminal), "Commander retained terminal authority after walking away")
	user.forceMove(ground)
	leader.open_commands(user)
	var/datum/action/cooldown/ms13_squad_command/action = leader.command_action.resolve()
	SQUAD_ASSERT(action && action.IsAvailable(), "Claiming command did not provide a usable HUD action")
	SQUAD_ASSERT(action.button_icon_state in icon_states(action.button_icon), "Command action icon does not exist")
	user.stat = DEAD
	SQUAD_ASSERT(leader.claim_command(stranger), "Dead commander permanently locked the squad")
	leader.open_commands(stranger)
	SQUAD_ASSERT(QDELETED(action), "Command transfer left the former commander's action attached")
	action = leader.command_action.resolve()
	qdel(leader)
	SQUAD_ASSERT(QDELETED(action), "Deleted leader left a command action attached to its player")

/datum/unit_test/ms13_squad_inventory/Run()
	var/turf/ground = run_loc_floor_bottom_left
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, ground)
	unit.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/obj/item/wrench/item = allocate(/obj/item/wrench, get_step(ground, EAST))
	unit.set_order("Pick up", item)
	unit.act_on_order()
	SQUAD_ASSERT(item in unit.held_items, "Pick-up order failed: [unit.order_status]; item at [item.loc]; hands [unit.get_num_held_items()]")
	SQUAD_ASSERT_EQUAL(unit.cargo?.resolve(), item, "Picked-up item was not tracked for delivery")
	unit.next_move = 0
	unit.set_order("Deliver", ground)
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(item.loc, ground, "Delivery did not release the actual carried item")
	var/obj/machinery/button/ms13_squad_test/button = allocate(/obj/machinery/button/ms13_squad_test, get_step(ground, NORTH))
	button.set_machine_stat(NONE)
	button.set_is_operational(TRUE)
	unit.next_move = 0
	unit.next_click = 0
	unit.set_order("Use", button)
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(button.presses, 1, "Use order did not reach the button's normal attack_hand")
	button.set_machine_stat(NOPOWER)
	unit.next_move = 0
	unit.next_click = 0
	unit.set_order("Use", button)
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(button.presses, 1, "NPC bypassed an unpowered button's normal controls")
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, get_step(ground, EAST))
	var/old_integrity = crate.get_integrity()
	unit.next_move = 0
	unit.next_click = 0
	unit.set_order("Break", crate)
	unit.act_on_order()
	SQUAD_ASSERT(crate.get_integrity() < old_integrity, "Break order bypassed or failed normal item damage")
	qdel(crate)
	unit.next_move = 0
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(unit.squad_order, "Guard", "Deleted work target left the NPC stuck")

/obj/machinery/button/ms13_squad_test
	var/presses = 0

/obj/machinery/button/ms13_squad_test/try_activate_button(mob/living/user)
	. = ..()
	if(.)
		presses++

/datum/unit_test/ms13_squad_combat/Run()
	var/turf/ground = run_loc_floor_bottom_left
	var/mob/living/carbon/human/ms13_squad/leader/leader = allocate(/mob/living/carbon/human/ms13_squad/leader, get_step(ground, NORTH))
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, ground)
	leader.squad_id = "combat test"
	unit.squad_id = leader.squad_id
	leader.ai_controller.set_ai_status(AI_STATUS_OFF)
	unit.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/enemy = allocate(/mob/living/carbon/human, get_ranged_target_turf(ground, EAST, 4))
	var/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm/gun = allocate(/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm, ground)
	unit.put_in_hands(gun)
	var/before_ammo = gun.get_ammo()
	SQUAD_ASSERT(before_ammo > 0 && gun.can_fire(), "Test firearm was not loaded")
	unit.set_order("Attack", enemy)
	unit.act_on_order()
	SQUAD_ASSERT(gun.get_ammo() < before_ammo, "Ranged order consumed no ammo: [unit.order_status]; next move [unit.next_move - world.time]; active [unit.get_active_held_item()]")
	unit.next_move = 0
	unit.next_click = 0
	before_ammo = gun.get_ammo()
	leader.forceMove(get_ranged_target_turf(ground, EAST, 2))
	SQUAD_ASSERT(!unit.safe_shot(enemy), "Friendly-fire line check missed a squadmate")
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(gun.get_ammo(), before_ammo, "NPC fired directly through its own leader")
	unit.threat = null
	leader.retaliate(enemy)
	SQUAD_ASSERT_EQUAL(unit.threat?.resolve(), enemy, "Physical leader did not share its attacker")
	unit.retaliate(leader)
	SQUAD_ASSERT_EQUAL(unit.threat?.resolve(), enemy, "Friendly hit replaced hostile target")
	leader.forceMove(get_step(ground, NORTH))
	sleep(2 SECONDS)
	unit.next_move = 0
	unit.next_click = 0
	unit.set_order("Fire direction", get_turf(enemy), EAST)
	before_ammo = gun.get_ammo()
	unit.act_on_order()
	SQUAD_ASSERT(gun.get_ammo() < before_ammo, "Directional fire consumed no ammo: [unit.order_status]; gun ready [gun.can_fire(TRUE)]")
	sleep(2 SECONDS)
	unit.next_move = 0
	unit.next_click = 0
	unit.set_order("Fire at area", get_turf(enemy))
	before_ammo = gun.get_ammo()
	unit.act_on_order()
	SQUAD_ASSERT(gun.get_ammo() < before_ammo, "Area fire consumed no ammo: [unit.order_status]; gun ready [gun.can_fire(TRUE)]")
	unit.dropItemToGround(gun)
	unit.threat = null
	unit.next_move = 0
	unit.set_order("Fire direction", get_turf(enemy), EAST)
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(unit.order_status, "Needs a loaded gun", "Unarmed suppressive fire created a substitute weapon or chased into melee")
	var/mob/living/basic/ms13/raider/raider = allocate(/mob/living/basic/ms13/raider, get_step(ground, NORTH))
	raider.ai_controller.set_ai_status(AI_STATUS_OFF)
	unit.attack_basic_mob(raider)
	SQUAD_ASSERT_EQUAL(unit.threat?.resolve(), raider, "Basic-mob melee failed to provoke retaliation")

/datum/unit_test/ms13_squad_movement/Run()
	var/turf/ground = run_loc_floor_bottom_left
	var/turf/destination = get_ranged_target_turf(ground, EAST, 4)
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, ground)
	var/datum/ai_controller/ms13_squad/brain = unit.ai_controller
	unit.set_order("Move", destination)
	var/deadline = world.time + 15 SECONDS
	while(world.time < deadline && get_dist(unit, destination) > 1)
		brain.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT(get_dist(unit, destination) <= 1, "Actual JPS movement did not reach its destination")
	unit.set_order("Patrol", ground)
	var/turf/return_point = unit.patrol_origin
	deadline = world.time + 15 SECONDS
	while(world.time < deadline && unit.order_target?.resolve() != return_point)
		brain.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT_EQUAL(unit.order_target?.resolve(), return_point, "Patrol did not reverse after reaching its waypoint")
	unit.set_order("Move", destination)
	unit.order_deadline = world.time - 1
	unit.act_on_order()
	SQUAD_ASSERT_EQUAL(unit.squad_order, "Guard", "Expired movement order never released")
	unit.set_order("Move", destination)
	deadline = world.time + 15 SECONDS
	while(world.time < deadline && get_dist(unit, destination) > 1)
		brain.process(1)
		sleep(0.2 SECONDS)
	SQUAD_ASSERT(get_dist(unit, destination) <= 1, "NPC did not recover and execute new movement after failure")

/datum/unit_test/ms13_squad_fire_modes/Run()
	var/turf/ground = run_loc_floor_bottom_left
	var/mob/living/carbon/human/ms13_squad/leader/leader = allocate(/mob/living/carbon/human/ms13_squad/leader, get_step(ground, NORTH))
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, ground)
	leader.squad_id = "fire mode test"
	unit.squad_id = leader.squad_id
	leader.ai_controller.set_ai_status(AI_STATUS_OFF)
	unit.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, get_step(ground, NORTH))
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human, get_step(ground, NORTH))
	SQUAD_ASSERT(leader.claim_command(user), "Could not claim fire-mode test squad")
	SQUAD_ASSERT(!leader.issue_fire_mode(stranger, "Rapid", unit), "Stranger changed firing mode")
	SQUAD_ASSERT(!leader.issue_fire_mode(user, "bogus", unit), "Invalid firing mode accepted")
	SQUAD_ASSERT(leader.issue_fire_mode(user, "Precise", unit), "Individual firing mode rejected")
	SQUAD_ASSERT_EQUAL(leader.fire_mode, "Careful", "Individual setting changed the whole squad")
	var/obj/machinery/ms13/terminal/terminal = allocate(/obj/machinery/ms13/terminal, get_step(ground, NORTH))
	terminal.squad_id = leader.squad_id
	terminal.set_machine_stat(NOPOWER)
	SQUAD_ASSERT(!leader.issue_fire_mode(user, "Rapid", null, terminal), "Unpowered terminal changed fire modes")
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	SQUAD_ASSERT(leader.issue_fire_mode(user, "Rapid", null, terminal), "Restored terminal could not update the whole squad")
	SQUAD_ASSERT_EQUAL(unit.fire_mode, leader.fire_mode, "Squad fire-mode setting did not propagate")
	var/turf/target = get_ranged_target_turf(ground, EAST, 4)
	var/list/shots = list()
	for(var/mode in GLOB.ms13_squad_fire_modes)
		var/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm/gun = allocate(/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm, ground)
		unit.put_in_hands(gun)
		unit.fire_mode = mode
		unit.next_shot = 0
		unit.gun_recoil = 0
		unit.set_order("Fire direction", target, EAST)
		var/ammo = gun.get_ammo()
		var/deadline = world.time + 5 SECONDS
		while(world.time < deadline)
			unit.act_on_order()
			sleep(0.25 SECONDS)
		shots[mode] = ammo - gun.get_ammo()
		SQUAD_ASSERT(shots[mode] > 0, "[mode] never fired: [unit.order_status]")
		unit.dropItemToGround(gun)
		qdel(gun)
	SQUAD_ASSERT(shots["Rapid"] > shots["Careful"] && shots["Careful"] > shots["Precise"], "Cadences are not distinct: [json_encode(shots)]")
	var/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm/precise_gun = allocate(/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm, ground)
	unit.put_in_hands(precise_gun)
	unit.fire_mode = "Precise"
	unit.next_shot = 0
	unit.next_move = 0
	unit.set_order("Fire at area", target)
	unit.act_on_order()
	SQUAD_ASSERT(unit.aim_target, "Precise area fire did not begin aiming")
	unit.forceMove(get_step(ground, NORTH))
	SQUAD_ASSERT(!unit.aim_target, "Moving preserved completed aim")
	unit.forceMove(ground)
	var/remaining = precise_gun.get_ammo()
	var/deadline = world.time + 5 SECONDS
	while(world.time < deadline && precise_gun.get_ammo() == remaining)
		unit.act_on_order()
		sleep(0.25 SECONDS)
	SQUAD_ASSERT(precise_gun.get_ammo() < remaining, "Precise area fire never recovered after movement")

/datum/unit_test/ms13_squad_loadouts/Run()
	for(var/unit_type in list(/mob/living/carbon/human/ms13_squad/sidearm, /mob/living/carbon/human/ms13_squad/rifleman, /mob/living/carbon/human/ms13_squad/marksman, /mob/living/carbon/human/ms13_squad/support, /mob/living/carbon/human/ms13_squad/guard))
		var/mob/living/carbon/human/ms13_squad/unit = allocate(unit_type, run_loc_floor_bottom_left)
		unit.ai_controller.set_ai_status(AI_STATUS_OFF)
		var/obj/item/gun/ballistic/gun = unit.ready_weapon(TRUE)
		SQUAD_ASSERT(gun?.can_fire() && gun.get_ammo() > 0, "[unit_type] spawned without a usable loaded firearm")
		SQUAD_ASSERT(unit.w_uniform && unit.wear_suit && unit.back && unit.shoes, "[unit_type] lost equipped clothing or storage")
		var/spares = 0
		for(var/obj/item/ammo_box/magazine/mag in unit.back.contents)
			SQUAD_ASSERT(istype(mag, gun.mag_type), "[unit_type] has incompatible spare ammunition")
			spares++
		SQUAD_ASSERT_EQUAL(spares, 2, "[unit_type] failed to store both spare magazines")
		qdel(unit)

/datum/unit_test/ms13_squad_cryopods/Run()
	var/turf/ground = run_loc_floor_bottom_left
	var/obj/machinery/ms13/terminal/terminal = allocate(/obj/machinery/ms13/terminal, ground)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, ground)
	terminal.cryo_network = "test cryo"
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	var/obj/machinery/ms13/npc_cryopod/pod = allocate(/obj/machinery/ms13/npc_cryopod, get_step(ground, EAST))
	pod.network_id = terminal.cryo_network
	pod.squad_id = "test recruits"
	pod.mob_type = /mob/living/carbon/human/ms13_squad/rifleman
	pod.dir = NORTH
	pod.set_machine_stat(NONE)
	pod.set_is_operational(TRUE)
	var/obj/machinery/ms13/npc_cryopod/other = allocate(/obj/machinery/ms13/npc_cryopod, get_ranged_target_turf(ground, EAST, 3))
	other.network_id = "other network"
	SQUAD_ASSERT_EQUAL(terminal.wake_cryopods(user, other), 0, "Forged cross-network pod selection accepted")
	terminal.set_machine_stat(NOPOWER)
	SQUAD_ASSERT_EQUAL(terminal.wake_cryopods(user, pod), 0, "Unpowered terminal released a pod")
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	var/obj/structure/closet/crate/blocker = allocate(/obj/structure/closet/crate, get_step(pod, NORTH))
	SQUAD_ASSERT_EQUAL(terminal.wake_cryopods(user, pod), 0, "Blocked exit released an occupant")
	SQUAD_ASSERT(!pod.released, "Blocked release consumed the occupant")
	qdel(blocker)
	SQUAD_ASSERT_EQUAL(terminal.wake_cryopods(user), 1, "Wake-all failed to recover after clearing the exit")
	var/mob/living/carbon/human/ms13_squad/rifleman/recruit = locate() in get_step(pod, NORTH)
	SQUAD_ASSERT(recruit && recruit.squad_id == pod.squad_id, "Cryopod lost configured mob type or squad ID")
	allocated += recruit
	SQUAD_ASSERT_EQUAL(terminal.wake_cryopods(user), 0, "Repeated release duplicated the occupant")

/datum/unit_test/ms13_squad_doors/Run()
	var/turf/ground = locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/destination = get_ranged_target_turf(ground, EAST, 4)
	var/obj/machinery/door/unpowered/ms13/wood/door = allocate(/obj/machinery/door/unpowered/ms13/wood, get_ranged_target_turf(ground, EAST, 2))
	door.setDir(WEST)
	for(var/offset in list(-2, -1, 1, 2))
		var/obj/structure/barrier = allocate(/obj/structure, locate(door.x, door.y + offset, door.z))
		barrier.density = TRUE
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, ground)
	var/datum/ai_controller/ms13_squad/brain = unit.ai_controller
	brain.set_ai_status(AI_STATUS_OFF)
	door.lock_locked = TRUE
	SQUAD_ASSERT(!length(SSpathfinder.jps_pathfind_now(unit, destination, 20, 1)), "Pathfinder routes NPCs through locked doors")
	door.lock_locked = FALSE
	door.bolted = TRUE
	SQUAD_ASSERT(!length(SSpathfinder.jps_pathfind_now(unit, destination, 20, 1)), "Pathfinder routes NPCs through bolted doors")
	door.bolted = FALSE
	unit.set_order("Move", destination)
	var/deadline = world.time + 15 SECONDS
	while(world.time < deadline && get_dist(unit, destination) > 1)
		brain.process(0.5)
		sleep(0.25 SECONDS)
	SQUAD_ASSERT(unit.x > door.x && get_dist(unit, destination) <= 1, "NPC did not open and walk through the unlocked door")

/datum/unit_test/ms13_bodycams/Run()
	var/turf/ground = run_loc_floor_bottom_left
	var/mob/living/carbon/human/ms13_squad/guard/user = allocate(/mob/living/carbon/human/ms13_squad/guard, ground)
	user.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/obj/machinery/ms13/terminal/terminal = allocate(/obj/machinery/ms13/terminal, get_step(ground, NORTH))
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	var/obj/item/ms13/bodycam/camera = allocate(/obj/item/ms13/bodycam, ground)
	user.put_in_hands(camera)
	camera.melee_attack_chain(user, terminal, "")
	SQUAD_ASSERT(length(terminal.paired_bodycams) == 1, "Tapping the terminal did not pair the bodycam")
	SQUAD_ASSERT(terminal.pair_bodycam(camera, user) && length(terminal.paired_bodycams) == 1, "Re-pairing duplicated the camera")
	var/obj/machinery/computer/security/ms13_bodycam_viewer/viewer = allocate(/obj/machinery/computer/security/ms13_bodycam_viewer, terminal)
	terminal.bodycam_viewer = viewer
	viewer.active_camera = camera.feed
	SQUAD_ASSERT(!camera.feed.can_use(), "Unmounted camera transmitted")
	for(var/obj/item/clothing/clothing as anything in list(user.w_uniform, user.wear_suit, user.head))
		camera.melee_attack_chain(user, clothing, "")
		SQUAD_ASSERT(camera.mounted_on == clothing, "Tapping clothing did not attach the bodycam to [clothing.type]")
		SQUAD_ASSERT(camera.feed.can_use(), "Worn bodycam was unavailable")
		viewer.update_active_camera_screen()
		SQUAD_ASSERT(length(viewer.cam_screen.vis_contents), "Embedded bodycam map did not render any turfs")
		camera.enabled = FALSE
		viewer.update_active_camera_screen()
		SQUAD_ASSERT(!length(viewer.cam_screen.vis_contents), "Disabled bodycam retained its live view")
		camera.enabled = TRUE
		camera.remove_from_clothing(clothing, user)
		SQUAD_ASSERT(!camera.mounted_on && (camera in user.held_items), "Bodycam did not detach back into a hand")
	SQUAD_ASSERT(camera.attach_to(user.head, user), "Could not remount bodycam")
	user.forceMove(get_step(ground, EAST))
	viewer.update_active_camera_screen()
	SQUAD_ASSERT(get_turf(user) in viewer.cam_screen.vis_contents, "Camera feed did not follow its wearer")
	user.dropItemToGround(user.head)
	SQUAD_ASSERT(!camera.feed.can_use(), "Camera inside dropped clothing still transmitted")
	qdel(camera)
	viewer.update_active_camera_screen()
	SQUAD_ASSERT(!length(viewer.cam_screen.vis_contents) && !length(terminal.paired_bodycams), "Deleted camera left a stale view or pairing")
	terminal.set_machine_stat(NOPOWER)
	SQUAD_ASSERT_EQUAL(viewer.ui_status(user), UI_CLOSE, "Bodycam UI stayed open without terminal power")

/datum/unit_test/ms13_squad_spawn_interactions/Run()
	var/turf/ground = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, ground)
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human, ground)
	var/mob/living/carbon/human/ms13_squad/unit = allocate(/mob/living/carbon/human/ms13_squad, get_step(ground, EAST))
	unit.ai_controller.set_ai_status(AI_STATUS_OFF)
	user.AltClickOn(unit)
	SQUAD_ASSERT(unit.is_squad_leader && unit.squad_id && unit.commander?.resolve() == user, "Alt-click on a default spawned recruit did not establish command")
	SQUAD_ASSERT(unit.command_action?.resolve(), "Alt-click did not grant the actual command action")
	var/mob/living/carbon/human/ms13_squad/recruit = allocate(/mob/living/carbon/human/ms13_squad/rifleman, get_step(ground, NORTH))
	recruit.ai_controller.set_ai_status(AI_STATUS_OFF)
	user.AltClickOn(recruit)
	SQUAD_ASSERT(recruit.squad_leader() == unit, "Alt-click did not add a fresh recruit to the nearby commanded squad")
	stranger.AltClickOn(recruit)
	SQUAD_ASSERT(unit.commander?.resolve() == user, "Recruit interaction let a stranger steal command")
	var/obj/machinery/ms13/terminal/terminal = allocate(/obj/machinery/ms13/terminal, ground)
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	SQUAD_ASSERT(unit in terminal.available_squad_units(), "Default terminal did not discover nearby squad")
	SQUAD_ASSERT(unit.can_command(user, terminal), "Discovered squad was not controllable through the terminal")
	var/mob/living/carbon/human/ms13_squad/remote = allocate(/mob/living/carbon/human/ms13_squad, get_ranged_target_turf(ground, EAST, 3))
	remote.ai_controller.set_ai_status(AI_STATUS_OFF)
	world.push_usr(user, CALLBACK(terminal, "Topic", "", list("choice" = "squad", "recruit" = REF(remote))))
	SQUAD_ASSERT(remote.squad_leader() == unit && remote.squad_id == unit.squad_id, "Terminal hyperlink could not recruit a fresh nearby NPC")
	var/datum/action/cooldown/ms13_squad_command/action = unit.command_action?.resolve()
	SQUAD_ASSERT(action?.terminal_ref?.resolve() == terminal, "Terminal hyperlink did not open terminal command mode")
	world.push_usr(user, CALLBACK(action, "Topic", "", list("order" = "Hold")))
	SQUAD_ASSERT_EQUAL(remote.squad_order, "Hold", "Command-panel hyperlink did not issue an order")
	SQUAD_ASSERT_EQUAL(terminal.squad_id, unit.squad_id, "Terminal did not remember the recruited squad")
	unit.forceMove(locate(ground.x + 10, ground.y, ground.z))
	SQUAD_ASSERT(unit.can_command(user, terminal), "Terminal lost its linked squad when the leader left discovery range")
	unit.forceMove(get_step(ground, EAST))
	terminal.set_machine_stat(NOPOWER)
	SQUAD_ASSERT(!unit.issue_order(user, "Hold", null, null, terminal), "Offline discovery bypassed terminal power")
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	SQUAD_ASSERT(unit.issue_order(user, "Hold", null, null, terminal), "Terminal orders did not recover after restoring power")
	terminal.squad_id = "another squad"
	SQUAD_ASSERT(!unit.can_command(user, terminal), "Nearby discovery bypassed explicit terminal squad assignment")
	var/mob/living/carbon/human/ms13_squad/leader/fresh_leader = allocate(/mob/living/carbon/human/ms13_squad/leader, ground)
	fresh_leader.ai_controller.set_ai_status(AI_STATUS_OFF)
	user.AltClickOn(fresh_leader)
	SQUAD_ASSERT(fresh_leader.command_action?.resolve() && fresh_leader.squad_id != unit.squad_id, "Fresh leader subtype required a mapper ID or merged into another squad")

/datum/unit_test/ms13_cryopod_click/Run()
	var/turf/ground = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, ground)
	var/obj/machinery/ms13/terminal/terminal = allocate(/obj/machinery/ms13/terminal, ground)
	var/obj/machinery/ms13/npc_cryopod/pod = allocate(/obj/machinery/ms13/npc_cryopod, get_step(ground, EAST))
	pod.dir = NORTH
	SQUAD_ASSERT(pod in terminal.linked_cryopods(), "Blank nearby pod was invisible to an unconfigured terminal")
	pod.network_id = "private network"
	SQUAD_ASSERT(!(pod in terminal.linked_cryopods()), "Proximity bypassed explicit cryopod network")
	pod.network_id = ""
	pod.set_machine_stat(NOPOWER)
	pod.attack_hand(user, list())
	SQUAD_ASSERT(!pod.released, "Local click released an unpowered pod")
	pod.set_machine_stat(NONE)
	pod.set_is_operational(TRUE)
	var/obj/structure/closet/crate/blocker = allocate(/obj/structure/closet/crate, get_step(pod, NORTH))
	pod.attack_hand(user, list())
	SQUAD_ASSERT(!pod.released && pod.status == "Exit blocked", "Local click bypassed the blocked exit or did not reach pod interaction")
	qdel(blocker)
	pod.attack_hand(user, list())
	var/mob/living/carbon/human/ms13_squad/occupant = locate() in get_step(pod, NORTH)
	SQUAD_ASSERT(pod.released && occupant, "Local click failed to release after clearing the exit")
	allocated += occupant
	pod.attack_hand(user, list())
	var/count = 0
	for(var/mob/living/carbon/human/ms13_squad/unit in get_step(pod, NORTH))
		count++
	SQUAD_ASSERT_EQUAL(count, 1, "Repeated clicks duplicated the occupant")
	var/obj/machinery/ms13/npc_cryopod/remote = allocate(/obj/machinery/ms13/npc_cryopod, get_step(ground, WEST))
	remote.dir = NORTH
	remote.set_machine_stat(NONE)
	remote.set_is_operational(TRUE)
	terminal.set_machine_stat(NONE)
	terminal.set_is_operational(TRUE)
	world.push_usr(user, CALLBACK(terminal, "Topic", "", list("choice" = "cryo_wake", "pod" = REF(remote))))
	occupant = locate() in get_step(remote, NORTH)
	SQUAD_ASSERT(remote.released && occupant, "Terminal hyperlink failed to release a nearby unconfigured pod")
	allocated += occupant

#undef SQUAD_ASSERT
#undef SQUAD_ASSERT_EQUAL

#endif

#endif
