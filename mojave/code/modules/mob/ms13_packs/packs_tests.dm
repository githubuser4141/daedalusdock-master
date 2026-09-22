#ifdef UNIT_TESTS
/datum/unit_test/ms13_mob_packs
	name = "MOBS: Idle Mobs Sleep In Packs And Wake Together"

/datum/unit_test/ms13_mob_packs/Run()
	var/test_z = run_loc_floor_bottom_left.z
	for(var/turf/ground in block(locate(150, 150, test_z), locate(200, 200, test_z)))
		ground.ChangeTurf(/turf/open/floor/plating)
		for(var/obj/thing in ground)
			qdel(thing)
		for(var/mob/living/resident in ground)
			qdel(resident)
	var/list/ghouls = list()
	for(var/offset in 0 to 2)
		ghouls += spawn_mob(/mob/living/basic/ms13/ghoul, locate(170 + offset, 170, test_z), "ms13_pack_test")
	var/mob/living/basic/ms13/ghoul/insomniac = spawn_mob(/mob/living/basic/ms13/ghoul, locate(171, 172, test_z), "ms13_pack_test")
	insomniac.ms13_can_sleep = FALSE
	var/list/robots = list()
	for(var/offset in 0 to 1)
		robots += spawn_mob(/mob/living/simple_animal/hostile/ms13/robot/protectron, locate(185 + offset, 185, test_z), "ms13_pack_test_robots")

	// Forms the packs, then two quiet passes put them to sleep. The map's own mobs go through the same passes.
	for(var/pass in 1 to 3)
		SSms13_packs.fire()
	var/sleeping = 0
	for(var/mob/living/sleeper as anything in GLOB.mob_living_list)
		if(sleeper.ms13_asleep)
			sleeping++
	log_test("MS13 packs: [length(SSms13_packs.packs)] packs, [sleeping] mobs asleep across the map.")

	var/mob/living/basic/ms13/ghoul/first = ghouls[1]
	var/datum/ms13_pack/pack = first.ms13_pack
	if(!pack?.asleep || !length(pack.watched_cells))
		Fail("Idle ghouls did not fall asleep in a pack watching the cells around it.")
		return dissolve_packs()
	for(var/mob/living/basic/ms13/ghoul/ghoul as anything in ghouls)
		if(ghoul.ms13_pack != pack || !ghoul.ms13_asleep || ghoul.ai_controller.ai_status != AI_STATUS_OFF || ghoul.stasis_level < 10)
			Fail("A ghoul did not sleep with its pack: AI off and Life slowed.")
	if(insomniac.ms13_pack || insomniac.ms13_asleep)
		Fail("A mob that can't sleep joined a pack.")
	var/mob/living/simple_animal/hostile/ms13/robot/protectron/first_robot = robots[1]
	for(var/mob/living/simple_animal/hostile/ms13/robot/protectron/robot as anything in robots)
		if(!robot.ms13_asleep || robot.AIStatus != AI_OFF)
			Fail("A legacy hostile robot did not sleep.")
		if(robot.ms13_pack == pack || robot.ms13_pack != first_robot.ms13_pack)
			Fail("Robots and ghouls shared a pack, or the robots didn't.")

	// A hostile mob crossing into the pack's cells, still out of range, keeps it asleep; walking on into range wakes it.
	var/mob/living/basic/ms13/ghoul/intruder = spawn_mob(/mob/living/basic/ms13/ghoul, locate(170, 195, test_z), "ms13_pack_intruder")
	intruder.ms13_can_sleep = FALSE
	intruder.forceMove(locate(170, 186, test_z))
	if(!pack.asleep || !pack.watching_closely)
		Fail("A hostile mob inside the pack's cells, out of range, woke it or went unwatched.")
	intruder.forceMove(locate(170, 180, test_z))
	sleep(1.5 SECONDS)
	if(pack.asleep || pack.leader.ai_controller.ai_status != AI_STATUS_ON)
		Fail("A hostile mob walked into range and the leader slept on.")
	for(var/mob/living/basic/ms13/ghoul/ghoul as anything in ghouls)
		if(ghoul.ms13_asleep || ghoul.ai_controller.ai_status != AI_STATUS_ON)
			Fail("A follower did not wake after its leader.")

	// Awake, a follower takes the leader's target rather than looking around, until it is hurt.
	var/mob/living/basic/ms13/ghoul/leader = pack.leader
	var/mob/living/basic/ms13/ghoul/follower = ghouls[ghouls[1] == leader ? 2 : 1]
	follower.ms13_hurt_at = -INFINITY
	leader.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, intruder)
	follower.ai_controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	var/datum/ai_behavior/find_potential_targets/finder = GET_AI_BEHAVIOR(/datum/ai_behavior/find_potential_targets)
	finder.perform(1, follower.ai_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	if(follower.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] != intruder)
		Fail("A follower did not take its leader's target.")
	follower.ms13_hurt_at = world.time
	if(pack.follows(follower))
		Fail("A hurt follower kept waiting on its leader instead of fighting for itself.")
	follower.ms13_hurt_at = -INFINITY

	// A follower left behind while idle heads back to its leader.
	qdel(intruder)
	follower.forceMove(locate(leader.x + 6, leader.y, test_z))
	follower.ai_controller.set_blackboard_key(BB_NEXT_MOVE_TIME, 0)
	var/datum/ai_behavior/idle_random_walk/walker = GET_AI_BEHAVIOR(/datum/ai_behavior/idle_random_walk)
	walker.perform(1, follower.ai_controller)
	if(get_dist(follower, leader) >= 6)
		Fail("An idle follower did not head back to its leader.")

	// Hurting any sleeper wakes the pack.
	follower.forceMove(get_step(leader, EAST))
	pack.fall_asleep()
	if(!pack.asleep)
		Fail("The pack did not fall back asleep.")
	follower.adjustBruteLoss(5)
	if(pack.asleep || pack.leader.ms13_asleep)
		Fail("Hurting a sleeping member did not wake its pack's leader.")
	var/still_asleep = 0
	for(var/mob/living/basic/ms13/ghoul/ghoul as anything in ghouls)
		if(ghoul != pack.leader && ghoul.ms13_asleep)
			still_asleep++
	if(!still_asleep)
		Fail("Every follower woke in the same tick as the leader.")
	sleep(1 SECONDS)

	// Another member takes over from a dead leader.
	var/mob/living/old_leader = pack.leader
	old_leader.death()
	if(QDELETED(pack) || (old_leader in pack.members) || !(pack.leader in pack.members))
		Fail("Nobody took over from a dead leader.")

	var/datum/ms13_pack/robot_pack = first_robot.ms13_pack
	robot_pack?.wake()
	sleep(1 SECONDS)
	for(var/mob/living/simple_animal/hostile/ms13/robot/protectron/robot as anything in robots)
		if(robot.ms13_asleep || robot.AIStatus == AI_OFF)
			Fail("A legacy hostile robot did not wake.")
	dissolve_packs()

/datum/unit_test/ms13_mob_packs/proc/spawn_mob(mob_type, turf/spot, faction_name)
	var/mob/living/spawned = allocate(mob_type, spot)
	spawned.faction = list(faction_name)
	return spawned

/// Wakes every mob this test put to sleep, map mobs included, so later tests find the map as it was.
/datum/unit_test/ms13_mob_packs/proc/dissolve_packs()
	for(var/datum/ms13_pack/pack as anything in SSms13_packs.packs.Copy())
		qdel(pack)
#endif
