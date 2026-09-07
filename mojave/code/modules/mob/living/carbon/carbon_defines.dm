/mob/living/carbon
	/// To be or not to be fat, that is the question
	var/fatness = FATNESS_AVERAGE
	/// Cooldown for the next smell - imagine the smell
	// Renamed from next_smell: that name collides with the unrelated /datum/weakref/next_smell
	// already declared on /mob/living in code/modules/mob/living/living_defines.dm.
	var/smell_emote_cooldown = 0
