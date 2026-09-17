/**
 * Gives anything with a hollow inside - a street lamp's access panel, a car's trunk, an animal's belly - a
 * space to search and hide things in.
 *
 * Some spaces are open to anyone's hand. Others are shut until someone uses open_tool on them (TOOL_KNIFE
 * takes any edged item), after which they stay open for everyone. The first time the space is reached it rolls
 * its loot table once and unpacks its stash, then it's a normal container that keeps whatever is put in it.
 *
 * Both halves of that matter for persistence:
 * - `searched` lives on the component, which lives on the atom, so the roll happens exactly once per prop
 *   for the life of that prop. It never re-rolls and never resets.
 * - create_storage() is called once and guarded, because it QDEL_NULLs any existing storage datum - calling
 *   it twice would silently throw away everything stored in the prop.
 *
 * Hosts that already have their own container UI (postboxes inherit DD's filing cabinet, which stores items
 * through its own TGUI and its own attack_hand) pass use_atom_storage = FALSE. They get the one-time loot
 * roll without a second storage system fighting the first one over the same click.
 */
/datum/component/ms13_searchable
	dupe_mode = COMPONENT_DUPE_UNIQUE

	/// Loot table spawner type rolled once, on first search. Null means "empty container, no loot".
	var/loot_table
	/// Item types (to counts) waiting inside, each rolled against the opening tool's butchering effectiveness.
	var/list/stash
	/// Whether to give the prop its own /datum/storage. FALSE for hosts that already have a container UI.
	var/use_atom_storage = TRUE
	var/slots = 1
	var/max_item_size = WEIGHT_CLASS_SMALL
	var/max_total = 4
	/// Shown once, the first time this prop is searched.
	var/search_message
	/// Tool behaviour needed to get inside. Null means a hand will do.
	var/open_tool
	var/open_time = 3 SECONDS
	/// Set after the one-time loot roll. From here on this is just a container.
	var/searched = FALSE

/datum/component/ms13_searchable/Initialize(
	loot_table,
	slots = 1,
	max_item_size = WEIGHT_CLASS_SMALL,
	max_total = 4,
	search_message,
	use_atom_storage = TRUE,
	open_tool,
	open_time = 3 SECONDS,
	list/stash,
)
	. = ..()
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

	src.loot_table = loot_table
	src.slots = slots
	src.max_item_size = max_item_size
	src.max_total = max_total
	src.search_message = search_message
	src.use_atom_storage = use_atom_storage
	src.open_tool = open_tool
	src.open_time = open_time
	src.stash = stash

/datum/component/ms13_searchable/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_ATTACK_HAND, PROC_REF(on_attack_hand))
	if(open_tool)
		RegisterSignal(parent, COMSIG_ATOM_TOOL_ACT(open_tool), PROC_REF(on_tool_act))
		RegisterSignal(parent, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(on_item_interaction))

/datum/component/ms13_searchable/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_ATTACK_HAND, COMSIG_ATOM_ITEM_INTERACTION))
	if(open_tool)
		UnregisterSignal(parent, COMSIG_ATOM_TOOL_ACT(open_tool))
	return ..()

/**
 * Only the FIRST search goes through here. Afterwards this returns immediately and /datum/storage's own
 * COMSIG_ATOM_ATTACK_HAND handler (registered when create_storage() ran below) opens the prop normally.
 */
/datum/component/ms13_searchable/proc/on_attack_hand(datum/source, mob/user, list/modifiers)
	SIGNAL_HANDLER

	if(searched)
		return
	var/atom/prop = parent
	if(open_tool)
		// A container it already had (a brahmin's saddlebags) stays reachable while this space is shut.
		if(prop.atom_storage)
			return
		to_chat(user, span_warning("[prop] is shut. You'd need [open_tool == TOOL_KNIFE ? "a blade" : "a [open_tool]"] to get inside."))
		return COMPONENT_CANCEL_ATTACK_CHAIN
	searched = TRUE
	// open_storage() can sleep, and a signal handler must not.
	INVOKE_ASYNC(src, PROC_REF(do_first_search), user)

/datum/component/ms13_searchable/proc/on_tool_act(datum/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	return try_open(user, tool)

/// Edged items rarely carry TOOL_KNIFE, and in combat mode tool acts don't run at all.
/datum/component/ms13_searchable/proc/on_item_interaction(datum/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(tool.tool_behaviour == open_tool || (open_tool == TOOL_KNIFE && (tool.sharpness & SHARP_EDGED)))
		return try_open(user, tool)

/datum/component/ms13_searchable/proc/try_open(mob/living/user, obj/item/tool)
	if(searched)
		return NONE
	INVOKE_ASYNC(src, PROC_REF(open_with), user, tool)
	return ITEM_INTERACT_SUCCESS

/datum/component/ms13_searchable/proc/open_with(mob/living/user, obj/item/tool)
	var/atom/prop = parent
	to_chat(user, span_notice("You start working [prop] open with [tool]..."))
	tool.play_tool_sound(prop)
	if(!do_after(user, prop, open_time * tool.toolspeed, DO_PUBLIC, display = tool) || searched || QDELETED(prop))
		return
	searched = TRUE
	do_first_search(user, tool)

/datum/component/ms13_searchable/proc/do_first_search(mob/user, obj/item/tool)
	var/atom/prop = parent
	if(QDELETED(prop))
		return

	if(use_atom_storage && !prop.atom_storage)
		prop.create_storage(max_slots = slots, max_specific_storage = max_item_size, max_total_storage = max_total)

	roll_loot()
	unpack_stash(tool)

	if(search_message && user)
		to_chat(user, span_notice(search_message))

	// Storage registered its own attack_hand handler only just now, so it can't have seen the click that got
	// us here - open it by hand this once so the first search isn't a no-op.
	if(user && prop.atom_storage)
		prop.atom_storage.open_storage(user)

/**
 * Reuses the existing mojave loot tables rather than defining new ones. Their spawn_scatter_radius is 0, so
 * the spawner drops its loot into its own loc - which is the prop - instead of onto the floor.
 */
/datum/component/ms13_searchable/proc/roll_loot()
	if(!loot_table)
		return
	var/obj/effect/spawner/random/spawner = new loot_table(parent)
	// Spawners that fire on Initialize() have already spawned and qdel'd themselves by now; ones that don't
	// still need firing. Checking rather than assuming avoids double-rolling the table.
	if(QDELETED(spawner))
		return
	spawner.spawn_loot()
	qdel(spawner)

/// A clumsy tool loses some of the stash, the same odds butchering gives it.
/datum/component/ms13_searchable/proc/unpack_stash(obj/item/tool)
	var/datum/component/butchering/butchering = tool?.GetComponent(/datum/component/butchering)
	var/effectiveness = butchering ? butchering.effectiveness : 100
	var/mob/living/carcass = parent
	if(isliving(carcass))
		effectiveness -= carcass.butcher_difficulty
	for(var/item_type in stash)
		for(var/i in 1 to stash[item_type])
			if(prob(effectiveness))
				var/atom/movable/unpacked_item = new item_type(parent)
				var/datum/component/ms13_livestock/livestock = parent.GetComponent(/datum/component/ms13_livestock)
				livestock?.apply_to_product(unpacked_item)
	stash = null
