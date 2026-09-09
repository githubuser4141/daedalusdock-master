// just changing the messages here to be clearer, mkay?
// AI EDIT: params were "armour_penetration"/"weak_against_armour" (British spelling) - DD's real base
// proc (code/modules/mob/living/living_defense.dm) uses "armor_penetration"/"weak_against_armor". Since
// this fully replaces that proc, callers using DD's real spelling as named args (e.g.
// code/datums/components/embedded.dm:94's weak_against_armor=) crashed with "bad arg name".
/mob/living/run_armor_check(def_zone = null, attack_flag = BLUNT, absorb_text = null, soften_text = null, armor_penetration, penetrated_text, silent=FALSE, weak_against_armor = FALSE)
	var/armor = getarmor(def_zone, attack_flag)

	if(armor <= 0)
		return armor

	if(weak_against_armor && (armor >= 0))
		armor *= ARMOR_WEAKENED_MULTIPLIER

	if(silent)
		return max(0, armor - armor_penetration)

	//the if "armor" check is because this is used for everything on /living, including humans
	if(armor_penetration >= armor)
		armor = max(0, armor - armor_penetration)
		if(penetrated_text)
			to_chat(src, span_userdanger("[penetrated_text]"))
		else
			to_chat(src, span_userdanger("Your DR armor was penetrated!"))
	else if(armor >= 100)
		if(absorb_text)
			to_chat(src, span_notice("[absorb_text]"))
		else
			to_chat(src, span_notice("Your DR armor absorbs the blow!"))
	else
		if(soften_text)
			to_chat(src, span_warning("[soften_text]"))
		else
			to_chat(src, span_warning("Your DR armor softens the blow!"))
	return armor

/mob/living/proc/run_subarmor_check(def_zone = null, \
						attack_flag = BLUNT, \
						absorb_text = null, \
						soften_text = null, \
						armor_penetration = null, \
						penetrated_text = null, \
						silent = FALSE, \
						weak_against_armor = FALSE, \
						sharpness = NONE)
	//We need to convert attack flags into actually useful subarmor variables
	var/static/list/conversion_table = list(BLUNT, PUNCTURE)
	if(attack_flag in conversion_table)
		attack_flag = CRUSHING
		if(sharpness & SHARP_IMPALING)
			attack_flag = IMPALING
		else if(sharpness & SHARP_POINTY)
			attack_flag = PIERCING
		else if(sharpness & SHARP_EDGED)
			attack_flag = CUTTING

	var/armor = getsubarmor(def_zone, attack_flag)
	if(armor <= 0)
		return armor

	if(weak_against_armor && (armor >= 0))
		armor *= ARMOR_WEAKENED_MULTIPLIER

	if(silent)
		return max(0, armor - armor_penetration)

	//the if "armor" check is because this is used for everything on /living, including humans
	if(armor_penetration >= armor)
		armor = max(0, armor - armor_penetration)
		if(penetrated_text)
			to_chat(src, span_userdanger("[penetrated_text]"))
		else
			to_chat(src, span_userdanger("Your armor was fully penetrated!"))
	else if(armor >= 100)
		if(absorb_text)
			to_chat(src, span_notice("[absorb_text]"))
		else
			to_chat(src, span_notice("Your armor fully absorbs the blow!"))
	else
		if(soften_text)
			to_chat(src, span_warning("[soften_text]"))
		else
			to_chat(src, span_warning("Your armor softens the blow!"))

	return max(0, armor - armor_penetration)

/mob/living/proc/getsubarmor(def_zone, d_type)
	return 0

/mob/living/proc/get_edge_protection(def_zone)
	return 0

/mob/living/proc/get_subarmor_flags(def_zone)
	return NONE

/mob/living/proc/damage_armor(damage = 0, damage_flag = BLUNT, damage_type = BRUTE, sharpness = NONE, def_zone = BODY_ZONE_CHEST)
	return damage

/// Used by code/modules/projectiles/projectile.dm's on_hit() to suppress its blood-splatter effect,
/// which is otherwise computed from the pre-hit armor% and has no idea power armor can independently
/// zero out the wearer's actual damage. /mob/living/carbon/human overrides this with the real check.
/mob/living/proc/wearing_power_armor()
	return FALSE

/**
 * Real DT (flat subtraction) hook for BRUTE damage, called from code/modules/mob/living/damage_procs.dm's
 * apply_damage() - see mojave/code/datums/armor/subarmor.dm. Base living mobs have no subarmor, so this
 * is a no-op here; /mob/living/carbon/human overrides it with the real lookup.
 */
/mob/living/proc/get_subarmor_dt_reduction(def_zone, sharpness = NONE)
	return 0
