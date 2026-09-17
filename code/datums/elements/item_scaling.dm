/**
 * Element for scaling item appearances in the overworld or in inventory/storage.
 *
 * This bespoke element allows for items to have varying sizes depending on their location.
 * The overworld simply refers to items being on a turf.  Inventory includes HUD item slots,
 * and storage is anywhere a storage component is used.
 * Scaling should affect the item's icon and all attached overlays (such as blood decals).
 *
 */
/datum/element/item_scaling
	element_flags = ELEMENT_BESPOKE
	id_arg_index = 2
	/// Scaling value when the attached item is in the overworld (on a turf).
	var/overworld_scaling
	/// Scaling value when the attached item is in a storage component or inventory slot.
	var/storage_scaling

/**
 * Attach proc for the item_scaling element
 *
 * The proc checks the target's type before attaching.  It then initializes
 * the target to overworld scaling.  The target should then rescale if it is placed
 * in inventory/storage on initialization.  Relevant signals are registered to listen
 * for pickup/drop or storage events.  Scaling values of 1 will result in items
 * returning to their original size.
 * Arguments:
 * * target - Datum to attach the element to.
 * * overworld_scaling - Integer or float to scale the item in the overworld.
 * * storage_scaling - Integer or float to scale the item in storage/inventory.
 */
/datum/element/item_scaling/Attach(atom/target, overworld_scaling, storage_scaling)
	. = ..()
	if(!isatom(target))
		return ELEMENT_INCOMPATIBLE

	src.overworld_scaling = overworld_scaling
	src.storage_scaling = storage_scaling
	scale(target, isturf(target.loc) ? overworld_scaling : storage_scaling)

	// Make sure overlays also inherit the scaling.
	ADD_KEEP_TOGETHER(target, ITEM_SCALING_TRAIT)

	// MOJAVE EDIT: ATOM_ENTERED/EXITED go to the container, not the item, so moving between the floor and a bag
	// or body never rescaled it. Rescale whenever the item moves on or off a turf instead.
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/**
 * Detach proc for the item_scaling element.
 *
 * All registered signals are unregistered, and the attached element is removed from the target datum.
 * Arguments:
 * * target - Datum which the element is attached to.
 */
/datum/element/item_scaling/Detach(atom/target)
	UnregisterSignal(target, COMSIG_MOVABLE_MOVED)

	REMOVE_KEEP_TOGETHER(target, ITEM_SCALING_TRAIT)

	return ..()

/**
 * Scales the attached item's matrix.
 *
 * The proc first narrows the type of the source to (datums do not have a transform matrix).
 * It then creates an identity matrix, M, which is transformed by the scaling value.
 * The object's transform variable (matrix) is then set to the resulting value of M.
 * Arguments:
 * * source - Source datum which sent the signal.
 * * scaling - Integer or float to scale the item's matrix.
 */
/datum/element/item_scaling/proc/scale(datum/source, scaling)
	var/atom/scalable_object = source
	var/matrix/M = matrix()
	scalable_object.transform = M.Scale(scaling)

/// Overworld size on a turf, storage size anywhere else (hands, bags, bodies).
/datum/element/item_scaling/proc/on_moved(atom/movable/source, atom/old_loc)
	SIGNAL_HANDLER

	if(isturf(source.loc) != isturf(old_loc))
		scale(source, isturf(source.loc) ? overworld_scaling : storage_scaling)
