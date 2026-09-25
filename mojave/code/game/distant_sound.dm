/// How fast sound carries. Faster than real sound over these distances, where the true delay would be too slight to notice.
#define DISTANT_SOUND_TILES_PER_SECOND 100
/// How far into the plain sound's range, as a share of it, the distant sound starts fading in, so one hands over to the other.
#define DISTANT_SOUND_BLEND_START 0.75
/// Played quieter than this, even a loud sound doesn't carry.
#define DISTANT_SOUND_MIN_VOLUME 25

/**
 * Called by playsound() for every sound: a loud one with baked distant versions (distant_sound_versions.dm, made by
 * tools/distant_sounds) carries on its own, out as far as its kind does. Gunfire, engines, monsters, the hivemind,
 * structures taking a beating. Explosions go their own way (shake_the_room() below).
 *
 * Played to reach further or less far than usual, it carries further or less far in step: a hard blow (ms13_hit_scale()).
 */
/proc/carry_sound(turf/turf_source, sound_file, vol, extrarange)
	if(vol < DISTANT_SOUND_MIN_VOLUME)
		return
	var/list/versions = GLOB.distant_sound_versions["[sound_file]"]
	if(versions)
		playsound_distant(turf_source, sound_file, min(vol * 0.8, 60), versions[3] * (SOUND_RANGE + extrarange) / SOUND_RANGE, near_vol = vol, near_max = SOUND_RANGE + extrarange)

/// A blow this hard sounds as every hit used to: a ghoul's claw, a pipe swung at a door.
#define MS13_SOLID_HIT 25

/// Set while a blow's sounds play (take_damage(), playsound_hit()): how hard it landed, before armor.
GLOBAL_VAR(ms13_hit_force)

/**
 * How much louder, and how much further, a blow sounds than its sound usually plays. Sound pressure goes as the square
 * root of a blow's energy: a solid MS13_SOLID_HIT hit sounds as every hit used to, one four times as hard twice as loud
 * and far, which is as loud as the usual volume 50 hit sound can play. 1 for anything that isn't a blow.
 */
/proc/ms13_hit_scale()
	if(isnull(GLOB.ms13_hit_force))
		return 1
	// A blow too light to hurt still taps.
	return min(sqrt(max(GLOB.ms13_hit_force, 1) / MS13_SOLID_HIT), 2)

/// Plays a blow's sound, as hard as it landed.
/proc/playsound_hit(atom/source, soundin, vol, force)
	var/heard_force = GLOB.ms13_hit_force
	GLOB.ms13_hit_force = force
	playsound(source, soundin, vol, TRUE)
	GLOB.ms13_hit_force = heard_force

#undef MS13_SOLID_HIT

/**
 * Loud sounds carry. Past where a sound can normally be heard, listeners out to far_range still hear it, from the
 * direction it came: fainter, duller and more echo than shot the further off they are.
 *
 * Sounds with baked distant versions play those: dulled, the crack softened, with a reverb tail and echoes off the land,
 * and at the edge of hearing a low rolling thump. Others fall back to far_sound if given, or the sound itself, dulled
 * and echoed with BYOND's own effects.
 *
 * vol is how loud it is heard distant; near_vol and near_max are how loud and how far it was played plainly.
 */
/proc/playsound_distant(atom/source, soundin, vol, far_range = SOUND_RANGE * 4, far_sound, vary = TRUE, near_vol = vol, near_max = SOUND_RANGE)
	var/turf/turf_source = get_turf(source)
	if(!turf_source || !vol)
		return
	// Starts where the sound played plainly fades out, so nobody in between hears nothing.
	var/near_range = CALCULATE_MAX_SOUND_AUDIBLE_DISTANCE(near_vol, near_max, SOUND_DEFAULT_FALLOFF_DISTANCE, SOUND_FALLOFF_EXPONENT)
	if(far_range <= near_range)
		return
	var/blend_start = near_range * DISTANT_SOUND_BLEND_START
	var/list/listeners = SSmobs.clients_by_zlevel[turf_source.z] | SSmobs.dead_players_by_zlevel[turf_source.z]
	for(var/mob/listener as anything in listeners)
		var/distance = get_dist(listener, turf_source)
		if(distance <= blend_start || distance > far_range)
			continue
		var/fade_in = min((distance - blend_start) / max(near_range - blend_start, 1), 1)
		var/remoteness = max(distance - near_range, 0) / (far_range - near_range)
		addtimer(CALLBACK(listener, TYPE_PROC_REF(/mob, hear_distant_sound), turf_source, soundin, far_sound, vol * fade_in, remoteness, vary), distance / DISTANT_SOUND_TILES_PER_SECOND * (1 SECONDS))

#undef DISTANT_SOUND_TILES_PER_SECOND
#undef DISTANT_SOUND_BLEND_START
#undef DISTANT_SOUND_MIN_VOLUME

/**
 * A blast out here: the blast itself up close, then its baked distant versions by how far off, out further the bigger
 * it is. No space station hull creaking. Screen shake as DD's.
 */
/datum/controller/subsystem/explosions/shake_the_room(turf/epicenter, near_distance, far_distance, quake_factor, echo_factor, creaking, sound/near_sound = sound(get_sfx(SFX_EXPLOSION)), sound/far_sound, sound/echo_sound, sound/creaking_sound, hull_creaking_sound)
	var/list/versions = GLOB.distant_sound_versions["[near_sound.file]"]
	if(!versions)
		return ..()
	var/frequency = get_rand_frequency()
	var/near_reach = round(near_distance + world.view - 2, 1)
	for(var/mob/listener as anything in GLOB.player_list)
		var/turf/listener_turf = get_turf(listener)
		if(!listener_turf || listener_turf.z != epicenter.z)
			continue
		var/distance = get_dist(epicenter, listener_turf)
		var/shake = isobserver(listener) ? 0 : sqrt(near_distance / (distance + 1))
		if(distance <= near_reach)
			listener.playsound_local(epicenter, null, 100, TRUE, frequency, sound_to_use = near_sound)
			if(shake > 0)
				shake_camera(listener, 1.5 SECONDS, min(shake, 5))
		else if(distance < far_distance && (shake || quake_factor))
			shake_camera(listener, 1 SECONDS, min(max(shake, quake_factor * 3), 1.5))
	// A grenade carries a good way; a big bomb, as far as explosions do.
	playsound_distant(epicenter, near_sound.file, 70, versions[3] * clamp(near_distance / 10, 0.4, 1), vary = FALSE, near_vol = 100, near_max = near_reach)

/**
 * Hears a sound from turf_source, far off: remoteness runs from 0, just past where it'd be heard plainly, to 1 at the
 * limit of hearing it at all.
 */
/mob/proc/hear_distant_sound(turf/turf_source, soundin, far_sound, vol, remoteness, vary)
	if(!client || !can_hear())
		return
	var/turf/ear = get_turf(src)
	var/baked = distant_version(soundin, remoteness)
	if(baked)
		SEND_SOUND(src, make_distant_sound(turf_source, ear, baked, vol, remoteness, vary, TRUE))
		return
	soundin = far_sound || soundin
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

/// The baked version of soundin for how far off it's heard: the far one out to halfway, then the one at the edge of hearing.
/proc/distant_version(soundin, remoteness)
	var/list/versions = GLOB.distant_sound_versions["[get_sfx(soundin)]"]
	return versions?[remoteness < 0.5 ? 1 : 2]

/// baked: soundin already has its distance, reverb and echoes in it, and only needs placing.
/proc/make_distant_sound(turf/turf_source, turf/ear, soundin, vol, remoteness, vary, baked = FALSE)
	var/sound/far = sound(get_sfx(soundin))
	far.channel = SSsounds.random_available_channel()
	far.volume = vol * (1 - 0.7 * remoteness)
	if(vary)
		far.frequency = get_rand_frequency()
	// From the direction it came, without BYOND fading it further.
	far.x = turf_source.x - ear.x
	far.z = turf_source.y - ear.y
	far.falloff = get_dist(ear, turf_source) + 1
	if(baked)
		return far
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

// A mob that gives its shots no sound fires them with the projectile's own.
/mob/living/simple_animal/hostile/Shoot(atom/targeted_atom)
	. = ..()
	if(projectilesound || QDELETED(targeted_atom) || !(casingtype || projectiletype))
		return
	var/shot_sound = default_fire_sound()
	if(shot_sound)
		playsound(src, shot_sound, 100, TRUE)

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
	var/near_version = distant_version('mojave/sound/ms13weapons/hunting_rifle.ogg', 0.2)
	var/edge_version = distant_version('mojave/sound/ms13weapons/hunting_rifle.ogg', 0.9)
	if(!isfile(near_version) || !isfile(edge_version) || near_version == edge_version)
		Fail("A gunshot heard far off didn't play its baked versions, one for far and one for the edge of hearing.")
	// Not just gunfire: a blast, an engine, a monster, the hivemind and a structure taking a beating all carry.
	for(var/loud in list("sound/effects/explosion1.ogg", "mojave/sound/ms13machines/engine_running1.ogg", "mojave/sound/ms13npc/yaoguai_attack1.ogg", "mojave/sound/wip/necromorphs/brute_shout_1.ogg", "sound/weapons/smash.ogg"))
		if(!(GLOB.distant_sound_versions[loud]?[3] > SOUND_RANGE))
			Fail("[loud] doesn't carry past where it's heard plainly.")
	for(var/obj/item/gun/gun_type as anything in subtypesof(/obj/item/gun))
		var/fire_sound = initial(gun_type.fire_sound)
		if(fire_sound && findtext("[gun_type]", "/ms13") && !findtext("[fire_sound]", "suppressed") && !GLOB.distant_sound_versions["[fire_sound]"])
			Fail("[gun_type]'s fire sound has no distant versions: run tools/distant_sounds/make_distant_sounds.py.")
	// A blow sounds as hard as it lands: a claw as hits always did, a charging hellpig twice as loud and far, no further.
	var/obj/structure/ms13_hit_probe/probe = allocate(/obj/structure/ms13_hit_probe, ear)
	probe.take_damage(100)
	if(probe.heard_force != 100 || !isnull(GLOB.ms13_hit_force))
		Fail("A blow's sound didn't hear how hard it landed, or kept hearing it after.")
	var/list/scales = list()
	for(var/force in list(25, 6.25, 100, 300))
		GLOB.ms13_hit_force = force
		scales += ms13_hit_scale()
	GLOB.ms13_hit_force = null
	if(scales[1] != 1 || scales[2] != 0.5 || scales[3] != 2 || scales[4] != 2 || ms13_hit_scale() != 1)
		Fail("Blows sounded [english_list(scales)] times as loud at 25, 6.25, 100 and 300 force, not 1, 0.5, 2 and 2.")

/obj/structure/ms13_hit_probe
	max_integrity = 1000
	var/heard_force

/obj/structure/ms13_hit_probe/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	heard_force = GLOB.ms13_hit_force
#endif
