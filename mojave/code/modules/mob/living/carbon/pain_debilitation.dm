// Full override of DD's handle_pain()/handle_shock() collapse behavior (code/modules/mob/living/carbon/pain.dm).
// DD's originals force Unconscious() once pain or shock crosses a threshold, which - since pain from an
// untreated wound doesn't go away - can chain into staying unconscious indefinitely. This keeps mojave
// characters conscious and able to act at those same trigger points, just severely hampered. Everything
// else (bodypart/organ pain messages, mood, shrug-off-pain rolls, cardiac arrest, death) is untouched -
// copied verbatim from DD's original so only the collapse response differs. Raised thresholds live in
// mojave/code/_DEFINES/pain_debilitation.dm; the actual response is the status effects defined in
// mojave/code/datums/status_effects/pain_debilitation.dm.
//
// This can't be done as a signal listener instead (e.g. hooking COMSIG_LIVING_STATUS_UNCONSCIOUS and
// blocking it with COMPONENT_NO_STUN) without either editing pain.dm to tag its calls with a
// distinguishing source, or blocking every Unconscious() call on the mob regardless of cause - which
// would also swallow legitimate unconsciousness from sleep toxin, other stuns, etc. A full override is
// the only way to change specifically the pain/shock collapse point without touching either DD file.

/mob/living/carbon/handle_pain(delta_time)
	if(stat == DEAD)
		return

	var/pain = getPain()
	var/painkiller = CHEM_EFFECT_MAGNITUDE(src, CE_PAINKILLER)
	/// Brain health scales the pain passout modifier with an importance of 80%
	var/brain_health_factor = 1 + ((maxHealth - getBrainLoss()) / maxHealth - 1) * 0.8
	/// Blood circulation scales the pain passout modifier with an importance of 40%
	var/blood_circulation_factor = 1 + (get_blood_circulation() / 100 - 1) * 0.4

	var/pain_passout = min(MS13_PAIN_AMT_PASSOUT * brain_health_factor * blood_circulation_factor, MS13_PAIN_AMT_PASSOUT)

	if(pain <= max((pain_passout * 0.075), 10))
		var/slowdown = min(pain * (PAIN_MAX_SLOWDOWN / pain_passout), PAIN_MAX_SLOWDOWN)
		add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/pain, TRUE, slowdown)
	else
		remove_movespeed_modifier(/datum/movespeed_modifier/pain)

	if(pain >= pain_passout)
		apply_status_effect(/datum/status_effect/ms13_pain_debilitation, pain / pain_passout)
		return

	if(stat != CONSCIOUS)
		return

	var/highest_bp_pain = 0
	var/obj/item/bodypart/damaged_part
	for(var/obj/item/bodypart/loop as anything in bodyparts)
		if(loop.bodypart_flags & BP_NO_PAIN)
			continue

		var/bp_pain = loop.getPain()
		if(bp_pain > highest_bp_pain || (highest_bp_pain == bp_pain && prob(50)))
			damaged_part = loop
			highest_bp_pain = bp_pain

	if(damaged_part && painkiller < highest_bp_pain)
		if(highest_bp_pain > PAIN_THRESHOLD_REDUCE_SLEEP)
			AdjustSleeping(-(highest_bp_pain / 5) SECONDS)

		if(highest_bp_pain > PAIN_THRESHOLD_DROP_ITEM && COOLDOWN_FINISHED(src, pain_cooldowns["drop_item"]))
			pain_drop_item(highest_bp_pain)

		var/burning = damaged_part.burn_dam > damaged_part.brute_dam
		var/msg
		var/highest_bp_pain_class = pain_class(highest_bp_pain)

		if(COOLDOWN_FINISHED(src, pain_cooldowns[highest_bp_pain_class]))
			switch(highest_bp_pain_class)
				if(PAIN_CLASS_AGONIZING)
					COOLDOWN_START(src, pain_cooldowns[highest_bp_pain_class], 20 SECONDS)
					msg = "OH GOD! Your [damaged_part.plaintext_zone] is [burning ? "on fire" : "hurting terribly"]!"

				if(PAIN_CLASS_MEDIUM)
					COOLDOWN_START(src, pain_cooldowns[highest_bp_pain_class], 40 SECONDS)
					msg = "Your [damaged_part.plaintext_zone] [burning ? "burns" : "hurts"] badly."

				if(PAIN_CLASS_LOW)
					msg = "Your [damaged_part.plaintext_zone] [burning ? "burns" : "hurts"]."
					COOLDOWN_START(src, pain_cooldowns[highest_bp_pain_class], 60 SECONDS)

			if(msg)
				pain_message(msg, highest_bp_pain, TRUE)


	// Damage to internal organs hurts a lot.
	var/list/organ_pain_zones
	for(var/obj/item/organ/I as anything in organs)
		if(istype(I, /obj/item/organ/brain))
			continue

		if(!I.is_causing_pain())
			continue

		var/obj/item/bodypart/parent = I.ownerlimb
		if(parent.bodypart_flags & BP_NO_PAIN)
			continue

		LAZYINITLIST(organ_pain_zones)

		if(I.damage > (I.low_threshold * I.maxHealth))
			organ_pain_zones[parent] += 25
		if(I.damage > (I.high_threshold * I.maxHealth))
			organ_pain_zones[parent] += 40
		else
			organ_pain_zones[parent] += 10


	for(var/obj/item/bodypart/painful_part as anything in organ_pain_zones)
		var/organ_pain_applied = organ_pain_zones[painful_part]
		var/message
		switch(organ_pain_applied)
			if(0 to 10)
				message = "You feel a dull pain in your [painful_part.plaintext_zone]"
			if(11 to 44)
				message = "You feel a pain in your [painful_part.plaintext_zone]"
			else
				message = "You feel a sharp pain in your [painful_part.plaintext_zone]"

		apply_pain(organ_pain_applied, painful_part, message, TRUE, updating_health = FALSE)

	if(prob(1))
		var/systemic_organ_failure = getToxLoss()
		switch(systemic_organ_failure)
			if(5 to 17)
				pain_message("Your body stings slightly.", 1, TRUE)
			if(17 to 35)
				pain_message("Your body stings.", PAIN_AMT_LOW, TRUE)
			if(35 to 60)
				pain_message("Your body stings strongly.", PAIN_AMT_MEDIUM, TRUE)
			if(60 to 100)
				pain_message("Your whole body hurts badly.", PAIN_AMT_MEDIUM, TRUE)
			if(100 to INFINITY)
				pain_message("Your body aches all over, it's driving you mad.", PAIN_AMT_AGONIZING, TRUE)

	update_health_hud()

#define SHOCK_STRING_MINOR \
	pick("It hurts...",\
		"Uaaaghhhh...",\
		"Agh..."\
	)

#define SHOCK_STRING_MAJOR \
	pick("The pain is excruciating!",\
		"Please, just end the pain!",\
		"I can't feel anything!"\
	)

/mob/living/carbon/handle_shock(delta_time)
	if(status_flags & GODMODE)
		return

	if(HAS_TRAIT(src, TRAIT_FAKEDEATH))
		return

	if(HAS_TRAIT(src, TRAIT_NO_PAINSHOCK))
		shock_stage = 0
		return

	// If our heart has stopped, INSTANTLY enter shock tier 4
	var/heart_attack_gaming = undergoing_cardiac_arrest()
	if(heart_attack_gaming)
		shock_stage = max(shock_stage + 1, SHOCK_TIER_4 + 1)

	var/pain = getPain()
	var/overall_pain_class = pain_class(pain)

	// Pain mood adjustment
	switch(overall_pain_class)
		if(PAIN_CLASS_AGONIZING)
			mob_mood.add_mood_event("pain", /datum/mood_event/pain_four)
		if(PAIN_CLASS_MEDIUM)
			mob_mood.add_mood_event("pain", /datum/mood_event/pain_three)
		if(PAIN_CLASS_LOW)
			mob_mood.add_mood_event("pain", /datum/mood_event/pain_two)
		if(PAIN_CLASS_NEGLIGIBLE)
			mob_mood.add_mood_event("pain", /datum/mood_event/pain_one)
		if(PAIN_CLASS_NONE)
			mob_mood.clear_mood_event("pain")

	if(pain >= max(SHOCK_MIN_PAIN_TO_BEGIN, shock_stage * 0.8))
		// A chance to fight through the pain.
		if((shock_stage >= SHOCK_TIER_3) && stat == CONSCIOUS && !heart_attack_gaming && stats.cooldown_finished("shrug_off_pain"))
			var/datum/roll_result/result = stat_roll(12, /datum/rpg_skill/knuckle_down)
			switch(result.outcome)
				if(CRIT_SUCCESS)
					to_chat(src, result.create_tooltip("You won't give in now. Stay in the fight."))
					shock_stage = max(shock_stage - 15, 0)
					apply_status_effect(/datum/status_effect/determined/ms13_adrenaline)
					stats.set_cooldown("shrug_off_pain", 180 SECONDS)
					return

				if(SUCCESS)
					shock_stage = max(shock_stage - 5, 0)
					to_chat(src, result.create_tooltip("Not here, not now."))
					apply_status_effect(/datum/status_effect/determined/ms13_adrenaline)
					stats.set_cooldown("shrug_off_pain", 180 SECONDS)
					return

				if(FAILURE)
					stats.set_cooldown("shrug_off_pain", 30 SECONDS)
					// Do not return

				if(CRIT_FAILURE)
					shock_stage = min(shock_stage + 1, MS13_SHOCK_MAXIMUM)
					to_chat(src, result.create_tooltip("I'm going to die here."))
					stats.set_cooldown("shrug_off_pain", 60 SECONDS)
					// Do not return

		if(shock_stage == 0)
			throw_alert("traumatic shock", /atom/movable/screen/alert/shock)
		shock_stage = min(shock_stage + 1, MS13_SHOCK_MAXIMUM)

	else if(!heart_attack_gaming)
		shock_stage = min(shock_stage, MS13_SHOCK_MAXIMUM)
		var/recovery = 2
		if(pain < 0.5 * shock_stage)
			recovery = 4
		else if(pain < 0.25 * shock_stage)
			recovery = 3

		// ~25% chance at base to recover twice as fast..
		if(stat_roll(13, /datum/rpg_skill/knuckle_down).outcome >= SUCCESS)
			recovery *= 2

		shock_stage = max(shock_stage - recovery, 0)
		if(shock_stage == 0)
			clear_alert("traumatic shock")
		return

	if(stat)
		return

	var/message = ""
	if(shock_stage == SHOCK_TIER_1)
		message = SHOCK_STRING_MINOR

	if((shock_stage > SHOCK_TIER_2 && prob(2)) || shock_stage == SHOCK_TIER_2)
		if(shock_stage == SHOCK_TIER_2 && organs_by_slot[ORGAN_SLOT_EYES])
			manual_emote("is having trouble keeping [p_their()] eyes open.")
		blur_eyes(5)
		set_timed_status_effect(10 SECONDS, /datum/status_effect/speech/stutter, only_if_higher = TRUE)

	if(shock_stage == SHOCK_TIER_3)
		message = SHOCK_STRING_MAJOR

	else if(shock_stage >= SHOCK_TIER_3)
		if(prob(20))
			set_timed_status_effect(5 SECONDS, /datum/status_effect/speech/stutter, only_if_higher = TRUE)

	if((shock_stage > SHOCK_TIER_4 && prob(5)) || shock_stage == SHOCK_TIER_4)
		message = SHOCK_STRING_MAJOR
		manual_emote("stumbles over [p_them()]self.")
		Knockdown(2 SECONDS)

	else if((shock_stage > SHOCK_TIER_5 && prob(10)) || shock_stage == SHOCK_TIER_5)
		message = SHOCK_STRING_MAJOR
		manual_emote("stumbles over [p_them()]self.")
		Knockdown(2 SECONDS)

	if((shock_stage > MS13_SHOCK_TIER_COLLAPSE && prob(2)) || shock_stage == MS13_SHOCK_TIER_COLLAPSE)
		if(stat == CONSCIOUS)
			pain_message(pick("Your vision swims, but you refuse to go down.", "You grit your teeth against the agony.", "You can barely stay on your feet."), shock_stage - CHEM_EFFECT_MAGNITUDE(src, CE_PAINKILLER)/3, TRUE)
			apply_status_effect(/datum/status_effect/ms13_pain_debilitation, shock_stage / MS13_SHOCK_TIER_LIMP)
			return

	if(shock_stage >= MS13_SHOCK_TIER_LIMP)
		if(shock_stage == MS13_SHOCK_TIER_LIMP)
			visible_message("<b>[src]</b> staggers, barely able to keep moving!")
		apply_status_effect(/datum/status_effect/ms13_pain_debilitation, 1.5)

	// AI EDIT (bugfix, carried from DD's original): this condition was inverted - it only spoke while the
	// cooldown was still running, and since the cooldown starts inside the same branch it could never fire
	// the first time either. The net effect was that shock never announced itself at all.
	if(message && COOLDOWN_FINISHED(src, pain_cooldowns["shock"]))
		COOLDOWN_START(src, pain_cooldowns["shock"], 20 SECONDS)
		pain_message(message, shock_stage - CHEM_EFFECT_MAGNITUDE(src, CE_PAINKILLER)/3, TRUE)

#undef SHOCK_STRING_MINOR
#undef SHOCK_STRING_MAJOR
