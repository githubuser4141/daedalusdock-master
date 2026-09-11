// Wires /turf/closed/wall onto DD's existing atom_integrity/take_damage() engine. Scoped to walls, not all
// /turf, since atom_integrity is only assigned when uses_integrity is TRUE (code/game/atom/atoms.dm).
/turf/closed/wall
	uses_integrity = TRUE
	max_integrity = 350

TYPEINFO_DEF(/turf/closed/wall)
	default_armor = list(BLUNT = 40, PUNCTURE = 40, SLASH = 80, LASER = 50, ENERGY = 0, BOMB = 50, BIO = 0, FIRE = 0, ACID = 0)

/turf/closed/wall/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	. = ..()
	// A prior hit this tick (e.g. another pellet) may have already destroyed this wall - dismantle_wall()
	// replaces src with a separate qdeleted turf, and take_damage() hard-crashes if called again on it.
	if(QDELETED(src))
		return
	take_damage(hitting_projectile.damage, hitting_projectile.damage_type, hitting_projectile.armor_flag, FALSE, turn(hitting_projectile.dir, 180), hitting_projectile.armor_penetration)

/// Reuses the existing dismantle_wall() instead of a new destruction path. Bomb kills skip the girder.
/turf/closed/wall/atom_destruction(damage_flag)
	. = ..()
	dismantle_wall(devastated = (damage_flag == BOMB))

/turf/closed/wall/r_wall
	max_integrity = 700

TYPEINFO_DEF(/turf/closed/wall/r_wall)
	default_armor = list(BLUNT = 60, PUNCTURE = 60, SLASH = 90, LASER = 80, ENERGY = 0, BOMB = 75, BIO = 0, FIRE = 0, ACID = 0)
