/// Planning re-queues CAN_PLAN_DURING_EXECUTION behaviors every tick; they must not stack up as duplicates.
/datum/ai_behavior/unit_test_noop
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/unit_test/ai_behavior_queue_dedupe/Run()
	var/mob/living/basic/ms13/hostile_animal/radroach/roach = ALLOCATE_BOTTOM_LEFT()
	var/datum/ai_controller/controller = roach.ai_controller
	TEST_ASSERT(controller, "Radroach has no AI controller.")
	controller.CancelActions()

	controller.queue_behavior(/datum/ai_behavior/unit_test_noop)
	controller.queue_behavior(/datum/ai_behavior/unit_test_noop)
	var/datum/ai_behavior/noop = GET_AI_BEHAVIOR(/datum/ai_behavior/unit_test_noop)
	TEST_ASSERT_EQUAL(LAZYLEN(controller.current_behaviors), 1, "Queuing one behavior twice left duplicates in current_behaviors.")

	noop.finish_action(controller, TRUE)
	TEST_ASSERT(!(noop in controller.current_behaviors), "A finished behavior was still queued.")

/// IsReachableBy() skips building DirectAccess() for turfs and atoms on turfs; these are the cases that shortcut has to cover.
/datum/unit_test/can_reach_direct_access_shortcut/Run()
	var/mob/living/carbon/human/user = ALLOCATE_BOTTOM_LEFT()
	var/obj/item/wrench/wrench = ALLOCATE_BOTTOM_LEFT()

	TEST_ASSERT(user.IsReachableBy(user), "A mob could not reach itself.")
	TEST_ASSERT(user.loc.IsReachableBy(user), "A mob could not reach the turf it stands on.")

	user.put_in_hands(wrench)
	TEST_ASSERT(wrench.IsReachableBy(user), "A mob could not reach an item in its own hand.")

	TEST_ASSERT(get_dist(user, run_loc_floor_top_right) > 1, "Unit test area is too small for this check.")
	TEST_ASSERT(!run_loc_floor_top_right.IsReachableBy(user), "A mob reached a turf across the test area.")
