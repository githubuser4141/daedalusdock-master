//MOJAVE SUN KEY OBJECTS AND FUNCTION FILE//
/obj/item/ms13/key
	name = "base ms13 key"
	desc = "Lock this guy up and throw this away."
	icon = 'mojave/icons/objects/tools/keys_world.dmi'
	icon_state = "brass"
	lefthand_file = 'mojave/icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'mojave/icons/mob/inhands/items_righthand.dmi'
	worn_icon = 'mojave/icons/mob/worn_melee.dmi'
	worn_icon_state = "empty_placeholder"
	w_class = WEIGHT_CLASS_SMALL
	//grid_width = 32
	//grid_height = 32
	// lock_group is inherited from the base /obj var (obj_defines.dm): non-null here means this key
	// opens any /obj sharing the same lock_group. Used by grouped container locks (container_locks.dm)
	// so one key can cover several crates/lockers. Doors don't use this - see matching_door below.

/obj/item/ms13/key/Initialize()
	. = ..()
	AddElement(/datum/element/world_icon, null, icon, 'mojave/icons/objects/tools/keys_inventory.dmi')

/// Spawned alongside a roundstart-locked door (doors.dm) - using it on its matching door (see that
/// door's attackby()) unlocks that door specifically, as an alternative to lockpicking it.
/obj/item/ms13/key/door
	name = "worn key"
	desc = "An old key. Looks like it belongs to a nearby door."
	var/datum/weakref/matching_door

/// A mapper-placed key covering every door/crate/locker sharing its lock_group string (set both here
/// and on each lock-bearing /obj via VV - see the generic grouped-lock handling in obj_defines.dm).
/// Distinct subtype purely for a clearer in-game name/desc; the actual grouping is the plain lock_group
/// var every /obj/item/ms13/key already has.
/obj/item/ms13/key/master
	name = "master key"
	desc = "A heavier, more ornate key. This one looks like it opens more than a single door."

#define KEY_PLACEMENT_SEARCH_RADIUS 10
#define KEY_PLACEMENT_MOB_CHANCE 25
#define KEY_PLACEMENT_STORAGE_CHANCE 25
/**
 * Places a roundstart lock's matching key somewhere near owner, giving it a chance to land
 * somewhere with narrative weight instead of always just sitting on the floor:
 * - on a nearby mob, dead or alive, that isn't player-controlled (covers both "in a corpse's
 *   pocket" and "on the NPC who owns the room" - mechanically identical, just forceMove into
 *   their contents)
 * - inside a nearby structure's storage (a dresser, table, unlocked crate/locker)
 * - loose on a nearby open floor tile, same as the original always-on-the-floor behavior
 *
 * Called from LateInitialize, not Initialize - mob and storage candidates need every atom on the
 * map to already exist (a corpse prop is itself a spawner that resolves into a real mob during
 * its own Initialize, which isn't guaranteed to have already run yet during ours).
 */
/proc/place_roundstart_key_nearby(obj/item/ms13/key/new_key, atom/owner)
	if(prob(KEY_PLACEMENT_MOB_CHANCE))
		var/list/mob/living/mob_candidates = list()
		for(var/mob/living/candidate in range(KEY_PLACEMENT_SEARCH_RADIUS, owner))
			if(!candidate.client)
				mob_candidates += candidate
		if(mob_candidates.len)
			new_key.forceMove(pick(mob_candidates))
			return

	if(prob(KEY_PLACEMENT_STORAGE_CHANCE))
		var/list/obj/storage_candidates = list()
		for(var/obj/candidate in range(KEY_PLACEMENT_SEARCH_RADIUS, owner))
			if(candidate.atom_storage && !candidate.atom_storage.locked)
				storage_candidates += candidate
		if(storage_candidates.len)
			new_key.forceMove(pick(storage_candidates))
			return

	var/list/turf/open/floor_candidates = list()
	for(var/turf/open/candidate in range(KEY_PLACEMENT_SEARCH_RADIUS, owner))
		floor_candidates += candidate
	if(floor_candidates.len)
		new_key.forceMove(pick(floor_candidates))
#undef KEY_PLACEMENT_SEARCH_RADIUS
#undef KEY_PLACEMENT_MOB_CHANCE
#undef KEY_PLACEMENT_STORAGE_CHANCE
