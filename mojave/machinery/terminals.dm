// This will allow you to show an icon in the browse window
// This is added to mob so that it can be used without a reference to the browser object
/mob/proc/browse_rsc_icon(icon, icon_state, dir = -1)

//// Actual Terminals ////
/obj/machinery/ms13/terminal
	name = "desktop terminal"
	desc = "A RobCo Industries terminal, widely available for commercial and private use before the war."
	icon = 'mojave/icons/structure/terminals.dmi'
	icon_state = "terminal"
	light_color = LIGHT_COLOR_GREEN
	pixel_y = 8
	layer = BELOW_OBJ_LAYER
	max_integrity = 500 // Hearty lil things.
	integrity_failure = 0
	idle_power_usage = 300
	active_power_usage = 300
	density = TRUE
	var/broken = FALSE // Used for pre-broken terminals
	var/active = TRUE // These should usually probably start off
	var/screen_icon = "terminal_screen" // The icon grabbed for the screen icon overlay
	var/termtag = "Home" // We use this for flavor.
	var/termnumber = null // Flavor
	var/mode = 0 // What page we're on. 0 is the main menu. 1 is the text editor. 2 is the document viewer. 3 is the optional utility page
	var/system = "ROBCO50" // Flavour text on the top indicating system type. Very awesome stuff.
	var/prog_notekeeper = TRUE // Almost all consoles have the word processor installed, but we can remove it if we want to
	var/remote_capability = FALSE // For special terminals that can activate certain things. Wall terminals / The quirky ones with antennas namely
	/// Camera network available from Utili-Dock; blank disables the camera menu.
	var/camera_network = ""
	var/obj/machinery/computer/security/ms13_terminal_viewer/camera_viewer
	var/rigged = FALSE // Ultra cursed var. If true, terminal explodes violently on certain interaction. Delightfully devilish.
	var/riggable = TRUE // To determine rigging eligibility
	var/datum/looping_sound/ms13/terminal/soundloop
	var/password_needed = FALSE
	var/password
	var/unlocked = FALSE
	var/joker_titles = list("Safe codes",
	"Stash location",
	"About the safe",
	"Weapons cache details",
	"Your payment",
	"Pickup location",
	"Something really important",
	"Looking for a good time",
	"Power Armor unlock code",
	"Bunker Location",
	"Free caps") // Suffer
	var/chosen_joker = ""
	//Used for the Background
	var/main_color = "#062113"
	//Used for the Text
	var/secondary_color = "#4aed92"

// Document variables
	var/doc_title_1 = "readme"
	var/doc_content_1 = ""
	var/doc_title_2 = ""
	var/doc_content_2 = ""
	var/doc_title_3 = ""
	var/doc_content_3 = ""
	var/doc_title_4 = ""
	var/doc_content_4 = ""
	var/doc_title_5 = ""
	var/doc_content_5 = ""
	var/loaded_title = ""
	var/loaded_content = ""

// Signal variables
	var/signal_title_1 = ""
	var/signal_id_1 = "null"
	var/signal_title_2 = ""
	var/signal_id_2 = "null"
	var/signal_title_3 = ""
	var/signal_id_3 = "null"
	var/signal_title_4 = ""
	var/signal_id_4 = "null"
	var/signal_title_5 = ""
	var/signal_id_5 = "null"
	var/signal_title_6 = ""
	var/signal_id_6 = "null"
	var/signal_title_single = "" //single use commands
	var/signal_id_single = "null"
	var/used = FALSE
	var/id = null // Currently selected ID

// Notekeeper vars
	var/notehtml = ""
	var/title = "ERROR 0xCM513F3D"
	var/note = "'Invalid Entry. Please enter your information.'"

/obj/machinery/ms13/terminal/Initialize(mapload)
	. = ..()
	register_context()
	chosen_joker = pick(joker_titles)
	termnumber = "No.[rand(360,620)]" // VERY unlikely to get two identical numbers.
	FXtoggle()
	if(!broken)
		write_documents()

/obj/machinery/ms13/terminal/screwdriver_act_secondary(mob/living/user, obj/item/weapon)
	if(flags_1&NODECONSTRUCT_1)
		return TRUE
	..()
	weapon.play_tool_sound(src)
	if(do_after(user, src, 30 SECONDS, interaction_key = DOAFTER_SOURCE_DECON))
		deconstruct(disassembled = TRUE)
		return TRUE

/obj/machinery/ms13/terminal/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		if(disassembled)
			new /obj/item/stack/sheet/ms13/scrap(loc, 3)
			new /obj/item/stack/sheet/ms13/scrap_parts(loc, 3)
			new /obj/item/stack/sheet/ms13/glass(loc, 2)
			new /obj/item/stack/sheet/ms13/scrap_electronics(loc, 4)
			new /obj/item/stack/sheet/ms13/scrap_copper(loc, 3)
			new /obj/item/stack/sheet/ms13/circuits(loc, 2)
			new /obj/item/ms13/component/vacuum_tube(loc)
		else
			new /obj/item/stack/sheet/ms13/scrap(loc)
			new /obj/item/stack/sheet/ms13/scrap_parts(loc)
			new /obj/item/stack/sheet/ms13/glass(loc)
			new /obj/item/stack/sheet/ms13/scrap_electronics(loc)
			new /obj/item/stack/sheet/ms13/scrap_copper(loc)
	qdel(src)

/obj/machinery/ms13/terminal/examine(mob/user)
	. = ..()
	. += deconstruction_hints(user)

/obj/machinery/ms13/terminal/proc/deconstruction_hints(mob/user)
	return span_notice("You could use a <b>screwdriver</b> to carefully take apart [src] for parts.")

/obj/machinery/ms13/terminal/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	. = ..()

	switch (held_item?.tool_behaviour)
		if (TOOL_SCREWDRIVER)
			context[SCREENTIP_CONTEXT_RMB] = "Disassemble"
			return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/ms13/terminal/proc/FXtoggle() // For overlays/sound
	cut_overlays()
	if(!broken && active && is_operational)
		add_overlay(image(icon, "[screen_icon]", ABOVE_OBJ_LAYER, dir))
		if(!soundloop)
			soundloop = new(src, TRUE)
	else
		cut_overlays()
		QDEL_NULL(soundloop)

/obj/machinery/ms13/terminal/take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	. = ..()
	if(prob(35))
		do_sparks(1, FALSE, src)
	if(atom_integrity < 250)
		broken = TRUE
		desc = "[initial(desc)] It looks broken."
		FXtoggle()
		update_icon_state()

/obj/machinery/ms13/terminal/proc/Boom()
	explosion(src,1,2,3,3,2)
	do_sparks(8, TRUE, src)
	broken = TRUE
	qdel(src)

/obj/machinery/ms13/terminal/Destroy()
	QDEL_NULL(camera_viewer)
	. = ..()
	QDEL_NULL(soundloop)

/obj/machinery/ms13/terminal/update_icon_state()
	. = ..()
	if(!active)
		cut_overlays()
	if(broken)
		icon_state = "[initial(icon_state)]_ruined"
	if(rigged)
		icon_state = "[initial(icon_state)]_rigged"

/obj/machinery/ms13/terminal/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(broken || !active || !is_operational)
		return

	if(!user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY))
		return

	if(password_needed && !unlocked)
		var/guess = tgui_input_text(user, "Enter the password", "Password")
		if(!guess || guess != password || !user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY) || broken || !active || !is_operational)
			return
		unlocked = TRUE
		to_chat(user, span_notice("You unlock the computer."))

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MS13Terminal", name)
		ui.open()
		ensure_camera_views()
		bodycam_viewer.cam_screen.render_to_tgui(user.client, ui.window)
		camera_viewer.cam_screen.render_to_tgui(user.client, ui.window)

/obj/machinery/ms13/terminal/Topic(href, href_list)
	if(..())
		return
	var/mob/living/U = usr
	if(!terminal_available(U))
		return
	if(findtext(href_list["choice"], "workshop") == 1)
		mode = 4
		var/obj/structure/bench = locate(href_list["bench"]) in workshop_benches()
		switch(href_list["choice"])
			if("workshop_queue")
				var/datum/crafting_recipe/recipe = locate(href_list["recipe"]) in GLOB.crafting_recipes
				queue_recipe(bench, recipe, U)
			if("workshop_start")
				start_workshop(U)
			if("workshop_stop")
				stop_workshop(U)
			if("workshop_hoist")
				if(istype(bench, /obj/structure/ms13/pa_jack))
					var/obj/structure/ms13/pa_jack/hoist = bench
					hoist.toggle_mount(U, src)
		ui_interact(U)
		return
	if(href_list["choice"] == "workbench")
		var/obj/structure/bench = locate(href_list["bench"]) in workshop_benches()
		open_workbench(bench, U)
		return
	if(href_list["choice"] == "cameras")
		open_cameras(U)
		return
	if(findtext(href_list["choice"], "signal_") == 1)
		activate_link(href_list["choice"], U)
		ui_interact(U)
		return

	if(!href_list["close"])
		add_fingerprint(U)
		U.set_machine(src)
		switch(href_list["choice"])

// Notekeeper
			if ("Title")
				var/t = tgui_input_text(U, "Please enter your entry title", "entry title", max_length = 25)
				if (in_range(src, U))
					if (mode == 1 && t)
						title = t

			if ("Contents")
				var/n = tgui_input_text(U, "Please enter your entry contents", "entry contents")
				if (in_range(src, U))
					if (mode == 1 && n)
						note = n
						notehtml = parsemarkdown(n, U)
				else
					return

			if ("Save")
				if (!in_range(src, U))
					return
				var/choice = tgui_alert(usr, "Please select data slot", buttons = list("Slot 1","Slot 2","Slot 3","Slot 4","Slot 5"))

				if(choice=="Slot 1")
					doc_title_1 = title
					doc_content_1 = note

				if(choice=="Slot 2")
					doc_title_2 = title
					doc_content_2 = note

				if(choice=="Slot 3")
					doc_title_3 = title
					doc_content_3 = note

				if(choice=="Slot 4")
					doc_title_4 = title
					doc_content_4 = note

				if(choice=="Slot 5")
					doc_title_5 = title
					doc_content_5 = note

// Files - We assign the datum information to the loaded_ variables so we don't need a different page for each document
			if ("doc_1")
				loaded_title = doc_title_1
				loaded_content = doc_content_1
				mode = 2

			if ("doc_2")
				loaded_title = doc_title_2
				loaded_content = doc_content_2
				mode = 2

			if ("doc_3")
				loaded_title = doc_title_3
				loaded_content = doc_content_3
				mode = 2

			if ("doc_4")
				loaded_title = doc_title_4
				loaded_content = doc_content_4
				mode = 2

			if ("doc_5")
				loaded_title = doc_title_5
				loaded_content = doc_content_5
				mode = 2

// Signal sender - Should have a few of these just in case.
// Joker - AKA character killer
			if("joker") // It's go time. Used for rigged terminals.
				if(!rigged)
					return
				var/file_in_memory = /datum/terminal/document/joker
				var/datum/terminal/document/J = new file_in_memory

				loaded_title = J.title
				loaded_content = J.content
				mode = 2
				addtimer(CALLBACK(src, PROC_REF(Boom)), 2 SECONDS)
				message_admins("A rigged terminal has been triggered. [ADMIN_JMP(src)].")

// Return
			if("Return")
				if(mode) // If we're not on the home page...
					mode = 0 // Take us there

// Menu functions
			if ("1") // Notepad
				mode = 1
			if ("3") // Signaller
				if(remote_capability)
					mode = 3

	updateUsrDialog()
	return

/obj/machinery/ms13/terminal/proc/write_documents()
	for(var/slot in 1 to 5)
		var/title_var = "doc_title_[slot]"
		var/document_type = text2path("/datum/terminal/document/[vars[title_var]]")
		if(!ispath(document_type, /datum/terminal/document))
			continue // Custom mapper titles and their contents are already complete.
		var/datum/terminal/document/document = new document_type
		vars[title_var] = document.title
		vars["doc_content_[slot]"] = document.content
		qdel(document)

#include "terminal_controls.dm"
#include "terminal_ui.dm"

//// Extra variants ////
/obj/machinery/ms13/terminal/pristine
	icon_state = "terminal_new" // Shouldn't really even be used. But i'll add it anyways.

/obj/machinery/ms13/terminal/rusty
	icon_state = "terminal_rusted"

/obj/machinery/ms13/terminal/vault
	name = "terminal stand"
	desc = "A multi-monitored heavy duty vault-tec terminal stand. Very uncommon to see anywhere else."
	icon_state = "terminal_vault"
	screen_icon = "terminal_vault_screen"
	termtag = "vault"
	system = "ROBCO38"
	light_color = LIGHT_COLOR_DARK_BLUE
	main_color = "#2b84bb"
	secondary_color = "#093b4d"

/obj/machinery/ms13/terminal/crafted
	name = "crafted terminal"
	desc = "A miracle of man- A terminal that has been locally produced by a wastelander, as can be clearly seen by the quality."
	icon_state = "terminal_handmade"
	screen_icon = "terminal_handmade_screen"
	termtag = "INVLD_Tt"
	system = "BOOTLEG"
	pixel_y = 12
	doc_title_1 = "corrupted" // this shit bootleg

//// Wall mounted terminals ////
/obj/machinery/ms13/terminal/wall
	name = "wall mounted terminal"
	desc = "A RobCo Industries terminal. This one is handily mounted to a wall for added convenience."
	icon_state = "wallterminal"
	base_icon_state = "wallterminal"
	screen_icon = "wallterminal_screen"
	termtag = "Utility"
	active = FALSE
	remote_capability = TRUE
	density = FALSE
	riggable = FALSE
	var/flippable = TRUE

/obj/machinery/ms13/terminal/wall/Initialize(mapload)
	. = ..()
	if(!flippable)
		active = TRUE
	AddElement(/datum/element/wall_mount)
	FXtoggle()

/obj/machinery/ms13/terminal/wall/AltClick(mob/user)
	. = ..()
	if(!user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY))
		return
	if(broken)
		return
	update_icon_state()
	if(!flippable)
		return
	if(!active)
		playsound(src, 'mojave/sound/ms13machines/terminals/keyboard_down.ogg', 50, FALSE)
		playsound(src, 'mojave/sound/ms13machines/terminals/poweron.ogg', 50, FALSE)
		active = TRUE
		icon_state = "[base_icon_state]_down"
	else
		playsound(src, 'mojave/sound/ms13machines/terminals/keyboard_up.ogg', 50, FALSE)
		playsound(src, 'mojave/sound/ms13machines/terminals/poweroff.ogg', 50, FALSE)
		active = FALSE
		icon_state = "[base_icon_state]"
	FXtoggle()

/obj/machinery/ms13/terminal/wall/examine(mob/user)
	. = ..()
	if(flippable)
		. += span_notice("You can flip [src] up and down using <b>ALT+CLICK.</b>")

/obj/machinery/ms13/terminal/wall/pristine
	icon_state = "wallterminal_new"
	base_icon_state = "wallterminal_new"

/obj/machinery/ms13/terminal/wall/rust
	icon_state = "wallterminal_rusted"
	base_icon_state = "wallterminal_rusted"

/obj/machinery/ms13/terminal/wall/classic
	icon_state = "terminal_classic"
	base_icon_state = "terminal_classic"
	screen_icon = "terminal_classic_screen"
	light_color = LIGHT_COLOR_DARK_BLUE
	main_color = "#1f7cb6"
	secondary_color = "#012c3b"
	flippable = FALSE
	system = "APRICOT"

//// Unique Computers ////

/obj/machinery/ms13/terminal/pristine/mayor

/obj/machinery/ms13/terminal/pristine/mayor/Initialize(mapload)
	. = ..()
	password = "[GLOB.fscpassword]"

//// Wasteland Computers ////
/// Potentially controversial. These are computers that should be primarily scatterd through the wastland. They have a high chance of being inoperable roundstart, and a VERY VERY SLIGHT chance to be visibly rigged to explode. ///

/obj/machinery/ms13/terminal/wasteland

/obj/machinery/ms13/terminal/wasteland/Initialize(mapload)
/*	if(prob(65))
		broken = TRUE
		riggable = FALSE
		update_icon_state() */
	if(!riggable)
		return
	else if(prob(1)) // Ultra rare pre-rigged terminals. Stay woke out there.
		rigged = TRUE
	. = ..()
