// DD already has a generic atom_integrity/take_damage()/run_atom_armor() engine (code/game/atom_defense.dm)
// - it's just never been wired up to /turf/closed/wall, so gunfire and everyday melee currently do nothing
// to a plain wall (only specific instant-dismantle rolls like hulk/blob/environment-smash exist). This
// connects walls to that real system instead of reinventing BeeStation's parallel one.
//
// Scoped to /turf/closed/wall only, not /turf broadly - uses_integrity defaults FALSE and atom_integrity is
// only assigned at Initialize() when it's TRUE (code/game/atom/atoms.dm:275-281), so this costs nothing on
// the far larger set of open/floor turfs that never need it.
/turf/closed/wall
	uses_integrity = TRUE
	max_integrity = 350

TYPEINFO_DEF(/turf/closed/wall)
	default_armor = list(BLUNT = 40, PUNCTURE = 40, SLASH = 80, LASER = 50, ENERGY = 0, BOMB = 50, BIO = 0, FIRE = 0, ACID = 0)

/// Gunfire chipping a wall's integrity, alongside (not replacing) bullet_math.dm's own ricochet/overpen math
/// for walls - that system only handles the ricochet/pass-through/fragment branches and falls through to
/// this normal bullet_act() path otherwise (see Impact(), mojave/__DEFINES/bullet_math.dm).
/turf/closed/wall/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	. = ..()
	take_damage(hitting_projectile.damage, hitting_projectile.damage_type, hitting_projectile.armor_flag, FALSE, turn(hitting_projectile.dir, 180), hitting_projectile.armor_penetration)

/// Integrity hitting 0 dismantles the wall the same way manual deconstruction already does - reuses the
/// existing proc instead of reinventing it. Bomb-caused destruction skips the girder, matching ex_act().
/turf/closed/wall/atom_destruction(damage_flag)
	. = ..()
	dismantle_wall(devastated = (damage_flag == BOMB))

/turf/closed/wall/r_wall
	max_integrity = 700

TYPEINFO_DEF(/turf/closed/wall)
	default_armor = list(BLUNT = 60, PUNCTURE = 60, SLASH = 90, LASER = 80, ENERGY = 0, BOMB = 75, BIO = 0, FIRE = 0, ACID = 0)