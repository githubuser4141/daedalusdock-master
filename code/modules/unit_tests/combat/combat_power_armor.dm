/// Power armor components must fully absorb hits that don't have enough armor_penetration to
/// beat their subarmor rating, but let a sufficiently-penetrating hit through to the wearer -
/// see mojave/code/modules/mob/living/carbon/human/human_armor.dm.
/datum/unit_test/combat/power_armor_penetration
	name = "COMBAT: Power Armor Blocks Weak Hits, Lets Strong Ones Through"

/datum/unit_test/combat/power_armor_penetration/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/t51/suit = allocate(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/t51)

	victim.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING, TRUE, TRUE)
	TEST_ASSERT_EQUAL(victim.wear_suit, suit, "Power armor suit did not equip to the wearer.")

	var/obj/item/ms13/power_armor/chest_part = suit.module_armor[BODY_ZONE_CHEST]
	var/obj/item/ms13/power_armor/arm_part = suit.module_armor[BODY_ZONE_L_ARM]
	TEST_ASSERT(chest_part, "T-51 suit did not spawn with a chest component installed.")
	TEST_ASSERT(arm_part, "T-51 suit did not spawn with a left arm component installed.")

	var/chest_integrity_before = chest_part.atom_integrity

	victim.apply_damage(30, BRUTE, BODY_ZONE_CHEST, armor_penetration = 0)
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), 0, "Wearer took damage from a hit with 0 armor_penetration despite an intact chest component.")
	TEST_ASSERT(chest_part.atom_integrity < chest_integrity_before, "Chest component took no integrity damage from an absorbed hit.")

	victim.apply_damage(30, BRUTE, BODY_ZONE_L_ARM, armor_penetration = 9999)
	TEST_ASSERT(victim.getBruteLoss() > 0, "Wearer took no damage from a hit with enough armor_penetration to punch clean through an intact component.")
