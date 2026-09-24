/obj/item/gun
	/// A multiplier of the duration the recoil takes to go back to normal view, this is (recoil*recoil_backtime_multiplier)+1
	var/recoil_backtime_multiplier = 2
	/// This is how much deviation the gun recoil can have, recoil pushes the screen towards the reverse angle you shot + some deviation which this is the max.
	var/recoil_deviation = 22.5

	/// Range beyond which no one is hearing anything, not even far_fire_sound
	var/far_fire_range = SOUND_RANGE * 4
	/// Falloff distance for far fire sound, no need to fuck with falloff for nearby guns honestly
	var/far_fire_falloff_distance = SOUND_RANGE
	/// Fire sound for long distances (not providing a default because it would be so fucked up dude)
	var/far_fire_sound
	/// Whether or not to apply variation to the far fire sound
	var/vary_far_fire_sound = TRUE
	/// Volume of the far fire sound (generally should be lower than the normal fire sound, obviously)
	var/far_fire_sound_volume = 50

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

/// Gunfire carries: past where the shot is heard plainly, out to far_fire_range, it's heard distant (playsound_distant()).
/obj/item/gun/proc/play_far_fire_sound()
	if(!suppressed)
		playsound_distant(src, fire_sound, far_fire_sound_volume, far_fire_range, far_fire_sound, vary_far_fire_sound, fire_sound_volume)

/obj/item/gun/play_fire_sound()
	. = ..()
	play_far_fire_sound()

// Energy guns play their own fire sound, without the one above.
/obj/item/gun/energy/play_fire_sound()
	. = ..()
	play_far_fire_sound()
