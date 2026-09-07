/datum/pathogen/kuru
	name = "Kuru"
	desc = "A disease that slowly corrodes the brain into uselessness."
	spread_flags = PATHOGEN_SPREAD_NON_CONTAGIOUS
	max_stages = 4
	stage_prob = 0.15 // This is that slow burn roleplay experience we're talking about. The chance for this to advance is real low. You get to play for longer! YIPPIE!
	spread_text = "Non-contagious"
	spread_flags = NONE
	cure_text = "Incurable"
	form = "Prion"
	agent = "prions"
	viable_mobtypes = list(/mob/living/carbon/human)
	required_organs = list(/obj/item/organ/brain)
	bypasses_immunity = TRUE
	severity = PATHOGEN_SEVERITY_BIOHAZARD

/datum/pathogen/kuru/on_process(delta_time, times_fired)
	. = ..()
	if(!.)
		return

	switch(stage)
		if(1)
			if(DT_PROB(1, delta_time))
				affected_mob.emote("laugh")
			if(DT_PROB(3, delta_time))
				affected_mob.adjust_jitter(10 SECONDS)
		if(2)
			if(DT_PROB(1, delta_time))
				affected_mob.Knockdown(4 SECONDS)
			if(DT_PROB(2, delta_time))
				affected_mob.emote("laugh")
			if(DT_PROB(3, delta_time))
				affected_mob.adjust_jitter(10 SECONDS)

			if(DT_PROB(2, delta_time))
				affected_mob.adjustOrganLoss(ORGAN_SLOT_BRAIN, 1, 150)
		if(3)
			if(DT_PROB(1, delta_time))
				affected_mob.Unconscious(4 SECONDS)
			if(DT_PROB(2, delta_time))
				affected_mob.Knockdown(4 SECONDS)
			if(DT_PROB(2, delta_time))
				affected_mob.emote("laugh")
			if(DT_PROB(2, delta_time))
				affected_mob.emote("scream")
			if(DT_PROB(2, delta_time))
				affected_mob.set_confusion_if_lower(max(10 SECONDS))
			if(DT_PROB(5, delta_time))
				affected_mob.adjust_jitter(10 SECONDS)
			if(DT_PROB(7.5, delta_time))
				affected_mob.adjust_stutter(3 SECONDS)

			if(DT_PROB(3, delta_time))
				affected_mob.adjustOrganLoss(ORGAN_SLOT_BRAIN, 2, 150)
			if(DT_PROB(1, delta_time))
				affected_mob.gain_trauma_type(BRAIN_TRAUMA_MILD, TRAUMA_RESILIENCE_LOBOTOMY)
		if(4)
			if(DT_PROB(2, delta_time))
				affected_mob.Unconscious(4 SECONDS)
			if(DT_PROB(3, delta_time))
				affected_mob.emote("laugh")
			if(DT_PROB(3, delta_time))
				affected_mob.emote("scream")
			if(DT_PROB(3, delta_time))
				affected_mob.set_confusion_if_lower(max(10 SECONDS))
			if(DT_PROB(4, delta_time))
				affected_mob.Knockdown(4 SECONDS)
			if(DT_PROB(7.5, delta_time))
				affected_mob.adjust_jitter(10 SECONDS)
			if(DT_PROB(10, delta_time))
				affected_mob.adjust_stutter(6 SECONDS)

			if(DT_PROB(5, delta_time))
				affected_mob.adjustOrganLoss(ORGAN_SLOT_BRAIN, 3, 200)
			if(DT_PROB(1, delta_time))
				affected_mob.gain_trauma_type(pick(BRAIN_TRAUMA_MILD, BRAIN_TRAUMA_SEVERE), TRAUMA_RESILIENCE_LOBOTOMY)
