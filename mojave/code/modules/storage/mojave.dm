/datum/storage/ms13/suit/large
	max_slots = 4
	max_specific_storage = WEIGHT_CLASS_SMALL
	max_total_storage = 8
	grid_columns = 4
	grid_start_x = 15

/datum/storage/ms13/suit/med
	max_slots = 3
	max_specific_storage = WEIGHT_CLASS_SMALL
	max_total_storage = 6
	grid_columns = 2

/datum/storage/ms13/suit/small
	max_slots = 2
	max_specific_storage = WEIGHT_CLASS_TINY
	max_total_storage = 4

/datum/storage/ms13/shoes
	max_slots = 1
	max_specific_storage = WEIGHT_CLASS_TINY
	max_total_storage = 2
	grid_columns = 1
	grid_rows = 2
	grid_start_x = 17
	grid_start_y = 4

/*
 * Grid inventory, ported from MS13's tarkov.dm (itself from Septic Shock) onto DD's storage datums. Items lie on a grid
 * of cells, each taking grid_width x grid_height pixels of it (a cell is world.icon_size). They go in the first free
 * spot, turned if they only fit the other way, or exactly where the grid is clicked; ctrl-click the grid to turn what
 * you're holding, and a green or red outline shows whether it fits where you point. Drag the close button to move the
 * window once ctrl-clicking it has unlocked it; shift-click it to put the window back. The grid is the capacity: slot
 * and total-weight limits don't apply to it, only the biggest thing it takes. MS13's own storage (/datum/storage/ms13)
 * is a grid; SS13's, full of things never sized for one, keeps its slots.
 */
/obj/item
	/// Size on a storage grid, in pixels. Unset, it's sized by w_class.
	var/grid_width = 0
	var/grid_height = 0

/obj/item/Initialize(mapload)
	. = ..()
	if(grid_width <= 0)
		grid_width = w_class * world.icon_size
	if(grid_height <= 0)
		grid_height = w_class * world.icon_size

/// Turns it a quarter, for fitting on a grid.
/obj/item/proc/inventory_flip(mob/user)
	var/old_width = grid_width
	grid_width = grid_height
	grid_height = old_width
	if(user)
		to_chat(user, span_notice("You turn [src] around."))

/datum/storage
	/// Lays its items out on a grid.
	var/grid = FALSE
	/// Its size in cells, and where the top-left cell sits on screen.
	var/grid_columns = 8
	var/grid_rows = 3
	var/grid_start_x = 6
	var/grid_start_y = 5
	var/grid_pixel_x = 5
	var/grid_pixel_y = 0
	/// Its window can't be dragged about until the close button's ctrl-clicked.
	var/grid_locked = TRUE
	/// Cell "x,y" -> the item covering it, and item -> the cell under its bottom-left corner, list(x, y).
	var/list/grid_cells
	var/list/grid_origins
	/// Where a click on the grid asked the next item to go, list(x, y).
	var/tmp/list/grid_target
	/// Item outlines by size.
	var/static/list/grid_outlines = list()

/datum/storage/can_insert(obj/item/to_insert, mob/user, messages = TRUE, force = FALSE)
	. = ..()
	if(!. || !grid)
		return
	if(!grid_spot_turning(to_insert))
		if(messages && user)
			to_chat(user, span_warning("There's no room for [to_insert] in [parent]."))
		return FALSE

/datum/storage/check_slots_full(obj/item/to_insert)
	return grid || ..()

/datum/storage/check_total_weight(obj/item/to_insert)
	return grid || ..()

/datum/storage/set_real_location(atom/new_real_loc, should_drop = FALSE)
	. = ..()
	if(grid && new_real_loc)
		for(var/obj/item/item in new_real_loc)
			grid_take(item)

/datum/storage/handle_enter(datum/source, obj/item/arrived)
	if(grid && istype(arrived))
		grid_take(arrived)
	grid_target = null
	return ..()

/datum/storage/handle_exit(datum/source, obj/item/gone)
	if(istype(gone))
		grid_remove(gone)
	return ..()

/// Finds a place on the grid for something that's come inside, or it falls back out.
/datum/storage/proc/grid_take(obj/item/item)
	if(LAZYACCESS(grid_origins, item))
		return
	var/list/spot = grid_spot_turning(item)
	if(spot)
		grid_place(item, spot)
	else
		addtimer(CALLBACK(src, PROC_REF(grid_spill), item), 0)

/// Something went in with no room for it, not through can_insert(): it falls out, unless room's been made meanwhile.
/// With nowhere to fall (a kit put together out of play), it waits inside for the next look.
/datum/storage/proc/grid_spill(obj/item/item)
	if(QDELETED(item) || item.loc != real_location || LAZYACCESS(grid_origins, item))
		return
	var/list/spot = grid_spot_turning(item)
	if(spot)
		grid_place(item, spot)
		refresh_views()
		return
	var/atom/drop = parent.drop_location()
	if(!drop)
		return
	item.forceMove(drop)
	parent.visible_message(span_warning("[item] falls out of [parent]."))

/// An item's size in cells, list(wide, high), even before Initialize() has sized it.
/proc/grid_cells_of(obj/item/item)
	var/width = item.grid_width > 0 ? item.grid_width : item.w_class * world.icon_size
	var/height = item.grid_height > 0 ? item.grid_height : item.w_class * world.icon_size
	return list(max(1, round(width / world.icon_size)), max(1, round(height / world.icon_size)))

/// Whether a wide x high item fits with its bottom-left corner on cell x,y, ignoring any of it that's already there.
/datum/storage/proc/grid_fits(x, y, wide, high, obj/item/ignore)
	if(x < 0 || y < 0 || x + wide > grid_columns || y + high > grid_rows)
		return FALSE
	for(var/cell_x in x to x + wide - 1)
		for(var/cell_y in y to y + high - 1)
			var/obj/item/there = LAZYACCESS(grid_cells, "[cell_x],[cell_y]")
			if(there && there != ignore)
				return FALSE
	return TRUE

/// The cell for item's bottom-left corner, list(x, y): where the grid was clicked, else the first free spot, working
/// down each column from the top left. Null if there's none.
/datum/storage/proc/grid_spot(obj/item/item)
	var/list/size = grid_cells_of(item)
	if(grid_target)
		return grid_fits(grid_target[1], grid_target[2], size[1], size[2], item) ? grid_target : null
	for(var/x in 0 to grid_columns - size[1])
		for(var/y in grid_rows - size[2] to 0 step -1)
			if(grid_fits(x, y, size[1], size[2], item))
				return list(x, y)
	return null

/// As grid_spot(), turning item if it only fits the other way (though never into a spot that was clicked).
/datum/storage/proc/grid_spot_turning(obj/item/item)
	. = grid_spot(item)
	if(. || grid_target || item.grid_width == item.grid_height)
		return
	item.inventory_flip()
	. = grid_spot(item)
	if(!.)
		item.inventory_flip()

/datum/storage/proc/grid_place(obj/item/item, list/spot)
	var/list/size = grid_cells_of(item)
	LAZYSET(grid_origins, item, spot.Copy())
	for(var/cell_x in spot[1] to spot[1] + size[1] - 1)
		for(var/cell_y in spot[2] to spot[2] + size[2] - 1)
			LAZYSET(grid_cells, "[cell_x],[cell_y]", item)

/datum/storage/proc/grid_remove(obj/item/item)
	if(!LAZYACCESS(grid_origins, item))
		return
	LAZYREMOVE(grid_origins, item)
	for(var/cell in grid_cells?.Copy())
		if(grid_cells[cell] == item)
			LAZYREMOVE(grid_cells, cell)
	var/list/size = grid_cells_of(item)
	item.underlays -= grid_outline(size[1], size[2])

/// Screen location of cell x,y, plus a pixel offset.
/datum/storage/proc/grid_screen_loc(x, y, offset_x = 0, offset_y = 0)
	var/pixel_x = (grid_start_x + x) * world.icon_size + grid_pixel_x + offset_x
	var/pixel_y = (grid_start_y - grid_rows + 1 + y) * world.icon_size + grid_pixel_y + offset_y
	return "[round(pixel_x / world.icon_size)]:[pixel_x % world.icon_size],[round(pixel_y / world.icon_size)]:[pixel_y % world.icon_size]"

/// The cell under a screen location from click params ("x:px,y:py"), list(x, y). Null if it's off the grid.
/datum/storage/proc/grid_cell_at(screen_loc)
	var/list/axes = splittext(screen_loc, ",")
	if(length(axes) != 2)
		return null
	var/list/along = splittext(axes[1], ":")
	var/list/up = splittext(axes[2], ":")
	if(length(along) < 2 || length(up) < 2)
		return null
	var/pixel_x = text2num(along[length(along) - 1]) * world.icon_size + text2num(along[length(along)]) - 1
	var/pixel_y = text2num(up[length(up) - 1]) * world.icon_size + text2num(up[length(up)]) - 1
	var/x = round((pixel_x - (grid_start_x * world.icon_size + grid_pixel_x)) / world.icon_size)
	var/y = round((pixel_y - ((grid_start_y - grid_rows + 1) * world.icon_size + grid_pixel_y)) / world.icon_size)
	if(x < 0 || y < 0 || x >= grid_columns || y >= grid_rows)
		return null
	return list(x, y)

/datum/storage/orient_to_hud()
	if(!grid)
		return ..()
	boxes.icon = 'mojave/icons/hud/storage.dmi'
	boxes.icon_state = "background"
	boxes.alpha = 180
	boxes.screen_loc = "[grid_start_x]:[grid_pixel_x],[grid_start_y]:[grid_pixel_y] to [grid_start_x + grid_columns - 1]:[grid_pixel_x],[grid_start_y - grid_rows + 1]:[grid_pixel_y]"
	for(var/obj/item/item in real_location)
		var/list/spot = LAZYACCESS(grid_origins, item)
		if(!spot)
			grid_take(item)
			continue
		var/list/size = grid_cells_of(item)
		var/mutable_appearance/outline = grid_outline(size[1], size[2])
		item.underlays -= outline
		item.underlays += outline
		item.mouse_opacity = MOUSE_OPACITY_OPAQUE
		item.plane = ABOVE_HUD_PLANE
		item.maptext = ""
		// Centred over the cells it covers.
		item.screen_loc = grid_screen_loc(spot[1], spot[2], world.icon_size / 2 * (size[1] - 1), world.icon_size / 2 * (size[2] - 1))
	grid_update_closer()

/// The close button: over the top of the window, as wide as it is.
/datum/storage/proc/grid_update_closer()
	closer.icon = 'mojave/icons/hud/storage.dmi'
	closer.cut_overlays()
	var/half = (grid_columns - 1) / 2
	var/half_floor = round(half)
	var/half_ceiling = -round(-half)
	closer.screen_loc = "[grid_start_x + half_floor]:[grid_pixel_x],[grid_start_y + 1]:[grid_pixel_y]"
	closer.icon_state = grid_columns <= 1 ? "close" : grid_columns == 2 ? "close_left" : "close_mid"
	for(var/step in 1 to half_floor)
		var/image/piece = image(closer.icon, step >= half_floor ? "close_left" : "close_mid")
		piece.transform = matrix().Translate(world.icon_size * -step, 0)
		closer.add_overlay(piece)
	for(var/step in 1 to half_ceiling)
		var/image/piece = image(closer.icon, step >= half_ceiling ? "close_right" : "close_mid")
		piece.transform = matrix().Translate(world.icon_size * step, 0)
		closer.add_overlay(piece)
	if(grid_columns > 1)
		var/image/cross = image(closer.icon, "close_overlay")
		cross.transform = matrix().Translate(world.icon_size * (half - half_floor), 0)
		closer.add_overlay(cross)

/// The frame drawn round an item on the grid, wide x high cells, built once per size.
/datum/storage/proc/grid_outline(wide, high)
	var/key = "[wide]x[high]"
	if(grid_outlines[key])
		return grid_outlines[key]
	var/width = wide * world.icon_size
	var/height = high * world.icon_size
	var/top = height - world.icon_size
	var/right = width - world.icon_size
	var/icon/frame = icon('mojave/icons/hud/storage.dmi', "blank")
	frame.Scale(width, height)
	var/icon/piece = icon('mojave/icons/hud/storage.dmi', "block_under")
	piece.Scale(width, height)
	frame.Blend(piece, ICON_OVERLAY)
	var/list/rows = list("down" = 0, "up" = top)
	for(var/edge in rows)
		piece = icon('mojave/icons/hud/storage.dmi', edge)
		piece.Scale(width, world.icon_size)
		frame.Blend(piece, ICON_OVERLAY, 1, 1 + rows[edge])
	var/list/columns = list("left" = 0, "right" = right)
	for(var/edge in columns)
		piece = icon('mojave/icons/hud/storage.dmi', edge)
		piece.Scale(world.icon_size, height)
		frame.Blend(piece, ICON_OVERLAY, 1 + columns[edge], 1)
	frame.Blend(icon('mojave/icons/hud/storage.dmi', "corner_left_down"), ICON_OVERLAY, 1, 1)
	frame.Blend(icon('mojave/icons/hud/storage.dmi', "corner_right_down"), ICON_OVERLAY, 1 + right, 1)
	frame.Blend(icon('mojave/icons/hud/storage.dmi', "corner_left_up"), ICON_OVERLAY, 1, 1 + top)
	frame.Blend(icon('mojave/icons/hud/storage.dmi', "corner_right_up"), ICON_OVERLAY, 1 + right, 1 + top)
	var/mutable_appearance/outline = mutable_appearance(frame)
	outline.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA
	// Items are drawn centred over their cells, so the frame's pulled back to their corner.
	outline.transform = matrix().Translate(-right / 2, -top / 2)
	grid_outlines[key] = outline
	return outline

/atom/movable/screen/storage
	/// The outline showing where what's held would go.
	var/atom/movable/screen/storage_hover/hovering
	/// The last mouse position, to redraw that outline when what's held is turned.
	var/list/last_mouse

/atom/movable/screen/storage/Destroy()
	QDEL_NULL(hovering)
	return ..()

/atom/movable/screen/storage/Click(location, control, params)
	var/datum/storage/storage = master_ref?.resolve()
	if(!storage?.grid)
		return ..()
	var/list/modifiers = params2list(params)
	var/obj/item/held = usr.get_active_held_item()
	if(held && LAZYACCESS(modifiers, CTRL_CLICK))
		held.inventory_flip(usr)
		if(length(last_mouse) == 3)
			MouseMove(last_mouse[1], last_mouse[2], last_mouse[3])
		return TRUE
	storage.grid_target = storage.grid_cell_at(LAZYACCESS(modifiers, SCREEN_LOC))
	. = ..()
	storage.grid_target = null

/// Dropped somewhere else on the grid it's already in, it just moves there.
/atom/movable/screen/storage/MouseDroppedOn(atom/dropping, mob/user, params)
	var/datum/storage/storage = master_ref?.resolve()
	if(!storage?.grid)
		return ..()
	storage.grid_target = storage.grid_cell_at(LAZYACCESS(params2list(params), SCREEN_LOC))
	var/obj/item/item = dropping
	if(istype(item) && item.loc == storage.get_real_location() && !user.incapacitated())
		var/list/spot = storage.grid_target && storage.grid_spot(item)
		if(spot)
			storage.grid_remove(item)
			storage.grid_place(item, spot)
			storage.refresh_views()
		storage.grid_target = null
		return TRUE
	. = ..()
	storage.grid_target = null

/atom/movable/screen/storage/MouseEntered(location, control, params)
	. = ..()
	MouseMove(location, control, params)

/atom/movable/screen/storage/MouseExited(location, control, params)
	. = ..()
	usr.client?.screen -= hovering

/atom/movable/screen/storage/MouseMove(location, control, params)
	. = ..()
	last_mouse = list(location, control, params)
	if(!usr.client)
		return
	usr.client.screen -= hovering
	var/datum/storage/storage = master_ref?.resolve()
	var/obj/item/held = usr.get_active_held_item()
	if(!storage?.grid || usr.active_storage != storage || !held || held == storage.parent || usr.incapacitated())
		return
	var/list/cell = storage.grid_cell_at(LAZYACCESS(params2list(params), SCREEN_LOC))
	if(!cell)
		return
	storage.grid_target = cell
	var/fits = storage.can_insert(held, usr, messages = FALSE)
	storage.grid_target = null
	if(!hovering)
		hovering = new
	hovering.color = fits ? COLOR_LIME : COLOR_RED_LIGHT
	var/list/size = grid_cells_of(held)
	hovering.transform = matrix(size[1], 0, world.icon_size / 2 * (size[1] - 1), 0, size[2], world.icon_size / 2 * (size[2] - 1))
	hovering.screen_loc = storage.grid_screen_loc(cell[1], cell[2])
	usr.client.screen |= hovering

/atom/movable/screen/storage_hover
	icon = 'mojave/icons/hud/storage.dmi'
	icon_state = "white"
	plane = ABOVE_HUD_PLANE
	layer = 1
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	alpha = 96

/atom/movable/screen/close/Click(location, control, params)
	var/datum/storage/storage = master_ref?.resolve()
	if(!storage?.grid)
		return ..()
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, SHIFT_CLICK))
		storage.grid_start_x = initial(storage.grid_start_x)
		storage.grid_start_y = initial(storage.grid_start_y)
		storage.refresh_views()
		to_chat(usr, span_notice("Storage window put back."))
		return TRUE
	if(LAZYACCESS(modifiers, CTRL_CLICK))
		storage.grid_locked = !storage.grid_locked
		to_chat(usr, span_notice("Storage window [storage.grid_locked ? "locked" : "unlocked"]."))
		return TRUE
	return ..()

/// Dragging the close button moves the window, once it's unlocked, keeping it on screen.
/atom/movable/screen/close/MouseDrop(atom/over, src_location, over_location, src_control, over_control, params)
	. = ..()
	var/datum/storage/storage = master_ref?.resolve()
	if(!storage?.grid || !usr.client)
		return
	if(storage.grid_locked)
		to_chat(usr, span_warning("The storage window is locked; ctrl-click its close button to unlock it."))
		return
	var/list/axes = splittext(LAZYACCESS(params2list(params), SCREEN_LOC), ",")
	if(length(axes) != 2)
		return
	var/list/along = splittext(axes[1], ":")
	var/list/up = splittext(axes[2], ":")
	var/list/view = getviewsize(usr.client.view)
	storage.grid_start_x = clamp(text2num(along[length(along) - 1]) - round((storage.grid_columns - 1) / 2), 1, view[1] - storage.grid_columns + 1)
	storage.grid_start_y = clamp(text2num(up[length(up) - 1]) - 1, storage.grid_rows, view[2] - 1)
	storage.refresh_views()

// Grid layouts, as MS13 had them.
/datum/storage/ms13
	grid = TRUE

/datum/storage/ms13/backpack
	grid_columns = 6
	grid_rows = 6
	grid_start_x = 13
	grid_start_y = 7

/datum/storage/ms13/backpack/rad_pack
	grid_columns = 4
	grid_rows = 4
	grid_start_x = 15
	grid_start_y = 5

/datum/storage/ms13/satchel
	grid_columns = 6
	grid_rows = 4
	grid_start_x = 13
	grid_start_y = 5

/datum/storage/ms13/backpack_military
	grid_columns = 6
	grid_rows = 7
	grid_start_x = 13
	grid_start_y = 7

/datum/storage/ms13/duffel_military
	grid_columns = 7
	grid_rows = 5
	grid_start_x = 12
	grid_start_y = 7

/datum/storage/ms13/harvest_bag
	grid_columns = 4
	grid_rows = 4
	grid_start_x = 15
	grid_start_y = 5

/datum/storage/ms13/firstaid
	grid_columns = 4
	grid_rows = 3
	grid_start_x = 15
	grid_start_y = 4

/datum/storage/ms13/doctors_bag
	grid_columns = 4
	grid_rows = 4
	grid_start_x = 15
	grid_start_y = 5

/datum/storage/ms13/toolbox
	grid_columns = 6
	grid_rows = 4
	grid_start_x = 13
	grid_start_y = 5

/datum/storage/ms13/suit
	grid_columns = 1
	grid_rows = 2
	grid_start_x = 17
	grid_start_y = 4

// Core items MS13 sized for the grid.
/obj/item/food/badrecipe
	grid_width = 32
	grid_height = 32

#ifdef UNIT_TESTS
/datum/unit_test/ms13_grid_inventory
	name = "INVENTORY: Items Fill A Grid By Their Size"

/datum/unit_test/ms13_grid_inventory/Run()
	var/obj/item/storage/ms13/backpack = allocate(/obj/item/storage/ms13)
	var/datum/storage/storage = backpack.atom_storage
	if(!storage.grid || storage.grid_columns != 6 || storage.grid_rows != 6)
		return Fail("An MS13 backpack isn't a 6x6 grid.")
	// Nine 2x2 things fill a 6x6 grid exactly, the first in the top-left corner.
	var/list/things = list()
	for(var/i in 1 to 9)
		var/obj/item/ms13_grid_test/thing = allocate(/obj/item/ms13_grid_test)
		if(!storage.can_insert(thing, messages = FALSE))
			return Fail("A 2x2 thing didn't fit a 6x6 grid with [i - 1] in it.")
		thing.forceMove(backpack)
		things += thing
	var/list/first = LAZYACCESS(storage.grid_origins, things[1])
	if(!first || first[1] != 0 || first[2] != 4)
		return Fail("The first thing went to [json_encode(first)], not the top-left corner (0,4).")
	var/obj/item/ms13_grid_test/extra = allocate(/obj/item/ms13_grid_test)
	if(storage.can_insert(extra, messages = FALSE))
		return Fail("A full grid took another thing.")
	// Taking one out makes room exactly where it was.
	var/list/freed = LAZYACCESS(storage.grid_origins, things[5])
	things[5].forceMove(run_loc_floor_bottom_left)
	extra.forceMove(backpack)
	var/list/refilled = LAZYACCESS(storage.grid_origins, extra)
	if(!refilled || refilled[1] != freed[1] || refilled[2] != freed[2])
		return Fail("A thing didn't take the space another left.")
	// With no room, something forced in falls back out.
	var/obj/item/ms13_grid_test/pushed = allocate(/obj/item/ms13_grid_test)
	pushed.forceMove(backpack)
	if(LAZYACCESS(storage.grid_origins, pushed))
		return Fail("Something forced into a full grid was given room that wasn't there.")
	storage.grid_spill(pushed)
	if(pushed.loc == backpack)
		return Fail("Something forced into a full grid stayed there, taking no space.")

	// Two wide won't lie across a one-wide pocket, but turned it fits.
	var/obj/item/ms13_grid_test/pocket = allocate(/obj/item/ms13_grid_test)
	var/datum/storage/suit = pocket.create_storage(type = /datum/storage/ms13/suit)
	var/obj/item/ms13_grid_test/long = allocate(/obj/item/ms13_grid_test)
	long.grid_width = 64
	long.grid_height = 32
	if(!suit.can_insert(long, messages = FALSE) || long.grid_width != 32 || long.grid_height != 64)
		return Fail("A 2x1 thing wasn't turned to fit a 1x2 pocket.")

	// A click on the grid puts it there, or nowhere.
	var/obj/item/storage/ms13/other = allocate(/obj/item/storage/ms13)
	var/obj/item/ms13_grid_test/aimed = allocate(/obj/item/ms13_grid_test)
	other.atom_storage.grid_target = list(2, 0)
	aimed.forceMove(other)
	var/list/landed = LAZYACCESS(other.atom_storage.grid_origins, aimed)
	if(!landed || landed[1] != 2 || landed[2] != 0)
		return Fail("A thing put on the grid at 2,0 went to [json_encode(landed)].")
	other.atom_storage.grid_target = list(5, 5)
	if(other.atom_storage.can_insert(allocate(/obj/item/ms13_grid_test), messages = FALSE))
		return Fail("A 2x2 thing fitted hanging off the grid's corner.")
	other.atom_storage.grid_target = null

/obj/item/ms13_grid_test
	w_class = WEIGHT_CLASS_TINY
	grid_width = 64
	grid_height = 64
#endif
