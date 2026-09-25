GLOBAL_LIST_INIT(sentrybot_damaged_sound, list(
									'mojave/sound/ms13npc/sentrybot/damaged1.ogg',
									'mojave/sound/ms13npc/sentrybot/damaged2.ogg',
									'mojave/sound/ms13npc/sentrybot/damaged3.ogg',
									'mojave/sound/ms13npc/sentrybot/damaged4.ogg',
									'mojave/sound/ms13npc/sentrybot/damaged5.ogg'
									))

//Cooldowns for non death/damaged sounds being played; assoc key value laid out as
//Path to sound file = cooldown in SECONDS

//Idle search => fight
GLOBAL_LIST_INIT(sentrybot_hostiles_located_sound, list(
									'mojave/sound/ms13npc/sentrybot/hostiles_located1.ogg' = 5 SECONDS,
									'mojave/sound/ms13npc/sentrybot/hostiles_located2.ogg' = 6 SECONDS,
									'mojave/sound/ms13npc/sentrybot/hostiles_located3.ogg' = 4 SECONDS,
									'mojave/sound/ms13npc/sentrybot/hostiles_located4.ogg' = 6 SECONDS
									))

GLOBAL_LIST_INIT(sentrybot_idle_patrol_sound, list(
									'mojave/sound/ms13npc/sentrybot/idle_patrol1.ogg' = 7 SECONDS,
									'mojave/sound/ms13npc/sentrybot/idle_patrol2.ogg' = 11 SECONDS,
									'mojave/sound/ms13npc/sentrybot/idle_patrol3.ogg' = 7 SECONDS,
									'mojave/sound/ms13npc/sentrybot/idle_patrol4.ogg' = 6 SECONDS
									))

//Whenever a new hostile enemy is picked
GLOBAL_LIST_INIT(sentrybot_new_hostile_sound, list(
									'mojave/sound/ms13npc/sentrybot/new_hostile_targeted1.ogg' = 3 SECONDS,
									'mojave/sound/ms13npc/sentrybot/new_hostile_targeted2.ogg' = 3 SECONDS
									))

//fight => idle
GLOBAL_LIST_INIT(sentrybot_switch_to_patrol_sound, list(
									'mojave/sound/ms13npc/sentrybot/switch_to_patrol1.ogg' = 5 SECONDS,
									'mojave/sound/ms13npc/sentrybot/switch_to_patrol2.ogg' = 7 SECONDS,
									'mojave/sound/ms13npc/sentrybot/switch_to_patrol3.ogg' = 5 SECONDS,
									'mojave/sound/ms13npc/sentrybot/switch_to_patrol4.ogg' = 5 SECONDS
									))

//In combat
GLOBAL_LIST_INIT(sentrybot_in_combat_sound, list(
									'mojave/sound/ms13npc/sentrybot/in_combat1.ogg' = 8 SECONDS,
									'mojave/sound/ms13npc/sentrybot/in_combat2.ogg' = 7 SECONDS,
									'mojave/sound/ms13npc/sentrybot/in_combat3.ogg' = 8 SECONDS,
									'mojave/sound/ms13npc/sentrybot/in_combat4.ogg' = 9 SECONDS,
									))

//Dying before self destruct
//the seconds refer to the time before actually exploding
GLOBAL_LIST_INIT(sentrybot_dying_sound, list(
									'mojave/sound/ms13npc/sentrybot/death1.ogg' = 2.5 SECONDS,
									'mojave/sound/ms13npc/sentrybot/death2.ogg' = 2.5 SECONDS,
									'mojave/sound/ms13npc/sentrybot/death3.ogg' = 1.5 SECONDS,
									'mojave/sound/ms13npc/sentrybot/death4.ogg' = 2.5 SECONDS,
									'mojave/sound/ms13npc/sentrybot/death5.ogg' = 1.5 SECONDS,
									))

/mob/living/simple_animal/hostile/ms13/robot/sentrybot
	name = "sentry bot"
	desc = "A robot with the scariest arsenal you seen so far, it's a pretty good idea if you stopped looking at it."
	icon = 'mojave/icons/mob/48x48.dmi'
	icon_state = "sentrybot"
	mob_size = MOB_SIZE_LARGE
	footstep_type = null //Element is modified in Initialize()
	robust_searching = TRUE
	minimum_distance = 3 //We'll decrease this if needed
	retreat_distance = 3
	speed = 1
	move_to_delay = 4
	var/last_move_done_at = 0
	//var/drift_cooldown = 0
	attack_sound = 'mojave/sound/ms13weapons/meleesounds/heavyblunt_hit1.ogg'
	loot = list(/obj/item/stack/sheet/ms13/scrap_steel/ten, /obj/item/stack/sheet/ms13/scrap_electronics/ten, /obj/item/stack/sheet/ms13/scrap_parts/ten, /obj/item/stack/sheet/ms13/circuits/eight)
	vision_range = 12
	aggro_vision_range = 12
	dodge_prob = 50
	maxHealth = 1360
	health = 1360
	idlechance = 20
	melee_damage_lower = 25
	melee_damage_upper = 25
	subtractible_armour_penetration = 15
	sharpness = NONE
	//wound_bonus = 8
	//bare_wound_bonus 0
	ranged = TRUE
	stat_attack = CONSCIOUS
	casingtype = /obj/item/ammo_casing/energy/ms13/laser/sentrybot
	ranged_cooldown = 4.5 SECONDS
	rapid = 24
	rapid_fire_delay = 0.045 SECONDS //24 shots over 1 second
	pixel_x = -8
	base_pixel_x = -8
	bot_type = "Sentrybot"
	shadow_type = "shadow_large"
	projectilesound = null
	check_friendly_fire = FALSE //no
	move_resist = INFINITY
	var/datum/action/cooldown/launch_rocket/rocket
	var/datum/action/cooldown/launch_grenade/grenade
	var/datum/action/cooldown/flamethrow/flamethrow
	var/already_firing = FALSE
	var/speech_cooldown = 0
	var/datum/looping_sound/treads/soundloop
	// blind_fire_turf/blind_fire_until/blind_fire_duration/blind_fire_los_range/blind_fire_target_was_prone
	// now live on the shared /mob/living/simple_animal/hostile/ms13/robot parent - see
	// mojave/code/modules/mob/robots/_ranged_robot_ai.dm.

/datum/looping_sound/treads
	start_sound = 'mojave/sound/ms13npc/sentrybot/treads_start.mp3'
	start_length = 1
	mid_sounds = list('mojave/sound/ms13npc/sentrybot/treads_mid_1.mp3' = 1, 'mojave/sound/ms13npc/sentrybot/treads_mid_2.mp3' = 1, 'mojave/sound/ms13npc/sentrybot/treads_mid_3.mp3' = 1, 'mojave/sound/ms13npc/sentrybot/treads_mid_4.mp3' = 1)
	mid_length = 1
	end_sound = 'mojave/sound/ms13npc/sentrybot/treads_end.mp3'
	vary = FALSE
	volume = 25

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/Initialize()
	. = ..()
	grenade = new /datum/action/cooldown/launch_grenade/incend()
	rocket = new /datum/action/cooldown/launch_rocket()
	grenade.Grant(src)
	rocket.Grant(src)
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(play_move_sound), override = TRUE)
	soundloop = new(src, FALSE)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/play_move_sound()
	SIGNAL_HANDLER
	//playsound(src, 'sound/mecha/mechstep.ogg', 40, TRUE)
	last_move_done_at = world.time
	addtimer(CALLBACK(src, PROC_REF(check_if_loop_should_continue), world.time), move_to_delay + 0.5 SECONDS)
	/*
	if(drift_cooldown > world.time) //Special move cooldown + drifting shouldn't restart the tread sounds
		return
	*/
	soundloop.start()

/*
/mob/living/simple_animal/hostile/ms13/robot/sentrybot/Goto(target, delay, minimum_distance)
	if(drift_cooldown < world.time)
		return
	..()
*/

//Anti original code
/mob/living/simple_animal/hostile/ms13/robot/sentrybot/AttackingTarget(atom/attacked_target)
	. = ..()
	RangedAttack(target)
	return .

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/check_if_loop_should_continue(the_time)
	if(the_time != last_move_done_at)
		return
	/*
	if(drift_cooldown > world.time)
		return
	//TOKYO DRIFT
	*/
	soundloop.stop()
	/*
	playsound(src, 'mojave/sound/ms13npc/sentrybot/drift_king.ogg', 50, FALSE)
	drift_cooldown = world.time + 5 SECONDS
	var/time_til_next_move = 0
	var/turf_move_towards = get_step(src, src.dir)
	for(var/i = 1, i < 7, i++)
		time_til_next_move += (i * 0.1)
		addtimer(CALLBACK(src, PROC_REF(wrapped_move), turf_move_towards, src.dir), (10 * time_til_next_move))
		turf_move_towards = get_step(turf_move_towards, src.dir)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/wrapped_move(_newLoc, _Dir)
	if(get_dist(loc, _newLoc) > 1)
		return
	Move(_newLoc, _Dir)
*/

// ListTargets() override (keeping a lost-LoS target in scope within aggro_vision_range) now lives on the
// shared /mob/living/simple_animal/hostile/ms13/robot parent - see _ranged_robot_ai.dm.

// AI EDIT: added cause_of_death and forwarded it - see atmosphere.dm's /mob/living/death() for why.
/mob/living/simple_animal/hostile/ms13/robot/sentrybot/death(gibbed, cause_of_death = "Unknown")
	LoseTarget()
	vision_range = 0
	aggro_vision_range = 0
	stop_automated_movement = TRUE
	SSmove_manager.move_to(src, src, min_dist = 0, delay = 0)
	var/the_sound = pick(GLOB.sentrybot_dying_sound)
	playsound(src, the_sound, 50, FALSE)
	addtimer(CALLBACK(src, PROC_REF(self_destruct)), GLOB.sentrybot_dying_sound[the_sound])
	..(gibbed, cause_of_death)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/self_destruct()
	explosion(src, devastation_range = 0, heavy_impact_range = 1, light_impact_range = 2, flame_range = 4, flash_range = 5, smoke = TRUE)
	qdel(src)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/play_speech_sound(glob_list_used, bypass_cooldown = FALSE)
	if(!bypass_cooldown && (speech_cooldown > world.time))
		return
	var/random_speech = pick(glob_list_used)
	speech_cooldown = world.time + glob_list_used[random_speech]
	playsound(src, random_speech, 80, FALSE)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/Destroy()
	QDEL_NULL(rocket)
	QDEL_NULL(grenade)
	QDEL_NULL(flamethrow)
	QDEL_NULL(soundloop)
	return ..()

/**
 * Losing line of sight doesn't stop the gun - it keeps putting bullets through whatever's in the way, aimed
 * at wherever the target was last actually seen (not omnisciently tracking them live through the wall), via
 * the shared get_blind_fire_target() (_ranged_robot_ai.dm) for blind_fire_duration before giving up and
 * looking for a new target. If the target was LYING_DOWN the moment LoS was lost, that blind fire aims low
 * instead - see low_aim_mode/ready_proj() below. Regaining LoS resets everything back to a normal aimed
 * firing stance. Re-resolved on every call (both the initial "start windup" call and the "actually fire"
 * callback below) since LoS/the blind-fire window can change in the second between them.
 */
/mob/living/simple_animal/hostile/ms13/robot/sentrybot/OpenFire(atom/A, actually_fire = FALSE)
	A = get_blind_fire_target(A)
	if(!A)
		// AI EDIT (bugfix): must reset already_firing here too, or giving up mid-windup leaves it stuck TRUE
		// forever - every later OpenFire() call then hits "if(!already_firing)" as FALSE and does nothing at
		// all, silently and permanently stopping the sentry bot from ever firing again.
		wind_down_gun()
		return
	if(actually_fire)
		. = ..()
		gunfire_sound()
		addtimer(CALLBACK(src, PROC_REF(wind_down_gun)), 1 SECONDS)
	else
		if(!already_firing)
			addtimer(CALLBACK(src, PROC_REF(trigger_abilities), A), rand(1.5 SECONDS, 3 SECONDS))
			addtimer(CALLBACK(src, PROC_REF(OpenFire), A, TRUE), 1 SECONDS)
			spinup_sound()
			already_firing = TRUE
	return

// Its gatling's own burst sound covers every shot.
/mob/living/simple_animal/hostile/ms13/robot/sentrybot/default_fire_sound()
	return null

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/gunfire_sound()
	playsound(src, 'mojave/sound/ms13npc/sentrybot/laser_gatling.ogg', 50, FALSE)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/spinup_sound()
	playsound(src, 'mojave/sound/ms13npc/sentrybot/gatling_windup.ogg', 75, FALSE)

//Don't bother kiting if we lose sight of the target, we gotta rush them
/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/checkLoS()
	if(!can_see(src, target, length = blind_fire_los_range))
		minimum_distance = 1
		retreat_distance = 1
	else
		minimum_distance = 3
		retreat_distance = 3

//Quick LoS checking to begin chasing of target rather than keeping a minimum distance
/mob/living/simple_animal/hostile/ms13/robot/sentrybot/GiveTarget(new_target)
	if(new_target && target && (new_target != target))
		UnregisterSignal(target, COMSIG_MOVABLE_MOVED)
	. = ..()
	if(target)
		RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(checkLoS), override = TRUE)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/LoseTarget()
	if(target)
		UnregisterSignal(target, COMSIG_MOVABLE_MOVED)
	. = ..()

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/bullet_act(obj/projectile/Proj)
	if(istype(Proj, /obj/projectile/bullet/shrapnel))
		visible_message(span_danger("[Proj] bounces off of the [src]!"))
		return BULLET_ACT_BLOCK
	// Its own rounds pass it by, bounced back off a wall or broken into fragments (whose firer is the round).
	var/obj/projectile/round = Proj
	while(istype(round.firer, /obj/projectile))
		round = round.firer
	if(round.firer == src)
		return BULLET_ACT_FORCE_PIERCE
	return ..()

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/trigger_abilities(atom/A)
	if(!client)
		if(grenade.IsAvailable() && can_see(src, target, blind_fire_los_range))
			grenade.Trigger(target = target)
			return
		if(rocket.IsAvailable() && can_see(src, target, blind_fire_los_range) && HAS_TRAIT(target, TRAIT_IN_POWERARMOUR))
			rocket.Trigger(target = target)
			return

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/AIShouldSleep(list/possible_targets)
	. = ..()
	if(.) //Failed to find new targets, going into idle
		play_speech_sound(GLOB.sentrybot_switch_to_patrol_sound, bypass_cooldown = TRUE)
		add_overlay("scanning")
		set_light(l_outer_range = 1.5, l_power = 8, l_color = "#ff0000")

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/wind_down_gun()
	playsound(src, 'mojave/sound/ms13npc/sentrybot/gatling_winddown.ogg', 50, FALSE)
	already_firing = FALSE

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/handle_automated_action()
	. = ..()
	if(client)
		return
	if(AIStatus == AI_ON)
		play_speech_sound(GLOB.sentrybot_in_combat_sound, bypass_cooldown = FALSE)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/handle_automated_speech()
	. = ..()
	if(AIStatus == AI_IDLE)
		play_speech_sound(GLOB.sentrybot_idle_patrol_sound, bypass_cooldown = FALSE)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/toggle_ai(togglestatus)
	var/oldAIStatus = AIStatus
	. = ..()
	if((oldAIStatus == AI_IDLE) && (AIStatus == AI_ON))
		play_speech_sound(GLOB.sentrybot_hostiles_located_sound, bypass_cooldown = FALSE)
		toggle_ai(AI_ON)
		cut_overlays("scanning")
		set_light(l_outer_range = 1.5, l_power = 8, l_color = "#ff0000")
		update_icon()

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/adjustHealth(amount, updating_health = TRUE, forced = FALSE)
	. = ..()
	if(amount > 10 && prob(20))
		playsound(src, pick(GLOB.sentrybot_damaged_sound), 50, FALSE)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/FindTarget(list/possible_targets, HasTargetsList = 0, IgnoreRepetiveCall = FALSE)
	var/old_target = target //If we change target (NULL => new target, old target => new target) play a sound effect
	. = ..()
	if((old_target != null) && (old_target != target) && !client)
		play_speech_sound(GLOB.sentrybot_new_hostile_sound, bypass_cooldown = FALSE)
	//If we still don't have a target, we should try finding a target again but in critical condition
	if(!target && !IgnoreRepetiveCall && (stat_attack != UNCONSCIOUS))
		stat_attack = UNCONSCIOUS
		FindTarget(possible_targets, HasTargetsList, IgnoreRepetiveCall = TRUE)
		//We'll give a grace period for the sentry bot being able to attack crit'd targets for about 1 volley
		addtimer(CALLBACK(src, PROC_REF(reset_stat_attack)), 3 SECONDS)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/proc/reset_stat_attack()
	stat_attack = initial(stat_attack)

/**
 * DD's real ready_proj() (code/modules/projectiles/ammunition/_firing.dm) sets hit_prone_targets from
 * user.combat_mode, and can_hit_target() (code/modules/projectiles/projectile.dm) only bypasses that check
 * (direct_target) when the shot was aimed straight at the living target itself. Sentrybots never set
 * combat_mode, and blind fire is aimed at blind_fire_turf (not the mob) - so between those two, a genuinely
 * aimed in-sight shot already hits prone targets and a blind one already doesn't, with no extra code needed.
 *
 * low_aim_mode covers the one case DD's engine doesn't: a target last seen LYING_DOWN before LoS was lost.
 * Rather than a flat "never hits prone," the shooter aims low at where they went down - a moderate,
 * uniform chance of hitting whoever's actually there, standing or prone, representing spraying the lower
 * part of the structure instead of a precise shot. Set per-shot (see the two ready_proj() overrides below),
 * not a static default, so it never leaks into a genuinely aimed shot.
 */
/obj/projectile
	var/low_aim_mode = FALSE

/obj/projectile/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	if(low_aim_mode && isliving(target) && !direct_target)
		return prob(50)
	return ..()

//randomspread prerequisite
/obj/item/ammo_casing/energy/ms13/laser/sentrybot
	projectile_type = /obj/projectile/beam/ms13/laser/sentrybot
	variance = 30
	pellets = 1
	fire_sound = 'mojave/sound/ms13weapons/gunsounds/lasrifle/laser_heavy.ogg'
	randomspread = TRUE

/obj/item/ammo_casing/energy/ms13/laser/sentrybot/fire_casing(atom/target, mob/living/user, params, distro, quiet, zone_override, spread, atom/fired_from)
	. = ..()
	if(. && !QDELETED(src))
		qdel(src)

/// See /obj/projectile/var/low_aim_mode above - this is where DD's real ready_proj() already sets
/// hit_prone_targets from user.combat_mode, so it's the natural place to set our own per-shot state too.
/obj/item/ammo_casing/energy/ms13/laser/sentrybot/ready_proj(atom/target, mob/living/user, quiet, zone_override, atom/fired_from)
	. = ..()
	var/mob/living/simple_animal/hostile/ms13/robot/sentrybot/shooter = istype(user, /mob/living/simple_animal/hostile/ms13/robot/sentrybot) ? user : null
	if(loaded_projectile && shooter && shooter.blind_fire_until && shooter.blind_fire_target_was_prone)
		loaded_projectile.low_aim_mode = TRUE

/obj/projectile/beam/ms13/laser/sentrybot
	damage = 8
	debris_chance = 20
	subtractible_armour_penetration = 32
	//wound_bonus = 18
	//bare_wound_bonus 10

//A special rocket for sentrybot; light explosion fixed with lots of fire

/obj/projectile/bullet/sentrybot_rocket
	name = "explosive rocket"
	icon_state = "84mm-hedp"
	damage = 20 //Damage comes from the light explosion and fire
	embedding = null
	shrapnel_type = null
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL //slower because it's a rocket

/obj/projectile/bullet/sentrybot_rocket/on_hit(atom/target, blocked = FALSE)
	explosion(get_turf(target), devastation_range = -1, heavy_impact_range = -1, light_impact_range = 2, flame_range = 3, explosion_cause = src)
	return BULLET_ACT_HIT

//Launches a rocket out of you
/datum/action/cooldown/launch_rocket
	name = "Launch a rocket"
	desc = "Launches a cool rocket at the enemy"
	cooldown_time = 13 SECONDS
	click_to_activate = TRUE
	var/obj/projectile/projectile = /obj/projectile/bullet/sentrybot_rocket

/datum/action/cooldown/launch_rocket/Activate(atom/target_atom)
	StartCooldown(13 SECONDS)
	launch_rocket(target_atom)
	StartCooldown()

/datum/action/cooldown/launch_rocket/proc/launch_rocket(atom/target_atom)
	playsound(owner, 'mojave/sound/ms13npc/sentrybot/rocket1.ogg', 60, TRUE, -1)
	var/obj/projectile/projectile_obj = new projectile(get_turf(owner))
	projectile_obj.firer = owner
	projectile_obj.preparePixelProjectile(target_atom, owner)
	projectile_obj.fire()

//Launch rocket but it's a shrapnel grenade
/datum/action/cooldown/launch_grenade
	name = "Launch a shrapnel grenade"
	desc = "Launches a cool grenade at the enemy"
	cooldown_time = 7.5 SECONDS
	click_to_activate = TRUE
	var/obj/item/grenade/grenade = /obj/item/grenade/frag/sentrybot

/datum/action/cooldown/launch_grenade/Activate(atom/target_atom)
	StartCooldown(7.5 SECONDS)
	launch_grenade(target_atom)
	StartCooldown()

/datum/action/cooldown/launch_grenade/proc/launch_grenade(atom/target_atom)
	//living_owner.SetStun(1.5 SECONDS, ignore_canstun = TRUE)
	playsound(owner, 'mojave/sound/ms13npc/sentrybot/grenade2.ogg', 60, TRUE, -1)
	//var/obj/item/grenade/thrown_grenade = new grenade(get_step(owner, get_dir(owner, target_atom)))
	var/obj/item/grenade/thrown_grenade = new grenade(get_turf(owner))
	var/original_density = owner.density
	//Aim ahead of target by 3 steps
	var/new_target_turf = target_atom
	for(var/i = 0; i != 3; i++)
		new_target_turf = get_step(new_target_turf, get_dir(owner, target_atom))
	owner.density = FALSE
	thrown_grenade.throw_at(new_target_turf, 15, 2, owner, FALSE, FALSE)
	owner.density = original_density
	thrown_grenade.arm_grenade(owner, 1.5 SECONDS, 2, 1, owner, TRUE)

/datum/action/cooldown/launch_grenade/incend
	name = "Launch a incendiary grenade"
	cooldown_time = 8 SECONDS
	grenade = /obj/item/grenade/ms13/incend_sentry

/datum/action/cooldown/launch_grenade/incend/Activate(atom/target_atom)
	StartCooldown(8 SECONDS)
	launch_grenade(target_atom)
	StartCooldown()

/obj/item/grenade/frag/sentrybot
	name = "frag grenade"
	desc = "An anti-personnel fragmentation grenade, this weapon excels at killing soft targets by shredding them with metal shrapnel."
	icon = 'mojave/icons/objects/throwables/ms_bomb_sentrybot.dmi'
	icon_state = "bomb"
	shrapnel_type = /obj/projectile/bullet/shrapnel/ms13
	pass_flags = PASSMOB
	shrapnel_radius = 4
	ex_heavy = -1
	ex_light = 1
	ex_flame = 2

/obj/item/grenade/ms13/incend_sentry
	name = "incendiary grenade"
	desc = "An anti-personnel incendiary grenade, this weapon excels at killing soft targets by lighting them aflame."
	icon = 'mojave/icons/objects/throwables/ms_bomb_sentrybot.dmi'
	icon_state = "bomb"
	pass_flags = PASSMOB
	ex_heavy = 0
	ex_light = 0
	ex_flame = 2

/obj/item/grenade/ms13/incend_sentry/detonate(mob/living/lanced_by)
	flame_radius(2, get_turf(src))
	playsound(loc, 'mojave/sound/ms13effects/explosion_fire_grenade.ogg', 50, TRUE, 4)
	qdel(src)

/obj/item/shrapnel/ms13
	name = "shrapnel shard"
	icon = 'mojave/icons/objects/projectiles/projectiles.dmi'
	icon_state = "nail" //placeholder
	sharpness = SHARP_POINTY

/obj/projectile/bullet/shrapnel/ms13
	name = "flying shrapnel shard"
	damage = COMPACTPISTOL_DAMAGE
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_INSANE
	range = 25
	icon = 'mojave/icons/objects/projectiles/projectiles.dmi'
	icon_state = "nail" //placeholder
	shrapnel_type = /obj/item/shrapnel/ms13
	sharpness = SHARP_POINTY
	bulletTipType = BULLET_SHARP
	embedding = list("embedded_pain_multiplier" = 1, "embed_chance" = 50, "embedded_fall_chance" = 10, "ignore_throwspeed_threshold" = TRUE)

//A flamethrower that's essentially a forward facing backblast of the rocket launcher
/datum/action/cooldown/flamethrow
	name = "Flamethrower"
	desc = "Throws a bunch of flame at the target"
	cooldown_time = 6 SECONDS
	click_to_activate = TRUE
	var/obj/projectile/bullet/incendiary/backblast/proj = /obj/projectile/bullet/incendiary/backblast

/datum/action/cooldown/flamethrow/Activate(atom/target_atom)
	StartCooldown(6 SECONDS)
	throw_flame(target_atom)
	StartCooldown()

/datum/action/cooldown/flamethrow/proc/throw_flame(atom/target_atom)
	var/forwards_angle = get_angle(owner, target_atom)
	//Forwards_angle - (angle spread * 0.5)
	var/starting_angle = SIMPLIFY_DEGREES(forwards_angle-(48 * 0.5))
	//Angle spread / plumes
	var/iter_offset = 48 / 4 // how much we increment the angle for each plume
	//in 1 to plumes
	for(var/i in 1 to 4)
		var/this_angle = SIMPLIFY_DEGREES(starting_angle + ((i - 1) * iter_offset))
		var/turf/target_turf = get_turf_in_angle(this_angle, get_turf(owner), 10)
		var/obj/projectile/bullet/P = new(get_turf(owner))
		P.original = target_turf
		P.range = 6
		P.fired_from = get_turf(owner)
		P.firer = owner // don't hit ourself that would be really annoying
		P.impacted = list(owner = TRUE) // don't hit the target we hit already with the flak
		P.preparePixelProjectile(target_turf, owner)
		P.fire()

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/ballistic
	icon_state = "ballisentry"
	casingtype = /obj/item/ammo_casing/ms13/sentry
	ranged_cooldown = 5.5 SECONDS
	rapid = 50
	rapid_fire_delay = 0.022 SECONDS //50 shots over 1.1 seconds

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/ballistic/Initialize()
	. = ..()
	grenade = new /datum/action/cooldown/launch_grenade()
	rocket = new /datum/action/cooldown/railgun()
	grenade.Grant(src)
	rocket.Grant(src)
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(play_move_sound), override = TRUE)
	soundloop = new(src, FALSE)

//Wind down is combined with windup sound
/mob/living/simple_animal/hostile/ms13/robot/sentrybot/ballistic/wind_down_gun()
	already_firing = FALSE

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/ballistic/gunfire_sound()
	playsound(src, 'mojave/sound/ms13npc/sentrybot/ballistic_minigun_fire.ogg', 50, FALSE)

/mob/living/simple_animal/hostile/ms13/robot/sentrybot/ballistic/spinup_sound()
	playsound(src, 'mojave/sound/ms13npc/sentrybot/ballistic_minigun_spinup_down.ogg', 50, FALSE)

/obj/item/ammo_casing/ms13/sentry
	name = "5mm bullet casing"
	projectile_type = /obj/projectile/bullet/ms13/sentry
	icon_state = "556_casing"
	variance = 40
	pellets = 1
	fire_sound = 'mojave/sound/ms13weapons/arfire.ogg'
	randomspread = TRUE

/obj/item/ammo_casing/ms13/sentry/fire_casing(atom/target, mob/living/user, params, distro, quiet, zone_override, spread, atom/fired_from)
	. = ..()
	pixel_z = 8 //bounce time
	var/rand_spin = (rand(1, 3) * 10 ) //* SECONDS
	SpinAnimation(speed = rand_spin, loops = 1)
	// AI EDIT: dropped the movable_physics bounce-and-roll effect - it needs a whole subsystem (SSmovablephysics)
	// that doesn't exist in DD at all, not something with a clean rename target

/// See /obj/item/ammo_casing/energy/ms13/laser/sentrybot/ready_proj() above - same deal, ballistic side.
/obj/item/ammo_casing/ms13/sentry/ready_proj(atom/target, mob/living/user, quiet, zone_override, atom/fired_from)
	. = ..()
	var/mob/living/simple_animal/hostile/ms13/robot/sentrybot/shooter = istype(user, /mob/living/simple_animal/hostile/ms13/robot/sentrybot) ? user : null
	if(loaded_projectile && shooter && shooter.blind_fire_until && shooter.blind_fire_target_was_prone)
		loaded_projectile.low_aim_mode = TRUE

TYPEINFO_DEF(/obj/projectile/bullet/ms13/sentry)
	default_armor = FMJ_RIFLE
/obj/projectile/bullet/ms13/sentry
	name = "5mm bullet"
	icon_state = "medium_bullet"
	damage = SMALL_RIFLE_DAMAGE
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RIFLE_VFAST
	bulletTipType = BULLET_SHARP
	debris_chance = 20

/datum/action/cooldown/railgun
	name = "Fire a railgun"
	desc = "Launches a cool railgun at the enemy"
	cooldown_time = 2.6 SECONDS
	click_to_activate = TRUE
	var/obj/projectile/projectile = /obj/projectile/bullet/ms13/gauss/sentry

/datum/action/cooldown/railgun/Activate(atom/target_atom)
	StartCooldown(2.6 SECONDS)
	launch_railgun(target_atom)
	StartCooldown()

/datum/action/cooldown/railgun/proc/launch_railgun(atom/target_atom)
	playsound(owner, 'mojave/sound/ms13weapons/gunsounds/Gauss/bigbore.ogg', 60, FALSE, -1)
	var/obj/projectile/projectile_obj = new projectile(get_turf(owner))
	projectile_obj.firer = owner
	projectile_obj.preparePixelProjectile(target_atom, owner)
	projectile_obj.fire()

TYPEINFO_DEF(/obj/projectile/bullet/ms13/gauss/sentry)
	default_armor = ANTI_MATERIEL
/obj/projectile/bullet/ms13/gauss/sentry
	name = "heavy gauss bullet"
	damage = RAILGUN_DAMAGE
	bulletTipType = BULLET_ULTRASHARP
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RAILGUN

#ifdef UNIT_TESTS
/datum/unit_test/ms13_sentrybot_own_rounds
	name = "MOBS: A Sentry Bot's Own Rounds Don't Hit It"

/datum/unit_test/ms13_sentrybot_own_rounds/Run()
	var/mob/living/simple_animal/hostile/ms13/robot/sentrybot/ballistic/sentry = allocate(/mob/living/simple_animal/hostile/ms13/robot/sentrybot/ballistic)
	var/obj/projectile/bullet/ricochet = allocate(/obj/projectile/bullet)
	ricochet.firer = sentry
	ricochet.ignore_source_check = TRUE
	var/obj/projectile/bullet/fragment = allocate(/obj/projectile/bullet)
	fragment.firer = ricochet
	if(sentry.bullet_act(ricochet) != BULLET_ACT_FORCE_PIERCE || sentry.bullet_act(fragment) != BULLET_ACT_FORCE_PIERCE || sentry.health < sentry.maxHealth)
		Fail("A sentry bot was hit by its own round, bounced back or broken into fragments.")
#endif
