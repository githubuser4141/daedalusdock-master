/mob/living/basic
	var/subtractible_armour_penetration = 0

// The living parent only announces basic-mob hits; each victim branch applies damage.
/mob/living/simple_animal/attack_basic_mob(mob/living/basic/user, list/modifiers)
	. = ..()
	if(!.)
		return
	var/damage = rand(user.melee_damage_lower, user.melee_damage_upper)
	if(check_block(user, damage, "the [user.name]", MELEE_ATTACK, user.armor_penetration, user.melee_damage_type))
		return FALSE
	var/armor_block = run_armor_check(user.zone_selected, BLUNT, armor_penetration = user.armor_penetration)
	return apply_damage(damage, user.melee_damage_type, user.zone_selected, armor_block, sharpness = user.sharpness, attack_direction = get_dir(user, src))

#ifdef UNIT_TESTS
/datum/unit_test/ms13_basic_melee/Run()
	var/mob/living/basic/ms13/hostile_animal/attacker = allocate(/mob/living/basic/ms13/hostile_animal, run_loc_floor_bottom_left)
	var/mob/living/simple_animal/victim = allocate(/mob/living/simple_animal, get_step(run_loc_floor_bottom_left, EAST))
	attacker.melee_damage_lower = 10
	attacker.melee_damage_upper = 10
	var/old_health = victim.health
	attacker.melee_attack(victim)
	if(victim.health != old_health - 10)
		Fail("Basic mob melee must damage simple animals exactly once.")
	old_health = victim.health
	attacker.melee_damage_upper = 0
	attacker.melee_attack(victim)
	if(victim.health != old_health)
		Fail("Friendly interactions must not damage simple animals.")
	attacker.melee_damage_upper = 10
	ADD_TRAIT(attacker, TRAIT_PACIFISM, "melee_test")
	attacker.melee_attack(victim)
	if(victim.health != old_health)
		Fail("Pacifist basic mobs must not damage simple animals.")
	REMOVE_TRAIT(attacker, TRAIT_PACIFISM, "melee_test")
	victim.damage_coeff = victim.damage_coeff.Copy()
	victim.damage_coeff[BRUTE] = 0.5
	attacker.melee_attack(victim)
	if(victim.health != old_health - 5)
		Fail("Simple animal damage resistance must apply to basic melee attacks.")
#endif
