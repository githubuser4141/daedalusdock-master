TYPEINFO_DEF(/mob/living/simple_animal/hostile/ms13/robot/handy)
	default_armor = list(PUNCTURE = ARMOR_HANDGUNS - 20, BLUNT = 25, SLASH = 30)
	default_subarmor = list(CUTTING = 5)

/mob/living/simple_animal/hostile/ms13/robot/handy
	name = "Mr. Handy"
	desc = "A standard model Mr. Handy unit. It's long lost any rational wires in its circuits."
	icon_state = "mrhandy_claw"
	icon_living = "mrhandy_claw"
	health = 130
	maxHealth = 130
	melee_damage_lower = 15
	melee_damage_upper = 15
	subtractible_armour_penetration = 5
	move_to_delay = 3
	speed = 1
	sharpness = NONE
	speak_emote = list("states", "says")
	attack_verb_continuous = "pinches"
	attack_verb_simple = "pinch"
	attack_sound = 'mojave/sound/ms13weapons/meleesounds/pipe_hit.ogg'
	footstep_type = null
	stat_attack = UNCONSCIOUS
	shadow_type = "shadow_large"
	/// Throttles cover searches for the legacy simple-animal gun variants.
	var/next_cover_attempt = 0

/mob/living/simple_animal/hostile/ms13/robot/handy/New()
	..()
	add_overlay(image(icon, "[shadow_type]", BELOW_MOB_LAYER, dir))

// AI EDIT: added gibbed/cause_of_death - see atmosphere.dm's /mob/living/death() for why.
/mob/living/simple_animal/hostile/ms13/robot/handy/death(gibbed, cause_of_death = "Unknown")
	. = ..()
	do_sparks(3, TRUE, src)
	playsound(src, 'mojave/sound/ms13npc/robot_death.ogg', 60, TRUE)
	qdel(src)

/**
 * Armed Handies predate the controller AI and otherwise inherit hostile.dm's ranged kiting: move directly
 * away from the target one tile at a time, with no pathfinding. Use the same cover picker and JPS movement
 * as the modern gunner instead. Melee Handies retain their original movement unchanged.
 */
/mob/living/simple_animal/hostile/ms13/robot/handy/MoveToTarget(list/possible_targets)
	if(!ranged || !target || !(target in possible_targets))
		return ..()

	if(world.time >= next_cover_attempt && can_see(src, target, blind_fire_los_range) && ms13_shot_quality(target, src) >= MS13_AI_EXPOSED_THRESHOLD)
		next_cover_attempt = world.time + 4 SECONDS
		var/turf/cover_turf = ms13_find_cover_turf(src, target)
		if(cover_turf)
			var/atom/target_from = GET_TARGETS_FROM(src)
			if(!target.Adjacent(target_from) && ranged_cooldown <= world.time)
				OpenFire(target)
			Goto(cover_turf, move_to_delay, 0)
			return TRUE

	return ..()

/mob/living/simple_animal/hostile/ms13/robot/handy/Goto(target, delay, minimum_distance)
	if(!ranged)
		return ..()
	if(prevent_goto_movement)
		return FALSE
	approaching_target = target == src.target
	return !!SSmove_manager.jps_move(
		src,
		target,
		delay,
		repath_delay = 0.5 SECONDS,
		max_path_length = AI_MAX_PATH_LENGTH,
		minimum_distance = minimum_distance,
		simulated_only = !HAS_TRAIT(src, TRAIT_FREE_FLOAT_MOVEMENT),
		flags = MOVEMENT_LOOP_IGNORE_GLIDE,
	)

/mob/living/simple_animal/hostile/ms13/robot/handy/saw
	desc = "A work model Mr. Handy unit, armed with a horrifyingly sharp saw. It's long lost any rational wires in its circuits."
	icon_state = "mrhandy_saw"
	icon_living = "mrhandy_saw"
	melee_damage_lower = 30
	melee_damage_upper = 30
	armor_penetration = 10 // AI EDIT: armour_penetration -> armor_penetration (DD's real spelling for this var)
	sharpness = SHARP_EDGED
	attack_verb_continuous = "saws"
	attack_verb_simple = "saw"
	attack_sound = 'sound/weapons/circsawhit.ogg'

/mob/living/simple_animal/hostile/ms13/robot/handy/gun
	desc = "An armed model of Mr. Handy unit. It's long lost any rational wires in its circuits. It's equipped with a ballistic firearm!"
	icon_state = "mrhandy_gun"
	icon_living = "mrhandy_gun"
	minimum_distance = MS13_AI_ENGAGE_RANGE
	retreat_distance = null
	move_to_delay = 1
	loot = list(/obj/item/stack/sheet/ms13/scrap/two, /obj/effect/decal/cleanable/robot_debris, /obj/item/stack/sheet/ms13/scrap_electronics/two, /obj/item/stack/sheet/ms13/scrap_parts/two, /obj/item/ms13/component/cell)
	ranged = TRUE
	ranged_cooldown = 1.65 SECONDS
	casingtype = /obj/item/ammo_casing/ms13/a762/junk/handy
	projectilesound = 'mojave/sound/ms13weapons/chinesearfire.ogg'

TYPEINFO_DEF(/mob/living/simple_animal/hostile/ms13/robot/handy/gutsy)
	default_armor = list(PUNCTURE = ARMOR_HANDGUNS - 10, BLUNT = 25, SLASH = 50)
	default_subarmor = list(CUTTING = 5, PIERCING = 5)

/mob/living/simple_animal/hostile/ms13/robot/handy/gutsy
	name = "Mr. Gutsy"
	desc = "A militarized version of the Handy model. Equiped with a compact plasma rifle, it's a dangerous foe."
	icon_state = "mrhandy_gutsy"
	icon_living = "mrhandy_gutsy"
	health = 165
	maxHealth = 165
	melee_damage_lower = 30
	melee_damage_upper = 30
	subtractible_armour_penetration = 15
	sharpness = SHARP_EDGED
	minimum_distance = MS13_AI_ENGAGE_RANGE
	retreat_distance = null
	move_to_delay = 1
	loot = list(/obj/item/stack/sheet/ms13/scrap_steel/two, /obj/effect/decal/cleanable/robot_debris, /obj/item/stack/sheet/ms13/scrap_electronics/two, /obj/item/stack/sheet/ms13/scrap_parts/two, /obj/item/ms13/component/plasma_battery, /obj/item/stack/sheet/ms13/circuits)
	ranged = TRUE
	ranged_cooldown = 2 SECONDS
	casingtype = /obj/item/ammo_casing/energy/ms13/plasma/gutsy
	projectilesound = 'mojave/sound/ms13weapons/gunsounds/plasrifle/plasma_3.ogg'
	attack_sound = list('mojave/sound/ms13weapons/meleesounds/ripper_hit1.ogg', 'mojave/sound/ms13weapons/meleesounds/ripper_hit2.ogg')
