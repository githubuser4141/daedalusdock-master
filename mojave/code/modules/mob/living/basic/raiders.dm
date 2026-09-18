// Sprite sheet sourced from Foundation-19/Hail-Mary at commit
// f6fd9c84b520b88f54db9d3a139ef6583865e7b0 under AGPL-3.0.

/mob/living/basic/ms13/raider
	name = "raider"
	desc = "Another murderer churned out by the wastes."
	icon = 'mojave/icons/mob/raiders.dmi'
	icon_state = "raider_melee"
	icon_dead = "raider_dead"
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	health = 100
	maxHealth = 100
	speed = 0.5
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	melee_damage_lower = 5
	melee_damage_upper = 14
	attack_sound = 'sound/weapons/bladeslice.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	combat_mode = TRUE
	faction = list("raider")
	sharpness = SHARP_EDGED
	ai_controller = /datum/ai_controller/basic_controller/ms13/raider

/mob/living/basic/ms13/raider/metal
	name = "armored raider"
	desc = "A raider wrapped in scavenged metal armor."
	icon_state = "metal_raider"
	icon_dead = "metal_raider_dead"
	health = 125
	maxHealth = 125

/mob/living/basic/ms13/raider/firefighter
	name = "firefighter raider"
	desc = "A raider wearing the scorched remains of firefighting gear."
	icon_state = "firefighter_raider"
	icon_dead = "firefighter_raider_dead"
	health = 115
	maxHealth = 115

/mob/living/basic/ms13/raider/tribal
	name = "tribal raider"
	desc = "A lightly equipped raider armed for close combat."
	icon_state = "tribal_raider"
	icon_dead = "tribal_raider_dead"
	health = 110
	maxHealth = 110
	melee_damage_lower = 10
	melee_damage_upper = 18

/mob/living/basic/ms13/raider/baseball
	name = "baseball raider"
	desc = "A raider dressed for a very different kind of ball game."
	icon_state = "baseball_raider"
	icon_dead = "baseball_raider_dead"
	health = 120
	maxHealth = 120
	melee_damage_lower = 12
	melee_damage_upper = 20

/mob/living/basic/ms13/raider/badlands
	name = "badlands raider"
	desc = "A hardened raider who has survived long enough to become dangerous."
	icon_state = "badland_raider"
	icon_dead = "badland_raider_dead"
	health = 145
	maxHealth = 145
	melee_damage_lower = 14
	melee_damage_upper = 23

/mob/living/basic/ms13/raider/sulphite
	name = "sulphite brawler"
	desc = "A heavily armed raider carrying a vicious heated blade."
	icon_state = "sulphite"
	icon_dead = "sulphite_dead"
	health = 160
	maxHealth = 160
	melee_damage_lower = 16
	melee_damage_upper = 26

/mob/living/basic/ms13/raider/boss
	name = "raider boss"
	desc = "A seasoned raider whose scars and heavy gear mark them as the one in charge."
	icon_state = "raiderboss"
	icon_dead = "raiderboss_dead"
	health = 225
	maxHealth = 225
	melee_damage_lower = 18
	melee_damage_upper = 30

/datum/ai_controller/basic_controller/ms13/raider
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/generic,
		BB_TARGET_MINIMUM_STAT = DEAD,
	)
	ai_movement = /datum/ai_movement/basic_avoidance/bypass_tables
	default_behavior = /datum/ai_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree/ms13/raider,
	)

/datum/ai_planning_subtree/basic_melee_attack_subtree/ms13/raider
	melee_attack_behavior = /datum/ai_behavior/basic_melee_attack/ms13/raider

/datum/ai_behavior/basic_melee_attack/ms13/raider
	action_cooldown = 1.5 SECONDS
