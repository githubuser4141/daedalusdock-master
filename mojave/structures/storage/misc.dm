/obj/structure/closet/ms13/wall
	name = "wasteland wall storage"
	desc = "Holds wastelands, while being attatched to a wall, presumably."
	pixel_y = 32
	density = FALSE
	hitted_sound = 'mojave/sound/ms13effects/impact/metal/metal_sheet_2.wav'

/obj/structure/closet/ms13/wall/Initialize()
	. = ..()
	AddElement(/datum/element/wall_mount)

/obj/structure/closet/ms13/wall/firstaid
	name = "emergency aid kit"
	desc = "A first aid kit, mounted to the wall. Commonly used for emergencies before the war."
	icon_state = "firstaid"
	anchored = TRUE
	anchorable = FALSE
	wall_mounted = TRUE
	max_mob_size = MOB_SIZE_TINY
	mob_storage_capacity = 1

/obj/structure/closet/ms13/wall/firstaid/update_icon()
	. = ..()
	layer = ON_EDGED_TURF_LAYER

////Sneaky Storage////

/obj/structure/ms13/storage/vent
	name = "vent"
	desc = "A vent used to move air to and from places."
	icon = 'mojave/icons/structure/storage.dmi'
	icon_state = "vent"
	flags_1 = INDESTRUCTIBLE | ACID_PROOF | FIRE_PROOF
	pixel_y = 24
	density = FALSE
	hitted_sound = 'mojave/sound/ms13effects/impact/metal/metal_sheet_2.wav'

/obj/structure/ms13/storage/vent/Initialize()
	. = ..()
	AddComponent(/datum/component/ms13_searchable, loot_table = /obj/effect/spawner/random/ms13/crafting/lowrandom, slots = 2, max_item_size = WEIGHT_CLASS_SMALL, max_total = 4, open_tool = TOOL_SCREWDRIVER, search_message = "You unscrew the vent cover.")
	if(prob(50))
		icon_state = "[initial(icon_state)]-damaged"


/obj/structure/ms13/storage/washingmachine
	name = "washing machine"
	desc = "An old washing machine, before the war this did all the washing for you! But now it washes nothing."
	icon = 'mojave/icons/structure/storage.dmi'
	icon_state = "normwasher"
	density = TRUE
	anchored = TRUE
	pixel_y = 12
	// storage_type left unset - /datum/storage/machine_large doesn't exist in DD, create_storage() is called in Initialize() instead
	var/closed = TRUE
	var/working = FALSE
	var/busy = FALSE
	var/datum/looping_sound/ms13/washing_machine/soundloop

/obj/structure/ms13/storage/washingmachine/working
	working = TRUE

/obj/structure/ms13/storage/washingmachine/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 20, max_specific_storage = WEIGHT_CLASS_BULKY, max_total_storage = 70)
	register_context()
	soundloop = new(src, FALSE)
	if(working)
		desc = "An old washing machine, before the war this did all the washing for you! Still a has a bit of life in it somehow."

/obj/structure/ms13/storage/washingmachine/examine(mob/user)
	. = ..()
	if(working)
		. += "<span class='notice'>Close the door and right click to wash the item inside. Ctrl-Click to open/close.</span>"

/obj/structure/ms13/storage/washingmachine/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	. = ..()

	if(isnull(held_item) && working)
		context[SCREENTIP_CONTEXT_CTRL_LMB] = "Open/Close"
		context[SCREENTIP_CONTEXT_RMB] = "Turn On"
		return CONTEXTUAL_SCREENTIP_SET

/obj/structure/ms13/storage/washingmachine/attackby(obj/item/I, mob/living/user, params)
	if(closed)
		to_chat(user, "<span class='danger'>[src] is closed.</span>")
		return
	else
		. = ..()

/obj/structure/ms13/storage/washingmachine/MouseDrop()
	if(closed && (usr.stat != DEAD))
		to_chat(usr, "<span class='danger'>[src] is closed.</span>")
		return COMPONENT_NO_MOUSEDROP
	else
		return . = ..()

/obj/structure/ms13/storage/washingmachine/attackby_secondary(obj/item/weapon, mob/user, params)
	attackby(weapon, user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/structure/ms13/storage/washingmachine/alt_click_on_secondary(mob/user)
	attack_hand(user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/structure/ms13/storage/washingmachine/AltClick(mob/user)
	attack_hand(user)
	return

/obj/structure/ms13/storage/washingmachine/update_overlays()
	. = ..()
	if(!busy)
		cut_overlays()
	if(busy && dir == SOUTH)
		add_overlay(image(icon, icon_state = "[initial(icon_state)]_on"))

/obj/structure/ms13/storage/washingmachine/CtrlClick(mob/living/user)
	if(user.stat == DEAD)
		return
	if(busy)
		to_chat(user, span_warning("[src] is currently in use."))
		return
	if(closed)
		if(do_after(user, time = 0.5 SECONDS, interaction_key = DOAFTER_SOURCE_DOORS))
			to_chat(user, span_notice("You open [src]."))
			playsound(src, 'mojave/sound/ms13effects/furniture/washer_open.ogg', 50)
			icon_state = "[initial(icon_state)]_open"
			closed = FALSE
	else
		if(do_after(user, time = 0.5 SECONDS, interaction_key = DOAFTER_SOURCE_DOORS))
			to_chat(user, span_notice("You close [src]."))
			playsound(src, 'mojave/sound/ms13effects/furniture/washer_close.ogg', 50)
			icon_state = "[initial(icon_state)]"
			closed = TRUE

/obj/structure/ms13/storage/washingmachine/attack_hand_secondary(mob/user, modifiers)
	if(user.stat == DEAD)
		return
	if(!working)
		to_chat(user, span_warning("You press the on button and nothing happens."))
		return SECONDARY_ATTACK_CONTINUE_CHAIN
	if(busy)
		to_chat(user, span_warning("[src] is currently in use."))
		return SECONDARY_ATTACK_CONTINUE_CHAIN
	if(!closed)
		to_chat(user, span_warning("Close the door first!"))
		return SECONDARY_ATTACK_CONTINUE_CHAIN
	busy = TRUE
	to_chat(user, span_notice("You press the on button and [src] kicks to life."))
	update_overlays()
	addtimer(CALLBACK(src, PROC_REF(washed)), 20 SECONDS, TIMER_UNIQUE)
	soundloop.start()
	START_PROCESSING(SSfastprocess, src)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/structure/ms13/storage/washingmachine/proc/washed()
	busy = FALSE
	soundloop.stop()
	update_overlays()
	src.visible_message(span_notice("The [src] finishes its washing cycle."))
	for(var/X in contents)
		var/atom/movable/AM = X
		if(AM.GetComponent(/datum/component/machine_washable))
			var/datum/component/machine_washable/machine_washable = AM.GetComponent(/datum/component/machine_washable)
			machine_washable.washed = TRUE
		AM.wash(CLEAN_WASH)

/obj/structure/ms13/storage/washingmachine/process(delta_time)
	if(!busy)
		animate(src, transform=matrix(), time=2)
		return PROCESS_KILL
	if(prob(50))
		Shake(rand(-1, 1), rand(0, 1), 1)

/obj/structure/ms13/storage/washingmachine/welder_act_secondary(mob/living/user, obj/item/I)
	if(!I.tool_start_check(user, amount=0))
		return TRUE
	if(I.use_tool(src, user, 30 SECONDS, volume=80))
		deconstruct(disassembled = TRUE)
		return TRUE

/obj/structure/ms13/storage/washingmachine/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		if(disassembled)
			new /obj/item/stack/sheet/ms13/rubber(loc, 1)
			new /obj/item/stack/sheet/ms13/scrap_electronics(loc, 2)
			new /obj/item/stack/sheet/ms13/scrap_alu(loc, 4)
			new /obj/item/stack/sheet/ms13/scrap(loc, 4)
		else
			new /obj/item/stack/sheet/ms13/scrap_alu(loc)
			new /obj/item/stack/sheet/ms13/scrap(loc)
			new /obj/item/stack/sheet/ms13/scrap_electronics(loc)
	qdel(src)

/obj/structure/ms13/storage/washingmachine/examine(mob/user)
	. = ..()
	. += deconstruction_hints(user)

/obj/structure/ms13/storage/washingmachine/proc/deconstruction_hints(mob/user)
	return span_notice("You could use a <b>welding tool</b> to take apart [src] for parts.")

/obj/structure/ms13/storage/washingmachine/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	. = ..()

	switch (held_item?.tool_behaviour)
		if (TOOL_WELDER)
			context[SCREENTIP_CONTEXT_RMB] = "Take apart"
			return CONTEXTUAL_SCREENTIP_SET

/obj/structure/ms13/storage/washingmachine/industrial
	name = "industrial washing machine"
	desc = "A large washing machine, for when you need to wash a lot of clothes! Unfortunately, it's been broken for a long time."
	icon_state = "industwasher"

/obj/structure/ms13/storage/washingmachine/industrial/Initialize(mapload)
	. = ..()
	if(working)
		desc = "A large washing machine, for when you need to wash a lot of clothes! Still a has a bit of life in it somehow."

/obj/structure/ms13/storage/washingmachine/industrial/working
	working = TRUE

/obj/structure/ms13/storage/washingmachine/industrial/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		if(disassembled)
			new /obj/item/stack/sheet/ms13/rubber(loc, 1)
			new /obj/item/stack/sheet/ms13/scrap_electronics(loc, 2)
			new /obj/item/stack/sheet/ms13/scrap_alu(loc, 6)
			new /obj/item/stack/sheet/ms13/scrap(loc, 6)
		else
			new /obj/item/stack/sheet/ms13/scrap_electronics(loc, 1)
			new /obj/item/stack/sheet/ms13/scrap_alu(loc, 2)
			new /obj/item/stack/sheet/ms13/scrap(loc, 2)
	qdel(src)

/obj/structure/ms13/pa_jack
	name = "power armor hoist"
	desc = "A heavy duty hoist used to stabilize and lift the incredibly hefty power armours in order to modify and repair them."
	icon = 'mojave/icons/objects/workbench.dmi'
	icon_state = "station"
	pixel_y = -16
	pixel_x = -16
	anchored = TRUE
	max_integrity = 500
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/obj_connected = null
	var/mount_busy = FALSE

/obj/structure/ms13/pa_jack/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(release_mount))

/obj/structure/ms13/pa_jack/Destroy()
	release_mount()
	return ..()

/obj/structure/ms13/pa_jack/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/ms13/scrap_steel/four(loc)
		new /obj/item/stack/sheet/ms13/scrap_parts/two(loc)
	qdel(src)

/obj/structure/ms13/pa_jack/wrench_act_secondary(mob/living/user, obj/item/tool)
	if(obj_connected)
		to_chat(user, span_warning("Disconnect the power armor before taking [src] apart."))
		return ITEM_INTERACT_BLOCKING
	to_chat(user, span_notice("You start taking [src] apart..."))
	if(tool.use_tool(src, user, 5 SECONDS, volume = 50))
		deconstruct(TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/structure/ms13/pa_jack/examine(mob/user)
	. = ..()
	. += "Alt+left click this to connect to power armor."

/obj/structure/ms13/pa_jack/AltClick(mob/user)
	return toggle_mount(user)

/obj/structure/ms13/pa_jack/proc/can_operate(mob/user, obj/machinery/ms13/terminal/terminal)
	if(QDELETED(src) || QDELETED(user) || !isturf(loc))
		return FALSE
	if(terminal)
		return !QDELETED(terminal) && terminal.terminal_available(user) && (src in terminal.workshop_benches())
	return user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY)

/obj/structure/ms13/pa_jack/proc/toggle_mount(mob/user, obj/machinery/ms13/terminal/terminal)
	if(mount_busy || !can_operate(user, terminal))
		return FALSE
	var/releasing = !!obj_connected
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/frame = obj_connected || (locate(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor) in loc)
	if(!frame || frame.loc != loc || (frame.link_to && frame.link_to != src))
		to_chat(user, span_warning("Place an unoccupied power armor frame on [src] first."))
		return FALSE
	mount_busy = TRUE
	playsound(src, 'mojave/sound/ms13effects/chain_jostle.ogg', 25, TRUE)
	var/finished = do_after(user, target = terminal || src, time = 4 SECONDS, interaction_key = DOAFTER_SOURCE_PAHOIST, extra_checks = CALLBACK(src, PROC_REF(can_operate), user, terminal))
	mount_busy = FALSE
	if(!finished || !can_operate(user, terminal) || QDELETED(frame) || frame.loc != loc || (releasing ? obj_connected != frame : obj_connected || frame.link_to))
		return FALSE
	if(releasing)
		release_mount()
		to_chat(user, span_notice("You release [frame] from [src]."))
	else
		obj_connected = frame
		frame.link_to = src
		RegisterSignal(frame, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING), PROC_REF(release_mount))
		add_overlay(icon(icon, "chains"))
		to_chat(user, span_notice("You secure [frame] to [src]."))
	return TRUE

/obj/structure/ms13/pa_jack/proc/release_mount(datum/source)
	SIGNAL_HANDLER
	if(obj_connected)
		UnregisterSignal(obj_connected, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))
		obj_connected.link_to = null
	obj_connected = null
	cut_overlays()

#ifdef UNIT_TESTS
/datum/unit_test/ms13_terminal_hoist
	name = "PA: Local And Terminal Hoist Controls"
	var/area/test_area
	var/old_requires_power
	var/mount_result

/datum/unit_test/ms13_terminal_hoist/Destroy()
	if(test_area)
		test_area.requires_power = old_requires_power
	return ..()

/datum/unit_test/ms13_terminal_hoist/proc/mount(obj/structure/ms13/pa_jack/hoist, mob/user, obj/machinery/ms13/terminal/terminal)
	mount_result = hoist.toggle_mount(user, terminal)

/datum/unit_test/ms13_terminal_hoist/Run()
	var/turf/site = get_step(get_step(run_loc_floor_bottom_left, NORTHEAST), NORTHEAST)
	test_area = get_area(site)
	old_requires_power = test_area.requires_power
	test_area.requires_power = FALSE
	var/obj/structure/ms13/pa_jack/hoist = allocate(/obj/structure/ms13/pa_jack, site)
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/frame = allocate(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor, site)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, get_step(site, SOUTH))
	if(!hoist.AltClick(user) || hoist.obj_connected != frame || frame.link_to != hoist)
		return Fail("A valid nearby user could not mount power armor with Alt-click.")
	frame.forceMove(get_step(site, EAST))
	if(hoist.obj_connected || frame.link_to)
		Fail("Moving mounted armor left a stale hoist link.")
	frame.forceMove(site)
	var/obj/machinery/ms13/terminal/wasteland/terminal = allocate(/obj/machinery/ms13/terminal/wasteland, get_step(site, WEST))
	user.forceMove(get_step(terminal, WEST))
	if(hoist.IsReachableBy(user) || !(hoist in terminal.workshop_benches()) || !hoist.toggle_mount(user, terminal))
		return Fail("The terminal could not operate its adjacent PA hoist.")
	if(!findtext(terminal.workshop_html(user), "Release armor") || !hoist.toggle_mount(user, terminal) || frame.link_to)
		Fail("The terminal did not show mounted armor or release it.")
	mount_result = null
	INVOKE_ASYNC(src, PROC_REF(mount), hoist, user, terminal)
	sleep(1)
	terminal.set_machine_stat(NOPOWER)
	sleep(5 SECONDS)
	if(mount_result || hoist.obj_connected || hoist.mount_busy)
		Fail("Power loss did not interrupt and release the hoist operation.")
	terminal.set_machine_stat(NONE)
	if(!hoist.toggle_mount(user, terminal))
		Fail("Restoring terminal power did not let the hoist work again.")
	qdel(frame)
	if(hoist.obj_connected)
		Fail("Deleting mounted armor left the hoist holding a deleted frame.")
#endif
