/datum/job/ms13/town_drought/baron
	title = "The Baron"
	total_positions = 1
	spawn_positions = 1
	supervisors = "No one but yourself."
	description = "You are the supreme leader of the Barony. Enact your will as you see fit and navigate the Barony through these changing times however you like. Remember, you answer to no one but yourself!"
	forbid = ""
	enforce = ""

	outfit = /datum/outfit/job/ms13/town_drought/baron

	//display_order = JOB_DISPLAY_ORDER_MS13_BARON

/datum/outfit/job/ms13/town_drought/baron
	name = "_The Baron"
	jobtype = /datum/job/ms13/town_drought/baron

	id =         /obj/item/card/id/ms13/drought_baron
	head =		 /obj/item/clothing/head/helmet/ms13/metal/baron
	neck = 		 /obj/item/clothing/neck/cloak/ms13/baron
	uniform =    /obj/item/clothing/under/ms13/wasteland/baron
	shoes =      /obj/item/clothing/shoes/ms13/military/diesel
	suit_store = /obj/item/gun/ballistic/automatic/pistol/ms13/pistol45
	belt =		 /obj/item/knife/ms13/switchblade
	r_pocket =   /obj/item/ammo_box/magazine/ms13/m45
	r_hand =     /obj/item/radio/ms13/broadcast
	l_pocket =   /obj/item/stack/ms13/currency/cap/baron
	back =       null

/datum/outfit/job/ms13/town_drought/baron/pre_equip(mob/living/carbon/human/H)
	..()

/datum/outfit/job/ms13/town_drought/baron/pre_equip(mob/living/carbon/human/H)
	..()
	if(H.gender != MALE)
		H.gender = MALE
		H.physique = MALE
		// AI EDIT: disabled, not fixed - random_unique_raider_name() genuinely doesn't exist anywhere, not even in
		// MS's own live source (checked their current repo directly); GLOB.raider_names (mojave/code/_globalvars/
		// lists/names.dm) exists but nothing ever reads from it. Left H's original name alone rather than rename
		// with a nonexistent generator - only the forced gender/physique above still applies.
