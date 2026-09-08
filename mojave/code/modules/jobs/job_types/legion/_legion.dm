/datum/job/ms13/legion
	selection_color = "#9c0000"
	departments_list = list(
		/datum/job_department/legion,
	)
	exp_granted_type = EXP_TYPE_LEGION
	exp_required_type = EXP_TYPE_LEGION
	forbid = "Caesar's Legion forbids: chem usage, over-reliance on technology of all forms."

/datum/outfit/job/ms13/legion
	name = "Default"
	jobtype = /datum/job/ms13/legion

	back = /obj/item/storage/ms13/leather_backpack

/datum/outfit/job/ms13/legion/pre_equip(mob/living/carbon/human/H)
	..()

/datum/outfit/job/ms13/legion/post_equip(mob/living/carbon/human/H, visualsOnly)
	. = ..()
	if(H.gender != MALE)
		H.gender = MALE
		H.physique = MALE

//These are base jobs, we don't want them appearing at all
/datum/job/ms13/legion/config_check()
	if(type == /datum/job/ms13/legion)
		return FALSE
	return ..()

/datum/job/ms13/legion/map_check()
	if(type == /datum/job/ms13/legion)
		return FALSE
	return ..()

/datum/job/ms13/legion/after_spawn(mob/living/spawned, client/player_client)
	. = ..()
	if(!ishuman(spawned))
		return
	spawned.apply_pref_name(/datum/preference/name/legion_name, player_client)

// AI EDIT: this type was called above but never defined anywhere - not in this repo, not in MS's own live
// source either. Added following DD's own /datum/preference/name/religion pattern exactly (code/modules/client/
// preferences/names.dm) - same shape, using the legion name-list globals that already exist (mojave/code/
// _globalvars/lists/names.dm) and their backing string files (mojave/strings/names/legion_*_names.txt).
/datum/preference/name/legion_name
	savefile_key = "legion_name"
	allow_numbers = TRUE
	explanation = "Legion Name"
	group = "legion"

/datum/preference/name/legion_name/create_default_value()
	return "[capitalize(pick(GLOB.first_names_legion))] [capitalize(pick(GLOB.last_names_legion))]"
