// Visual "pale skin" overlay when circulation is low (undergoing_pale_skin(), code/modules/mob/living/
// carbon/carbon_health.dm - already folds in vessel circulation via get_blood_circulation(), see vessel.dm).
// Mirrors the existing TRAIT_JAUNDICE_SKIN pattern (code/modules/mob/living/carbon/human/init_signals.dm,
// code/modules/mob/living/carbon/life.dm's handle_liver()) instead of inventing a new one: same per-tick
// ADD_TRAIT/REMOVE_TRAIT toggle, same SIGNAL_ADDTRAIT/REMOVETRAIT-driven add_color_override() overlay.

/mob/living/carbon/human/register_init_signals()
	. = ..()
	RegisterSignal(src, SIGNAL_ADDTRAIT(TRAIT_PALE_SKIN), PROC_REF(on_pale_skin_gain))
	RegisterSignal(src, SIGNAL_REMOVETRAIT(TRAIT_PALE_SKIN), PROC_REF(on_pale_skin_loss))

/// Called when TRAIT_PALE_SKIN is gained.
/mob/living/carbon/human/proc/on_pale_skin_gain(datum/source)
	SIGNAL_HANDLER
	for(var/obj/item/bodypart/BP as anything in bodyparts)
		if(!BP.can_be_jaundiced()) // same organic-limb-with-skin-tone gate jaundice uses
			continue
		BP.add_color_override("#b8c4c9", LIMB_COLOR_PALE_SKIN)
	update_body_parts()

/// Called when TRAIT_PALE_SKIN is lost.
/mob/living/carbon/human/proc/on_pale_skin_loss(datum/source)
	SIGNAL_HANDLER
	for(var/obj/item/bodypart/BP as anything in bodyparts)
		BP.remove_color_override(LIMB_COLOR_PALE_SKIN)
	update_body_parts()

/// Same per-tick toggle idiom as handle_liver()'s TRAIT_JAUNDICE_SKIN (code/modules/mob/living/carbon/life.dm).
/mob/living/carbon/human/Life(delta_time = SSMOBS_DT, times_fired)
	. = ..()
	if(undergoing_pale_skin())
		ADD_TRAIT(src, TRAIT_PALE_SKIN, INNATE_TRAIT)
	else
		REMOVE_TRAIT(src, TRAIT_PALE_SKIN, INNATE_TRAIT)
