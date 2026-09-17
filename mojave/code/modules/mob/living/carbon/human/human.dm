/mob/living/carbon/human
	/// Dead body stink: 0 fresh, 1 starting to turn, 2 far gone.
	var/rotting = 0
	var/pre_spawn = FALSE

/mob/living/carbon/human/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/fixeye)
	AddComponent(/datum/component/mumbleboop)

/mob/living/carbon/human/verb/open_job_info()
	set category = "IC"
	set name = "Open Role Information"

	if(!mind?.assigned_role)
		return FALSE
	if(!istype(mind.assigned_role, /datum/job))
		return FALSE
	mind.assigned_role.ui_interact(src)

//miasma

/mob/living/carbon/human/process()
	. = ..()
	if(stat == DEAD && rotting)
		var/turf/my_turf = get_turf(src)
		my_turf.VapourListTurf(list(/datum/vapours/ms13/miasma = 50), VAPOUR_ACTIVE_EMITTER_CAP)

// AI EDIT: added cause_of_death - see atmosphere.dm's /mob/living/death() for why.
/mob/living/carbon/human/death(gibbed, cause_of_death = "Unknown")
	. = ..()
	if(stat == DEAD)
		var/wait = pre_spawn ? rand(75 MINUTES, 90 MINUTES) : rand(30 MINUTES, 45 MINUTES)
		addtimer(CALLBACK(src, PROC_REF(rot), wait), wait)

/// Each stage of rot takes about as long as the first.
/mob/living/carbon/human/proc/rot(wait)
	if(stat != DEAD || rotting >= 2)
		return
	rotting++
	update_damage_overlays()
	if(rotting < 2)
		addtimer(CALLBACK(src, PROC_REF(rot), wait), wait)
