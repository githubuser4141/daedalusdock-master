/// Resolve inherited DD defaults here so direct resource calls and SFX tokens agree.
/// Specific weapon, creature and material recordings retain their own sounds.
/proc/get_sfx_mojave(soundin)
	switch("[soundin]")
		if("sound/effects/explosion1.ogg")
			return 'mojave/sound/ms13effects/explosion_1.ogg'
		if("sound/effects/explosion2.ogg")
			return pick('mojave/sound/ms13effects/explosion_2.ogg', 'mojave/sound/ms13effects/explosion_3.ogg')
		if("sound/effects/explosion3.ogg")
			return 'mojave/sound/ms13effects/explosion_3.ogg'
		if("sound/weapons/attack/punch.ogg", "sound/weapons/attack/punch_2.ogg", "sound/weapons/attack/punch_3.ogg", "sound/weapons/attack/punch_4.ogg")
			return pick('mojave/sound/ms13weapons/meleesounds/punch_1.ogg', 'mojave/sound/ms13weapons/meleesounds/punch_2.ogg', 'mojave/sound/ms13weapons/meleesounds/punch_3.ogg')
		if("sound/weapons/genhit.ogg", "sound/weapons/genhit1.ogg", "sound/weapons/genhit2.ogg", "sound/weapons/genhit3.ogg")
			return 'mojave/sound/ms13weapons/meleesounds/genericblunt_hit.ogg'
		if("sound/weapons/smash.ogg", "sound/effects/meteorimpact.ogg")
			return pick('mojave/sound/ms13weapons/meleesounds/heavyblunt_hit1.ogg', 'mojave/sound/ms13weapons/meleesounds/heavyblunt_hit2.ogg', 'mojave/sound/ms13weapons/meleesounds/heavyblunt_hit3.ogg')
		if("sound/weapons/bladeslice.ogg")
			return pick('mojave/sound/ms13weapons/meleesounds/blade_hit1.ogg', 'mojave/sound/ms13weapons/meleesounds/blade_hit2.ogg')
		if("sound/weapons/pierce.ogg")
			return 'mojave/sound/ms13weapons/meleesounds/stab_hit.ogg'
		if("sound/effects/glassbr1.ogg", "sound/effects/glassbr2.ogg", "sound/effects/glassbr3.ogg")
			return 'mojave/sound/ms13effects/glass_break.ogg'
		if("sound/effects/break_stone.ogg")
			return 'mojave/sound/ms13effects/rock_mined.ogg'
		if("sound/effects/bodyfall1.ogg", "sound/effects/bodyfall2.ogg", "sound/effects/bodyfall3.ogg", "sound/effects/bodyfall4.ogg")
			return 'mojave/sound/ms13effects/body_fall.ogg'
		if("modular_pariah/modules/aesthetics/lights/sound/light_on.ogg")
			return 'mojave/sound/ms13effects/lightson.ogg'
	return soundin

#ifdef UNIT_TESTS
/datum/unit_test/ms13_sound_effects
	name = "MOJAVE SUN: Inherited sound routing"

/datum/unit_test/ms13_sound_effects/Run()
	for(var/source in list(SFX_EXPLOSION, SFX_PUNCH, SFX_SWING_HIT, SFX_SHATTER, SFX_BODYFALL, 'sound/effects/explosion1.ogg', 'sound/weapons/bladeslice.ogg', 'sound/weapons/pierce.ogg', 'sound/effects/break_stone.ogg'))
		var/resolved = get_sfx(source)
		if(!findtext("[resolved]", "mojave/sound/") || !isfile(resolved))
			Fail("Inherited sound [source] did not resolve to an existing Mojave recording: [resolved].")
	for(var/index in 1 to 3)
		var/source = "mojave/sound/ms13effects/explosion_[index].ogg"
		var/list/versions = GLOB.distant_sound_versions[source]
		if(!versions || "[versions[1]]" != "mojave/sound/ms13effects/explosion_far_[index].ogg" || "[versions[2]]" != "mojave/sound/ms13effects/explosion_distant_[index].ogg")
			Fail("Explosion [index] does not use its authored distant recordings.")
	var/custom = 'mojave/sound/wip/necromorphs/exploder_blast_1.ogg'
	if(get_sfx(custom) != custom)
		Fail("A creature-specific sound was replaced by a generic effect.")
#endif
