/// Covers the two deterministic halves of the cover system: scoring how good a shot is through cover, and
/// picking somewhere better to stand. The projectile-side passchance roll is deliberately not asserted here -
/// it's a prob() call, so the meaningful thing to pin down is the scoring it's derived from.
/datum/unit_test/ms13_cover
	name = "COVER: Shot Quality And Cover Seeking"

/datum/unit_test/ms13_cover/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/shooter_turf = locate(origin.x + 1, origin.y + 1, origin.z)
	var/turf/midpoint = locate(origin.x + 2, origin.y + 1, origin.z)
	var/turf/target_turf = locate(origin.x + 3, origin.y + 1, origin.z)
	TEST_ASSERT(shooter_turf && midpoint && target_turf, "Test area is too small to lay out a firing line.")
	TEST_ASSERT(!midpoint.density, "Midpoint of the test firing line is a wall.")

	TEST_ASSERT_EQUAL(ms13_shot_quality(shooter_turf, target_turf), 1, "An unobstructed line should score as a perfectly clear shot.")

	// Semi-hard cover: degrades the shot without stopping it outright.
	var/obj/structure/table/blocker = new(midpoint)
	TEST_ASSERT(blocker.projectile_passchance > 0, "Tables should carry a passchance to act as semi-hard cover.")
	var/partial = ms13_shot_quality(shooter_turf, target_turf)
	TEST_ASSERT(partial > 0 && partial < 1, "Semi-hard cover should degrade the shot without blocking it, got [partial].")

	// Same object, hard cover: nothing gets through.
	blocker.projectile_passchance = 0
	TEST_ASSERT_EQUAL(ms13_shot_quality(shooter_turf, target_turf), 0, "Cover with no passchance should block the shot entirely.")
	qdel(blocker)

	TEST_ASSERT_EQUAL(ms13_shot_quality(shooter_turf, target_turf), 1, "Removing the cover should restore a clear shot.")

	// Cover seeking. Threat due east along the same strip the assertions above just proved is clear, an
	// obstacle partway down it, and the seeker one tile north of that obstacle out in the open - so the
	// sheltered tile on the far side of the obstacle is a real improvement on where it's standing.
	//
	//        y+2          . S .            S seeker (exposed)
	//        y+1      C   O   .   T        O obstacle   C the cover tile we expect to be chosen   T threat
	//               x+1  x+2 x+3 x+4
	var/turf/threat_turf = locate(origin.x + 4, origin.y + 1, origin.z)
	var/turf/obstacle_turf = locate(origin.x + 2, origin.y + 1, origin.z)
	var/turf/seeker_turf = locate(origin.x + 2, origin.y + 2, origin.z)
	TEST_ASSERT(threat_turf && obstacle_turf && seeker_turf, "Test area is too small to lay out the cover-seeking case.")
	TEST_ASSERT(!threat_turf.density && !obstacle_turf.density && !seeker_turf.density, "Cover-seeking layout runs into a wall - the unit test area is smaller than this test assumes.")

	var/mob/living/carbon/human/consistent/seeker = allocate(/mob/living/carbon/human/consistent)
	seeker.forceMove(seeker_turf)

	// Literal rather than MS13_AI_EXPOSED_THRESHOLD: that define lives in mojave/, which loads after code/,
	// so mojave-side defines aren't visible from a test file here. Keep the two in step by hand.
	var/exposed_quality = ms13_shot_quality(threat_turf, seeker_turf)
	TEST_ASSERT(exposed_quality > 0.5, "Seeker should start out genuinely exposed before any cover is placed, got [exposed_quality].")

	var/obj/structure/table/obstacle = new(obstacle_turf)

	var/turf/found = ms13_find_cover_turf(seeker, threat_turf)
	TEST_ASSERT(found, "Cover search found nothing despite an obstacle in reach.")
	TEST_ASSERT_NOTEQUAL(found, seeker_turf, "Cover search returned the exposed tile the seeker is already on.")

	var/covered_quality = ms13_shot_quality(threat_turf, found)
	TEST_ASSERT(covered_quality < exposed_quality, "Chosen cover ([covered_quality]) is no better than standing in the open ([exposed_quality]).")

	qdel(obstacle)
