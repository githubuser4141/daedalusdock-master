/datum/typeinfo/atom
	/// Subarmor (mojave/code/datums/armor/subarmor.dm) for every one of a type, kept once for the type as default_armor is:
	/// TYPEINFO_DEF(type) then default_subarmor = list(CRUSHING = 5, ...). A subarmor list set on the type itself still works.
	var/list/default_subarmor

/atom/Initialize(mapload, ...)
	. = ..()
	if(uses_integrity)
		returnSubarmor()

	if(loc)
		SEND_SIGNAL(loc, COMSIG_ATOM_CREATED, src)

/// This atom's subarmor: from a list set on its type, else its typeinfo's default_subarmor, else none.
/atom/proc/returnSubarmor()
	RETURN_TYPE(/datum/subarmor)
	if(istype(subarmor, /datum/subarmor))
		return subarmor
	var/list/ratings = subarmor
	if(!islist(ratings))
		if(subarmor)
			stack_trace("Invalid type [subarmor.type] found in .subarmor")
		var/datum/typeinfo/atom/info = typeinfo(type)
		ratings = info.default_subarmor
	subarmor = islist(ratings) ? getSubarmor(arglist(ms13_valid_subarmor(ratings, type))) : getSubarmor()
	return subarmor

/// ratings without any key subarmor doesn't have (PUNCTURE is armor's, subarmor's is PIERCING), which it names.
/proc/ms13_valid_subarmor(list/ratings, type)
	var/static/list/known = list(SUBARMOR_FLAGS, EDGE_PROTECTION, CRUSHING, CUTTING, PIERCING, IMPALING, LASER, ENERGY, BOMB, FIRE, ACID)
	. = list()
	for(var/key in ratings)
		if(key in known)
			.[key] = ratings[key]
		else
			stack_trace("[type]'s subarmor has [key], which isn't a subarmor rating: use [english_list(known, and_text = " or ")].")
