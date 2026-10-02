// Blood-loss stages blend each limb's skin tone toward the existing severe pallor.

/mob/living/carbon/human/register_init_signals()
	. = ..()
	RegisterSignal(src, SIGNAL_ADDTRAIT(TRAIT_PALE_SKIN), PROC_REF(update_pale_skin))
	RegisterSignal(src, SIGNAL_REMOVETRAIT(TRAIT_PALE_SKIN), PROC_REF(update_pale_skin))

/// Compare limb overrides so regrown limbs and skin-tone changes also recover correctly.
/mob/living/carbon/human/proc/update_pale_skin(datum/source)
	SIGNAL_HANDLER
	var/strength = 0
	if(HAS_TRAIT(src, TRAIT_PALE_SKIN) || undergoing_pale_skin() || blood_volume < BLOOD_VOLUME_BAD)
		strength = 1
	else if(blood_volume < BLOOD_VOLUME_OKAY)
		strength = 0.6
	else if(blood_volume <= BLOOD_VOLUME_SAFE)
		strength = 0.3
	var/changed = FALSE
	for(var/obj/item/bodypart/BP as anything in bodyparts)
		var/new_color
		if(strength && BP.can_be_jaundiced())
			new_color = BlendRGB(BP.species_color || GLOB.skin_tones[BP.skin_tone], "#b8c4c9", strength)
		if(LAZYACCESS(BP.color_overrides, "[LIMB_COLOR_PALE_SKIN]") == new_color)
			continue
		if(new_color)
			BP.add_color_override(new_color, LIMB_COLOR_PALE_SKIN)
		else
			BP.remove_color_override(LIMB_COLOR_PALE_SKIN)
		changed = TRUE
	if(changed)
		update_body_parts()

/// Same per-tick toggle idiom as handle_liver()'s TRAIT_JAUNDICE_SKIN (code/modules/mob/living/carbon/life.dm).
/mob/living/carbon/human/Life(delta_time = SSMOBS_DT, times_fired)
	. = ..()
	if(undergoing_pale_skin())
		ADD_TRAIT(src, TRAIT_PALE_SKIN, INNATE_TRAIT)
	else
		REMOVE_TRAIT(src, TRAIT_PALE_SKIN, INNATE_TRAIT)
	update_pale_skin()

#ifdef UNIT_TESTS
/datum/unit_test/ms13_pallor_stages/Run()
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/heart/heart = patient.getorganslot(ORGAN_SLOT_HEART)
	heart.pulse = PULSE_NORM
	var/obj/item/bodypart/arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	for(var/tone in list("Saxon", "Gondari (West)"))
		arm.skin_tone = tone
		for(var/strength in list(0.3, 0.6, 1, 0.6, 0.3, 0))
			switch(strength)
				if(0)
					patient.blood_volume = BLOOD_VOLUME_NORMAL
				if(0.3)
					patient.blood_volume = (BLOOD_VOLUME_OKAY + BLOOD_VOLUME_SAFE) / 2
				if(0.6)
					patient.blood_volume = BLOOD_VOLUME_OKAY - 10
				if(1)
					patient.blood_volume = BLOOD_VOLUME_BAD - 10
			patient.update_pale_skin()
			var/expected = strength ? BlendRGB(GLOB.skin_tones[tone], "#b8c4c9", strength) : null
			if(LAZYACCESS(arm.color_overrides, "[LIMB_COLOR_PALE_SKIN]") != expected)
				return Fail("Pallor stage [strength] failed for [tone], including recovery.")
			if(arm.draw_color != (expected || GLOB.skin_tones[tone]))
				return Fail("The limb renderer did not apply the [strength] pallor stage.")
	patient.blood_volume = BLOOD_VOLUME_OKAY - 10
	arm.bodytype = BODYTYPE_HUMANOID | BODYTYPE_ROBOTIC
	patient.update_pale_skin()
	if(LAZYACCESS(arm.color_overrides, "[LIMB_COLOR_PALE_SKIN]"))
		return Fail("Pallor tinted a robotic limb.")
#endif
