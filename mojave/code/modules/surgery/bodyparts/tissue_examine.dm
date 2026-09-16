// Diagnosis for the tissue systems (bone.dm, muscle.dm, vessel.dm) and the infection they pick up when
// neglected (tissue_care.dm).
//
// Deliberately not a scanner readout: this is a Fallout setting, and DD's health analyzer is a Space
// Station artifact that doesn't report organ damage anyway. Everything here goes through the two examine
// paths the game already has:
//
//   mob_examine()  - what anyone can see at a glance. Swelling, colour, a filthy dressing. No numbers.
//   inspect()      - the hands-on check, already gated behind do_afters and already the place DD reports
//                    broken bones, severed tendons and cut arteries. This is where a medic actually finds
//                    out what's wrong, and where the tissue assessment belongs.
//
// The wording maps the three 0-100 condition numbers onto plain description. Someone who knows what
// they're looking at can tell a strained muscle from a destroyed one; nobody has to read a percentage.

/// Plain-language state of this limb's bone, or null if there's nothing worth saying.
/obj/item/bodypart/proc/get_bone_examine_text()
	var/obj/item/organ/bone/B = get_bone_organ()
	if(!B)
		return
	if(B.organ_flags & ORGAN_DEAD)
		return span_alert("The bone shifts and grates under the skin - it's broken through.")
	switch(B.get_stability())
		if(0 to 40)
			return span_alert("The bone gives when pressed. It's badly cracked.")
		if(40 to 75)
			return span_warning("There's a tender spot along the bone - a fracture, but it's holding.")
		if(75 to 99)
			return span_notice("The bone is bruised but sound.")
	return

/// Same for muscle. Reads the limb-level number, so a good bone with a ruined muscle still reports badly.
/obj/item/bodypart/proc/get_muscle_examine_text()
	var/obj/item/organ/muscle/M = locate() in contained_organs
	if(!M)
		return
	if(M.organ_flags & ORGAN_DEAD)
		return span_alert("The muscle is torn clean through - it doesn't answer at all.")
	switch(M.get_performance())
		if(0 to 25)
			return span_alert("The muscle is slack and wasted. There's almost nothing left to pull with.")
		if(25 to 60)
			return span_warning("The muscle is weak and twitchy, and tires almost immediately.")
		if(60 to 95)
			return span_notice("The muscle is sore and stiff, but it works.")
	return

/// Circulation, read off the vessel plus how much blood is actually reaching the limb.
/obj/item/bodypart/proc/get_vessel_examine_text()
	var/obj/item/organ/vessel/V = locate() in contained_organs
	if(!V)
		return
	if(V.organ_flags & ORGAN_DEAD)
		return span_alert("Blood is welling up from somewhere deep inside. The artery has gone.")
	var/blood_ratio = local_blood_volume / local_blood_volume_max
	if(blood_ratio < 0.3)
		return span_alert("The limb is cold and bloodless, and barely has a pulse worth finding.")
	if(V.damage > V.maxHealth * V.low_threshold)
		return span_warning("Blood is pooling under the skin - something inside is leaking.")
	if(blood_ratio < 0.7)
		return span_warning("The pulse here is weak and thready.")
	return

/// Infection, on the same scale DD's own germ pipeline uses (germs_bodypart.dm).
/obj/item/bodypart/proc/get_infection_examine_text()
	if(germ_level >= INFECTION_LEVEL_THREE)
		return span_alert("The flesh here is grey and dying, and the smell is unmistakable.")
	if(germ_level >= INFECTION_LEVEL_TWO)
		return span_alert("Red streaks run up from the wound, and the whole limb is hot to the touch.")
	if(germ_level >= INFECTION_LEVEL_ONE)
		return span_warning("The skin around the wound is red, puffy and warm. It's starting to turn.")
	return

/// Whether the dressing is doing its job, which is the thing a medic most needs telling.
/obj/item/bodypart/proc/get_care_examine_text()
	if(!bandage && !splint)
		return
	if(world.time <= ms13_treated_at + MS13_TISSUE_TREATMENT_DURATION)
		return span_notice("The dressing is clean and recently changed.")
	return span_warning("The dressing is old and grimy - it needs changing.")

/**
 * Outward signs only. Someone across the room can see a limb swell up or go the wrong colour; they cannot
 * see a hairline fracture, so none of the hands-on detail belongs here.
 */
/obj/item/bodypart/mob_examine(hallucinating, covered)
	. = ..()
	if(!owner || covered || !IS_ORGANIC_LIMB(src))
		return
	var/infection = get_infection_examine_text()
	if(infection)
		. += "\t [infection]"
	// A destroyed muscle is visible as the limb simply hanging wrong, without needing to touch it.
	var/obj/item/organ/muscle/M = locate() in contained_organs
	if(M && (M.organ_flags & ORGAN_DEAD))
		. += "\t [span_alert("[owner.p_their(TRUE)] [plaintext_zone] hangs limp and useless.")]"

/**
 * The hands-on check. DD already walks the medic through wounds -> skin -> bones -> tendons/arteries here;
 * this appends the tissue assessment to the end of that same sequence, behind the same do_after gating,
 * so finding out how bad someone is costs time and access the way the rest of the proc already does.
 */
/obj/item/bodypart/inspect(mob/user)
	. = ..()
	if(!. || !owner)
		return
	if(!do_after(user, owner, 1 SECOND, DO_PUBLIC|DO_RESTRICT_USER_DIR_CHANGE))
		return .

	var/list/findings = list()
	for(var/text in list(get_muscle_examine_text(), get_vessel_examine_text(), get_infection_examine_text(), get_care_examine_text()))
		if(text)
			findings += text

	// Bone is reported by the parent already (it checks BP_BROKEN_BONES), so only add the organ's own read
	// when it says something the flag doesn't - a cracked-but-not-broken bone, which DD has no state for.
	if(!(bodypart_flags & BP_BROKEN_BONES))
		var/bone_text = get_bone_examine_text()
		if(bone_text)
			findings += bone_text

	if(!length(findings))
		to_chat(user, span_notice("The muscle and circulation in the [plaintext_zone] seem sound."))
		return .

	to_chat(user, span_notice("Feeling out the [plaintext_zone]..."))
	for(var/text in findings)
		to_chat(user, text)
	return .
