/atom
	/// Subtractible armor datum - See [mojave/code/datums/subarmor.dm] for more information
	var/datum/subarmor/subarmor

///returns the damage value of the attack after processing the atom's various armor protections
/atom/proc/run_atom_subarmor(damage_amount, damage_type, damage_flag = 0, attack_dir, armour_penetration = 0)
	if(!uses_integrity)
		CRASH("/atom/proc/run_atom_armor was called on [src] without being implemented as a type that uses integrity!")
	if(damage_flag == BLUNT && damage_amount < damage_deflection)
		return 0
	var/armor_protection = 0
	if(damage_flag)
		// AI EDIT: subarmor uses CRUSHING/CUTTING/PIERCING/IMPALING, not the DR-style BLUNT/PUNCTURE this
		// proc's callers pass by default - every other subarmor entry point (checksubarmor(),
		// run_subarmor_check(), damage_armor()) converts before calling getRating(), this one never did,
		// crashing with "undefined variable /datum/subarmor/var/puncture" on any subarmored atom.
		var/static/list/conversion_table = list(BLUNT, PUNCTURE)
		armor_protection = subarmor.getRating((damage_flag in conversion_table) ? CRUSHING : damage_flag)
	if(armor_protection) //Only apply weak-against-armor/hollowpoint effects if there actually IS armor.
		armor_protection = clamp(armor_protection - armour_penetration, min(armor_protection, 0), 100)
	return round(damage_amount * (100 - armor_protection)*0.01, DAMAGE_PRECISION)
