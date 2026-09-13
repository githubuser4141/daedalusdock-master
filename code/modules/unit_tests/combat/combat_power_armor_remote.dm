/// Core safety guarantees of remote-controlled power armor: the operator's mind actually moves into
/// the drone (not their real body), the suit can't be worn by a bystander while the receiver is
/// installed, cable is laid/reeled as the drone moves, and sever() always returns the operator to
/// their real body - even when that body is the one that got destroyed while they were linked.
/datum/unit_test/combat/power_armor_remote_link
	name = "COMBAT: Power Armor Remote Link Is Safe To Start, Move, And Sever"

/datum/unit_test/combat/power_armor_remote_link/Run()
	var/mob/living/carbon/human/consistent/operator = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/t51/suit = allocate(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/t51)
	var/obj/machinery/computer/ms13_pa_control/computer = allocate(/obj/machinery/computer/ms13_pa_control)

	operator.mind_initialize()
	TEST_ASSERT(operator.mind, "Test operator has no mind to transfer.")
	var/datum/mind/operator_mind = operator.mind

	var/obj/item/ms13/power_armor/chest_part = suit.module_armor[BODY_ZONE_CHEST]
	TEST_ASSERT(chest_part, "T-51 suit did not spawn with a chest component installed.")

	// mojave defines (MAIN_MODULE_PA, MS13_PA_LINK_CABLE) aren't visible here - mojave loads after
	// code/ in daedalus.dme, same reason bullet_math.dm hardcodes its own mojave constants.
	var/obj/item/ms13/pa_module/remote_receiver/receiver = new(chest_part)
	chest_part.modules["mainmodulepa"] = receiver
	receiver.part_pa = chest_part
	receiver.link_id = "unit_test_link"
	receiver.added_to_pa()
	computer.link_id = "unit_test_link"

	// qdel_on_fail = FALSE here on purpose - the suit is still needed for the drone below, and this
	// equip attempt is SUPPOSED to fail, so a qdel-on-fail would have deleted it out from under us.
	TEST_ASSERT(!bystander.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING, FALSE, TRUE), "A bystander was able to wear a suit with a receiver installed.")

	var/datum/ms13_remote_link/link = new(operator, receiver, computer, "cable")
	TEST_ASSERT_EQUAL(operator_mind.current, link.drone, "Operator's mind did not move to the drone.")
	TEST_ASSERT_NOTEQUAL(operator_mind.current, operator, "Operator's mind is still on their real body - they'd be physically 'present' in the armor.")
	TEST_ASSERT_EQUAL(link.drone.get_item_by_slot(ITEM_SLOT_OCLOTHING), suit, "The suit was not equipped onto the drone.")

	var/turf/start_turf = get_turf(link.drone)
	var/turf/next_turf = get_step(start_turf, EAST)
	TEST_ASSERT(next_turf, "No adjacent turf to move the drone into for the cable test.")
	// Two step_to() calls back-to-back with no elapsed time between them otherwise hit the normal
	// movement cooldown (next_move) - a real player would never chain moves this fast, but a unit
	// test does, so bypass it the same way other movement-driving tests do (e.g. combat_cuffs.dm).
	link.drone.next_move = -1
	step_to(link.drone, next_turf)
	TEST_ASSERT_EQUAL(length(link.cable_trail), 1, "Moving the drone one tile did not lay exactly one cable segment.")

	link.drone.next_move = -1
	step_to(link.drone, start_turf)
	TEST_ASSERT_EQUAL(length(link.cable_trail), 0, "Stepping back over its own cable did not reel the segment back in.")

	link.sever("unit test teardown")
	TEST_ASSERT_EQUAL(operator_mind.current, operator, "sever() did not return the operator's mind to their real body.")
	TEST_ASSERT(QDELETED(link.drone) || !link.drone, "The drone mob was not cleaned up after sever().")

	// Now the unrecoverable-body case: if the real body is gone by the time sever() runs, it must not
	// runtime - the drone's own mind handling takes over instead of a crash.
	var/mob/living/carbon/human/consistent/second_operator = allocate(/mob/living/carbon/human/consistent)
	second_operator.mind_initialize()
	var/datum/ms13_remote_link/second_link = new(second_operator, receiver, computer, "cable")
	qdel(second_operator)
	TEST_ASSERT(!second_link.drone, "Losing the real body mid-session did not tear the link down.")
