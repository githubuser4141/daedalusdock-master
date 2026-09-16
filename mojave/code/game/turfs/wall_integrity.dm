// Wires /turf/closed/wall onto DD's existing atom_integrity/take_damage() engine. Scoped to walls, not all
// /turf, since atom_integrity is only assigned when uses_integrity is TRUE (code/game/atom/atoms.dm).
/turf/closed/wall
	uses_integrity = TRUE
	max_integrity = 350

TYPEINFO_DEF(/turf/closed/wall)
	default_armor = list(BLUNT = 40, PUNCTURE = 40, SLASH = 80, LASER = 50, ENERGY = 0, BOMB = 50, BIO = 0, FIRE = 0, ACID = 0)

/// Fraction of the bullet's damage that transfers into the wall - the rest continues on as an
/// overpenetration hit (mirrors mob overpenetration, bullet_penetration.dm). A tougher wall (higher armor
/// rating) pushes this up; a tougher/harder-constructed bullet (get_own_hardness_ratio()) divides it back down.
/turf/closed/wall/proc/get_wall_bullet_transfer_fraction(obj/projectile/P)
	return ms13_bullet_transfer_fraction(returnArmor(), P)

/turf/closed/wall/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	var/original_damage = hitting_projectile.damage
	var/transfer_fraction = get_wall_bullet_transfer_fraction(hitting_projectile)
	hitting_projectile.damage *= transfer_fraction
	. = ..()
	// A prior hit this tick (e.g. another pellet) may have already destroyed this wall - dismantle_wall()
	// replaces src with a separate qdeleted turf, and take_damage() hard-crashes if called again on it.
	if(QDELETED(src))
		return
	if(. != BULLET_ACT_HIT)
		hitting_projectile.damage = original_damage
		return

	take_damage(hitting_projectile.damage, hitting_projectile.damage_type, hitting_projectile.armor_flag, FALSE, turn(hitting_projectile.dir, 180), hitting_projectile.armor_penetration)
	if(hitting_projectile.firer)
		log_combat(hitting_projectile.firer, src, "shot", hitting_projectile, "transferred [round(hitting_projectile.damage, 0.1)]/[original_damage] (fraction [round(transfer_fraction, 0.01)])")
	if(QDELETED(src))
		return

	var/remaining_damage = original_damage - hitting_projectile.damage
	if(remaining_damage >= MS13_BULLET_OVERPEN_MIN_REMAINING)
		hitting_projectile.damage = remaining_damage
		return BULLET_ACT_FORCE_PIERCE
	hitting_projectile.damage = original_damage

/// Reuses the existing dismantle_wall() instead of a new destruction path. Bomb kills skip the girder.
/turf/closed/wall/atom_destruction(damage_flag)
	. = ..()
	dismantle_wall(devastated = (damage_flag == BOMB))

/turf/closed/wall/r_wall
	max_integrity = 700

TYPEINFO_DEF(/turf/closed/wall/r_wall)
	default_armor = list(BLUNT = 60, PUNCTURE = 60, SLASH = 90, LASER = 80, ENERGY = 0, BOMB = 75, BIO = 0, FIRE = 0, ACID = 0)
