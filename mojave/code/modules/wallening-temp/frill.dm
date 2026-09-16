GLOBAL_LIST_EMPTY(frill_objects)


/proc/get_frill_object(icon_path, junction, alpha = 255, pixel_x = 0, pixel_y = 0, plane = FRILL_PLANE)
	. = GLOB.frill_objects["[icon_path]-[junction]-[alpha]-[pixel_x]-[pixel_y]-[plane]"]
	if(.)
		return
	var/mutable_appearance/mut_appearance = mutable_appearance(icon_path, "frill-[junction]", ABOVE_MOB_LAYER, plane, alpha)
	mut_appearance.pixel_x = pixel_x
	mut_appearance.pixel_y = pixel_y
	// AI EDIT: the cap is decoration and must never take clicks. It is drawn at pixel_y = 32, so with the
	// default MOUSE_OPACITY_ICON a wall's hit area grew a whole tile upward - the wall one tile south
	// covered the tile you were pointing at, on a higher plane and layer, so right-click resolved to it
	// (or to nothing) and the wall under the cursor never appeared in the menu. Same failure the
	// largetransparency component documents: "the entire icon's dimensions block mouse clicks".
	mut_appearance.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	return GLOB.frill_objects["[icon_path]-[junction]-[alpha]-[pixel_x]-[pixel_y]-[plane]"] = mut_appearance

/**
  * Attached to smoothing atoms. Adds a globally-cached object to their vis_contents and updates based on junction changes.
  ** ATTENTION: This element was supposed to be for atoms, but since only movables and turfs actually have vis_contents hacks have to be done.
  ** For now it treats all of its targets as turfs, but that will runtime if an invalid variable access happens.
  ** Yes, this is ugly. The alternative is making two different elements for the same purpose.
  */
/datum/element/frill
	element_flags = ELEMENT_BESPOKE | ELEMENT_DETACH
	id_arg_index = 2
	var/icon_path


/datum/element/frill/Attach(datum/target, icon_path)
	if(!isturf(target) && !ismovable(target)) // Turfs and movables have vis_contents. Atoms don't. Pain.
		return ELEMENT_INCOMPATIBLE
	. = ..()
	src.icon_path = icon_path

	var/atom/atom_target = target

	on_junction_change(atom_target, atom_target.smoothing_junction)
	RegisterSignal(target, COMSIG_ATOM_SET_SMOOTHED_ICON_STATE, PROC_REF(on_junction_change))

/datum/element/frill/Detach(turf/target)

	target.cut_overlay(get_frill_object(icon_path, target.smoothing_junction, pixel_y = 32))
	target.cut_overlay(get_frill_object(icon_path, target.smoothing_junction, plane = WALL_PLANE, pixel_y = 32))
	UnregisterSignal(target, COMSIG_ATOM_SET_SMOOTHED_ICON_STATE)
	return ..()


/**
 * AI EDIT (experiment): every cap now goes on FRILL_PLANE instead of switching to WALL_PLANE when the wall
 * has a northern neighbour.
 *
 * Evidence for doing this: after the missing plane masters were restored, isolated walls - which take the
 * no-NORTH branch and therefore FRILL_PLANE - began rendering as proper cubes, while walls in a run stayed
 * flat. Those are the ones that take the WALL_PLANE branch. /turf/closed now also lives on WALL_PLANE, so
 * a cap placed there shares a plane with every wall body and stops reading as a separate layer above them.
 *
 * The original branch exists so a cap that lands on a neighbouring wall's tile is drawn behind it rather
 * than over it. Putting everything on FRILL_PLANE may therefore make caps overlap the wall to the north.
 * If that happens, the fix is to keep the split but give WALL_PLANE caps their own plane between the wall
 * body and FRILL_PLANE, rather than reusing the body's plane.
 */
/datum/element/frill/proc/on_junction_change(atom/source, new_junction)
	SIGNAL_HANDLER
	var/turf/turf_or_movable = source
	turf_or_movable.cut_overlay(get_frill_object(icon_path, source.smoothing_junction, pixel_y = 32))
	turf_or_movable.add_overlay(get_frill_object(icon_path, new_junction, pixel_y = 32))
