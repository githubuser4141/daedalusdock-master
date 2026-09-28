// The hands wear the player's UI style: its hand_l/hand_r, with the hand_active outline on the hand in use. (MS13's own
// hand art, ms_ui_slots_hands.dmi, is drawn for its own HUD layout, which never came across.)

/// Wielding two-handed, both hands are in use.
/atom/movable/screen/inventory/hand/update_overlays()
	. = ..()
	var/obj/item/held = hud?.mymob?.get_item_for_held_index(held_index)
	if(held?.wielded || istype(held, /obj/item/offhand))
		. += "hand_active"

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
