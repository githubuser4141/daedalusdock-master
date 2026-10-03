#ifndef MS13_BODYCAMS_INCLUDED
#define MS13_BODYCAMS_INCLUDED

GLOBAL_VAR_INIT(ms13_bodycam_serial, 0)

/obj/item/ms13/bodycam
	name = "body camera"
	desc = "A clip-on camera. Tap it on a terminal to pair it, then on a uniform, suit or helmet to attach it. Alt-right-click the clothing to remove it. Use in hand to toggle transmission."
	icon = 'icons/obj/machines/camera.dmi'
	icon_state = "cameracase"
	w_class = WEIGHT_CLASS_SMALL
	var/enabled = TRUE
	var/obj/item/clothing/mounted_on
	var/obj/machinery/camera/ms13_bodycam/feed

/obj/item/ms13/bodycam/Initialize(mapload)
	. = ..()
	feed = new(src)
	feed.c_tag = "Bodycam [++GLOB.ms13_bodycam_serial]"
	name = "body camera ([feed.c_tag])"

/obj/item/ms13/bodycam/Destroy()
	unmount()
	QDEL_NULL(feed)
	return ..()

/obj/item/ms13/bodycam/Moved(atom/old_loc, movement_dir, forced, list/old_locs)
	. = ..()
	if(mounted_on && loc != mounted_on)
		unmount()

/obj/item/ms13/bodycam/attack_self(mob/user)
	enabled = !enabled
	to_chat(user, span_notice("[src] is now [enabled ? "on" : "off"]."))

/obj/item/ms13/bodycam/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	if(istype(target, /obj/machinery/ms13/terminal))
		var/obj/machinery/ms13/terminal/terminal = target
		if(terminal.pair_bodycam(src, user))
			to_chat(user, span_notice("[feed.c_tag] paired with [terminal]."))
		return ITEM_INTERACT_SUCCESS
	else if(isclothing(target))
		attach_to(target, user)
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/item/ms13/bodycam/proc/attach_to(obj/item/clothing/clothing, mob/living/user)
	if(mounted_on || !(istype(clothing, /obj/item/clothing/under) || istype(clothing, /obj/item/clothing/suit) || istype(clothing, /obj/item/clothing/head)))
		return FALSE
	if(!user.canUseTopic(clothing, USE_CLOSE|USE_DEXTERITY) || !(src in user.held_items) || (locate(/obj/item/ms13/bodycam) in clothing))
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(src))
		return FALSE
	forceMove(clothing)
	mounted_on = clothing
	RegisterSignal(clothing, COMSIG_CLICK_ALT_SECONDARY, PROC_REF(remove_from_clothing))
	RegisterSignal(clothing, COMSIG_PARENT_EXAMINE, PROC_REF(examine_mount))
	RegisterSignal(clothing, COMSIG_PARENT_QDELETING, PROC_REF(mount_deleted))
	to_chat(user, span_notice("You clip [src] onto [clothing]."))
	return TRUE

/obj/item/ms13/bodycam/proc/unmount()
	if(mounted_on)
		UnregisterSignal(mounted_on, list(COMSIG_CLICK_ALT_SECONDARY, COMSIG_PARENT_EXAMINE, COMSIG_PARENT_QDELETING))
		mounted_on = null

/obj/item/ms13/bodycam/proc/remove_from_clothing(datum/source, mob/living/user)
	SIGNAL_HANDLER
	if(mounted_on && user.canUseTopic(mounted_on, USE_CLOSE|USE_DEXTERITY))
		forceMove(get_turf(mounted_on))
		user.put_in_hands(src)
	return COMPONENT_CANCEL_CLICK_ALT_SECONDARY

/obj/item/ms13/bodycam/proc/mount_deleted(datum/source)
	SIGNAL_HANDLER
	forceMove(get_turf(mounted_on))

/obj/item/ms13/bodycam/proc/examine_mount(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_notice("[feed.c_tag] is clipped here. Alt-right-click to remove it.")

/obj/machinery/camera/ms13_bodycam
	name = "bodycam transmitter"
	network = list()
	use_power = NO_POWER_USE
	internal_light = FALSE
	view_range = 5
	start_active = TRUE

/obj/machinery/camera/ms13_bodycam/can_use()
	var/obj/item/ms13/bodycam/camera = loc
	if(!istype(camera) || !camera.enabled || !camera.mounted_on)
		return FALSE
	var/mob/living/carbon/human/wearer = camera.mounted_on.loc
	return istype(wearer) && (camera.mounted_on in list(wearer.w_uniform, wearer.wear_suit, wearer.head)) && ..()

/obj/machinery/ms13/terminal
	var/list/paired_bodycams = list()
	var/obj/machinery/computer/security/ms13_bodycam_viewer/bodycam_viewer

/obj/machinery/ms13/terminal/Destroy()
	QDEL_NULL(bodycam_viewer)
	paired_bodycams = null
	return ..()

/obj/machinery/ms13/terminal/proc/pair_bodycam(obj/item/ms13/bodycam/camera, mob/living/user)
	if(QDELETED(camera) || !terminal_available(user) || !(camera in user.held_items))
		return FALSE
	paired_bodycams |= WEAKREF(camera)
	bodycam_viewer?.update_static_data_for_all()
	return TRUE

/obj/machinery/ms13/terminal/Topic(href, list/href_list)
	if(href_list["choice"] != "bodycams")
		return ..()
	if(!terminal_available(usr))
		return TRUE
	mode = 7
	ui_interact(usr)
	return TRUE

/// The existing CameraConsole embeds a ByondUi map; it never replaces client.eye.
/obj/machinery/computer/security/ms13_bodycam_viewer
	name = "terminal body cameras"
	use_power = NO_POWER_USE
	circuit = null

/obj/machinery/computer/security/ms13_bodycam_viewer/ui_status(mob/user)
	var/obj/machinery/ms13/terminal/terminal = loc
	return istype(terminal) && terminal.terminal_available(user) ? UI_INTERACTIVE : UI_CLOSE

/obj/machinery/computer/security/ms13_bodycam_viewer/get_available_cameras()
	. = list()
	var/obj/machinery/ms13/terminal/terminal = loc
	if(!istype(terminal))
		return
	for(var/datum/weakref/camera_ref as anything in terminal.paired_bodycams.Copy())
		var/obj/item/ms13/bodycam/camera = camera_ref.resolve()
		if(!camera?.feed)
			terminal.paired_bodycams -= camera_ref
			continue
		.[camera.feed.c_tag] = camera.feed

/obj/machinery/computer/security/ms13_bodycam_viewer/update_active_camera_screen()
	var/list/cameras = get_available_cameras()
	if(QDELETED(active_camera) || cameras[active_camera.c_tag] != active_camera)
		active_camera = null
		for(var/tag in cameras)
			var/obj/machinery/camera/candidate = cameras[tag]
			if(candidate.can_use())
				active_camera = candidate
				break
	if(!active_camera)
		cam_screen.show_camera_static()
		return
	if(!active_camera.can_use())
		cam_screen.show_camera_static()
		return
	// Nested wearable items need their turf as the view origin. Refresh even when stationary:
	// doors can open or shut without the wearer moving.
	var/list/visible_turfs = list()
	for(var/turf/tile in view(active_camera.view_range, get_turf(active_camera)))
		visible_turfs += tile
	if(!length(visible_turfs))
		cam_screen.show_camera_static()
		return
	var/list/bounds = get_bbox_of_atoms(visible_turfs)
	cam_screen.show_camera(visible_turfs, bounds[3] - bounds[1] + 1, bounds[4] - bounds[2] + 1)

#endif
