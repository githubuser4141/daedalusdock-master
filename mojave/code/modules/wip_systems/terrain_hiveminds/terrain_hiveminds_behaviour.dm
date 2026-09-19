// Focused extensions kept separate from the framework so variant balance can be tuned independently.

/datum/ms13_terrain_hivemind
	/// A corpse delivered to a core or converter permanently expands the network's storage.
	var/corpse_capacity_value = 5

/datum/ms13_terrain_hivemind/advance_corpse_conversion(mob/living/corpse, datum/converter, delta_time, conversion_time, claim = TRUE)
	var/atom/delivery_structure = istype(converter, /obj/structure/ms13_hivemind) ? converter : null
	var/old_unit_count = length(units)
	var/conversion_subject = corpse?.stat == DEAD ? "remains" : "living host"
	var/conversion_verb = corpse?.stat == DEAD ? "consumes" : "incubates"
	. = ..()
	if(!. || !delivery_structure)
		return
	max_resources += corpse_capacity_value
	if(length(units) > old_unit_count)
		delivery_structure.visible_message(span_notice("[delivery_structure] [conversion_verb] the [conversion_subject], expands the hive's biomass reserve, and births a new unit."))
	else
		delivery_structure.visible_message(span_notice("[delivery_structure] [conversion_verb] the [conversion_subject], increasing the hive's biomass capacity and stored resources."))

/datum/ms13_terrain_hivemind/find_reported_corpse(atom/seeker)
	. = ..()
	if(istype(seeker, /mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter) && . && get_dist(seeker, .) > 14)
		return null

/datum/ms13_terrain_hivemind/eris/New(turf/start, new_territory_limit)
	. = ..()
	unit_appearances["suicide"] = list(
		"name" = "hivemind bomber",
		"icon" = 'mojave/icons/wip/terrain_hivemind/eris_hivemind_mobs.dmi',
		"state" = "bomber",
	)
	evolved_mob_types |= /mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide

/datum/ms13_terrain_hivemind/necromorph/New(turf/start, new_territory_limit)
	. = ..()
	unit_appearances["siege"] = list(
		"name" = "necromorph tripod",
		"icon" = 'mojave/icons/wip/terrain_hivemind/ds13_tripod.dmi',
		"state" = "preview",
		"pixel_x" = -54,
	)
	unit_appearances["suicide"] = list(
		"name" = "necromorph exploder",
		"icon" = 'mojave/icons/wip/terrain_hivemind/ds13_exploder.dmi',
		"state" = "preview",
		"pixel_x" = -8,
		"pixel_y" = -8,
	)
	unit_appearances["regenerator"] = list(
		"name" = "necromorph hunter",
		"icon" = 'mojave/icons/wip/terrain_hivemind/ds13_hunter.dmi',
		"state" = "preview",
		"pixel_x" = -8,
		"pixel_y" = -16,
	)
	elite_mob_types |= /mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/siege
	elite_mob_types |= /mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide/necromorph
	elite_mob_types |= /mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/regenerator

/datum/ms13_terrain_hivemind/xenomorph/New(turf/start, new_territory_limit)
	special_types = special_types.Copy()
	special_types -= /obj/structure/ms13_hivemind/special/converter
	special_types += /obj/structure/ms13_hivemind/special/xenomorph_egg
	return ..()

/datum/ms13_terrain_hivemind/xenomorph/prepare_delivered_subject(mob/living/subject, obj/structure/ms13_hivemind/destination)
	if(!is_convertible_corpse(subject) || !is_territory(get_turf(subject)))
		return destination
	for(var/obj/structure/ms13_hivemind/xenomorph_nest/nest in get_turf(subject))
		if(nest.network == src)
			return nest
	return new /obj/structure/ms13_hivemind/xenomorph_nest(get_turf(subject), src, subject)

/datum/ms13_terrain_hivemind/xenomorph/process_terrain_corpses(delta_time)
	var/territory_count = length(territory)
	if(!territory_count)
		return
	var/check_count = min(terrain_corpse_scan_budget, territory_count)
	for(var/i in 1 to check_count)
		if(terrain_corpse_scan_cursor > territory_count)
			terrain_corpse_scan_cursor = 1
		var/obj/structure/ms13_hivemind/terrain/growth = territory[terrain_corpse_scan_cursor++]
		if(!growth || QDELETED(growth))
			continue
		for(var/mob/living/host in get_turf(growth))
			if(!is_convertible_corpse(host) || LAZYLEN(host.grabbed_by) || get_corpse_claim(host))
				continue
			var/obj/structure/ms13_hivemind/xenomorph_nest/nest = prepare_delivered_subject(host, core)
			if(!nest)
				continue
			if(!claim_corpse(host, nest))
				qdel(nest)

/obj/structure/low_wall/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(.)
		return
	var/mob/living/simple_animal/hostile/ms13/terrain_hivemind/unit = mover
	if(istype(unit) && unit.network?.can_cross_low_walls)
		return TRUE
	var/mob/living/dragged_body = mover
	if(!istype(dragged_body))
		return FALSE
	for(var/obj/item/hand_item/grab/grab as anything in dragged_body.grabbed_by)
		unit = grab.assailant
		if(istype(unit) && unit.network?.can_haul_over_low_walls)
			return TRUE
	return FALSE

/obj/structure/ms13_hivemind/special/xenomorph_egg
	name = "xenomorph egg"
	desc = "A taut resin egg holding a single, violently impatient parasite."
	icon = 'icons/mob/alien.dmi'
	icon_state = "egg"
	density = FALSE
	max_integrity = 80
	var/activation_range = 5
	var/spent = FALSE

/obj/structure/ms13_hivemind/special/xenomorph_egg/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	if(network)
		START_PROCESSING(SSobj, src)

/obj/structure/ms13_hivemind/special/xenomorph_egg/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/ms13_hivemind/special/xenomorph_egg/process(delta_time)
	if(spent || !network?.active)
		return PROCESS_KILL
	for(var/mob/living/carbon/target in viewers(activation_range, src))
		if(target.stat == DEAD || network.is_allied(target) || !target.get_bodypart(BODY_ZONE_HEAD) || istype(target.wear_mask, /obj/item/clothing/mask/facehugger))
			continue
		spent = TRUE
		visible_message(span_danger("[src] splits open and launches a facehugger at [target]!"))
		var/obj/item/clothing/mask/facehugger/ms13_hive/hugger = new(get_turf(src), network)
		hugger.throw_at(target, activation_range, 1, null)
		new /obj/structure/ms13_hivemind/xenomorph_egg_wreck(get_turf(src))
		qdel(src)
		return PROCESS_KILL

/obj/structure/ms13_hivemind/xenomorph_egg_wreck
	name = "wrecked xenomorph egg"
	desc = "An empty, split-open resin shell."
	icon = 'icons/mob/alien.dmi'
	icon_state = "egg_hatched"
	anchored = TRUE
	density = FALSE
	max_integrity = 30

/obj/item/clothing/mask/facehugger/ms13_hive
	name = "hive facehugger"
	var/datum/ms13_terrain_hivemind/network
	var/armor_threshold = 40

/obj/item/clothing/mask/facehugger/ms13_hive/Initialize(mapload, datum/ms13_terrain_hivemind/join_network)
	. = ..()
	network = join_network

/obj/item/clothing/mask/facehugger/ms13_hive/Leap(mob/living/hit_mob)
	if(hit_mob?.stat == DEAD || !valid_to_attach(hit_mob))
		return FALSE
	var/mob/living/carbon/target = hit_mob
	if(target.wear_mask && istype(target.wear_mask, /obj/item/clothing/mask/facehugger))
		return FALSE
	target.visible_message(span_danger("[src] leaps at [target]'s face!"), span_userdanger("[src] leaps at your face!"))
	if(target.getarmor(BODY_ZONE_HEAD, PUNCTURE) >= armor_threshold)
		target.visible_message(span_warning("[src] cracks against [target]'s head protection and falls away!"), span_notice("Your head protection stops [src]."))
		Die()
		return FALSE
	if(target.head && !target.dropItemToGround(target.head))
		Die()
		return FALSE
	if(target.wear_mask && !target.dropItemToGround(target.wear_mask))
		Die()
		return FALSE
	if(!target.equip_to_slot_if_possible(src, ITEM_SLOT_MASK, 0, 1, 1))
		return FALSE
	log_combat(target, src, "was facehugged by")
	return TRUE

/obj/item/clothing/mask/facehugger/ms13_hive/Impregnate(mob/living/target)
	if(!target || target.stat == DEAD || !iscarbon(target))
		return
	var/mob/living/carbon/carbon_target = target
	if(carbon_target.wear_mask != src)
		return
	target.visible_message(span_danger("[src] falls limp after implanting [target]!"), span_userdanger("[src] falls limp after implanting you!"))
	Die()
	icon_state = "[base_icon_state]_impregnated"
	worn_icon_state = "[base_icon_state]_impregnated"
	if(network?.active)
		network.report_corpse(target)

/obj/structure/ms13_hivemind/xenomorph_nest
	name = "resin nest"
	desc = "A cocoon of resin which restrains and stabilizes a living host."
	icon = 'mojave/icons/by_nc/tgmc_xenomorphs/structures.dmi'
	icon_state = "thickmembrane15"
	anchored = TRUE
	density = FALSE
	layer = ABOVE_MOB_LAYER
	max_integrity = 90
	var/datum/weakref/host_ref
	var/bleeding_reduced = FALSE

/obj/structure/ms13_hivemind/xenomorph_nest/Initialize(mapload, datum/ms13_terrain_hivemind/join_network, mob/living/host)
	. = ..()
	if(!join_network || !host)
		return INITIALIZE_HINT_QDEL
	network = join_network
	host_ref = WEAKREF(host)
	var/mob/living/carbon/human/human_host = host
	if(istype(human_host) && human_host.physiology)
		human_host.physiology.bleed_mod *= 0.4
		bleeding_reduced = TRUE
	START_PROCESSING(SSobj, src)

/obj/structure/ms13_hivemind/xenomorph_nest/Destroy()
	STOP_PROCESSING(SSobj, src)
	var/mob/living/host = host_ref?.resolve()
	if(bleeding_reduced && ishuman(host))
		var/mob/living/carbon/human/human_host = host
		if(human_host.physiology)
			human_host.physiology.bleed_mod /= 0.4
	network?.release_corpse_claim(host, src)
	host_ref = null
	network = null
	return ..()

/obj/structure/ms13_hivemind/xenomorph_nest/process(delta_time)
	var/mob/living/host = host_ref?.resolve()
	if(!network?.active || !network.is_convertible_corpse(host) || get_turf(host) != get_turf(src))
		qdel(src)
		return PROCESS_KILL
	host.Paralyze(2 SECONDS)
	host.adjustOxyLoss(-0.5 * delta_time)
	if(network.advance_corpse_conversion(host, src, delta_time, network.structure_conversion_time))
		qdel(src)
		return PROCESS_KILL

/mob/living/simple_animal/hostile/ms13/terrain_hivemind
	var/force_opens_doors = TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/scout
	force_opens_doors = FALSE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter
	terrain_recovery_health = 0.4
	terrain_recovery_range = 12
	force_opens_doors = FALSE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/handle_automated_action()
	set waitfor = FALSE
	if(AIStatus == AI_OFF || !network?.active)
		return FALSE
	// Once committed, keep still long enough to make progress unless survival is genuinely urgent.
	if(health > maxHealth * 0.25 && has_adjacent_conversion_target())
		clear_roam_target()
		return TRUE
	if(handle_converter_recovery())
		return TRUE
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/handle_corpse_work()
	var/mob/living/corpse = corpse_target_ref?.resolve()
	if(corpse && get_dist(src, corpse) <= 1 && LAZYLEN(corpse.grabbed_by))
		clear_corpse_task()
		return FALSE
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/pick_roam_target()
	if(!isturf(loc) || roam_range <= 0)
		return
	var/list/candidates = list()
	for(var/obj/structure/ms13_hivemind/terrain/growth as anything in network.territory)
		var/turf/candidate = get_turf(growth)
		var/distance = get_dist(src, candidate)
		if(distance >= roam_min_distance && distance <= roam_range)
			candidates += candidate
	if(length(candidates))
		return pick(candidates)
	var/obj/structure/ms13_hivemind/terrain/closest = get_closest_atom(/obj/structure/ms13_hivemind/terrain, network.territory, src)
	return get_turf(closest)

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/proc/has_adjacent_conversion_target()
	var/mob/living/corpse = corpse_target_ref?.resolve()
	if(!network?.is_convertible_corpse(corpse) || get_dist(src, corpse) > 1 || LAZYLEN(corpse.grabbed_by))
		return FALSE
	var/datum/current_claim = network.get_corpse_claim(corpse)
	return !current_claim || current_claim == src

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/converter/proc/handle_converter_recovery()
	if(network.is_territory(get_turf(src)) || health > maxHealth * terrain_recovery_health)
		return FALSE
	var/obj/structure/ms13_hivemind/terrain/growth = get_closest_atom(/obj/structure/ms13_hivemind/terrain, network.territory, src)
	if(!growth || get_dist(src, growth) > terrain_recovery_range)
		return FALSE
	LoseTarget()
	clear_corpse_task()
	clear_roam_target()
	Goto(growth, move_to_delay, 0)
	return TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide
	unit_role = "suicide"
	evolution_rank = 2
	health_multiplier = 0.8
	damage_multiplier = 0.5
	corpse_hauler = FALSE
	move_to_delay = 2
	roam_range = 18
	roam_min_distance = 8
	var/fires_shaped_charge_jet = TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide/necromorph
	fires_shaped_charge_jet = FALSE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/suicide/AttackingTarget(atom/attacked_target)
	var/atom/victim = attacked_target
	if(!victim)
		victim = target
	if(!victim || get_dist(src, victim) > 1)
		return ..()
	var/turf/origin = get_turf(src)
	var/attack_direction = get_dir(src, victim)
	if(!attack_direction)
		attack_direction = dir
	var/jet_angle = dir2angle(attack_direction)
	var/blast_shape = fires_shaped_charge_jet ? "focused" : "violent"
	visible_message(span_danger("[src] ruptures in a [blast_shape] blast!"))
	explosion(origin, devastation_range = -1, heavy_impact_range = -1, light_impact_range = 1, adminlog = FALSE, explosion_cause = src)
	if(fires_shaped_charge_jet)
		ms13_fire_shaped_charge_jet(origin, jet_angle, 48, 150, 5, 4, src)
	qdel(src)
	return TRUE

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/siege
	unit_role = "siege"
	health_multiplier = 4
	damage_multiplier = 2.25
	obj_damage = 130
	move_to_delay = 7
	vision_range = 10
	aggro_vision_range = 12

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/heavy/regenerator
	unit_role = "regenerator"
	health_multiplier = 2.75
	damage_multiplier = 1.75
	regeneration_multiplier = 4
	move_to_delay = 4
	vision_range = 10
	aggro_vision_range = 12

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/DestroyObjectsInDirection(direction)
	if(force_opens_doors)
		var/atom/target_from = GET_TARGETS_FROM(src)
		var/turf/next_turf = get_step(target_from, direction)
		if(next_turf?.Adjacent(target_from))
			for(var/obj/machinery/door/door in next_turf)
				if(door.density && door.Adjacent(target_from) && try_force_open_door(door))
					return
	return ..()

/mob/living/simple_animal/hostile/ms13/terrain_hivemind/proc/try_force_open_door(obj/machinery/door/door)
	if(!force_opens_doors || !door?.density || istype(door, /obj/machinery/door/airlock/ms13))
		return FALSE
	var/opened
	if(istype(door, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/airlock = door
		opened = airlock.open(2)
	else
		opened = door.open()
	if(opened)
		visible_message(span_warning("[src] forces [door] open!"))
	return opened
