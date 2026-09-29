// Den ecology is opt-in. Existing placed animals retain their original controller.
GLOBAL_LIST_EMPTY(ms13_wildlife)

#include "wildlife_species.dm"

/obj/effect/spawner/ms13/wildlife_den
	parent_type = /obj/effect
	name = "wildlife den - wolves"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "x"
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	/// Use an existing basic animal; its combat stats, sounds and butcher drops are preserved.
	var/animal_type = /mob/living/basic/ms13/hostile_animal/wolf
	/// Pick one species per den, once per round; replenishment keeps that species.
	var/list/animal_pool
	var/population = 3
	var/respawn_delay = 20 MINUTES
	var/patrol_radius = 12
	var/territory_radius = 4
	var/leash_radius = 20
	var/retreat_health = 0.35
	var/recover_health = 0.85
	var/healing_per_second = 2
	var/meal_interval = 5 MINUTES
	var/list/members = list()
	var/next_spawn = 0

/obj/effect/spawner/ms13/wildlife_den/Initialize(mapload)
	. = ..()
	if(length(animal_pool))
		animal_type = pick_weight(animal_pool)
	if(!ispath(animal_type, /mob/living/basic))
		stack_trace("Invalid wildlife animal_type [animal_type] at [AREACOORD(src)]")
		return INITIALIZE_HINT_QDEL
	population = clamp(round(population), 0, 12)
	territory_radius = clamp(round(territory_radius), 0, 15)
	patrol_radius = clamp(round(patrol_radius), max(territory_radius, 1), 30)
	leash_radius = clamp(round(leash_radius), patrol_radius, 40)
	respawn_delay = max(respawn_delay, 1 MINUTES)
	meal_interval = max(meal_interval, 30 SECONDS)
	retreat_health = clamp(retreat_health, 0, 0.9)
	recover_health = clamp(recover_health, retreat_health + 0.05, 1)
	healing_per_second = clamp(healing_per_second, 0, 20)
	return INITIALIZE_HINT_LATELOAD

/obj/effect/spawner/ms13/wildlife_den/LateInitialize()
	START_PROCESSING(SSobj, src)
	process()

/obj/effect/spawner/ms13/wildlife_den/Destroy()
	STOP_PROCESSING(SSobj, src)
	for(var/mob/living/member as anything in members)
		UnregisterSignal(member, list(COMSIG_PARENT_QDELETING, COMSIG_LIVING_DEATH))
		var/datum/ai_controller/basic_controller/ms13_wildlife/controller = member.ai_controller
		if(istype(controller))
			controller.clear_job()
			controller.den_ref = null
	members.Cut()
	return ..()

/obj/effect/spawner/ms13/wildlife_den/process(delta_time)
	if(world.time < next_spawn)
		return
	var/alive = 0
	for(var/mob/living/member as anything in members)
		if(!QDELETED(member) && member.stat != DEAD)
			alive++
	if(alive >= population)
		return
	// One replacement per interval; initial population is filled on the first pass.
	var/to_spawn = length(members) ? 1 : population
	for(var/i in 1 to to_spawn)
		if(!spawn_animal())
			break
	next_spawn = world.time + respawn_delay

/obj/effect/spawner/ms13/wildlife_den/proc/spawn_animal()
	var/list/possible = list()
	for(var/turf/open/tile in range(2, src))
		// Nearby tiles across a wall are not part of the den's reachable entrance.
		if(ms13_ecology_clear_tile(tile) && (tile == get_turf(src) || length(SSpathfinder.jps_pathfind_now(src, tile, max_steps = 6, mintargetdist = 0))))
			possible += tile
	if(!length(possible))
		return
	var/mob/living/basic/animal = new animal_type(pick(possible))
	animal.ms13_can_sleep = FALSE
	animal.ms13_pack?.remove(animal)
	new /datum/ai_controller/basic_controller/ms13_wildlife(animal, src)
	members += animal
	RegisterSignal(animal, COMSIG_PARENT_QDELETING, PROC_REF(member_deleted))
	RegisterSignal(animal, COMSIG_LIVING_DEATH, PROC_REF(member_died))
	return animal

/obj/effect/spawner/ms13/wildlife_den/proc/member_died(mob/living/source)
	SIGNAL_HANDLER
	next_spawn = max(next_spawn, world.time + respawn_delay)

/obj/effect/spawner/ms13/wildlife_den/proc/member_deleted(mob/living/source)
	SIGNAL_HANDLER
	members -= source
	UnregisterSignal(source, list(COMSIG_PARENT_QDELETING, COMSIG_LIVING_DEATH))
	if(source.stat != DEAD)
		member_died(source)

/obj/effect/spawner/ms13/wildlife_den/hellpig
	name = "wildlife den - hellpig"
	animal_type = /mob/living/basic/ms13/hostile_animal/hellpig
	population = 1

/obj/effect/spawner/ms13/wildlife_den/yaoguai
	name = "wildlife den - yao guai"
	animal_type = /mob/living/basic/ms13/hostile_animal/yaoguai
	population = 1

/obj/effect/spawner/ms13/wildlife_den/boar
	name = "wildlife den - boars"
	animal_type = /mob/living/basic/ms13/hostile_animal/boar

/obj/effect/spawner/ms13/wildlife_den/molerat
	name = "wildlife den - molerats"
	animal_type = /mob/living/basic/ms13/hostile_animal/molerat
	territory_radius = 2

/obj/effect/spawner/ms13/wildlife_den/gecko
	name = "wildlife den - geckos"
	animal_type = /mob/living/basic/ms13/hostile_animal/gecko

/obj/effect/spawner/ms13/wildlife_den/radroach
	name = "wildlife den - radroaches"
	animal_type = /mob/living/basic/ms13/hostile_animal/radroach
	population = 4
	territory_radius = 1

// Region folders are inert. Old type paths remain compatible; names describe species, not fixed roles.
/obj/effect/spawner/ms13/wildlife_den/drought
	name = "Drought den - choose a species"
	population = 0

/obj/effect/spawner/ms13/wildlife_den/drought/predator/wolves
	parent_type = /obj/effect/spawner/ms13/wildlife_den
	name = "Drought den - desert wolves"
	desc = "A small pack ranging between the desert's sheltered hollows."
	population = 2
	patrol_radius = 14
	leash_radius = 22

/obj/effect/spawner/ms13/wildlife_den/drought/predator/hellpig
	parent_type = /obj/effect/spawner/ms13/wildlife_den/hellpig
	name = "Drought den - hellpig"
	desc = "A solitary apex omnivore guarding a broad desert territory."
	territory_radius = 5
	patrol_radius = 10
	respawn_delay = 30 MINUTES

/obj/effect/spawner/ms13/wildlife_den/drought/predator/golden_geckos
	parent_type = /obj/effect/spawner/ms13/wildlife_den/gecko
	name = "Drought den - golden geckos"
	desc = "A pair of golden geckos hunting insects around sun-warmed rocks."
	animal_type = /mob/living/basic/ms13/hostile_animal/gecko/golden
	population = 2
	territory_radius = 3
	patrol_radius = 9

/obj/effect/spawner/ms13/wildlife_den/drought/prey/molerats
	parent_type = /obj/effect/spawner/ms13/wildlife_den/molerat
	name = "Drought den - molerat burrow"
	desc = "A colony foraging for roots close to its burrow."
	population = 4
	patrol_radius = 8
	respawn_delay = 15 MINUTES

/obj/effect/spawner/ms13/wildlife_den/drought/prey/pigrats
	parent_type = /obj/effect/spawner/ms13/wildlife_den/molerat
	name = "Drought den - pigrat burrow"
	desc = "A small colony browsing tough desert vegetation."
	animal_type = /mob/living/basic/ms13/hostile_animal/pigrat
	patrol_radius = 9

/obj/effect/spawner/ms13/wildlife_den/drought/prey/radroaches
	parent_type = /obj/effect/spawner/ms13/wildlife_den/radroach
	name = "Drought den - radroach nest"
	desc = "A compact insect colony feeding on scrub and fungi."
	population = 5
	patrol_radius = 6
	respawn_delay = 12 MINUTES

/obj/effect/spawner/ms13/wildlife_den/mammoth
	name = "Mammoth den - choose a species"
	population = 0

/obj/effect/spawner/ms13/wildlife_den/mammoth/predator/wolves
	parent_type = /obj/effect/spawner/ms13/wildlife_den
	name = "Mammoth den - timber wolves"
	desc = "A wolf pack patrolling snow-covered woodland around its home."
	territory_radius = 5
	patrol_radius = 14
	leash_radius = 24

/obj/effect/spawner/ms13/wildlife_den/mammoth/predator/yaoguai
	parent_type = /obj/effect/spawner/ms13/wildlife_den/yaoguai
	name = "Mammoth den - yao guai"
	desc = "A solitary bear that hunts boars and smaller wildlife and browses woodland plants."
	territory_radius = 5
	patrol_radius = 10
	respawn_delay = 30 MINUTES

/obj/effect/spawner/ms13/wildlife_den/mammoth/predator/ice_geckos
	parent_type = /obj/effect/spawner/ms13/wildlife_den/gecko
	name = "Mammoth den - ice geckos"
	desc = "Cold-adapted geckos that supplement small prey with woodland forage."
	animal_type = /mob/living/basic/ms13/hostile_animal/gecko/ice
	population = 2
	territory_radius = 3
	patrol_radius = 8

/obj/effect/spawner/ms13/wildlife_den/mammoth/prey/boars
	parent_type = /obj/effect/spawner/ms13/wildlife_den/boar
	name = "Mammoth den - woodland boars"
	desc = "A small herd browsing bushes and low tree foliage."
	territory_radius = 2
	patrol_radius = 10

/obj/effect/spawner/ms13/wildlife_den/mammoth/prey/molerats
	parent_type = /obj/effect/spawner/ms13/wildlife_den/molerat
	name = "Mammoth den - sheltered molerat burrow"
	desc = "A sheltered colony foraging close to home in the cold."
	population = 4
	patrol_radius = 7
	respawn_delay = 15 MINUTES

/obj/effect/spawner/ms13/wildlife_den/mammoth/prey/pigrats
	parent_type = /obj/effect/spawner/ms13/wildlife_den/drought/prey/pigrats
	name = "Mammoth den - woodland pigrats"
	desc = "A colony browsing roots and undergrowth beneath the snow."
	population = 4
	patrol_radius = 8

/mob/living
	var/tmp/datum/weakref/ms13_wildlife_claim

/datum/ai_controller/basic_controller/ms13_wildlife
	ai_movement = /datum/ai_movement/jps
	max_target_distance = 40
	blackboard = list(BB_TARGETING_STRATEGY = /datum/targeting_strategy/generic/ms13_wildlife)
	var/datum/weakref/den_ref
	var/datum/weakref/aggressor_ref
	var/aggressor_until = 0
	var/hungry_at = 0
	var/frightened_until = 0
	var/datum/weakref/noise_source
	var/noise_cooldown = 0
	var/retreating = FALSE
	var/next_decision = 0
	var/job
	var/datum/weakref/job_target
	var/datum/weakref/food_ref
	var/job_deadline = 0
	var/progress_deadline = 0
	var/best_distance = INFINITY
	var/last_target_health
	var/eating_since = 0
	var/list/ignored_targets = list()
	var/changing_job = FALSE

/datum/ai_controller/basic_controller/ms13_wildlife/New(mob/living/basic/animal, obj/effect/spawner/ms13/wildlife_den/den)
	den_ref = WEAKREF(den)
	hungry_at = world.time + rand(30 SECONDS, den.meal_interval)
	..(animal)
	GLOB.ms13_wildlife += src

/datum/ai_controller/basic_controller/ms13_wildlife/Destroy()
	GLOB.ms13_wildlife -= src
	clear_job()
	den_ref = null
	aggressor_ref = null
	return ..()

/datum/ai_controller/basic_controller/ms13_wildlife/on_stat_change(datum/source, new_stat, old_stat)
	. = ..()
	if(new_stat != CONSCIOUS)
		clear_job()
	if(new_stat == DEAD)
		GLOB.ms13_wildlife -= src
	else
		GLOB.ms13_wildlife |= src

/datum/ai_controller/basic_controller/ms13_wildlife/on_sentience_gained()
	clear_job()
	return ..()

/datum/ai_controller/basic_controller/ms13_wildlife/proc/clear_job(failed = FALSE)
	var/atom/target = job_target?.resolve()
	var/mob/living/basic/animal = pawn
	var/mob/living/food = food_ref?.resolve()
	if(failed)
		if(target)
			ignored_targets[REF(target)] = world.time + 30 SECONDS
		if(food)
			ignored_targets[REF(food)] = world.time + 30 SECONDS
	if(food)
		animal?.release_grabs(food)
		if(food.ms13_wildlife_claim?.resolve() == src)
			food.ms13_wildlife_claim = null
	job = null
	job_target = null
	food_ref = null
	eating_since = 0
	changing_job = TRUE
	CancelActions()
	changing_job = FALSE
	clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	set_move_target(null)

/datum/ai_controller/basic_controller/ms13_wildlife/proc/start_job(new_job, atom/target)
	clear_job()
	var/mob/living/basic/animal = pawn
	job = new_job
	job_target = WEAKREF(target)
	job_deadline = world.time + 45 SECONDS
	progress_deadline = world.time + 10 SECONDS
	best_distance = get_dist(pawn, target)
	last_target_health = isliving(target) ? astype(target, /mob/living).health : null
	if(job == "hunt")
		set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
		var/attack_behavior = animal.wildlife_ranged ? /datum/ai_behavior/basic_ranged_attack/ms13_wildlife : /datum/ai_behavior/basic_melee_attack/ms13_wildlife
		queue_behavior(attack_behavior, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	else
		var/travel_behavior = job == "escape" ? /datum/ai_behavior/ms13_wildlife_travel/escape : /datum/ai_behavior/ms13_wildlife_travel
		queue_behavior(travel_behavior, target)

/datum/ai_controller/basic_controller/ms13_wildlife/proc/ignored(atom/target)
	return ignored_targets[REF(target)] > world.time

/datum/ai_controller/basic_controller/ms13_wildlife/proc/provoke(mob/living/attacker)
	if(QDELETED(attacker) || attacker == pawn || attacker.stat == DEAD)
		return
	aggressor_ref = WEAKREF(attacker)
	aggressor_until = world.time + 45 SECONDS
	// A previously unreachable attacker can now reach us. Reconsider it instead of ignoring fresh injuries.
	ignored_targets -= REF(attacker)
	frightened_until = 0
	next_decision = 0

/// Rough risk estimate, not a combat simulation. Injury never makes a large animal look harmless.
/datum/ai_controller/basic_controller/ms13_wildlife/proc/combat_strength(mob/living/animal, include_allies = FALSE)
	if(QDELETED(animal) || animal.stat != CONSCIOUS)
		return 0
	var/damage = 20
	var/size = 2
	var/mob/living/basic/basic = animal
	var/mob/living/simple_animal/simple = animal
	if(istype(basic))
		damage = (basic.melee_damage_lower + basic.melee_damage_upper) / 2
		size = basic.wildlife_size
	else if(istype(simple))
		damage = (simple.melee_damage_lower + simple.melee_damage_upper) / 2
	var/strength = max(animal.health, animal.maxHealth * 0.5) * max(damage, 5) * max(size / 2, 1)
	if(!include_allies || !istype(basic))
		return strength
	// ponytail: local risk heuristic; allies contribute half strength, with no shared target orders.
	// Bounded to visible neighbours; use a combat forecast only if these balance estimates prove inadequate.
	for(var/mob/living/basic/ally in view(3, animal))
		if(ally == animal || ally.client || ally.stat != CONSCIOUS || (!istype(ally, animal.type) && !istype(animal, ally.type)))
			continue
		var/datum/ai_controller/basic_controller/ms13_wildlife/controller = ally.ai_controller
		if(!istype(controller) || controller.retreating || world.time < controller.frightened_until)
			continue
		var/obj/effect/spawner/ms13/wildlife_den/den = controller.den_ref?.resolve()
		if(!den || ally.health <= ally.maxHealth * den.retreat_health || get_dist(den, animal) > den.leash_radius)
			continue
		if(!animal.IsReachableBy(ally) && !length(SSpathfinder.jps_pathfind_now(ally, animal, max_steps = 5, mintargetdist = 1)))
			continue
		strength += combat_strength(ally) * 0.5
	return strength

/datum/ai_controller/basic_controller/ms13_wildlife/proc/is_prey(mob/living/target)
	var/mob/living/basic/animal = pawn
	var/obj/effect/spawner/ms13/wildlife_den/den = den_ref?.resolve()
	if(!den || !animal.wildlife_eats_meat || QDELETED(target) || target == pawn || ishuman(target) || !(target.mob_biotypes & MOB_ORGANIC) || !(target.mob_biotypes & MOB_BEAST) || (target.mob_biotypes & MOB_ROBOTIC))
		return FALSE
	if(istype(target, animal.type) || istype(animal, target.type))
		return FALSE
	var/datum/ai_controller/basic_controller/ms13_wildlife/other = target.ai_controller
	if(istype(other) && other.den_ref?.resolve() == den)
		return FALSE
	// Scavenging an existing carcass does not require winning a fight against its living species.
	return target.stat == DEAD || combat_strength(animal, TRUE) >= combat_strength(target, TRUE) * animal.wildlife_hunt_ratio

/datum/ai_controller/basic_controller/ms13_wildlife/proc/can_hunt(mob/living/target)
	var/obj/effect/spawner/ms13/wildlife_den/den = den_ref?.resolve()
	if(QDELETED(target) || target == pawn || target.stat == DEAD || !isturf(target.loc) || target.z != pawn.z || ignored(target))
		return FALSE
	if(!den)
		return target == aggressor_ref?.resolve() && world.time < aggressor_until && get_dist(pawn, target) <= 7
	if(target.z != den.z || get_dist(target, den) > den.leash_radius)
		return FALSE
	if(target == aggressor_ref?.resolve() && world.time < aggressor_until)
		return TRUE
	if(ishuman(target))
		var/mob/living/basic/animal = pawn
		return animal.wildlife_hostile_to_people || get_dist(den, target) <= den.territory_radius
	return world.time >= hungry_at && is_prey(target)

/datum/targeting_strategy/generic/ms13_wildlife/should_attack_mob(mob/living/pawn, datum/ai_controller/basic_controller/ms13_wildlife/controller, mob/living/target)
	return controller.can_hunt(target)

/datum/targeting_strategy/generic/ms13_wildlife/can_attack(mob/living/pawn, atom/target, vision_range)
	return isliving(target) && ..()

/datum/ai_controller/basic_controller/ms13_wildlife/ProcessBehaviorSelection(delta_time)
	if(world.time < next_decision || !able_to_run())
		return
	next_decision = world.time + 1 SECONDS
	var/mob/living/basic/animal = pawn
	var/obj/effect/spawner/ms13/wildlife_den/den = den_ref?.resolve()
	if(!den)
		// Losing the den must not turn a previously peaceful animal into a generic hostile.
		var/mob/living/attacker = aggressor_ref?.resolve()
		if(can_hunt(attacker))
			if(job != "hunt" || job_target?.resolve() != attacker)
				start_job("hunt", attacker)
		else
			clear_job()
			step_rand(animal)
			next_decision = world.time + 3 SECONDS
		return
	for(var/key in ignored_targets)
		if(ignored_targets[key] <= world.time)
			ignored_targets -= key
	var/atom/target = job_target?.resolve()
	if(job)
		if(!target || target.z != animal.z || world.time >= job_deadline || world.time >= progress_deadline)
			clear_job(TRUE)
		else
			var/distance = get_dist(animal, target)
			var/target_health = isliving(target) ? astype(target, /mob/living).health : null
			if(distance < best_distance || (!isnull(target_health) && target_health < last_target_health))
				best_distance = distance
				progress_deadline = world.time + 10 SECONDS
			last_target_health = target_health
	if(animal.health <= animal.maxHealth * den.retreat_health)
		retreating = TRUE
	if(retreating && animal.health >= animal.maxHealth * den.recover_health)
		retreating = FALSE
	var/mob/living/attacker = aggressor_ref?.resolve()
	if(can_hunt(attacker) && (attacker in view(7, animal)))
		if(retreating || combat_strength(animal, TRUE) < combat_strength(attacker, TRUE))
			if(job == "escape" && target && get_dist(target, attacker) > get_dist(animal, attacker))
				return
			if(choose_patrol(TRUE, get_turf(attacker)))
				return
		// Cornered animals defend themselves, including at home and regardless of diet.
		if(job != "hunt" || target != attacker)
			start_job("hunt", attacker)
		return
	if(!retreating && world.time < frightened_until)
		if(job != "escape")
			clear_job()
			choose_patrol(TRUE, noise_source?.resolve())
		return
	if(retreating || animal.z != den.z || get_dist(animal, den) > den.leash_radius)
		if(get_dist(animal, den) <= 2 && animal.z == den.z)
			clear_job()
			if(world.time > animal.ms13_hurt_at + 5 SECONDS)
				animal.adjustBruteLoss(-den.healing_per_second)
			return
		if(job == "home" || job == "escape")
			return
		if(!ignored(den))
			start_job("home", den)
		else
			choose_patrol(TRUE)
		return
	// Threats can interrupt grazing or hauling. Hearing a gun does not identify an enemy.
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	var/mob/living/threat
	for(var/mob/living/candidate in view(7, animal))
		if((ishuman(candidate) || candidate == aggressor_ref?.resolve()) && strategy.can_attack(animal, candidate, 7))
			threat = candidate
			break
	if(threat && (job != "hunt" || target != threat))
		start_job("hunt", threat)
		return
	if(threat)
		return
	if(job == "hunt")
		var/mob/living/victim = job_target?.resolve()
		if(victim?.stat == DEAD && is_prey(victim))
			begin_haul(victim)
		else if(!can_hunt(victim))
			clear_job()
	if(job == "haul")
		var/mob/living/food = food_ref?.resolve()
		if(!edible_corpse(food) || !animal.is_grabbing(food) || get_dist(animal, food) > 1)
			clear_job(TRUE)
		else
			return // Finish a meal already secured unless safety interrupts it above.
	// Compare nearby opportunities by need, distance and risk; no species-specific action sequence.
	var/best_score = 18
	var/best_job
	var/atom/best_target
	if(world.time >= hungry_at)
		var/hunger = 1 + min(2, (world.time - hungry_at) / den.meal_interval)
		for(var/mob/living/food in view(7, animal))
			if(edible_corpse(food) && !ignored(food))
				var/score = 80 * hunger - 4 * get_dist(animal, food) + (food == target ? 15 : 0)
				if(score > best_score)
					best_score = score
					best_job = "fetch"
					best_target = food
			else if(strategy.can_attack(animal, food, 7))
				var/score = 65 * hunger - 4 * get_dist(animal, food) - 25 * food.health / max(animal.health, 1) + (food == target ? 15 : 0)
				if(score > best_score)
					best_score = score
					best_job = "hunt"
					best_target = food
		if(animal.wildlife_eats_plants)
			for(var/obj/structure/flora/plant in view(7, animal))
				if(!ignored(plant) && plant.ms13_can_graze() && get_dist(den, plant) <= den.leash_radius)
					var/score = 60 * hunger - 3 * get_dist(animal, plant) + (plant == target ? 15 : 0)
					if(score > best_score)
						best_score = score
						best_job = "graze"
						best_target = plant
	if(best_target)
		if(job != best_job || target != best_target)
			if(best_job == "fetch")
				begin_haul(best_target)
			else
				start_job(best_job, best_target)
		return
	if(!job)
		if(prob(25))
			next_decision = world.time + rand(4, 12) SECONDS
		else
			choose_patrol()

/datum/ai_controller/basic_controller/ms13_wildlife/proc/choose_patrol(escaping = FALSE, turf/away_from)
	var/obj/effect/spawner/ms13/wildlife_den/den = den_ref?.resolve()
	if(!den)
		return FALSE
	if(escaping && away_from)
		// Check every adjacent exit before deciding we are cornered. Never flee through the threat.
		for(var/direction in shuffle(GLOB.alldirs))
			var/turf/exit = get_step(pawn, direction)
			if(!isfloorturf(exit) || ignored(exit) || exit.is_blocked_turf(source_atom = pawn) || get_dist(exit, away_from) <= get_dist(pawn, away_from))
				continue
			if(!length(SSpathfinder.jps_pathfind_now(pawn, exit, max_steps = 2, mintargetdist = 0, exclude = away_from)))
				continue
			start_job("escape", exit)
			return TRUE
		return FALSE
	// Bounded attempts: a sealed den must not spend a whole tick searching its surroundings.
	for(var/i in 1 to 8)
		var/turf/center = escaping ? get_turf(pawn) : get_turf(den)
		var/radius = escaping ? 4 : den.patrol_radius
		var/turf/destination = locate(center.x + rand(-radius, radius), center.y + rand(-radius, radius), center.z)
		if(!destination || ignored(destination) || !ms13_ecology_clear_tile(destination))
			continue
		if(away_from && get_dist(destination, away_from) <= get_dist(pawn, away_from))
			continue
		start_job(escaping ? "escape" : "patrol", destination)
		return TRUE
	return FALSE

/datum/ai_controller/basic_controller/ms13_wildlife/proc/edible_corpse(mob/living/food)
	if(QDELETED(food) || food.stat != DEAD || !is_prey(food) || !isturf(food.loc) || food.z != pawn.z || food.buckled)
		return FALSE
	var/datum/ai_controller/owner = food.ms13_wildlife_claim?.resolve()
	if(owner && owner != src)
		return FALSE
	var/mob/living/animal = pawn
	return !length(food.grabbed_by) || animal.is_grabbing(food)

/datum/ai_controller/basic_controller/ms13_wildlife/proc/begin_haul(mob/living/food)
	if(!edible_corpse(food))
		clear_job(TRUE)
		return
	start_job("fetch", food)
	food.ms13_wildlife_claim = WEAKREF(src)
	food_ref = WEAKREF(food)

/datum/ai_controller/basic_controller/ms13_wildlife/proc/arrive()
	var/mob/living/basic/animal = pawn
	var/obj/effect/spawner/ms13/wildlife_den/den = den_ref?.resolve()
	if(!den)
		clear_job()
		return
	switch(job)
		if("fetch")
			var/mob/living/food = food_ref?.resolve()
			if(!edible_corpse(food) || !animal.try_make_grab(food))
				clear_job(TRUE)
				return
			// Keep ownership and the grab while changing the movement destination.
			changing_job = TRUE
			CancelActions()
			changing_job = FALSE
			job = "haul"
			job_target = WEAKREF(den)
			best_distance = get_dist(animal, den)
			progress_deadline = world.time + 10 SECONDS
			job_deadline = world.time + 45 SECONDS
			queue_behavior(/datum/ai_behavior/ms13_wildlife_travel, den)
		if("haul")
			var/mob/living/food = food_ref?.resolve()
			if(!edible_corpse(food) || !animal.is_grabbing(food) || get_dist(food, den) > 2)
				clear_job(TRUE)
				return
			if(!eating_since)
				eating_since = world.time
			if(world.time < eating_since + 5 SECONDS)
				return
			animal.visible_message(span_notice("[animal] consumes [food] at its den."))
			clear_job()
			// Wildlife prey only: human corpses and their equipment are never eaten.
			for(var/obj/item/item in food.contents)
				food.dropItemToGround(item, TRUE)
			qdel(food)
			hungry_at = world.time + den.meal_interval
			animal.adjustBruteLoss(-animal.maxHealth * 0.15)
		if("graze")
			var/obj/structure/flora/plant = job_target?.resolve()
			if(!plant?.ms13_can_graze())
				clear_job(TRUE)
				return
			if(!eating_since)
				eating_since = world.time
			if(world.time < eating_since + 4 SECONDS)
				return
			if(plant.ms13_graze())
				animal.visible_message(span_notice("[animal] grazes on [plant]."))
				hungry_at = world.time + den.meal_interval
			clear_job()
		else
			var/escaping = job == "escape"
			clear_job()
			next_decision = escaping ? 0 : world.time + rand(2 SECONDS, 5 SECONDS)

/datum/ai_behavior/ms13_wildlife_travel
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_REQUIRE_REACH | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	action_cooldown = 1 SECONDS

/datum/ai_behavior/ms13_wildlife_travel/escape
	required_distance = 0

/datum/ai_behavior/ms13_wildlife_travel/setup(datum/ai_controller/controller, atom/destination)
	controller.set_move_target(destination)
	return TRUE

/datum/ai_behavior/ms13_wildlife_travel/perform(delta_time, datum/ai_controller/basic_controller/ms13_wildlife/controller, atom/destination)
	controller.arrive()
	return BEHAVIOR_PERFORM_COOLDOWN

/datum/ai_behavior/ms13_wildlife_travel/finish_action(datum/ai_controller/basic_controller/ms13_wildlife/controller, succeeded, atom/destination)
	. = ..()
	if(!succeeded && !controller.changing_job)
		controller.clear_job(TRUE)

/datum/ai_behavior/basic_melee_attack/ms13_wildlife
	action_cooldown = 1.5 SECONDS

/datum/ai_behavior/basic_ranged_attack/ms13_wildlife
	required_distance = 7
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	action_cooldown = 1.5 SECONDS

/datum/ai_behavior/basic_ranged_attack/ms13_wildlife/finish_action(datum/ai_controller/basic_controller/ms13_wildlife/controller, succeeded, target_key, targeting_strategy_key, hiding_location_key)
	. = ..()
	if(!succeeded && !controller.changing_job)
		controller.clear_job(TRUE)

/datum/ai_behavior/basic_melee_attack/ms13_wildlife/finish_action(datum/ai_controller/basic_controller/ms13_wildlife/controller, succeeded, target_key, targeting_strategy_key, hiding_location_key)
	. = ..()
	if(!succeeded && !controller.changing_job)
		var/mob/living/target = controller.job_target?.resolve()
		if(target?.stat == DEAD && controller.is_prey(target))
			controller.begin_haul(target)
		else
			controller.clear_job(TRUE)

/// Loud sounds use the same source turf and volume as the audible sound system.
/proc/ms13_startle_wildlife(turf/source, volume, audible_range = 18)
	if(!source || volume < 70)
		return
	// ponytail: linear in den wildlife, not all mobs; spatial indexing if maps sustain hundreds of animals.
	for(var/datum/ai_controller/basic_controller/ms13_wildlife/controller as anything in GLOB.ms13_wildlife)
		controller.hear_noise(source, audible_range, volume)

/datum/ai_controller/basic_controller/ms13_wildlife/proc/hear_noise(turf/source, audible_range, volume = 80)
	var/obj/effect/spawner/ms13/wildlife_den/den = den_ref?.resolve()
	if(!den || !able_to_run() || pawn.z != source.z || get_dist(pawn, source) > audible_range || get_dist(pawn, source) == 0 || world.time < noise_cooldown || get_dist(pawn, den) <= den.territory_radius)
		return FALSE
	if(volume * ms13_wall_muffle(source, get_turf(pawn)) < 40)
		return FALSE
	noise_cooldown = world.time + 20 SECONDS
	var/mob/living/basic/animal = pawn
	if(!prob(animal.wildlife_noise_flee_chance))
		return FALSE
	frightened_until = world.time + 12 SECONDS
	noise_source = WEAKREF(source)
	clear_job()
	next_decision = 0
	return TRUE

// Basic-mob bullet_act does not call its parent signal. Damage comparisons also avoid provoking on petting or healing.
/mob/living/basic/proc/ms13_wildlife_attacked(mob/living/attacker, old_health)
	if(health >= old_health || !istype(ai_controller, /datum/ai_controller/basic_controller/ms13_wildlife))
		return
	var/datum/ai_controller/basic_controller/ms13_wildlife/controller = ai_controller
	controller.provoke(attacker)

/mob/living/basic/attacked_by(obj/item/item, mob/living/attacker, datum/special_attack/special)
	var/old_health = health
	. = ..()
	ms13_wildlife_attacked(attacker, old_health)

/mob/living/basic/attack_hand(mob/living/carbon/human/user, list/modifiers)
	var/old_health = health
	. = ..()
	ms13_wildlife_attacked(user, old_health)

/mob/living/basic/attack_basic_mob(mob/living/basic/user, list/modifiers)
	var/old_health = health
	. = ..()
	ms13_wildlife_attacked(user, old_health)

/mob/living/basic/attack_animal(mob/living/simple_animal/user, list/modifiers)
	var/old_health = health
	. = ..()
	ms13_wildlife_attacked(user, old_health)

/mob/living/basic/bullet_act(obj/projectile/projectile, def_zone, piercing_hit = FALSE)
	var/old_health = health
	. = ..()
	if(isliving(projectile.firer))
		ms13_wildlife_attacked(projectile.firer, old_health)
