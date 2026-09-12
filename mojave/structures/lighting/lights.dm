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
	var/obj/structure/light_construct/new_light = null
	switch(fitting)
		if("tube")
			new_light = new /obj/machinery/light/ms13/built(loc)
			new_light.pixel_x = pixel_x
			new_light.pixel_y = pixel_y

		if("bulb")
			new_light = new /obj/machinery/light/ms13/bulb/built(loc)
			new_light.pixel_x = pixel_x
			new_light.pixel_y = pixel_y

	new_light.setDir(dir)
	if(!disassembled)
		new_light.take_damage(new_light.max_integrity * 0.5, sound_effect=FALSE)
		if(status != LIGHT_BROKEN)
			break_light_tube()
		if(status != LIGHT_EMPTY)
			drop_light_tube()
	transfer_fingerprints_to(new_light)
	qdel(src)

/obj/machinery/light/ms13/Initialize(mapload) //shoutout to the shartcoder that coded in lights backwards
	. = ..()
	// MOJAVE EDIT: WEST/EAST used to also push pixel_y by 16 alongside pixel_x, on top of the sprite's
	// own facing offset - shoving the light diagonally out past the edge of its own tile instead of
	// flush against the wall like the NORTH/SOUTH cases (single-axis, matches core DD's own
	// /obj/machinery/light/setDir() in code/modules/power/lighting/light.dm). Made WEST/EAST
	// single-axis too.
	switch(dir)
		if(SOUTH)
			pixel_x = 0
			pixel_y = -2
		if(NORTH)
			pixel_x = 0
			pixel_y = 2
		if(WEST)
			pixel_x = -16
			pixel_y = 0
		if(EAST)
			pixel_x = 16
			pixel_y = 0

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
