/**
 * Makes an ordinary background prop worth walking up to.
 *
 * The first time someone searches it, it rolls a loot table once and then becomes a normal container that
 * keeps whatever is put in it - so a street lamp's access panel is somewhere to find a fuse the first time
 * and somewhere to hide a pistol every time after.
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
	/// Whether to give the prop its own /datum/storage. FALSE for hosts that already have a container UI.
	var/use_atom_storage = TRUE
	var/slots = 1
	var/max_item_size = WEIGHT_CLASS_SMALL
	var/max_total = 4
	/// Shown once, the first time this prop is searched.
	var/search_message
	/// Set after the one-time loot roll. From here on this is just a container.
	var/searched = FALSE

/datum/component/ms13_searchable/Initialize(
	loot_table,
	slots = 1,
	max_item_size = WEIGHT_CLASS_SMALL,
	max_total = 4,
	search_message,
	use_atom_storage = TRUE,
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

/datum/component/ms13_searchable/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_ATTACK_HAND, PROC_REF(on_attack_hand))

/datum/component/ms13_searchable/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ATOM_ATTACK_HAND)
	return ..()

/**
 * Only the FIRST search goes through here. Afterwards this returns immediately and /datum/storage's own
 * COMSIG_ATOM_ATTACK_HAND handler (registered when create_storage() ran below) opens the prop normally.
 */
/datum/component/ms13_searchable/proc/on_attack_hand(datum/source, mob/user, list/modifiers)
	SIGNAL_HANDLER

	if(searched)
		return
	searched = TRUE
	// open_storage() can sleep, and a signal handler must not.
	INVOKE_ASYNC(src, PROC_REF(do_first_search), user)

/datum/component/ms13_searchable/proc/do_first_search(mob/user)
	var/atom/prop = parent
	if(QDELETED(prop))
		return

	if(use_atom_storage && !prop.atom_storage)
		prop.create_storage(max_slots = slots, max_specific_storage = max_item_size, max_total_storage = max_total)

	roll_loot()

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
