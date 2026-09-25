/**
 * Monsters from Cataclysm: Dark Days Ahead, drawn with the Ultimate Cataclysm tileset (mojave/icons/cdda_ultimate_cataclysm,
 * CC BY-SA 3.0). The zombies are CDDA's: the shambling dead, and the shockers, boomers, brutes and hulks they turn into.
 * The rest came through from the Nether: mi-go, shoggoths, flaming eyes and their like.
 *
 * The sprites face one way, and CDDA leaves a corpse item rather than drawing one, so a dead one falls on its side.
 */
/mob/living/simple_animal/hostile/ms13/cdda
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters_32x48.dmi'
	faction = list("cdda")
	see_in_dark = 8
	vision_range = 9
	aggro_vision_range = 9
	speak_chance = 5
	attack_verb_continuous = "claws"
	attack_verb_simple = "claw"
	/// Sprites it's drawn with, one picked at random.
	var/list/looks
	/// Chance a blow knocks its target off their feet, and how far it throws them.
	var/knockdown_chance = 0
	var/throw_distance = 1
	/// Its charge, if it has one: it rushes whoever it's after from a few tiles off.
	var/datum/action/cooldown/mob_cooldown/charge/charge

/mob/living/simple_animal/hostile/ms13/cdda/Initialize(mapload)
	. = ..()
	if(charge)
		charge = new charge()
		charge.Grant(src)
	if(length(looks))
		icon_state = pick(looks)
	icon_living = icon_state
	icon_dead = icon_state
	// Drawn wider than a tile, it stands centred on its own.
	base_pixel_x = (world.icon_size - ms13_icon_size(icon)[1]) / 2
	pixel_x = base_pixel_x

/mob/living/simple_animal/hostile/ms13/cdda/death(gibbed, cause_of_death = "Unknown")
	. = ..()
	if(gibbed || QDELETED(src))
		return
	// On its side, still on its own tile.
	var/list/size = ms13_icon_size(icon)
	var/matrix/lying = matrix()
	lying.Turn(90)
	lying.Translate(0, (size[1] - size[2]) / 2)
	transform = lying

/mob/living/simple_animal/hostile/ms13/cdda/AttackingTarget(atom/attacked_target)
	. = ..()
	if(!. || !isliving(target) || !prob(knockdown_chance))
		return
	var/mob/living/victim = target
	victim.Knockdown(1 SECONDS)
	victim.throw_at(get_edge_target_turf(victim, get_dir(src, victim)), throw_distance, 1, src)

/mob/living/simple_animal/hostile/ms13/cdda/OpenFire(atom/aimed_at)
	if(!charge)
		return ..()
	if(get_dist(src, aimed_at) < 3 || !charge.IsAvailable() || !ms13_can_see(src, aimed_at, vision_range))
		return
	ranged_cooldown = world.time + ranged_cooldown_time
	INVOKE_ASYNC(src, PROC_REF(rush), aimed_at)

/// Stands for its wind-up, rushes, and goes back to the chase.
/mob/living/simple_animal/hostile/ms13/cdda/proc/rush(atom/aimed_at)
	prevent_goto_movement = TRUE
	SSmove_manager.stop_looping(src)
	charge.Trigger(target = aimed_at)
	prevent_goto_movement = FALSE

/// A rush that bowls over whoever it hits and flings them aside. It batters through what's in its way.
/datum/action/cooldown/mob_cooldown/charge/cdda
	charge_delay = 0.8 SECONDS
	charge_speed = 0.1 SECONDS
	charge_past = 2
	charge_distance = 8
	cooldown_time = 8 SECONDS
	charge_damage = 30
	/// How far it flings whoever it hits.
	var/fling = 2

/datum/action/cooldown/mob_cooldown/charge/cdda/on_bump(atom/movable/source, atom/target)
	if(owner == target)
		return
	INVOKE_ASYNC(src, PROC_REF(DestroySurroundings), source)
	hit_target(source, target, charge_damage)

/datum/action/cooldown/mob_cooldown/charge/cdda/hit_target(atom/movable/source, atom/target, damage_dealt)
	. = ..()
	if(!isliving(target))
		return
	var/mob/living/victim = target
	victim.Knockdown(2 SECONDS)
	victim.throw_at(get_edge_target_turf(victim, source.dir), fling, 2, source)

/// A hulk's rush blasts through walls and all, and it comes on twice more. Where each one ends, it slams the ground.
/datum/action/cooldown/mob_cooldown/charge/cdda/hulk
	charge_delay = 1.2 SECONDS
	charge_past = 3
	charge_distance = 12
	cooldown_time = 12 SECONDS
	charge_damage = 45
	fling = 4
	var/rushes = 3
	var/slam_range = 2
	var/slam_damage = 15

/datum/action/cooldown/mob_cooldown/charge/cdda/hulk/on_bump(atom/movable/source, atom/target)
	if(isturf(target) || (isobj(target) && target.density))
		EX_ACT(target, EXPLODE_HEAVY)
	return ..()

/datum/action/cooldown/mob_cooldown/charge/cdda/hulk/charge_sequence(atom/movable/charger, atom/target_atom, delay, past)
	var/mob/living/simple_animal/hostile/hulk = owner
	for(var/rush in 1 to rushes)
		if(QDELETED(target_atom) || hulk.stat == DEAD || !do_charge(charger, target_atom, delay, past))
			return
		slam(charger)
		target_atom = hulk.target

/datum/action/cooldown/mob_cooldown/charge/cdda/hulk/proc/slam(atom/movable/charger)
	var/turf/landing = get_turf(charger)
	var/mob/living/hulk = owner
	charger.visible_message(span_danger("[charger] slams into the ground!"))
	playsound(landing, 'sound/effects/meteorimpact.ogg', 100, TRUE)
	for(var/mob/living/caught in range(slam_range, landing))
		if(caught == charger || hulk.faction_check_atom(caught))
			continue
		caught.apply_damage(slam_damage, BRUTE)
		caught.Knockdown(1.5 SECONDS)
		shake_camera(caught, 3, 2)

/// An icon file's frame size, list(width, height). Looked up once per file.
/proc/ms13_icon_size(icon_file)
	var/static/list/sizes = list()
	var/key = "[icon_file]"
	if(!sizes[key])
		var/icon/sheet = icon(icon_file)
		sizes[key] = list(sheet.Width(), sheet.Height())
	return sizes[key]

/mob/living/simple_animal/hostile/ms13/cdda/zombie
	name = "zombie"
	desc = "A dead man on his feet, swaying, arms reaching. Its eyes have gone black and wet."
	looks = list("mon_zombie_#0", "mon_zombie_#1", "mon_zombie_#2", "mon_zombie_#3", "mon_zombie_#4")
	mob_biotypes = MOB_ORGANIC|MOB_HUMANOID|MOB_UNDEAD
	health = 120
	maxHealth = 120
	melee_damage_lower = 15
	melee_damage_upper = 25
	obj_damage = 20
	speed = 3
	move_to_delay = 5
	speak_emote = list("groans")
	emote_hear = list("groans.", "moans.")
	attack_verb_continuous = "claws"
	attack_verb_simple = "claw"
	attack_sound = list('mojave/sound/ms13npc/ghoul_attack1.ogg', 'mojave/sound/ms13npc/ghoul_attack2.ogg', 'mojave/sound/ms13npc/ghoul_attack3.ogg')
	deathsound = list('mojave/sound/ms13npc/ghoul_death1.ogg', 'mojave/sound/ms13npc/ghoul_death2.ogg', 'mojave/sound/ms13npc/ghoul_death3.ogg')

/// Lightning arcs off it at whoever it's after, and through its claws, and on from them to whoever's nearest.
/mob/living/simple_animal/hostile/ms13/cdda/zombie/shocker
	name = "shocker zombie"
	desc = "A zombie crackling with static, sparks jumping between its fingers."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters_64x64.dmi'
	looks = list("mon_zombie_electric_#0", "mon_zombie_electric_#1")
	health = 130
	maxHealth = 130
	move_to_delay = 4
	ranged = TRUE
	ranged_cooldown_time = 6 SECONDS
	var/zap_range = 4
	var/zap_damage = 15

/mob/living/simple_animal/hostile/ms13/cdda/zombie/shocker/OpenFire(atom/aimed_at)
	if(!isliving(aimed_at) || get_dist(src, aimed_at) > zap_range || !ms13_can_see(src, aimed_at, zap_range))
		return
	ranged_cooldown = world.time + ranged_cooldown_time
	zap(aimed_at, zap_damage)

/mob/living/simple_animal/hostile/ms13/cdda/zombie/shocker/AttackingTarget(atom/attacked_target)
	. = ..()
	if(. && isliving(target))
		zap(target, zap_damage / 2)

/mob/living/simple_animal/hostile/ms13/cdda/zombie/shocker/proc/zap(mob/living/victim, damage)
	// As the tesla's does, what's left arcs on, weaker with every jump. It passes creatures by.
	tesla_zap(victim, 3, tesla_zap_target(src, victim, damage * TESLA_MOB_DAMAGE_COEFF, ZAP_MOB_DAMAGE), ZAP_MOB_DAMAGE)

/// It spews bile that blinds, and when it dies it bursts, in a blast and a spray of it.
/mob/living/simple_animal/hostile/ms13/cdda/zombie/boomer
	name = "boomer"
	desc = "A grossly bloated zombie, skin stretched tight over something that sloshes."
	looks = list("mon_boomer")
	health = 90
	maxHealth = 90
	melee_damage_lower = 8
	melee_damage_upper = 12
	move_to_delay = 6
	ranged = TRUE
	ranged_cooldown_time = 8 SECONDS
	var/bile_range = 3
	/// How big a blast it bursts in.
	var/blast_heavy = 0
	var/blast_light = 1

/mob/living/simple_animal/hostile/ms13/cdda/zombie/boomer/OpenFire(atom/aimed_at)
	if(get_dist(src, aimed_at) > bile_range || !ms13_can_see(src, aimed_at, bile_range))
		return
	ranged_cooldown = world.time + ranged_cooldown_time
	visible_message(span_danger("[src] spews a stream of bile at [aimed_at]!"))
	spew(get_turf(aimed_at), 0)

/mob/living/simple_animal/hostile/ms13/cdda/zombie/boomer/death(gibbed, cause_of_death = "Unknown")
	var/turf/burst = get_turf(src)
	. = ..()
	visible_message(span_danger("[src] bursts, spraying bile everywhere!"))
	spew(burst, 2)
	explosion(burst, heavy_impact_range = blast_heavy, light_impact_range = blast_light, flash_range = blast_heavy + 1, explosion_cause = src)

/// Splashes bile over everyone within radius of where: it gets in their eyes.
/mob/living/simple_animal/hostile/ms13/cdda/zombie/boomer/proc/spew(turf/where, radius)
	if(!where)
		return
	playsound(where, 'sound/effects/splat.ogg', 60, TRUE)
	new /obj/effect/decal/cleanable/vomit(where)
	for(var/mob/living/carbon/soaked in range(radius, where))
		if(soaked == src || faction_check_atom(soaked))
			continue
		soaked.blur_eyes(8)
		to_chat(soaked, span_userdanger("Foul bile splashes into your eyes!"))

/// A boomer with a claymore strapped across its belly. It goes off when it dies.
/mob/living/simple_animal/hostile/ms13/cdda/zombie/boomer/claymore
	name = "claymore boomer"
	desc = "A bloated zombie with a claymore mine lashed across its belly, its wires trailing."
	looks = list("mon_boomer_claymore")
	blast_heavy = 1
	blast_light = 3

/mob/living/simple_animal/hostile/ms13/cdda/zombie/brute
	name = "zombie brute"
	desc = "A hulking zombie, its muscles swollen hard and its skin split over them."
	looks = list("mon_zombie_brute_#0", "mon_zombie_brute_#1", "mon_zombie_brute_#2", "mon_zombie_brute_#3")
	health = 350
	maxHealth = 350
	melee_damage_lower = 30
	melee_damage_upper = 40
	obj_damage = 60
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	move_to_delay = 3.5
	knockdown_chance = 25
	ranged = TRUE
	ranged_cooldown_time = 3 SECONDS
	charge = /datum/action/cooldown/mob_cooldown/charge/cdda
	attack_verb_continuous = "slams"
	attack_verb_simple = "slam"
	attack_sound = 'mojave/sound/wip/necromorphs/brute_attack_1.ogg'
	deathsound = 'mojave/sound/wip/necromorphs/brute_death.ogg'

/mob/living/simple_animal/hostile/ms13/cdda/zombie/hulk
	name = "zombie hulk"
	desc = "A mountain of dead flesh twice a man's height, with fists like sledgehammers."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters_64x96.dmi'
	looks = list("mon_zombie_hulk")
	health = 900
	maxHealth = 900
	melee_damage_lower = 50
	melee_damage_upper = 70
	obj_damage = 200
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES | ENVIRONMENT_SMASH_WALLS
	move_to_delay = 3.5
	mob_size = MOB_SIZE_HUGE
	status_flags = NONE
	knockdown_chance = 50
	throw_distance = 3
	ranged = TRUE
	ranged_cooldown_time = 3 SECONDS
	charge = /datum/action/cooldown/mob_cooldown/charge/cdda/hulk
	attack_verb_continuous = "pounds"
	attack_verb_simple = "pound"
	attack_sound = 'mojave/sound/wip/necromorphs/tripod_attack_1.ogg'
	deathsound = 'mojave/sound/wip/necromorphs/tripod_death_1.ogg'

/mob/living/simple_animal/hostile/ms13/cdda/nether
	see_in_dark = 10

/// It calls out in voices it took from people, to draw more in.
/mob/living/simple_animal/hostile/ms13/cdda/nether/mi_go
	name = "mi-go"
	desc = "A pinkish, fungal thing like a crab stood on end, a fan of antennae where its head should be."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters_64x64.dmi'
	looks = list("mon_mi_go")
	health = 180
	maxHealth = 180
	melee_damage_lower = 25
	melee_damage_upper = 35
	obj_damage = 40
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	move_to_delay = 2.8
	sharpness = SHARP_EDGED
	speak_chance = 8
	speak = list("Hello?", "Is anyone there?", "Help me!", "Over here!", "I'm hurt...", "Come closer.", "Where are you?")
	attack_verb_continuous = "lacerates"
	attack_verb_simple = "lacerate"
	attack_sound = 'mojave/sound/wip/necromorphs/slasher_attack_1.ogg'
	deathsound = 'sound/voice/hiss6.ogg'

/mob/living/simple_animal/hostile/ms13/cdda/nether/mi_go/scout
	name = "mi-go scout"
	desc = "A lean, quick mi-go, antennae constantly twitching."
	looks = list("mon_mi_go_scout")
	health = 110
	maxHealth = 110
	melee_damage_lower = 18
	melee_damage_upper = 26
	move_to_delay = 2.2

/mob/living/simple_animal/hostile/ms13/cdda/nether/mi_go/myrmidon
	name = "mi-go myrmidon"
	desc = "A massive mi-go, plated in something between chitin and machinery."
	looks = list("mon_mi_go_myrmidon")
	health = 320
	maxHealth = 320
	melee_damage_lower = 35
	melee_damage_upper = 45
	move_to_delay = 3.2
	knockdown_chance = 20

/// Its wounds close up almost as fast as they're made.
/mob/living/simple_animal/hostile/ms13/cdda/nether/shoggoth
	name = "shoggoth"
	desc = "A heaving mass of black ooze. Eyes and mouths rise through it and sink away again."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters_64x96.dmi'
	looks = list("mon_shoggoth")
	health = 1200
	maxHealth = 1200
	melee_damage_lower = 40
	melee_damage_upper = 60
	obj_damage = 150
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES | ENVIRONMENT_SMASH_WALLS
	move_to_delay = 4.5
	mob_size = MOB_SIZE_HUGE
	status_flags = NONE
	attack_verb_continuous = "engulfs"
	attack_verb_simple = "engulf"
	attack_sound = 'mojave/sound/wip/necromorphs/lurker_attack_1.ogg'
	deathsound = 'mojave/sound/wip/necromorphs/lurker_death_1.ogg'
	/// Health it knits back a second.
	var/regeneration = 5

/mob/living/simple_animal/hostile/ms13/cdda/nether/shoggoth/Life(delta_time = SSMOBS_DT, times_fired)
	. = ..()
	if(stat != DEAD)
		adjustBruteLoss(-regeneration * delta_time)

/// It hangs back, and wherever it looks, things catch fire.
/mob/living/simple_animal/hostile/ms13/cdda/nether/flaming_eye
	name = "flaming eye"
	desc = "A huge eye wreathed in blue fire, drifting a man's height off the ground."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters_64x96.dmi'
	looks = list("mon_flaming_eye")
	health = 260
	maxHealth = 260
	melee_damage_lower = 10
	melee_damage_upper = 15
	melee_damage_type = BURN
	move_to_delay = 4
	movement_type = FLYING
	retreat_distance = 3
	minimum_distance = 4
	ranged = TRUE
	ranged_cooldown_time = 5 SECONDS
	attack_verb_continuous = "sears"
	attack_verb_simple = "sear"
	deathsound = 'sound/magic/fireball.ogg'
	var/gaze_range = 7
	var/gaze_damage = 15

/mob/living/simple_animal/hostile/ms13/cdda/nether/flaming_eye/OpenFire(atom/aimed_at)
	if(!isliving(aimed_at) || get_dist(src, aimed_at) > gaze_range || !ms13_can_see(src, aimed_at, gaze_range))
		return
	ranged_cooldown = world.time + ranged_cooldown_time
	var/mob/living/victim = aimed_at
	Beam(victim, icon_state = "solar_beam", time = 0.5 SECONDS)
	playsound(src, 'sound/magic/fireball.ogg', 50, TRUE)
	victim.adjustFireLoss(gaze_damage)
	victim.adjust_fire_stacks(2)
	victim.ignite_mob()

/mob/living/simple_animal/hostile/ms13/cdda/nether/kreck
	name = "kreck"
	desc = "A small red thing like a skinned dog, all teeth."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters.dmi'
	looks = list("mon_kreck")
	mob_size = MOB_SIZE_SMALL
	health = 50
	maxHealth = 50
	melee_damage_lower = 10
	melee_damage_upper = 14
	move_to_delay = 2.5
	attack_verb_continuous = "bites"
	attack_verb_simple = "bite"
	attack_sound = list('mojave/sound/ms13npc/dog_attack1.ogg', 'mojave/sound/ms13npc/dog_attack2.ogg', 'mojave/sound/ms13npc/dog_attack3.ogg')
	deathsound = list('mojave/sound/ms13npc/dog_death1.ogg', 'mojave/sound/ms13npc/dog_death2.ogg')

/mob/living/simple_animal/hostile/ms13/cdda/nether/gozu
	name = "gozu"
	desc = "A pale, heavily muscled man with the head of a bull. It stinks of the slaughterhouse."
	looks = list("mon_gozu")
	health = 280
	maxHealth = 280
	melee_damage_lower = 30
	melee_damage_upper = 40
	obj_damage = 50
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	move_to_delay = 3.2
	knockdown_chance = 30
	ranged = TRUE
	ranged_cooldown_time = 3 SECONDS
	charge = /datum/action/cooldown/mob_cooldown/charge/cdda
	attack_verb_continuous = "gores"
	attack_verb_simple = "gore"
	emote_hear = list("bellows.")
	attack_sound = list('mojave/sound/ms13npc/brahmin_attack1.ogg', 'mojave/sound/ms13npc/brahmin_attack2.ogg')
	deathsound = 'mojave/sound/ms13npc/brahmin_death1.ogg'

/mob/living/simple_animal/hostile/ms13/cdda/nether/gracke
	name = "gracke"
	desc = "A tall, gaunt black shape, all long limbs ending in blades."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters_32x64.dmi'
	looks = list("mon_gracke")
	health = 220
	maxHealth = 220
	melee_damage_lower = 28
	melee_damage_upper = 38
	move_to_delay = 2.6
	sharpness = SHARP_EDGED
	attack_verb_continuous = "slices"
	attack_verb_simple = "slice"
	attack_sound = 'mojave/sound/wip/necromorphs/slasher_attack_1.ogg'
	deathsound = 'mojave/sound/wip/necromorphs/slasher_death_1.ogg'

/// It steps out of the nearest corner to its prey.
/mob/living/simple_animal/hostile/ms13/cdda/nether/hound_tindalos
	name = "hound of Tindalos"
	desc = "A lean blue-grey shape that seems to come out of the angles of things."
	icon = 'mojave/icons/cdda_ultimate_cataclysm/monsters.dmi'
	looks = list("mon_hound_tindalos_#0", "mon_hound_tindalos_#1", "mon_hound_tindalos_#2", "mon_hound_tindalos_#3", "mon_hound_tindalos_#4", "mon_hound_tindalos_#5", "mon_hound_tindalos_#6", "mon_hound_tindalos_#7", "mon_hound_tindalos_#8")
	health = 150
	maxHealth = 150
	melee_damage_lower = 20
	melee_damage_upper = 30
	move_to_delay = 3
	ranged = TRUE
	ranged_cooldown_time = 8 SECONDS
	attack_verb_continuous = "bites"
	attack_verb_simple = "bite"
	attack_sound = list('mojave/sound/ms13npc/dog_attack1.ogg', 'mojave/sound/ms13npc/dog_attack2.ogg', 'mojave/sound/ms13npc/dog_attack3.ogg')
	deathsound = 'sound/voice/hiss6.ogg'

/mob/living/simple_animal/hostile/ms13/cdda/nether/hound_tindalos/OpenFire(atom/aimed_at)
	var/list/beside = list()
	for(var/turf/open/spot in orange(1, aimed_at))
		if(!spot.is_blocked_turf(TRUE))
			beside += spot
	if(!length(beside))
		return
	ranged_cooldown = world.time + ranged_cooldown_time
	new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(src))
	forceMove(pick(beside))
	new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(src))
	playsound(src, 'sound/magic/blink.ogg', 50, TRUE)

#ifdef UNIT_TESTS
/datum/unit_test/ms13_cdda_monsters
	name = "MOBS: CDDA Monsters Are Drawn, Die Lying Down, And Do Their Tricks"

/datum/unit_test/ms13_cdda_monsters/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
	var/list/states_by_icon = list()
	for(var/monster_type in subtypesof(/mob/living/simple_animal/hostile/ms13/cdda) - /mob/living/simple_animal/hostile/ms13/cdda/nether)
		var/mob/living/simple_animal/hostile/ms13/cdda/monster = allocate(monster_type, spot)
		states_by_icon["[monster.icon]"] ||= icon_states(monster.icon)
		if(!(monster.icon_state in states_by_icon["[monster.icon]"]))
			Fail("[monster_type] has no sprite [monster.icon_state] in [monster.icon].")
		// A boomer bursting is a blast in the test room.
		if(istype(monster, /mob/living/simple_animal/hostile/ms13/cdda/zombie/boomer))
			continue
		monster.death()
		if(monster.transform.b == 0)
			Fail("[monster_type] died standing up.")
		qdel(monster)
	var/mob/living/carbon/human/consistent/survivor = allocate(/mob/living/carbon/human/consistent, get_step(spot, NORTH))
	var/mob/living/simple_animal/hostile/ms13/cdda/zombie/boomer/boomer = allocate(/mob/living/simple_animal/hostile/ms13/cdda/zombie/boomer, spot)
	boomer.OpenFire(survivor)
	if(!survivor.eye_blurry)
		Fail("A boomer's bile didn't get in its target's eyes.")
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, get_step(get_step(spot, NORTH), EAST))
	var/mob/living/simple_animal/hostile/ms13/cdda/zombie/shocker/shocker = allocate(/mob/living/simple_animal/hostile/ms13/cdda/zombie/shocker, spot)
	var/burns = survivor.getFireLoss()
	shocker.OpenFire(survivor)
	if(survivor.getFireLoss() <= burns || !bystander.getFireLoss())
		Fail("A shocker's lightning didn't burn its target, or arc on to the one beside them.")
	var/mob/living/simple_animal/hostile/ms13/cdda/zombie/brute/brute = allocate(/mob/living/simple_animal/hostile/ms13/cdda/zombie/brute, spot)
	var/mob/living/simple_animal/hostile/ms13/cdda/zombie/hulk/hulk = allocate(/mob/living/simple_animal/hostile/ms13/cdda/zombie/hulk, spot)
	if(!istype(brute.charge, /datum/action/cooldown/mob_cooldown/charge/cdda) || !istype(hulk.charge, /datum/action/cooldown/mob_cooldown/charge/cdda/hulk))
		Fail("A brute or a hulk came without its charge.")
	// Up the far side of the room, clear of everyone else.
	brute.forceMove(locate(run_loc_floor_top_right.x, run_loc_floor_bottom_left.y, spot.z))
	var/mob/living/carbon/human/consistent/runner = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_top_right.x, run_loc_floor_bottom_left.y + 3, spot.z))
	brute.charge.Trigger(target = runner)
	if(!runner.getBruteLoss() || runner.body_position != LYING_DOWN)
		Fail("A charging brute didn't bowl over whoever it ran at.")
	var/mob/living/simple_animal/hostile/ms13/cdda/nether/shoggoth/shoggoth = allocate(/mob/living/simple_animal/hostile/ms13/cdda/nether/shoggoth, spot)
	shoggoth.adjustBruteLoss(100)
	var/wounded = shoggoth.health
	shoggoth.Life(1)
	if(shoggoth.health <= wounded)
		Fail("A shoggoth's wounds didn't close.")
#endif
