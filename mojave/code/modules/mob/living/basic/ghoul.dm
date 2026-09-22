/mob/living/basic/ms13/ghoul
	name = "feral ghoul"
	desc = "A rotting, deformed ghoul that has gone feral either due to excess radiation exposure or simply the test of time."
	icon = 'mojave/icons/mob/ms13enemies.dmi'
	icon_state = "feralghoul"
	icon_dead = "feralghoul_dead"
	mob_biotypes = MOB_HUMANOID
	gender = MALE
	health = 100
	maxHealth = 100
	speed = 0.25
	attack_verb_continuous = "tears"
	attack_verb_simple = "claws"
	melee_damage_lower = 22
	melee_damage_upper = 22
	subtractible_armour_penetration = 5
	attack_sound = list('mojave/sound/ms13npc/ghoul_attack1.ogg', 'mojave/sound/ms13npc/ghoul_attack2.ogg', 'mojave/sound/ms13npc/ghoul_attack3.ogg')
	deathsound = list('mojave/sound/ms13npc/ghoul_death1.ogg', 'mojave/sound/ms13npc/ghoul_death2.ogg', 'mojave/sound/ms13npc/ghoul_death3.ogg')
	combat_mode = TRUE
	faction = list("ghoul")
	speak_emote = list("grumbles","growls")
	sharpness = SHARP_EDGED

	ai_controller = /datum/ai_controller/basic_controller/ms13/ghoul

/mob/living/basic/ms13/ghoul/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/basic_body_temp_sensitive, cold_damage = 7.5, heat_damage = 7.5)
	AddElement(/datum/element/atmos_requirements, list("min_oxy" = 5, "max_oxy" = 0, "min_plas" = 0, "max_plas" = 1, "min_co2" = 0, "max_co2" = 5, "min_n2" = 0, "max_n2" = 0), 7.5)

// AI EDIT: added gibbed/cause_of_death - see atmosphere.dm's /mob/living/death() for why.
/mob/living/basic/ms13/ghoul/death(gibbed, cause_of_death = "Unknown")
	. = ..()
	playsound(src, 'mojave/sound/ms13npc/ghoul_death2.ogg', 60, TRUE)

/datum/ai_controller/basic_controller/ms13/ghoul
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
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree/ms13/ghoul,
		/datum/ai_planning_subtree/random_speech/ms13/ghoul
	)

/datum/ai_planning_subtree/basic_melee_attack_subtree/ms13/ghoul
	melee_attack_behavior = /datum/ai_behavior/basic_melee_attack/ms13/ghoul

/datum/ai_behavior/basic_melee_attack/ms13/ghoul
	action_cooldown = 1.5 SECONDS

// Corpse attacks are idle work: periodically let a living threat preempt them.
// Keep the timer on the controller, not the shared behavior datum.
/datum/ai_controller/basic_controller/ms13
	COOLDOWN_DECLARE(living_threat_scan)

/datum/ai_controller/basic_controller/ms13/able_to_plan()
	if(QDELETED(pawn) || HAS_TRAIT(pawn, TRAIT_AI_DISABLE_PLANNING))
		return FALSE
	. = ..()
	if(.)
		return
	var/mob/living/current_target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	return istype(current_target) && current_target.stat == DEAD && COOLDOWN_FINISHED(src, living_threat_scan)

/datum/ai_controller/basic_controller/ms13/ProcessBehaviorSelection(delta_time)
	var/atom/current_target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	var/mob/living/current_mob = current_target
	var/mob/living/living_pawn = pawn
	// Pack followers take the leader's target instead (mojave/code/modules/mob/ms13_packs/packs.dm).
	var/follower = istype(living_pawn) && living_pawn.ms13_pack?.follows(living_pawn)
	if(!follower && (!current_target || QDELETED(current_target) || (istype(current_mob) && current_mob.stat == DEAD)) && COOLDOWN_FINISHED(src, living_threat_scan))
		COOLDOWN_START(src, living_threat_scan, 2 SECONDS)
		var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
		var/list/threats = hearers(9, pawn) + visible_hostile_machines(pawn, 9)
		for(var/atom/threat as anything in threats)
			var/mob/living/living_threat = threat
			if(threat == pawn || (istype(living_threat) && living_threat.stat == DEAD) || !strategy.can_attack(pawn, threat, 9))
				continue
			CancelActions()
			set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, threat)
			set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION, strategy.find_hidden_mobs(pawn, threat))
			break
	return ..()

/mob/living/basic/ms13/ghoul/brown
	icon_state = "feralghoul_brown"
	icon_dead = "feralghoul_brown_dead"

/mob/living/basic/ms13/ghoul/frozen
	name = "frozen feral ghoul"
	desc = "A frozen feral ghoul that has decided to seek heat once more. It's a miracle they can walk with all that ice in them."
	icon_state = "iceghoul"
	icon_dead = "iceghoul_dead"
	health = 140
	maxHealth = 140
	speed = 1.35
	melee_damage_lower = 22
	melee_damage_upper = 22
	subtractible_armour_penetration = 20

/mob/living/basic/ms13/ghoul/radioactive
	name = "glowing feral ghoul"
	desc = "A glowing, calloused ghoul. It looks like it has spent is entire lifetime sitting in a radioactive lake, as the damn thing can probably power a building if you hooked it up."
	icon_state = "glowingghoul"
	icon_dead = "glowingghoul_dead"
	health = 125
	maxHealth = 125
	melee_damage_lower = 26
	melee_damage_upper = 26
	subtractible_armour_penetration = 20
	light_outer_range = 2
	light_color = "#4ba54f"
