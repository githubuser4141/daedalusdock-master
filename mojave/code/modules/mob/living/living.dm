/mob/living/Initialize(mapload)
	. = ..()
	update_nv()

/// Wielding procs
/mob/living
	var/tmp/last_wield_input = -1

/mob/living/proc/wield_active_hand()
	// Old saved preferences can bind both "wield" and "wield_item" to V.
	if(last_wield_input == world.time || incapacitated())
		return FALSE
	var/obj/item/active = get_active_held_item()
	if(istype(active))
		last_wield_input = world.time
		return active.wielded ? active.unwield(src) : active.wield(src)
	else
		to_chat(src, span_warning("You have nothing to wield!"))
		return FALSE

/mob/living/proc/wield_ui_update(active = FALSE)
	if(!hud_used)
		return FALSE
	hud_used.wield_active = active
	for(var/atom/movable/screen/wield/wield_button in hud_used.hotkeybuttons)
		wield_button.update_appearance()
	var/atom/movable/screen/inventory/hand_hud
	for(var/hand in hud_used.hand_slots)
		hand_hud = hud_used.hand_slots[hand]
		hand_hud?.update_appearance()
	return TRUE

/// Alter speech when a mob is buried in a grave
/mob/living/proc/handle_buried_speech(mob/living/carbon/speaker, list/speech_args)
	SIGNAL_HANDLER

	var/message = speech_args[SPEECH_MESSAGE]
	if(message[1] != "*")
		speech_args[SPEECH_MESSAGE] = stars(message, 40)
