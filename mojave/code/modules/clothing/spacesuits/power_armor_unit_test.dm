/datum/unit_test/ms13_utility_pa
	name = "MS13 utility power armor: parts, sprites, helmet and worn icon"

/datum/unit_test/ms13_utility_pa/Run()
	check_set(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/utility, "utility")

/datum/unit_test/ms13_utility_pa/proc/check_set(suit_type, tag)
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/suit = allocate(suit_type)
	for(var/zone in suit.module_armor)
		var/obj/item/ms13/power_armor/part = suit.module_armor[zone]
		if(!istype(part))
			Fail("The [tag] suit spawned without its [zone] part.")
			continue
		if(!icon_exists(part.icon, part.icon_state))
			Fail("[part.type] has no inventory sprite '[part.icon_state]'.")
		if(part.icon_state_pa && !icon_exists(suit.worn_icon, part.icon_state_pa))
			Fail("[part.type] has no worn sprite '[part.icon_state_pa]'.")
	var/obj/item/clothing/head/helmet/space/hardsuit/ms13/power_armor/helmet = suit.helmet
	if(!istype(helmet))
		return Fail("The [tag] suit did not make its helmet.")
	for(var/light_on in 0 to 1)
		if(!icon_exists(helmet.worn_icon, "helmet[light_on]-[tag]"))
			Fail("Missing worn helmet sprite helmet[light_on]-[tag].")
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING, TRUE, TRUE, bypass_equip_delay_self = TRUE)
	suit.ToggleHelmet()
	if(wearer.wear_suit != suit || wearer.head != helmet)
		Fail("Putting on the [tag] suit did not equip the suit and its helmet.")
	var/mutable_appearance/worn = suit.build_worn_icon(wearer, default_layer = SUIT_LAYER, default_icon_file = suit.worn_icon)
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/bare = allocate(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor)
	var/mob/living/carbon/human/bare_wearer = allocate(/mob/living/carbon/human/consistent)
	bare_wearer.equip_to_slot_if_possible(bare, ITEM_SLOT_OCLOTHING, TRUE, TRUE, bypass_equip_delay_self = TRUE)
	var/mutable_appearance/bare_worn = bare.build_worn_icon(bare_wearer, default_layer = SUIT_LAYER, default_icon_file = bare.worn_icon)
	if(length(worn.overlays) - length(bare_worn.overlays) != 5)
		Fail("The worn [tag] suit showed [length(worn.overlays) - length(bare_worn.overlays)] of its 5 body parts over a bare frame.")
