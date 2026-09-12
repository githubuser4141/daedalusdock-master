//MOJAVE SUN CONTAINER LOCK EXTENSION - crates/lockers reuse the same padlock/key items and
//lock_locked/lock_group vars as doors (obj_defines.dm, keys.dm), just rolled and grouped here.

#define CONTAINER_ROUNDSTART_LOCK_CHANCE 15
#define CONTAINER_GROUP_CHANCE 50
#define CONTAINER_GROUP_RADIUS 7
#define CONTAINER_GROUP_MAX_SIZE 4

/// Containers that rolled a roundstart lock this round, queued for grouping in LateInitialize -
/// by then every other container on the map actually exists to search against, whereas any given
/// container's own Initialize() could run before or after its neighbors'.
GLOBAL_LIST_EMPTY(pending_locked_containers)

// Opt-in only: does nothing unless ms13_flags_1 & LOCKABLE_1 is set (mojave/structures/storage/
// crates.dm and lockers.dm set it on their ms13 base types), so this is inert for vanilla closets.
/obj/structure/closet/Initialize(mapload)
	. = ..()
	if(mapload)
		var/lock_hint = roll_for_roundstart_container_lock()
		if(lock_hint)
			. = lock_hint

/obj/structure/closet/LateInitialize()
	. = ..()
	if(src in GLOB.pending_locked_containers)
		GLOB.pending_locked_containers -= src
		assign_container_lock_group()

/obj/structure/closet/proc/roll_for_roundstart_container_lock()
	if(!(ms13_flags_1 & LOCKABLE_1))
		return
	if(!prob(CONTAINER_ROUNDSTART_LOCK_CHANCE))
		return

	var/obj/item/ms13/lock/new_lock = new(src)
	new_lock.lock_difficulty = rand(10, 17)
	new_lock.item_lock_locked = TRUE
	lock = new_lock
	AddElement(/datum/element/lockpickable, difficulty = new_lock.lock_difficulty)
	update_appearance()
	GLOB.pending_locked_containers += src
	return INITIALIZE_HINT_LATELOAD

/**
 * Either shares this container's lock with other still-ungrouped locked containers nearby (one key
 * covers the whole group) or gives it a unique key of its own - both cases just assign lock_group,
 * a solo lock is simply a "group" of one. Reuses the same key placement logic doors use.
 */
/obj/structure/closet/proc/assign_container_lock_group()
	var/list/obj/structure/closet/group = list(src)
	if(prob(CONTAINER_GROUP_CHANCE))
		for(var/obj/structure/closet/nearby in range(CONTAINER_GROUP_RADIUS, src))
			if(group.len >= CONTAINER_GROUP_MAX_SIZE)
				break
			if(nearby == src || !nearby.lock || nearby.lock_group)
				continue
			group += nearby

	var/group_id = "container_[REF(src)]"
	for(var/obj/structure/closet/member in group)
		member.lock_group = group_id

	var/obj/item/ms13/key/new_key = new
	new_key.lock_group = group_id
	if(group.len > 1)
		new_key.name = "worn ring key"
		new_key.desc = "An old key on a worn ring. Looks like it could open more than one thing nearby."
	else
		new_key.name = "worn key"
		new_key.desc = "An old key. Looks like it belongs to something nearby."
	place_roundstart_key_nearby(new_key, src)

#undef CONTAINER_ROUNDSTART_LOCK_CHANCE
#undef CONTAINER_GROUP_CHANCE
#undef CONTAINER_GROUP_RADIUS
#undef CONTAINER_GROUP_MAX_SIZE
