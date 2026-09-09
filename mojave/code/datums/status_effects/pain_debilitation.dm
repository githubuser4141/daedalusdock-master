// Status effects applied by the handle_pain()/handle_shock() overrides in
// mojave/code/modules/mob/living/carbon/pain_debilitation.dm. Tuning knobs live in
// mojave/code/_DEFINES/pain_debilitation.dm.

/atom/movable/screen/alert/status_effect/ms13_pain_debilitation
	name = "Debilitated"
	desc = "You're in agonizing pain and struggling to keep going - slow, shaky, and prone to stumbling or dropping what you're holding."
	icon_state = "convulsing"

/**
 * The mojave "debilitated by pain" response, applied in place of DD's Unconscious() collapse once
 * pain or shock crosses the raised thresholds. The owner stays conscious and able to act.
 * severity is roughly a 0.5-2 scale (how far past the relevant threshold the pain/shock was).
 */
/datum/status_effect/ms13_pain_debilitation
	id = "ms13_pain_debilitation"
	duration = MS13_PAIN_DEBILITATION_DURATION
	tick_interval = MS13_PAIN_DEBILITATION_TICK_INTERVAL
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /atom/movable/screen/alert/status_effect/ms13_pain_debilitation
	var/severity = 1

/datum/status_effect/ms13_pain_debilitation/on_creation(mob/living/new_owner, new_severity = 1)
	severity = clamp(new_severity, 0.5, 2)
	return ..()

/// Reapplying while already active refreshes the duration and updates severity to the latest reading.
/datum/status_effect/ms13_pain_debilitation/refresh(mob/living/parent, effect_path, new_severity = 1)
	. = ..()
	severity = clamp(new_severity, 0.5, 2)

/datum/status_effect/ms13_pain_debilitation/tick(delta_time, times_fired)
	if(owner.stat == DEAD || HAS_TRAIT(owner, TRAIT_FAKEDEATH))
		return

	owner.blur_eyes(MS13_PAIN_DEBILITATION_BLUR * severity)
	owner.set_jitter(MS13_PAIN_DEBILITATION_JITTER * severity)
	owner.set_timed_status_effect(MS13_PAIN_DEBILITATION_STUTTER * severity, /datum/status_effect/speech/stutter, only_if_higher = TRUE)

	if(owner.stat != CONSCIOUS || !iscarbon(owner))
		return

	var/mob/living/carbon/carbon_owner = owner
	if(prob(MS13_PAIN_DEBILITATION_STUMBLE_CHANCE * severity))
		owner.manual_emote(pick("staggers", "stumbles", "nearly collapses"))
		owner.Knockdown(MS13_PAIN_DEBILITATION_STUMBLE_DURATION)

	if(prob(MS13_PAIN_DEBILITATION_DROP_CHANCE * severity) && COOLDOWN_FINISHED(carbon_owner, pain_cooldowns["drop_item"]))
		carbon_owner.pain_drop_item(PAIN_THRESHOLD_DROP_ITEM * severity)

/**
 * DD's own /datum/status_effect/determined (code/datums/status_effects/wound_effects.dm) is a real
 * "fight-or-flight" buff - reduced bleeding, halved limp penalty, a visible alert - that's never
 * actually applied anywhere in the base game. This just gives it a finite duration so it can be
 * granted as a reward (see handle_shock()'s "shrug off pain" roll) instead of lasting forever.
 * Same id as the base type ("determined"), so anything checking has_status_effect(determined)
 * still sees it, e.g. the reduced-limping check in wound_effects.dm.
 */
/datum/status_effect/determined/ms13_adrenaline
	duration = MS13_ADRENALINE_DURATION
	status_type = STATUS_EFFECT_REFRESH
