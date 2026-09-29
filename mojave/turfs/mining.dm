// One automatic mining action per person, shared by walls, deposits and cave-in debris.
/mob/living
	var/tmp/ms13_mining = FALSE

/mob/living/proc/ms13_mining_delay(obj/item/tool)
	return clamp((10 / 3) SECONDS * tool.toolspeed / max(0.25, get_stat_ratio(SPECIAL_STRENGTH)), 2 SECONDS, 10 SECONDS)

/mob/living/proc/ms13_can_mine(atom/target, obj/item/tool)
	if(QDELETED(target) || QDELETED(tool) || !isturf(loc) || !is_holding(tool) || !Adjacent(target) || incapacitated())
		return FALSE
	if(tool.tool_behaviour != TOOL_MINING || !tool.tool_use_check(src, 0) || !stamina || stamina.current < 25)
		return FALSE
	if(istype(target, /turf/closed/mineral/random/ms13))
		return TRUE
	var/turf/site = get_turf(target)
	return (istype(target, /obj/structure/ms13/ore_deposit) || istype(target, /obj/structure/ms13/cave_in)) && !(target.resistance_flags & INDESTRUCTIBLE) && site && !site.density

/mob/living/proc/ms13_mine(atom/target, obj/item/tool)
	if(ms13_mining || DOING_INTERACTION(src, "MINING_ORE") || !ISADVANCEDTOOLUSER(src))
		return FALSE
	if(!ms13_can_mine(target, tool))
		if(stamina?.current < 25)
			to_chat(src, span_warning("You need to catch your breath before mining."))
		return FALSE
	ms13_mining = TRUE
	// Keep the existing stamina system's minimum recovery; each swing still costs more than it restores.
	var/datum/stamina_container/working_stamina = stamina
	working_stamina.add_regen_modifier("ms13_mining", -1000)
	to_chat(src, span_notice("You start mining [target]. Moving or putting away your tool stops the work."))
	while(ms13_can_mine(target, tool))
		tool.play_tool_sound(target, 40)
		if(!do_after(src, target, ms13_mining_delay(tool), DO_PUBLIC, extra_checks = CALLBACK(src, PROC_REF(ms13_can_mine), target, tool), interaction_key = "MINING_ORE", display = tool))
			break
		working_stamina.adjust(-25)
		if(istype(target, /turf/closed/mineral/random/ms13))
			var/turf/closed/mineral/random/ms13/rock = target
			var/damage = 40
			if(istype(tool, /obj/item/pickaxe))
				var/obj/item/pickaxe/pick = tool
				damage = pick.mining_damage
			rock.mine(max(1, damage), tool, src)
		else
			target.take_damage(max(1, tool.force * (1 + max(0, tool.mining_mult))), BRUTE, BLUNT)
		. = TRUE
	if(!QDELETED(working_stamina))
		working_stamina.remove_regen_modifier("ms13_mining")
	ms13_mining = FALSE

/turf/closed/mineral/random/ms13/attackby(obj/item/tool, mob/user, params)
	if(tool.tool_behaviour == TOOL_MINING && isliving(user))
		var/mob/living/miner = user
		return miner.ms13_mine(src, tool)

/// Rock uses mining health rather than atom integrity; mob attacks must make progress on that same pool.
/turf/closed/mineral/random/ms13/get_integrity()
	return mining_health

/turf/closed/mineral/random/ms13/attack_generic(mob/user, damage_amount = 0, damage_type = BRUTE, damage_flag = NONE, sound_effect = TRUE, armor_penetration = 0)
	if((resistance_flags & INDESTRUCTIBLE) || !(damage_type in list(BRUTE, BURN)) || damage_amount < DAMAGE_PRECISION || (damage_flag == BLUNT && damage_amount < damage_deflection))
		return FALSE
	user.do_attack_animation(src)
	user.changeNext_move(CLICK_CD_MELEE)
	if(sound_effect)
		playsound(src, SFX_ROCK_TAP, 50, TRUE)
	mine(damage_amount, user = user)
	return TRUE

/// Wall-smashers dig rock by their damage too, rather than DD's instant drilling.
/turf/closed/mineral/random/ms13/attack_animal(mob/living/simple_animal/user, list/modifiers)
	return attack_generic(user, user.obj_damage || user.melee_damage_upper, user.melee_damage_type, BLUNT)

/turf/closed/mineral/random/ms13/attack_basic_mob(mob/living/basic/user, list/modifiers)
	return attack_generic(user, user.obj_damage, user.melee_damage_type, BLUNT)

/turf/closed/mineral/random/ms13/MinedAway()
	var/turf/site = src
	. = ..()
	if(isopenturf(site))
		site.ms13_unsupported_span = rand(3, 5)
		site.ms13_check_roof()

/turf
	/// Zero means pre-existing terrain; newly excavated tiles get a fixed, random support spacing.
	var/ms13_unsupported_span = 0
	var/tmp/ms13_cave_in_pending = FALSE

/turf/proc/ms13_roof_supported()
	if(!ms13_unsupported_span || !isopenturf(src))
		return TRUE
	// A short flood fill prevents support through rock walls or around excessively long bends.
	var/list/frontier = list(src)
	var/list/visited = list(src)
	for(var/distance in 0 to ms13_unsupported_span)
		var/list/next_frontier = list()
		for(var/turf/site as anything in frontier)
			if(!site.ms13_unsupported_span)
				return TRUE // The original tunnel entrance is a natural anchor.
			for(var/obj/structure/ms13/cave_decor/support/beam in site)
				if(beam.anchored && !QDELETED(beam) && !istype(beam, /obj/structure/ms13/cave_decor/support/wall/broken))
					return TRUE
			for(var/direction in GLOB.cardinals)
				var/turf/neighbor = get_step(site, direction)
				if(!isopenturf(neighbor) || neighbor.density || (neighbor in visited))
					continue
				visited += neighbor
				next_frontier += neighbor
		frontier = next_frontier
	return FALSE

/turf/proc/ms13_check_roof()
	if(ms13_cave_in_pending || ms13_roof_supported() || (locate(/obj/structure/ms13/cave_in) in src))
		return
	ms13_cave_in_pending = TRUE
	visible_message(span_boldwarning("Dust rains from the ceiling! The unsupported rock is giving way!"))
	playsound(src, 'sound/effects/break_stone.ogg', 35, TRUE)
	addtimer(CALLBACK(src, PROC_REF(ms13_collapse_roof)), rand(10, 15) SECONDS)

/turf/proc/ms13_collapse_roof()
	ms13_cave_in_pending = FALSE
	if(ms13_roof_supported() || (locate(/obj/structure/ms13/cave_in) in src))
		return FALSE
	visible_message(span_boldwarning("The mine roof collapses in a shower of rock!"))
	playsound(src, 'sound/effects/meteorimpact.ogg', 70, TRUE)
	for(var/mob/living/victim in src)
		victim.adjustBruteLoss(35)
		victim.Knockdown(2 SECONDS)
	new /obj/structure/ms13/cave_in(src)
	return TRUE

/obj/structure/ms13/cave_decor/support/Destroy()
	for(var/turf/site in range(6, src))
		if(site.ms13_unsupported_span)
			addtimer(CALLBACK(site, TYPE_PROC_REF(/turf, ms13_check_roof)), 1)
	return ..()

/obj/structure/ms13/cave_in
	name = "collapsed rock"
	desc = "Fallen rock blocks the tunnel. A pickaxe can clear it, but the roof still needs support beams."
	icon = 'mojave/icons/structure/cave_decor.dmi'
	icon_state = "stalagmite3"
	anchored = TRUE
	density = TRUE
	max_integrity = 450
	hitted_sound = 'sound/effects/break_stone.ogg'

/obj/structure/ms13/cave_in/attackby(obj/item/tool, mob/user, params)
	if(tool.tool_behaviour == TOOL_MINING && isliving(user))
		var/mob/living/miner = user
		return miner.ms13_mine(src, tool)
	return ..()

/obj/structure/ms13/cave_in/Destroy()
	var/turf/site = get_turf(src)
	if(site)
		addtimer(CALLBACK(site, TYPE_PROC_REF(/turf, ms13_check_roof)), 1)
	return ..()

#ifdef UNIT_TESTS
#include "mining_unit_test.dm"
#endif
