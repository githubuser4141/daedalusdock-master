/obj/projectile
	var/subtractible_armour_penetration = 0
	var/weak_against_subtractible_armour = FALSE
	/// Chance, out of 100, of a hit on an object or wall throwing up impact smoke and debris. Lower it on guns that
	/// hose fire, whose every hit would otherwise spawn its own particles.
	var/debris_chance = 100

/atom/spawn_debris(obj/projectile/P)
	if(!prob(P.debris_chance))
		return
	return ..()
