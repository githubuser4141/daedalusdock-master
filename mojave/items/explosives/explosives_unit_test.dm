/datum/unit_test/ms13_shaped_charge_payloads
	name = "MOJAVE SUN: Shaped Charge Payloads"

/datum/unit_test/ms13_shaped_charge_payloads/Run()
	var/obj/item/grenade/c4/ms13/shaped/crude = new
	crude.craftsmanship = 0.8
	new /obj/item/stack/sheet/ms13/scrap_copper(crude)
	new /obj/item/ms13/component/gunpowder(crude)
	crude.CheckParts()
	var/obj/item/grenade/c4/ms13/shaped/precision = new
	precision.craftsmanship = 1.15
	new /obj/item/stack/sheet/ms13/refined_copper(precision)
	new /obj/item/ms13/component/gunpowder/hq(precision)
	precision.CheckParts()
	TEST_ASSERT(precision.jet_damage > crude.jet_damage, "Quality powder and precision construction did not improve shaped-charge damage.")
	TEST_ASSERT(precision.jet_penetration > crude.jet_penetration, "The refined liner did not improve shaped-charge penetration.")
	TEST_ASSERT(precision.jet_range > crude.jet_range, "The refined liner did not improve shaped-charge coherence.")
	TEST_ASSERT_EQUAL(precision.liner_description, "refined copper", "The charge did not derive its liner from the stack's material datum.")
	var/obj/projectile/bullet/ms13/shaped_charge_jet/test_jet = new
	TEST_ASSERT(test_jet.armor_penetration >= 100 && test_jet.breakup_count > 0 && !test_jet.canFragment && !test_jet.canRicochet, "The shaped-charge jet lacks penetration or controlled breakup tuning.")
	TEST_ASSERT(test_jet.bulletTipType, "The shaped-charge jet has no bullet_math tip profile.")
	TEST_ASSERT_EQUAL(test_jet.bulletArmorType, PUNCTURE, "The shaped-charge jet is not using bullet_math's puncture hardness model.")
	qdel(test_jet)
	qdel(crude)
	qdel(precision)
