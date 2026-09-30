/obj/item/mop/ms13
	name = "mop"
	desc = "An old mop. Essential for attempting to clean up the unspeakable."
	icon = 'mojave/icons/objects/tools/tools_world.dmi'
	icon_state = "mop"
	lefthand_file = 'mojave/icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'mojave/icons/mob/inhands/items_righthand.dmi'
	force = 10
	throwforce = 10
	throw_speed = 3
	throw_range = 7
	w_class = WEIGHT_CLASS_HUGE
	grid_width = 224
	///Maximum volume of reagents it can hold.
	max_reagent_volume = 15
	mopspeed = 3.5 SECONDS

/obj/item/mop/ms13/Initialize()
	. = ..()
	AddElement(/datum/element/world_icon, null, icon, 'mojave/icons/objects/tools/tools_inventory.dmi')

/obj/item/reagent_containers/glass/bucket/ms13
	name = "bucket"
	desc = "A metal bucket, great for transporting liquids such as water."
	icon = 'mojave/icons/objects/tools/tools_world.dmi'
	icon_state = "bucket"
	inhand_icon_state = "bucket"
	lefthand_file = 'mojave/icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'mojave/icons/mob/inhands/items_righthand.dmi'
	custom_materials = list(/datum/material/iron=200)
	w_class = WEIGHT_CLASS_NORMAL
	grid_width = 96
	grid_height = 64
	amount_per_transfer_from_this = 20
	volume = 150
	slot_flags = null

/obj/item/reagent_containers/glass/bucket/ms13/Initialize()
	. = ..()
	AddElement(/datum/element/world_icon, null, icon, 'mojave/icons/objects/tools/tools_inventory.dmi')

/// Fills from a tank that can be drawn from: fuel, water.
/obj/item/reagent_containers/glass/bucket/ms13/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/structure/reagent_dispensers) || !interacting_with.is_drainable())
		return ..()
	if(!interacting_with.reagents.total_volume)
		to_chat(user, span_warning("[interacting_with] is empty."))
		return ITEM_INTERACT_BLOCKING
	if(reagents.holder_full())
		to_chat(user, span_warning("[src] is full."))
		return ITEM_INTERACT_BLOCKING
	var/drawn = interacting_with.reagents.trans_to(src, amount_per_transfer_from_this, transfered_by = user)
	to_chat(user, span_notice("You fill [src] with [drawn] unit\s from [interacting_with]."))
	interacting_with.update_appearance()
	return ITEM_INTERACT_SUCCESS

#ifdef UNIT_TESTS
/datum/unit_test/ms13_bucket_draws_fuel
	name = "ITEMS: A Bucket Fills From A Fuel Tank"

/datum/unit_test/ms13_bucket_draws_fuel/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/reagent_dispensers/fueltank/tank = allocate(/obj/structure/reagent_dispensers/fueltank, get_step(user, EAST))
	var/obj/item/reagent_containers/glass/bucket/ms13/bucket = allocate(/obj/item/reagent_containers/glass/bucket/ms13)
	user.put_in_hands(bucket)
	bucket.melee_attack_chain(user, tank)
	if(!bucket.reagents.has_reagent(/datum/reagent/fuel, bucket.amount_per_transfer_from_this))
		Fail("A bucket used on a fuel tank didn't fill with fuel.")
#endif
