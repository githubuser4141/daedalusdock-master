/// What a round gets through depends on its damage and speed as well as its construction.
/datum/unit_test/bullet_barrier_penetration/Run()
	// Armor ratings in the range walls use: brick-like, sheet-metal-like and log-like.
	var/brick_stop = ms13_armor_stopping_power(40)
	var/sheet_stop = ms13_armor_stopping_power(5)
	var/log_stop = ms13_armor_stopping_power(15)

	var/obj/projectile/bullet/ms13/c22/small = allocate(/obj/projectile/bullet/ms13/c22)
	var/obj/projectile/bullet/ms13/c45/pistol = allocate(/obj/projectile/bullet/ms13/c45)
	var/obj/projectile/bullet/ms13/a762/rifle = allocate(/obj/projectile/bullet/ms13/a762)
	var/obj/projectile/bullet/bmg50/heavy = allocate(/obj/projectile/bullet/bmg50)

	TEST_ASSERT_EQUAL(ms13_bullet_stop_fraction(brick_stop, 0.1, small), 1, "A .22 got through brick.")
	TEST_ASSERT_EQUAL(ms13_bullet_stop_fraction(brick_stop, 0.1, pistol), 1, "A .45 got through brick.")
	// 10 is MS13_BULLET_OVERPEN_MIN_REMAINING; mojave defines aren't visible from code/.
	TEST_ASSERT(small.damage * (1 - ms13_bullet_stop_fraction(sheet_stop, 0.1, small)) >= 10, "A .22 could not get through sheet metal.")
	TEST_ASSERT(ms13_bullet_stop_fraction(brick_stop, 0.1, rifle) < 1, "A 7.62 could not get through brick.")
	TEST_ASSERT(ms13_bullet_stop_fraction(log_stop, 0.1, rifle) < ms13_bullet_stop_fraction(brick_stop, 0.1, rifle), "Logs stopped as much of a rifle round as brick did.")
	TEST_ASSERT(ms13_bullet_stop_fraction(brick_stop, 0.1, heavy) < ms13_bullet_stop_fraction(brick_stop, 0.1, rifle), "A .50 BMG lost as much to brick as a 7.62.")

	// Hard armor needs a fast round to dig into it; soft barriers don't care.
	var/obj/projectile/bullet/ms13/c45/slow = allocate(/obj/projectile/bullet/ms13/c45)
	TEST_ASSERT_EQUAL(ms13_armor_stopping_power(5, slow), sheet_stop, "Sheet metal resisted a slow .45 harder than its armor says.")
	TEST_ASSERT(ms13_armor_stopping_power(65, slow) > ms13_armor_stopping_power(65), "Armor plate resisted a slow .45 no harder than a fast round.")
	TEST_ASSERT_EQUAL(ms13_armor_stopping_power(65, rifle), ms13_armor_stopping_power(65), "Armor plate resisted a fast rifle round harder than its armor says.")

	var/fast_fraction = ms13_bullet_stop_fraction(log_stop, 0.1, rifle)
	rifle.speed *= 3
	TEST_ASSERT(ms13_bullet_stop_fraction(log_stop, 0.1, rifle) > fast_fraction, "A slowed round penetrated as well as a fast one.")

/// A round's damage is shared between everything it hits, never added to.
/datum/unit_test/bullet_damage_conservation/Run()
	var/obj/structure/window/ms13_vehicle_wall/solid/plate = ALLOCATE_BOTTOM_LEFT()
	plate.setArmor(getArmor(puncture = 10))
	plate.bullet_damage_ratio = 1
	var/mob/living/carbon/human/consistent/victim = ALLOCATE_BOTTOM_LEFT()
	var/obj/projectile/bullet/ms13/a762/bullet = ALLOCATE_BOTTOM_LEFT()
	var/start_damage = bullet.damage

	var/plate_before = plate.get_integrity()
	var/result = bullet.penetrating_hit(plate, null, FALSE)
	TEST_ASSERT_EQUAL(result, BULLET_ACT_FORCE_PIERCE, "A rifle round did not get through a thin plate.")
	var/plate_taken = plate_before - plate.get_integrity()
	TEST_ASSERT(plate_taken > 0, "The plate took no damage from a round it stopped part of.")
	TEST_ASSERT(plate_taken + bullet.damage <= start_damage + 0.01, "Plate damage ([plate_taken]) plus the round's leftover ([bullet.damage]) exceeded its [start_damage] damage.")

	var/reaching_body = bullet.damage
	var/brute_before = victim.getBruteLoss()
	var/organ_before = 0
	for(var/obj/item/organ/organ as anything in victim.organs)
		organ_before += organ.damage
	result = bullet.penetrating_hit(victim, BODY_ZONE_CHEST, FALSE)
	var/organ_after = 0
	for(var/obj/item/organ/organ as anything in victim.organs)
		organ_after += organ.damage
	var/body_taken = (victim.getBruteLoss() - brute_before) + (organ_after - organ_before)
	var/leftover = result == BULLET_ACT_FORCE_PIERCE ? bullet.damage : 0
	TEST_ASSERT(body_taken > 0, "The body took no damage.")
	TEST_ASSERT(body_taken + leftover <= reaching_body + 0.01, "Body damage ([body_taken]) plus the round's leftover ([leftover]) exceeded the [reaching_body] that reached the body.")

/// A round that bounces off armor does less to it than one that punches through.
/datum/unit_test/bullet_barrier_damage_falloff/Run()
	var/obj/structure/window/ms13_vehicle_wall/solid/plate = ALLOCATE_BOTTOM_LEFT()
	plate.setArmor(getArmor(puncture = 65))
	var/obj/projectile/bullet/ms13/c45/pistol = ALLOCATE_BOTTOM_LEFT()
	var/obj/projectile/bullet/ms13/a50MG/heavy = ALLOCATE_BOTTOM_LEFT()

	var/before = plate.get_integrity()
	TEST_ASSERT_NOTEQUAL(pistol.penetrating_hit(plate, null, FALSE), BULLET_ACT_FORCE_PIERCE, "A .45 got through light armor.")
	var/pistol_taken = before - plate.get_integrity()
	before = plate.get_integrity()
	TEST_ASSERT_EQUAL(heavy.penetrating_hit(plate, null, FALSE), BULLET_ACT_FORCE_PIERCE, "A .50 BMG did not get through light armor.")
	TEST_ASSERT(before - plate.get_integrity() > pistol_taken, "A .45 that bounced off light armor hurt it as much as a .50 BMG that went through.")
