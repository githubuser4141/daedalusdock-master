/obj/item/gun
	/// A multiplier of the duration the recoil takes to go back to normal view, this is (recoil*recoil_backtime_multiplier)+1
	var/recoil_backtime_multiplier = 2
	/// This is how much deviation the gun recoil can have, recoil pushes the screen towards the reverse angle you shot + some deviation which this is the max.
	var/recoil_deviation = 22.5

// An ammo_stack (mojave/code/modules/projectiles/boxes_magazines/ammo_stack.dm) is itself a subtype of
// /obj/item/ammo_box/magazine (deliberately, to reuse magazine behavior) - which means DD's core
// /obj/item/gun/ballistic/attackby() (code/modules/projectiles/guns/ballistic.dm) matches it against
// its "insert this as a whole replacement magazine" branch before ever reaching the "load loose rounds
// from a box/casing" branch below it. With a magazine already loaded, that branch just refuses with
// "There is already a magazine" and the loose rounds never transfer in at all. Intercept ammo_stack
// specifically before calling the core proc so it goes through the same round-loading path a loose
// casing or ammo_box would.
/obj/item/gun/ballistic/attackby(obj/item/A, mob/user, params)
	if(magazine && istype(A, /obj/item/ammo_box/magazine/ammo_stack))
		var/num_loaded = magazine.attempt_load_round(A, user, params, TRUE)
		if(num_loaded)
			to_chat(user, span_notice("You load [num_loaded] [cartridge_wording]\s into [src]."))
			playsound(src, load_sound, load_sound_volume, load_sound_vary, SHORT_RANGE_SOUND_EXTRARANGE)
			bolt.loaded_ammo()
			A.update_appearance()
			update_appearance()
		return TRUE
	return ..()

/// A long gun slings over a suit that takes guns, however big it is. Suit storage otherwise stops at bulky, and MS13's
/// rifles and shotguns are huge, so every loadout that slung one lost it at spawn.
/datum/species/can_equip(obj/item/I, slot, disable_warning, mob/living/carbon/human/H, bypass_equip_delay_self = FALSE, ignore_equipped = FALSE)
	if(slot == ITEM_SLOT_SUITSTORE && istype(I, /obj/item/gun) && !(slot & no_equip_flags) && H.wear_suit && is_type_in_list(I, H.wear_suit.allowed))
		return (ignore_equipped || !H.get_item_by_slot(slot)) && !HAS_TRAIT(I, TRAIT_NODROP)
	return ..()

#ifdef UNIT_TESTS
/datum/unit_test/ms13_slung_long_guns
	name = "GUNS: Long Guns Sling Over Armor"

/datum/unit_test/ms13_slung_long_guns/Run()
	var/mob/living/carbon/human/consistent/trooper = allocate(/mob/living/carbon/human/consistent)
	trooper.equip_to_slot_or_del(allocate(/obj/item/clothing/suit/armor/ms13/ncr), ITEM_SLOT_OCLOTHING)
	var/obj/item/gun/ballistic/automatic/ms13/semi/service/rifle = allocate(/obj/item/gun/ballistic/automatic/ms13/semi/service)
	if(rifle.w_class <= WEIGHT_CLASS_BULKY)
		Fail("The service rifle isn't a long gun any more; pick another for this test.")
	if(!trooper.equip_to_slot_if_possible(rifle, ITEM_SLOT_SUITSTORE, disable_warning = TRUE))
		Fail("A service rifle wouldn't sling over NCR armor.")
	var/obj/item/gun/ballistic/automatic/ms13/semi/service/second = allocate(/obj/item/gun/ballistic/automatic/ms13/semi/service)
	if(trooper.equip_to_slot_if_possible(second, ITEM_SLOT_SUITSTORE, disable_warning = TRUE))
		Fail("Two long guns slung over one suit.")
#endif
