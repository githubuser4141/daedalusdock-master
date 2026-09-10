// How muscle.dm's performance number reaches actual limb function - melee damage, movement speed, standing,
// and grab/drag strength. Everything here combines with DD's existing gating (bodypart_disabled, the
// limbless/grabbing movespeed modifiers, handle_resist()) rather than replacing it.

/// Floors at MS13_MUSCLE_MISSING_PERFORMANCE_FLOOR if this limb has no muscle organ installed at all.
/// Multiplied by bone stability (bone.dm) - a stable skeleton is the baseline a muscle needs to work at all,
/// not an independent input, so a badly broken bone drags this down even with perfectly healthy muscle.
/obj/item/bodypart/proc/get_muscle_performance()
	var/obj/item/organ/muscle/M = locate() in contained_organs
	var/base = M ? M.get_performance() : MS13_MUSCLE_MISSING_PERFORMANCE_FLOOR
	return round(base * (get_bone_stability() / 100), 0.1)

/**
 * The single point where muscle performance actually affects this limb - called from the muscle organ's
 * on_life()/Insert()/Remove()/set_organ_dead(), so every transition (damage, healing, blood flow, the organ
 * itself coming or going) stays in sync automatically:
 * - grabby limbs: scale unarmed_damage_low/high off the limb's own declared defaults (idempotent, not
 *   cumulative - repeated calls at the same performance always land on the same value)
 * - movement limbs: recompute the whole-body muscle_weakness movespeed modifier (both legs feed one)
 * - always: re-run update_disabled(), so a critically weak limb combines with DD's real disable cascade
 *   (usable_legs/usable_hands/TRAIT_FLOORED/TRAIT_HANDS_BLOCKED/item drop) instead of a parallel one
 */
/obj/item/bodypart/proc/refresh_muscle_effects()
	if(bodypart_flags & BP_IS_GRABBY_LIMB)
		var/perf_ratio = get_muscle_performance() / 100
		unarmed_damage_low = round(initial(unarmed_damage_low) * perf_ratio, 1)
		unarmed_damage_high = round(initial(unarmed_damage_high) * perf_ratio, 1)
		ms13_medical_debug(owner, "[plaintext_zone] unarmed damage now [unarmed_damage_low]-[unarmed_damage_high]")
	if(bodypart_flags & BP_IS_MOVEMENT_LIMB)
		var/mob/living/carbon/human/human_owner = istype(owner, /mob/living/carbon/human) ? owner : null
		human_owner?.update_muscle_movespeed()
	update_disabled()

/// See update_disabled()'s override in code/modules/surgery/bodyparts/_bodyparts.dm.
/obj/item/bodypart/proc/muscle_critically_weak()
	if(!(bodypart_flags & (BP_IS_GRABBY_LIMB|BP_IS_MOVEMENT_LIMB)))
		return FALSE
	return get_muscle_performance() <= MS13_MUSCLE_CRITICAL_PERFORMANCE

/// Both legs feed one whole-body penalty, stacking additively with DD's real /datum/movespeed_modifier/
/// limbless (living.dm's set_usable_legs()) - a fully disabled leg still gets that flat penalty as always,
/// this adds a graduated one for legs that are present but weak.
/mob/living/carbon/human/proc/update_muscle_movespeed()
	var/obj/item/bodypart/l_leg = get_bodypart(BODY_ZONE_L_LEG)
	var/obj/item/bodypart/r_leg = get_bodypart(BODY_ZONE_R_LEG)
	var/l_perf = l_leg ? l_leg.get_muscle_performance() : 100
	var/r_perf = r_leg ? r_leg.get_muscle_performance() : 100
	var/avg_deficit = 100 - ((l_perf + r_perf) * 0.5)
	if(avg_deficit <= 0)
		remove_movespeed_modifier(/datum/movespeed_modifier/muscle_weakness)
		return
	var/slowdown = (avg_deficit / 100) * MS13_MUSCLE_LEG_MAX_SLOWDOWN
	add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/muscle_weakness, slowdown = slowdown)
	ms13_medical_debug(src, "Leg muscle slowdown: [round(slowdown, 0.01)] (deficit=[round(avg_deficit, 0.1)])")

/datum/movespeed_modifier/muscle_weakness
	variable = TRUE
	movetypes = GROUND

/// DD's real update_pull_movespeed() (code/modules/mob/living/living_movement.dm) already applies slowdown
/// per active grab - this layers an independent penalty on top from whichever grabbing arm is weakest.
/mob/living/carbon/human/update_pull_movespeed()
	. = ..()
	var/worst_deficit = 0
	for(var/obj/item/hand_item/grab/G as anything in active_grabs)
		var/held_index = get_held_index_of_item(G)
		var/obj/item/bodypart/grab_arm = held_index ? hand_bodyparts?[held_index] : null
		if(!grab_arm)
			continue
		worst_deficit = max(worst_deficit, 100 - grab_arm.get_muscle_performance())
	if(worst_deficit <= 0)
		remove_movespeed_modifier(/datum/movespeed_modifier/muscle_drag_weakness)
		return
	var/drag_slowdown = (worst_deficit / 100) * MS13_MUSCLE_DRAG_MAX_SLOWDOWN
	add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/muscle_drag_weakness, slowdown = drag_slowdown)
	ms13_medical_debug(src, "Drag slowdown: [round(drag_slowdown, 0.01)] (worst grab arm deficit=[round(worst_deficit, 0.1)])")

/datum/movespeed_modifier/muscle_drag_weakness
	variable = TRUE
	movetypes = GROUND
