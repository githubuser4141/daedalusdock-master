/// Wielding two-handed, both hands are in use.
/atom/movable/screen/inventory/hand/update_overlays()
	. = ..()
	var/ms13_art = icon == 'mojave/icons/hud/ms_ui_slots_hands.dmi'
	var/hand_state = "[held_index % 2 ? "l" : "r"]hand"
	if(ms13_art)
		. -= "hand_active"
		if(held_index == hud?.mymob?.active_hand_index)
			. += "[hand_state]_active"
	var/obj/item/held = hud?.mymob?.get_item_for_held_index(held_index)
	if(held?.wielded || istype(held, /obj/item/offhand))
		. += ms13_art ? "[hand_state]_wield" : "hand_active"
	// The active and wield art are whole tiles: an unusable hand's mark goes on top of them, not under.
	if(blocked_overlay in .)
		. -= blocked_overlay
		. += blocked_overlay

#ifdef UNIT_TESTS
/datum/unit_test/ms13_hand_slots
	name = "HUD: Hand Slots Show Their Art"

/datum/unit_test/ms13_hand_slots/Run()
	// As build_hand_slots() makes them, in the default UI style.
	for(var/side in list("l", "r"))
		var/atom/movable/screen/inventory/hand/hand = new
		hand.icon = ui_style2icon(null)
		hand.icon_state = "hand_[side]"
		hand.held_index = side == "l" ? 1 : 2
		hand.update_appearance()
		if(!(hand.icon_state in icon_states(hand.icon)))
			Fail("A hand slot shows \"[hand.icon_state]\", which [hand.icon] doesn't have.")
		qdel(hand)
#endif
