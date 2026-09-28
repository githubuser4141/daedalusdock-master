// Species audio and special attacks; movement/collision uses the native charge action.
/mob/living/simple_animal/hostile/ms13/terrain_hivemind
	var/datum/action/cooldown/mob_cooldown/charge/ms13_hive/hive_charge
	var/hive_challenge_sound
	var/hive_splats_on_death = FALSE
	COOLDOWN_DECLARE(hive_challenge_cooldown)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/configure_hive_combat()
	if(istype(network, /datum/ms13_terrain_hivemind/xenomorph))
		deathsound = 'mojave/sound/by_nc/tgmc_xenomorphs/death.ogg'
		hive_challenge_sound = 'mojave/sound/by_nc/tgmc_xenomorphs/hiss1.ogg'
		if(unit_role == MS13_HIVE_ROLE_SCOUT)
			hive_charge = new /datum/action/cooldown/mob_cooldown/charge/ms13_hive/pounce
		else if(unit_role == MS13_HIVE_ROLE_HEAVY)
			hive_charge = new
			hive_challenge_sound = 'mojave/sound/by_nc/tgmc_xenomorphs/roar1.ogg'
	else if(istype(network, /datum/ms13_terrain_hivemind/necromorph))
		var/static/list/role_audio = list(
			MS13_HIVE_ROLE_SCOUT = list('sound/effects/blobattack.ogg', null, null),
			MS13_HIVE_ROLE_SOLDIER = list('mojave/sound/wip/necromorphs/slasher_attack_1.ogg', 'mojave/sound/wip/necromorphs/slasher_death_1.ogg', 'mojave/sound/wip/necromorphs/slasher_shout_1.ogg'),
			MS13_HIVE_ROLE_RANGED = list('mojave/sound/wip/necromorphs/lurker_attack_1.ogg', 'mojave/sound/wip/necromorphs/lurker_death_1.ogg', 'mojave/sound/wip/necromorphs/lurker_shout_1.ogg'),
			MS13_HIVE_ROLE_HEAVY = list('mojave/sound/wip/necromorphs/brute_attack_1.ogg', 'mojave/sound/wip/necromorphs/brute_death.ogg', 'mojave/sound/wip/necromorphs/brute_shout_1.ogg'),
			MS13_HIVE_ROLE_INFECTOR = list('mojave/sound/wip/necromorphs/infector_attack_1.ogg', 'mojave/sound/wip/necromorphs/infector_death_1.ogg', 'mojave/sound/wip/necromorphs/infector_shout_1.ogg'),
			"siege" = list('mojave/sound/wip/necromorphs/tripod_attack_1.ogg', 'mojave/sound/wip/necromorphs/tripod_death_1.ogg', 'mojave/sound/wip/necromorphs/tripod_shout_1.ogg'),
			"suicide" = list('mojave/sound/wip/necromorphs/exploder_attack_1.ogg', 'mojave/sound/wip/necromorphs/exploder_death_1.ogg', 'mojave/sound/wip/necromorphs/exploder_shout_1.ogg'),
		)
		var/list/audio = role_audio[unit_role] || role_audio[MS13_HIVE_ROLE_SOLDIER]
		attack_sound = audio[1]
		deathsound = audio[2]
		hive_challenge_sound = audio[3]
		if(unit_role == MS13_HIVE_ROLE_SCOUT)
			hive_splats_on_death = TRUE
			revivable_hive_corpse = FALSE
		if(unit_role == MS13_HIVE_ROLE_HEAVY || unit_role == "siege" || unit_role == "regenerator")
			hive_charge = new
	if(hive_charge)
		var/list/stats = network.get_strain_stats(type)
		if(!isnull(stats?["ram_damage"]))
			hive_charge.obstacle_damage = stats["ram_damage"]
		hive_charge.Grant(src)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/GiveTarget(atom/new_target)
	var/had_target = target
	. = ..()
	if(target != had_target)
		hive_last_seen_turf = get_turf(target)
		hive_last_seen_at = world.time
	if(target && !had_target && hive_challenge_sound && COOLDOWN_FINISHED(src, hive_challenge_cooldown))
		playsound(src, hive_challenge_sound, 60, TRUE)
		COOLDOWN_START(src, hive_challenge_cooldown, 12 SECONDS)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/LoseTarget()
	if(stat != DEAD && length(hive_charge?.charging))
		// The rush commits to a position. Losing/deleting the prey must not cancel its movement loop.
		GiveTarget(null)
		approaching_target = FALSE
		in_melee = FALSE
		LoseAggro()
		return
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/can_hive_charge_at(atom/charge_target)
	if(!hive_charge?.IsAvailable() || !charge_target || corpse_target_ref || LAZYLEN(grabbed_by) || !isturf(loc) || (!isturf(charge_target) && !isturf(charge_target.loc)))
		return FALSE
	var/living_target = isliving(charge_target)
	if(living_target ? (!CanAttack(charge_target) || can_capture_npc(charge_target)) : !can_hive_damage_obstacle(charge_target, hive_charge.obstacle_damage, TRUE))
		return FALSE
	var/distance = ms13_hive_distance(src, charge_target)
	return distance >= (living_target ? 2 : 1) && distance <= hive_charge.charge_distance && (charge_target in view(vision_range, src))

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/try_hive_charge(atom/charge_target = target)
	if(!can_hive_charge_at(charge_target))
		return FALSE
	SSmove_manager.stop_looping(src)
	in_melee = FALSE
	hive_charge.Trigger(target = charge_target)
	return TRUE

/datum/action/cooldown/mob_cooldown/charge/ms13_hive
	name = "Ramming charge"
	cooldown_time = 6 SECONDS
	charge_delay = 0.8 SECONDS
	charge_distance = 8
	charge_past = 3
	charge_speed = 1
	charge_damage = 35
	destroy_objects = FALSE
	var/obstacle_damage = 135

/datum/action/cooldown/mob_cooldown/charge/ms13_hive/pounce
	name = "Pounce"
	cooldown_time = 8 SECONDS
	charge_delay = 0.6 SECONDS
	charge_distance = 4
	charge_damage = 15
	charge_past = 1
	obstacle_damage = 0

/datum/action/cooldown/mob_cooldown/charge/ms13_hive/do_charge_indicator(atom/charger, atom/charge_target)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/unit = charger
	unit.visible_message(span_warning("[unit] lowers itself, preparing to rush!"))
	unit.Shake(2, 2, charge_delay)
	var/charge_sound = istype(src, /datum/action/cooldown/mob_cooldown/charge/ms13_hive/pounce) ? 'mojave/sound/by_nc/tgmc_xenomorphs/pounce.ogg' : unit.hive_challenge_sound
	if(charge_sound)
		playsound(unit, charge_sound, 75, TRUE)

/datum/action/cooldown/mob_cooldown/charge/ms13_hive/on_moved(atom/source)
	// Native footsteps suffice; the generic action plays a meteor impact on every tile.
	return

/datum/action/cooldown/mob_cooldown/charge/ms13_hive/do_charge(atom/movable/charger, atom/target_atom, delay, past)
	. = ..()
	// Also release the wind-up movement lock when death/failed movement aborts before a loop exists.
	if(!QDELETED(charger) && charger in charging)
		UnregisterSignal(charger, list(COMSIG_MOVABLE_BUMP, COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOVABLE_MOVED, COMSIG_MOB_STATCHANGE))
		charging -= charger
		actively_moving = FALSE
		if(owner)
			SEND_SIGNAL(owner, COMSIG_FINISHED_CHARGE)

/datum/action/cooldown/mob_cooldown/charge/ms13_hive/on_bump(atom/movable/source, atom/obstacle)
	SIGNAL_HANDLER
	if(!(source in charging))
		return
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/unit = source
	if(isliving(obstacle))
		if(unit.CanAttack(obstacle))
			hit_target(unit, obstacle, charge_damage)
	else if(obstacle_damage > 0)
		INVOKE_ASYNC(unit, TYPE_PROC_REF(/mob/living/simple_animal/hostile/ms13/terrain_hivemind, hive_attack_obstacle), obstacle, obstacle_damage)
	SSmove_manager.stop_looping(source)

/datum/action/cooldown/mob_cooldown/charge/ms13_hive/hit_target(atom/movable/source, atom/target, damage_dealt)
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/unit = source
	if(!isliving(target) || !unit.CanAttack(target) || unit.try_capture_npc(target))
		return
	var/mob/living/victim = target
	victim.apply_damage(damage_dealt, BRUTE)
	victim.Knockdown(2 SECONDS)
	playsound(victim, unit.attack_sound, 65, TRUE)
	victim.visible_message(span_danger("[unit] slams into [victim]!"))
