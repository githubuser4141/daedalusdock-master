/**
 * A dead animal keeps what butchering would have dropped inside itself. Someone cuts it open (a robot is
 * unscrewed instead) and the parts are there for anyone to take, rather than spilling out as the body is gibbed.
 */
/mob/living/death(gibbed, cause_of_death)
	. = ..()
	if(gibbed || iscarbon(src) || !(length(butcher_results) || length(guaranteed_butcher_results)))
		return
	var/list/stash = list()
	for(var/item_type in butcher_results)
		stash[item_type] += butcher_results[item_type]
	for(var/item_type in guaranteed_butcher_results)
		stash[item_type] += guaranteed_butcher_results[item_type]
	butcher_results = null
	guaranteed_butcher_results = null
	var/robotic = mob_biotypes & MOB_ROBOTIC
	var/room = 0
	for(var/item_type in stash)
		room += stash[item_type]
	AddComponent(/datum/component/ms13_searchable, \
		stash = stash, \
		open_tool = robotic ? TOOL_SCREWDRIVER : TOOL_KNIFE, \
		open_time = 8 SECONDS, \
		slots = room + 2, \
		max_item_size = WEIGHT_CLASS_BULKY, \
		max_total = (room + 2) * WEIGHT_CLASS_BULKY, \
		search_message = robotic ? "You pull [src]'s casing open." : "You cut [src] open.", \
	)
