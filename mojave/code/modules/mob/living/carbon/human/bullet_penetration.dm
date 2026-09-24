// Bullets through a body. A round crosses the limb's own soft tissue, then whichever organs its path happens
// to cross, shallow to deep (bullet_depth), and each soaks a share of the energy that reaches it: its armor against
// the round, through the same stopping-power maths as walls and plating (get_bullet_stopping_power(), bullet_math.dm),
// set against the round's remaining power. Soaking energy deforms the round, so everything after it soaks a bigger
// share of what's left. What an organ soaks isn't lost the way a steel plate sheds it: it goes into the organ and the
// wound channel around it. Whatever gets through all of it flies on, through DD's own BULLET_ACT_FORCE_PIERCE
// (penetrating_hit(), bullet_math.dm).
//
// Nothing adds damage, and nothing stops a round outright. A round stays in only when it has too little left to get
// out (MS13_BULLET_OVERPEN_MIN_REMAINING), and then what's left goes into the last thing it reached.

/obj/item/organ
	/// Percent chance a round through this organ's limb crosses it.
	var/bullet_hit_chance = 0
	/// How deep it sits (BULLET_DEPTH_*). A round crosses shallower organs first.
	var/bullet_depth = BULLET_DEPTH_INNER

/// How much of a round's power this organ soaks: its armor, and for muscle and bone its owner's Strength
/// (get_strength_density(), muscle.dm).
/obj/item/organ/proc/get_bullet_soak_power(obj/projectile/P)
	return get_bullet_stopping_power(P) * get_strength_density()

/obj/item/bodypart
	/// Skin, fat and connective tissue, crossed by every round through the limb before any organ: an armor rating
	/// through the same maths as organ armor. Kept off the limb's own armor, which already guards it from every hit.
	var/soft_tissue_armor = 4

/obj/item/bodypart/chest
	soft_tissue_armor = 5

/obj/item/bodypart/head
	soft_tissue_armor = 3

// DD's own chest and head organs. Mojave's tissue organs set theirs in muscle.dm, bone.dm and vessel.dm. Organ armor
// is only read by bullets, so PUNCTURE is how much of a round each soaks.

TYPEINFO_DEF(/obj/item/organ/brain)
	default_armor = list(BLUNT = 10, PUNCTURE = 7, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 10, ACID = 10)

/obj/item/organ/brain
	bullet_hit_chance = 70
	bullet_depth = BULLET_DEPTH_INNER

TYPEINFO_DEF(/obj/item/organ/eyes)
	default_armor = list(BLUNT = 10, PUNCTURE = 2, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 10, ACID = 10)

/obj/item/organ/eyes
	bullet_hit_chance = 5
	bullet_depth = BULLET_DEPTH_MIDDLE

/datum/typeinfo/obj/item/organ/lungs
	default_armor = list(BLUNT = 10, PUNCTURE = 3, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 10, ACID = 10)

/obj/item/organ/lungs
	bullet_hit_chance = 50
	bullet_depth = BULLET_DEPTH_INNER

/datum/typeinfo/obj/item/organ/heart
	default_armor = list(BLUNT = 10, PUNCTURE = 11, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 10, ACID = 10)

/obj/item/organ/heart
	bullet_hit_chance = 15
	bullet_depth = BULLET_DEPTH_INNER

TYPEINFO_DEF(/obj/item/organ/liver)
	default_armor = list(BLUNT = 10, PUNCTURE = 10, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 10, ACID = 10)

/obj/item/organ/liver
	bullet_hit_chance = 12
	bullet_depth = BULLET_DEPTH_INNER

TYPEINFO_DEF(/obj/item/organ/stomach)
	default_armor = list(BLUNT = 10, PUNCTURE = 6, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 10, ACID = 10)

/obj/item/organ/stomach
	bullet_hit_chance = 10
	bullet_depth = BULLET_DEPTH_INNER

TYPEINFO_DEF(/obj/item/organ/kidneys)
	default_armor = list(BLUNT = 10, PUNCTURE = 9, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 10, ACID = 10)

/obj/item/organ/kidneys
	bullet_hit_chance = 6
	bullet_depth = BULLET_DEPTH_INNER

/proc/cmp_organ_bullet_depth(obj/item/organ/a, obj/item/organ/b)
	return a.bullet_depth - b.bullet_depth

/mob/living/carbon/human
	/// What get_bullet_transfer_fraction() left for each organ it crossed, as organ = damage, waiting to see whether the hit lands.
	var/tmp/list/pending_bullet_organs
	var/tmp/obj/item/bodypart/pending_bullet_part
	/// Of the energy that path stopped, the share that became damage.
	var/tmp/pending_bullet_damage_share

/mob/living/carbon/human/get_bullet_transfer_fraction(obj/projectile/P, def_zone)
	pending_bullet_organs = null
	pending_bullet_part = null
	pending_bullet_damage_share = null
	var/obj/item/bodypart/hit_part = isbodypart(def_zone) ? def_zone : get_bodypart(deprecise_zone(def_zone))
	if(!hit_part || P.damage <= 0)
		return ..()
	if(P.simple_bullet) // Stays in, all of it on the limb: nothing to work out.
		return 1

	var/list/crossed = list()
	for(var/obj/item/organ/O in hit_part.contained_organs)
		if(!(O.organ_flags & ORGAN_DEAD) && !O.cosmetic_only && prob(O.bullet_hit_chance))
			crossed += O
	shuffle_inplace(crossed) // Organs at the same depth come in any order.
	sortTim(crossed, GLOBAL_PROC_REF(cmp_organ_bullet_depth))

	var/remaining = P.damage
	var/wound = 0
	var/list/organ_damage = list()
	var/atom/deepest = hit_part
	for(var/atom/layer as anything in list(hit_part) + crossed)
		var/obj/item/organ/organ = isorgan(layer) ? layer : null
		var/stopping = organ ? organ.get_bullet_soak_power(P) : ms13_armor_stopping_power(hit_part.soft_tissue_armor, P)
		var/share = stopping / max(stopping + remaining * P.get_velocity() * P.get_own_hardness_ratio(), 1)
		var/soaked = remaining * share
		remaining -= soaked
		wound += soak_bullet(layer, soaked, organ_damage)
		deepest = layer
		// It deforms by what it gave up: a round that had to dump half its energy comes out of it mangled. Kept above
		// 0 integrity, which would delete it in the middle of this hit.
		var/deform = min(MS13_BULLET_DEFORM * share, P.getBIntegrity() - 1)
		if(deform > 0)
			P.adjustIntegrity(-deform)

	// Too little left to get out: it stops in the deepest thing it reached.
	if(remaining < MS13_BULLET_OVERPEN_MIN_REMAINING)
		wound += soak_bullet(deepest, remaining, organ_damage)
		remaining = 0

	var/damage = wound
	for(var/obj/item/organ/O as anything in organ_damage)
		damage += organ_damage[O]
	pending_bullet_damage_share = damage / max(P.damage - remaining, 0.01)
	if(length(organ_damage))
		pending_bullet_organs = organ_damage
		pending_bullet_part = hit_part
	if(P.firer)
		var/list/names = list()
		for(var/obj/item/organ/O as anything in organ_damage)
			names += "[O] ([round(organ_damage[O], 0.1)])"
		log_combat(P.firer, src, "shot in the [hit_part.plaintext_zone]", P, "through [length(names) ? english_list(names) : "flesh only"], [round(damage, 0.1)] damage, [round(remaining, 0.1)]/[P.damage] carried on, integrity [round(P.getBIntegrity(), 1)]")
	return 1 - remaining / P.damage

/// Of what a layer soaks, its bullet_damage_ratio becomes damage. An organ keeps MS13_BULLET_ORGAN_SHARE of that;
/// the rest, and all of the soft tissue's, is the wound in the limb. Returns the wound's part.
/mob/living/carbon/human/proc/soak_bullet(atom/layer, soaked, list/organ_damage)
	var/damage = soaked * clamp(layer.bullet_damage_ratio, 0, 1)
	if(!isorgan(layer))
		return damage
	organ_damage[layer] += damage * MS13_BULLET_ORGAN_SHARE
	return damage * (1 - MS13_BULLET_ORGAN_SHARE)

/mob/living/carbon/human/get_bullet_damage_share(obj/projectile/P, stop_fraction)
	return isnull(pending_bullet_damage_share) ? ..() : pending_bullet_damage_share

/// The organs' damage comes out of the limb's, never on top of it.
/mob/living/carbon/human/divert_bullet_damage(obj/projectile/P)
	. = 0
	for(var/obj/item/organ/O as anything in pending_bullet_organs)
		. += pending_bullet_organs[O]

/// Armor that blunted the hit on the limb blunts it on the organs too.
/mob/living/carbon/human/finish_bullet_hit(obj/projectile/P, diverted, landed)
	var/list/organ_damage = pending_bullet_organs
	var/obj/item/bodypart/part = pending_bullet_part
	pending_bullet_organs = null
	pending_bullet_part = null
	pending_bullet_damage_share = null
	if(!landed || !part || diverted <= 0)
		return
	var/through_armor = (100 - clamp(P.last_hit_blocked, 0, 100)) / 100
	for(var/obj/item/organ/O as anything in organ_damage)
		apply_bullet_organ_damage(part, O, organ_damage[O] * through_armor, organ_damage, P.firer)

/// Some of an organ's damage bursts out into organs near it that weren't on the round's path, taken out of that
/// organ's own, never added to it.
/mob/living/carbon/human/proc/apply_bullet_organ_damage(obj/item/bodypart/hit_part, obj/item/organ/struck, amount, list/on_path, atom/firer)
	var/left = amount
	for(var/obj/item/organ/O in hit_part.contained_organs)
		if((O in on_path) || (O.organ_flags & ORGAN_DEAD) || O.cosmetic_only || !prob(O.bullet_hit_chance * MS13_BULLET_SPLASH_CHANCE_MULT))
			continue
		var/splash = min(left, amount * MS13_BULLET_SPLASH_SHARE)
		if(splash <= 0)
			break
		O.applyOrganDamage(splash)
		left -= splash
		if(firer)
			log_combat(firer, src, "bullet splash hit [O]", addition = "[round(splash, 0.1)] damage")
	struck.applyOrganDamage(left)

#ifdef UNIT_TESTS
/// A simple bullet stops in a body without taking the path through it: no organs crossed, and the round as it went in.
/datum/unit_test/ms13_simple_bullet
	name = "BULLETS: Simple Bullets Skip The Path Through A Body"

/datum/unit_test/ms13_simple_bullet/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/projectile/bullet/ms13/a762/bullet = allocate(/obj/projectile/bullet/ms13/a762)
	bullet.simple_bullet = TRUE
	var/integrity = bullet.getBIntegrity()
	var/stopped = victim.get_bullet_transfer_fraction(bullet, BODY_ZONE_CHEST)
	if(victim.pending_bullet_organs || bullet.getBIntegrity() != integrity || stopped != 1)
		Fail("A simple bullet took the path through a body, or came out the other side.")
#endif
