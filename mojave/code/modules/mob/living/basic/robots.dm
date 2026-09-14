/mob/living/basic/ms13/robot
	name = "robot"
	desc = "beep boop you have dysentery."
	icon = 'mojave/icons/mob/ms13robots.dmi'
	icon_state = "assaultron"
	mob_biotypes = MOB_ROBOTIC
	gender = NEUTER
	health = 150
	maxHealth = 150
	speed = 1
	attack_verb_continuous = "dissects"
	attack_verb_simple = "stabs"
	melee_damage_lower = 10
	melee_damage_upper = 10
	attack_sound = 'sound/weapons/punch1.ogg'
	deathsound = 'mojave/sound/ms13npc/robot_death.ogg'
	combat_mode = TRUE
	faction = list("robots")
	speak_emote = list("states","dictates")
	var/shadow_type = null // For shadows below floating robots

	ai_controller = /datum/ai_controller/basic_controller/ms13/robot

/mob/living/basic/ms13/robot/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/death_drops, list(/obj/effect/decal/cleanable/robot_debris))

/datum/ai_controller/basic_controller/ms13/robot
	// AI EDIT: BB_TARGETTING_DATUM/targetting_datum (old spelling, instantiated) doesn't exist - DD's real key is
	// BB_TARGETING_STRATEGY, holding a type path (not an instance), confirmed against DD's own cockroach.dm.
	// AI EDIT (bugfix): see the matching comment in hostile_animals.dm - /datum/targeting_strategy/basic's
	// can_attack() is an abstract stub that always fails, so this mob could never actually acquire a target.
	// Switched to /datum/targeting_strategy/generic (DD's real implementation).
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/generic,
		BB_TARGET_MINIMUM_STAT = DEAD,
	)

	ai_movement = /datum/ai_movement/basic_avoidance/bypass_tables
	default_behavior = /datum/ai_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/ms13/robot,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree/ms13/robot,
		/datum/ai_planning_subtree/find_and_hunt_target
	)

/datum/ai_planning_subtree/basic_melee_attack_subtree/ms13/robot
	melee_attack_behavior = /datum/ai_behavior/basic_melee_attack/ms13/robot

/datum/ai_behavior/basic_melee_attack/ms13/robot
	action_cooldown = 1.5 SECONDS

/mob/living/basic/ms13/robot/handy
    name = "Mr. Handy"
    desc = "A standard model Mr. Handy unit. It's long lost any rational wires in its circuits."
    icon_state = "mrhandy_claw"
    health = 130
    maxHealth = 130
    melee_damage_lower = 15
    melee_damage_upper = 15
    subtractible_armour_penetration = 5
    speed = 0.5
    speak_emote = list("states", "says")
    attack_verb_continuous = "pinches"
    attack_verb_simple = "pinch"
    attack_sound = 'mojave/sound/ms13weapons/meleesounds/pipe_hit.ogg'
    sharpness = NONE
    shadow_type = "shadow_large"

/mob/living/basic/ms13/robot/handy/New()
    ..()
    add_overlay(image(icon, "[shadow_type]", BELOW_MOB_LAYER, dir))

// AI EDIT: added gibbed/cause_of_death - see atmosphere.dm's /mob/living/death() for why.
/mob/living/basic/ms13/robot/handy/death(gibbed, cause_of_death = "Unknown")
	. = ..()
	do_sparks(3, TRUE, src)
	new /obj/item/stack/sheet/ms13/scrap/two(loc)
	new /obj/item/stack/sheet/ms13/scrap_parts(loc)
	new /obj/item/stack/sheet/ms13/scrap_electronics(loc)
	playsound(src, 'mojave/sound/ms13npc/robot_death.ogg', 60, TRUE)
	qdel(src)

/mob/living/basic/ms13/robot/handy/saw
    desc = "A work model Mr. Handy unit, armed with a horrifyingly sharp saw. It's long lost any rational wires in its circuits."
    icon_state = "mrhandy_saw"
    melee_damage_lower = 25
    melee_damage_upper = 25
    subtractible_armour_penetration = 15
    sharpness = SHARP_EDGED
    attack_verb_continuous = "saws"
    attack_verb_simple = "saw"
    attack_sound = list('mojave/sound/ms13weapons/meleesounds/ripper_hit1.ogg', 'mojave/sound/ms13weapons/meleesounds/ripper_hit2.ogg')

/**
 * The reference consumer for the cover AI in mojave/code/datums/ai/ms13_cover_ai.dm - a ranged mob on the
 * modern controller framework, which until now only drove melee ones (every existing gun-carrying robot is
 * on the legacy simple_animal AI instead). It takes cover when shot at and keeps firing at where it last saw
 * you after you break line of sight.
 */
/mob/living/basic/ms13/robot/handy/gun
	name = "Mr. Gutsy"
	desc = "A combat model Mr. Handy, still running a war's worth of engagement doctrine on badly degraded tape."
	icon_state = "mrhandy_gun"
	health = 160
	maxHealth = 160
	melee_damage_lower = 10
	melee_damage_upper = 10
	speed = 0.75
	attack_verb_continuous = "batters"
	attack_verb_simple = "batter"
	attack_sound = 'sound/weapons/punch1.ogg'
	sharpness = NONE
	ai_controller = /datum/ai_controller/basic_controller/ms13/robot/gunner

/mob/living/basic/ms13/robot/handy/gun/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/ranged_attacks, /obj/item/ammo_casing/ms13/c10mm)

/datum/ai_controller/basic_controller/ms13/robot/gunner
	// Cover-seeking needs to actually path around the thing it's getting behind, which the shared
	// bypass_tables mover can't do - it walks straight lines and vaults.
	ai_movement = /datum/ai_movement/jps
	planning_subtrees = list(
		/datum/ai_planning_subtree/random_speech/ms13/robot,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/ms13_combat_awareness,
		/datum/ai_planning_subtree/ms13_take_cover,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree,
		/datum/ai_planning_subtree/ms13_suppressing_fire,
	)
