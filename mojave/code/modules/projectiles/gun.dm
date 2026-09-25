/obj/item/gun
	/// A multiplier of the duration the recoil takes to go back to normal view, this is (recoil*recoil_backtime_multiplier)+1
	var/recoil_backtime_multiplier = 2
	/// This is how much deviation the gun recoil can have, recoil pushes the screen towards the reverse angle you shot + some deviation which this is the max.
	var/recoil_deviation = 22.5

// An ammo_stack (mojave/code/modules/projectiles/boxes_magazines/ammo_stack.dm) is itself a subtype of
// /obj/item/ammo_box/magazine (deliberately, to reuse magazine behavior) - which means DD's core
// /obj/item/gun/ballistic/attackby() (code/modules/projectiles/guns/ballistic.dm) matches it against
// its "insert this as a whole replacement magazine" branch before ever reaching the "load loose rounds
// from a box/casing" branch below it. With a magazine already loaded, that branch just refuses with
// "There is already a magazine" and the loose rounds never transfer in at all. Intercept ammo_stack
// specifically before calling the core proc so it goes through the same round-loading path a loose
// casing or ammo_box would.
/obj/item/gun/ballistic/attackby(obj/item/A, mob/user, params)
	if(magazine && istype(A, /obj/item/ammo_box/magazine/ammo_stack))
		var/num_loaded = magazine.attempt_load_round(A, user, params, TRUE)
		if(num_loaded)
			to_chat(user, span_notice("You load [num_loaded] [cartridge_wording]\s into [src]."))
			playsound(src, load_sound, load_sound_volume, load_sound_vary, SHORT_RANGE_SOUND_EXTRARANGE)
			bolt.loaded_ammo()
			A.update_appearance()
			update_appearance()
		return TRUE
	return ..()
