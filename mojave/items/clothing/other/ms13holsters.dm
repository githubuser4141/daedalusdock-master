/obj/item/storage/belt/holster/ms13 // These are pretty busted. Don't use.
	name = "holster"
	desc = "A holster able to carry revolvers and other handguns along with some ammo."
	icon = 'mojave/icons/objects/clothing/clothing_world/belts_world.dmi'
	worn_icon = 'mojave/icons/mob/clothing/belt.dmi'
	icon_state = "cowboy"
	worn_icon_state = "cowboy"
	storage_type = /datum/storage/ms13/holster

/obj/item/storage/belt/holster/ms13/Initialize()
	. = ..()
	AddElement(/datum/element/world_icon, null, icon, 'mojave/icons/objects/clothing/clothing_inventory/belts_inventory.dmi')

/obj/item/storage/belt/holster/ms13/equipped(mob/user, slot)
	. = ..()

/datum/storage/ms13/holster
	max_slots = 3 // This thing is super busted. See you on the other side.
	max_specific_storage = WEIGHT_CLASS_NORMAL
	set_holdable(can_hold_list = list(
		/obj/item/ammo_box/magazine/ms13/m45,
		/obj/item/ammo_box/magazine/ms13/deagle,
		/obj/item/ammo_box/magazine/ms13/m10mm,
		/obj/item/ammo_box/magazine/ms13/m9mm,
		/obj/item/ammo_box/magazine/ms13/m22,
		/obj/item/ammo_box/magazine/ms13/m12mm,
		/obj/item/ammo_box/ms13/cpistol,
		/obj/item/gun/ballistic/revolver
		))

/*
		/obj/item/gun/ballistic/automatic/pistol,
		/obj/item/ammo_box/ms13/rev4570, // Revolver speedloaders.
		/obj/item/ammo_box/ms13/rev44,
		/obj/item/ammo_box/ms13/rev357,
		/obj/item/ammo_box/ms13/rev556,
		/obj/item/ammo_box/ms13/rev10mm, // Pistol Mags
*/

/obj/item/storage/belt/holster/ms13/sheriff/full_44/PopulateContents()
	var/static/items_inside = list(
		/obj/item/gun/ballistic/revolver/ms13/rev44 = 1,
		/obj/item/ammo_box/ms13/rev44 = 2)
	generate_items_inside(items_inside,src)
/obj/item/storage/belt/holster/ms13/sheriff/full_357/PopulateContents()
	var/static/items_inside = list(
		/obj/item/gun/ballistic/revolver/ms13/rev357 = 1,
		/obj/item/ammo_box/ms13/rev357 = 2)
	generate_items_inside(items_inside,src)

/obj/item/storage/belt/holster/ms13/sheriff/full_357_lucky/PopulateContents()
	var/static/items_inside = list(
		/obj/item/gun/ballistic/revolver/ms13/rev357/lucky = 1,
		/obj/item/ammo_box/ms13/rev357 = 2)
	generate_items_inside(items_inside,src)
