/// How fast sound carries. Faster than real sound over these distances, where the true delay would be too slight to notice.
#define DISTANT_SOUND_TILES_PER_SECOND 100

/**
 * Loud sounds carry. Past where a sound can normally be heard, listeners out to far_range still hear it: fainter the
 * further off they are, muffled, and echoing off the land around them (or the room they're in), from the direction it
 * came. far_sound, if given, is played for them instead, a recording made at a distance.
 *
 * vol is how loud it is heard distant; near_vol is how loud it was played plainly, with playsound().
 * It's all done with BYOND's own sound effects (EAX reverb and echo), no extra sound files needed.
 */
/proc/playsound_distant(atom/source, soundin, vol, far_range = SOUND_RANGE * 4, far_sound, vary = TRUE, near_vol = vol)
	var/turf/turf_source = get_turf(source)
	if(!turf_source || !vol)
		return
	// Starts where the sound played plainly fades out, so nobody in between hears nothing.
	var/near_range = CALCULATE_MAX_SOUND_AUDIBLE_DISTANCE(near_vol, SOUND_RANGE, SOUND_DEFAULT_FALLOFF_DISTANCE, SOUND_FALLOFF_EXPONENT)
	if(far_range <= near_range)
		return
	var/list/listeners = SSmobs.clients_by_zlevel[turf_source.z] | SSmobs.dead_players_by_zlevel[turf_source.z]
	for(var/mob/listener as anything in listeners)
		var/distance = get_dist(listener, turf_source)
		if(distance > near_range && distance <= far_range)
			addtimer(CALLBACK(listener, TYPE_PROC_REF(/mob, hear_distant_sound), turf_source, far_sound || soundin, vol, (distance - near_range) / (far_range - near_range), vary), distance / DISTANT_SOUND_TILES_PER_SECOND * (1 SECONDS))

#undef DISTANT_SOUND_TILES_PER_SECOND

/**
 * Hears a sound from turf_source, far off: remoteness runs from 0, just past where it'd be heard plainly, to 1 at the
 * limit of hearing it at all.
 */
/mob/proc/hear_distant_sound(turf/turf_source, soundin, vol, remoteness, vary)
	if(!client || !can_hear())
		return
	var/turf/ear = get_turf(src)
	SEND_SOUND(src, make_distant_sound(turf_source, ear, soundin, vol, remoteness, vary))
	// Then its echo off the land: fainter, duller, later the further off, and from somewhere else.
	var/sound/echo = make_distant_sound(turf_source, ear, soundin, vol * 0.4, min(remoteness + 0.3, 1), vary)
	echo.x = -echo.x + rand(-4, 4)
	echo.z = -echo.z + rand(-4, 4)
	echo.falloff = get_dist(ear, turf_source) + 5
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(send_distant_echo), src, echo), (0.3 + 0.5 * remoteness) SECONDS)

/proc/send_distant_echo(mob/listener, sound/echo)
	if(listener.client && listener.can_hear())
		SEND_SOUND(listener, echo)

/proc/make_distant_sound(turf/turf_source, turf/ear, soundin, vol, remoteness, vary)
	var/sound/far = sound(get_sfx(soundin))
	far.channel = SSsounds.random_available_channel()
	far.volume = vol * (1 - 0.5 * remoteness)
	if(vary)
		far.frequency = get_rand_frequency()
	// From the direction it came, without BYOND fading it further.
	far.x = turf_source.x - ear.x
	far.z = turf_source.y - ear.y
	far.falloff = get_dist(ear, turf_source) + 1
	var/area/ear_area = get_area(ear)
	var/indoors = !ear_area.outdoors
	// The further off, the less of it arrives straight and the more as echo, and the duller both are. Walls muffle it more.
	far.echo[1] = -200 - 1000 * remoteness - (indoors ? 800 : 0)
	far.echo[2] = -1000 - 2500 * remoteness - (indoors ? 1500 : 0)
	far.echo[3] = 0
	far.echo[4] = -300 - 1200 * remoteness
	if(ear_area.sound_environment != SOUND_ENVIRONMENT_NONE)
		far.environment = ear_area.sound_environment
	else
		far.environment = indoors ? SOUND_ENVIRONMENT_STONEROOM : SOUND_ENVIRONMENT_MOUNTAINS
	return far

/datum/emote
	/// Loud enough to be heard far off (see playsound_distant()).
	var/carries_far = FALSE

/datum/emote/living/carbon/human/scream
	carries_far = TRUE

/datum/emote/living/agony
	carries_far = TRUE

// Mobs' gunfire carries too. A mob that gives its shots no sound fires them with the projectile's own.
/mob/living/simple_animal/hostile/Shoot(atom/targeted_atom)
	. = ..()
	if(QDELETED(targeted_atom) || !(casingtype || projectiletype))
		return
	var/shot_sound = projectilesound
	if(!shot_sound)
		shot_sound = default_fire_sound()
		if(!shot_sound)
			return
		playsound(src, shot_sound, 100, TRUE)
	playsound_distant(src, shot_sound, 50, near_vol = 100)

/// What its shots sound like when it gives them no sound: its casing's, or else the projectile's fallback_fire_sound.
/mob/living/simple_animal/hostile/proc/default_fire_sound()
	var/obj/item/ammo_casing/casing = casingtype
	if(casing && initial(casing.fire_sound))
		return initial(casing.fire_sound)
	var/obj/projectile/shot = casing ? initial(casing.projectile_type) : projectiletype
	return shot && initial(shot.fallback_fire_sound)

#ifdef UNIT_TESTS
/// A sound heard from further off is quieter and duller, and comes from the way it was made.
/datum/unit_test/ms13_distant_sound
	name = "SOUND: Distant Sounds Are Quieter, Duller And Directional"

/datum/unit_test/ms13_distant_sound/Run()
	var/turf/ear = run_loc_floor_bottom_left
	var/turf/source = run_loc_floor_top_right
	var/sound/near = make_distant_sound(source, ear, 'sound/weapons/gun/rifle/shot.ogg', 40, 0, FALSE)
	var/sound/far = make_distant_sound(source, ear, 'sound/weapons/gun/rifle/shot.ogg', 40, 1, FALSE)
	if(far.volume >= near.volume || far.echo[2] >= near.echo[2] || far.echo[1] >= near.echo[1])
		Fail("A sound heard further off wasn't quieter and duller.")
	if(near.x != source.x - ear.x || near.z != source.y - ear.y || near.environment == SOUND_ENVIRONMENT_NONE)
		Fail("A distant sound didn't come from the way it was made, or had no echo to it.")
	var/mob/living/simple_animal/hostile/shooter = allocate(/mob/living/simple_animal/hostile)
	shooter.projectiletype = /obj/projectile/beam/ms13/laser/protectron
	shooter.projectilesound = null
	var/obj/projectile/beam/ms13/laser = /obj/projectile/beam/ms13
	if(!shooter.default_fire_sound() || shooter.default_fire_sound() != initial(laser.fallback_fire_sound))
		Fail("A mob with no fire sound of its own didn't fall back to its laser's.")
#endif
