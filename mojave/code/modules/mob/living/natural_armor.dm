// Generic framework for the body's own tissue layers (muscle, eventually bone) blunting BRUTE damage before
// it reaches real health - independent of external armor/subarmor, which have already been applied by the
// time code/modules/mob/living/damage_procs.dm's apply_damage() calls apply_natural_armor_layers().
//
// Adding a new layer (e.g. bone): subclass /datum/natural_armor_layer, override get_organ(), add an instance
// to the list below. Nothing else needs to change - absorb()'s default split logic and the damage_procs.dm
// wiring are both already generic.

/datum/natural_armor_layer
	/// Fraction of the damage reaching this layer that's dissipated entirely - hurts neither the organ nor the person.
	var/gone_fraction = 0
	/// Fraction that becomes real damage to this layer's organ instead of reaching the person.
	var/absorb_fraction = 0

/// The organ this layer should route damage into for this hit, or null if the layer doesn't apply (wrong
/// damage type, no organ installed here, etc). This is the only proc subtypes normally need to override.
/datum/natural_armor_layer/proc/get_organ(mob/living/carbon/human/H, obj/item/bodypart/hit_part, damagetype)
	return null

/// Splits damage_amount three ways (gone / to the organ / passthrough, scaled by the organ's own remaining
/// health) and returns what's left to pass to the next layer or the person.
/datum/natural_armor_layer/proc/absorb(mob/living/carbon/human/H, damage_amount, damagetype, def_zone)
	var/obj/item/bodypart/hit_part = isbodypart(def_zone) ? def_zone : H.get_bodypart(deprecise_zone(def_zone))
	if(!hit_part)
		return damage_amount
	var/obj/item/organ/O = get_organ(H, hit_part, damagetype)
	if(!O || (O.organ_flags & ORGAN_DEAD))
		return damage_amount
	var/health_ratio = 1 - (O.damage / O.maxHealth)
	var/gone = damage_amount * gone_fraction * health_ratio
	var/absorbed = damage_amount * absorb_fraction * health_ratio
	O.applyOrganDamage(absorbed, updating_health = FALSE)
	var/remaining = damage_amount - gone - absorbed
	ms13_medical_debug(H, "[O.name] absorbed hit: [round(gone, 0.1)] gone, [round(absorbed, 0.1)] to organ, [round(remaining, 0.1)] passthrough")
	return remaining

/// Active layers, checked in order (muscle before bone - outside in, matching real anatomy). Add new layer
/// instances here.
GLOBAL_LIST_INIT(natural_armor_layers, list(new /datum/natural_armor_layer/muscle(), new /datum/natural_armor_layer/bone()))

/// Base stub - safe no-op for any mob without natural armor layers.
/mob/living/proc/apply_natural_armor_layers(damage_amount, damagetype, def_zone)
	return damage_amount

/mob/living/carbon/human/apply_natural_armor_layers(damage_amount, damagetype, def_zone)
	for(var/datum/natural_armor_layer/layer as anything in GLOB.natural_armor_layers)
		damage_amount = layer.absorb(src, damage_amount, damagetype, def_zone)
	return damage_amount
