/obj/machinery/light/ms13
	name = "light fixture"
	icon = 'mojave/icons/structure/lighting.dmi'
	overlay_icon = 'mojave/icons/structure/lighting_overlay.dmi'
	base_state = "light_tube"
	icon_state = "light_tube"
	desc = "A lighting fixture."
	max_integrity = 100
	bulb_outer_range = 6
	bulb_power = 0.9
	bulb_colour = "#e9d8b2"
	light_type = /obj/item/light/ms13/tube
	fitting = "tube"
	start_with_cell = FALSE
	no_emergency = TRUE

/obj/machinery/light/ms13/deconstruct(disassembled = TRUE)
	if(flags_1 & NODECONSTRUCT_1)
		qdel(src)
		return
	// A destroyed fixture must not respawn as another attackable, empty fixture.
	if(disassembled)
		var/frame_type = fitting == "tube" ? /obj/item/wallframe/light_fixture/ms13 : /obj/item/wallframe/light_fixture/ms13/bulb
		var/obj/item/frame = new frame_type(drop_location())
		transfer_fingerprints_to(frame)
	else
		new /obj/item/stack/sheet/ms13/scrap_parts(drop_location())
		if(status != LIGHT_BROKEN)
			break_light_tube()
		if(status != LIGHT_EMPTY && removable_bulb)
			drop_light_tube()
	if(!QDELETED(cell))
		cell.forceMove(drop_location())
		cell = null
	qdel(src)

/obj/machinery/light/ms13/Initialize(mapload)
	. = ..()
	align_to_wall()

// A frame put up mid-round gets its direction after it's made.
/obj/machinery/light/ms13/setDir(newdir)
	. = ..()
	align_to_wall()

/obj/machinery/light/ms13/proc/align_to_wall() //shoutout to the shartcoder that coded in lights backwards
	switch(dir)
		if(SOUTH)
			pixel_x = 0
			pixel_y = -2
		if(NORTH)
			pixel_x = 0
			pixel_y = 35
		if(WEST)
			pixel_x = -16
			pixel_y = 16
		if(EAST)
			pixel_x = 16
			pixel_y = 16

/obj/machinery/light/ms13/broken
	icon_state = "light_tube-broken"
	status = LIGHT_BROKEN

/obj/machinery/light/ms13/built
	icon_state = "light_tube-empty"
	status = LIGHT_EMPTY

/obj/machinery/light/ms13/bulb
	base_state = "light_bulb"
	icon_state = "light_bulb"
	max_integrity = 35
	bulb_outer_range = 5
	bulb_power = 0.8
	bulb_colour = "#ddd2b9"
	light_type = /obj/item/light/ms13/bulb
	fitting = "bulb"

/obj/machinery/light/ms13/bulb/broken
	icon_state = "light_bulb-broken"
	status = LIGHT_BROKEN

/obj/machinery/light/ms13/bulb/built
	icon_state = "light_bulb-empty"
	status = LIGHT_EMPTY

/obj/machinery/light/ms13/bulb/industrial
	base_state = "light_bulb_indust"
	icon_state = "light_bulb_indust"
	max_integrity = 55
	bulb_outer_range = 5

/obj/machinery/light/ms13/bulb/industrial/broken
	icon_state = "light_bulb_indust-broken"
	status = LIGHT_BROKEN

/obj/machinery/light/ms13/bulb/industrial/built
	icon_state = "light_bulb_indust-empty"
	status = LIGHT_EMPTY

/// An empty MS13 light fixture, ready to screw to a wall. Fit a tube once it's up.
/obj/item/wallframe/light_fixture/ms13
	name = "light fixture"
	desc = "An empty tube light fixture. Screw it to a wall, then fit a light tube."
	result_path = /obj/machinery/light/ms13/built

/obj/item/wallframe/light_fixture/ms13/bulb
	name = "bulb fixture"
	desc = "An empty bulb light fixture. Screw it to a wall, then fit a light bulb."
	icon_state = "bulb-construct-item"
	result_path = /obj/machinery/light/ms13/bulb/built
