#define WALL_MATS_SCRAP list(/obj/item/stack/sheet/ms13/scrap = 3, /obj/item/stack/sheet/ms13/scrap_steel = 2)
#define WALL_MATS_METAL list(/obj/item/stack/sheet/ms13/scrap = 2, /obj/item/stack/sheet/ms13/scrap_steel = 4)
#define WALL_MATS_STEEL list(/obj/item/stack/sheet/ms13/scrap_parts = 2, /obj/item/stack/sheet/ms13/scrap_steel = 6)
#define WALL_MATS_WOOD  list(/obj/item/stack/sheet/ms13/scrap_parts = 1, /obj/item/stack/sheet/ms13/wood/scrap_wood = 5)
#define WALL_MATS_STEEL_REINF list(/obj/item/stack/sheet/ms13/scrap_parts = 2, /obj/item/stack/sheet/ms13/refined_steel = 3, /obj/item/stack/sheet/ms13/scrap_steel = 3)
#define WALL_MATS_SUPER_REINF list(/obj/item/stack/sheet/ms13/scrap_parts = 3, /obj/item/stack/sheet/ms13/refined_steel = 6, /obj/item/stack/sheet/ms13/scrap_steel = 6)

TYPEINFO_DEF(/turf/closed/wall/ms13)
	default_armor = list(BLUNT = 50, PUNCTURE = 5, SLASH = 80, LASER = 50, ENERGY = 25, BOMB = 25, BIO = 100, FIRE = 25, ACID = 50)

/turf/closed/wall/ms13
	bullet_damage_ratio = 0.7
	name = "base class wall"
	desc = "God has abandoned us"
	icon_state = "wall-0"
	base_icon_state = "wall"
	smoothing_flags = SMOOTH_BITMASK
	// AI EDIT: the whole tile is clickable, not just opaque icon pixels - walls were falling out of the
	// right-click menu so they could not be VV'd despite being shootable.
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	smoothing_groups = SMOOTH_GROUP_MS13_WALL
	// low walls and windows already list SMOOTH_GROUP_MS13_WALL in their own canSmoothWith, expecting walls
	// to smooth toward them back - without this, that's one-directional, producing mismatched junctions.
	canSmoothWith = SMOOTH_GROUP_MS13_LOW_WALL + SMOOTH_GROUP_MS13_WINDOW + SMOOTH_GROUP_MS13_WALL + SMOOTH_GROUP_SHUTTERS_BLASTDOORS
	var/weldable = FALSE
	/// Sheet type -> amount it drops when it comes down.
	var/list/sheet_type
	max_integrity = 500
	damage_deflection = 20
	sheet_type = WALL_MATS_SCRAP

/turf/closed/wall/ms13/try_decon(obj/item/I, mob/user, turf/T)
	if(!weldable)
		return
	else
		. = ..()

/turf/closed/wall/ms13/ex_act()
	return

// MS13 walls set their own icon/name/desc per subtype and never touch DD's paint/materials system -
// set_materials() (called unconditionally from the parent Initialize()) would otherwise overwrite that
// custom icon with plating_material's (default: iron) DD wall_icon.
/turf/closed/wall/ms13/set_materials(plating_mat, reinf_mat, update_appearance = TRUE)
	return

/turf/closed/wall/ms13/deconstruction_hints()
	return

// MS13 walls come down as their own sheet_type, and never leave a girder.
/turf/closed/wall/ms13/break_wall(drop_mats = TRUE)
	if(drop_mats)
		drop_materials_used()

/turf/closed/wall/ms13/devastate_wall()
	drop_materials_used()

/turf/closed/wall/ms13/drop_materials_used(drop_reinf = FALSE)
	for(var/sheet in sheet_type)
		new sheet(src, sheet_type[sheet])

TYPEINFO_DEF(/turf/closed/wall/ms13/metal) // Thin iron sheet wall
	default_armor = list(BLUNT = 50, PUNCTURE = 10, SLASH = 80, LASER = 50, ENERGY = 25, BOMB = 25, BIO = 100, FIRE = 25, ACID = 50)

/turf/closed/wall/ms13/metal
	bullet_damage_ratio = 1
	name = "metal wall"
	desc = "A sturdy metal wall."
	icon = 'mojave/icons/turf/walls/metal.dmi'
	frill_icon = 'mojave/icons/turf/walls/metal_frill.dmi'
	max_integrity = 500
	damage_deflection = 25
	sheet_type = WALL_MATS_METAL

/turf/closed/wall/ms13/metal/rust
	bullet_damage_ratio = 1
	name = "rusted metal wall"
	desc = "A metal wall rusted with age."
	icon = 'mojave/icons/turf/walls/rustmetal.dmi'
	frill_icon = 'mojave/icons/turf/walls/rustmetal_frill.dmi'
	max_integrity = 300

TYPEINFO_DEF(/turf/closed/wall/ms13/wood)
	default_armor = list(BLUNT = 50, PUNCTURE = 10, SLASH = 80, LASER = 35, ENERGY = 25, BOMB = 10, BIO = 100, FIRE = 10, ACID = 50)

/turf/closed/wall/ms13/wood
	bullet_damage_ratio = 1
	name = "log wall"
	desc = "A rustic log wall."
	icon = 'mojave/icons/turf/walls/wood.dmi'
	frill_icon = 'mojave/icons/turf/walls/wood_frill.dmi'
	max_integrity = 200
	damage_deflection = 20
	sheet_type = WALL_MATS_WOOD

TYPEINFO_DEF(/turf/closed/wall/ms13/wood/fresh)
	default_armor = list(BLUNT = 50, PUNCTURE = 15, SLASH = 80, LASER = 50, ENERGY = 25, BOMB = 25, BIO = 100, FIRE = 25, ACID = 50)

/turf/closed/wall/ms13/wood/fresh
	name = "fresh log wall"
	desc = "A somewhat freshly made log wall."
	icon = 'mojave/icons/turf/walls/woodfresh.dmi'
	frill_icon = 'mojave/icons/turf/walls/woodfresh_frill.dmi'
	max_integrity = 500
	bullet_damage_ratio = 0.5 // its soft wood?

/turf/closed/wall/ms13/scrap
	bullet_damage_ratio = 1
	name = "scrap wall"
	desc = "A wall made of scrap metal."
	icon = 'mojave/icons/turf/walls/scrap.dmi'
	frill_icon = 'mojave/icons/turf/walls/scrap_frill.dmi'
	max_integrity = 400
	sheet_type = WALL_MATS_SCRAP

/turf/closed/wall/ms13/scrap/white
	icon = 'mojave/icons/turf/walls/scrapwhite.dmi'
	frill_icon = 'mojave/icons/turf/walls/scrapwhite_frill.dmi'

/turf/closed/wall/ms13/scrap/red
	icon = 'mojave/icons/turf/walls/scrapred.dmi'
	frill_icon = 'mojave/icons/turf/walls/scrapred_frill.dmi'

/turf/closed/wall/ms13/scrap/blue
	icon = 'mojave/icons/turf/walls/scrapblue.dmi'
	frill_icon = 'mojave/icons/turf/walls/scrapblue_frill.dmi'

TYPEINFO_DEF(/turf/closed/wall/ms13/adobe)
	default_armor = list(BLUNT = 50, PUNCTURE = 50, SLASH = 75, LASER = 75, ENERGY = 25, BOMB = 15, BIO = 100, FIRE = 50, ACID = 50)

/turf/closed/wall/ms13/adobe
	bullet_damage_ratio = 0.8
	name = "adobe wall"
	desc = ""
	icon = 'mojave/icons/turf/walls/drought/adobe.dmi'
	frill_icon = 'mojave/icons/turf/walls/drought/adobe_frill.dmi'
	max_integrity = 400
	damage_deflection = 15
	bullet_damage_ratio = 0.9
	sheet_type = list(/obj/item/stack/sheet/ms13/ceramic = 1)

/turf/closed/wall/ms13/siding
	bullet_damage_ratio = 1
	name = "sided wall"
	desc = ""
	icon = 'mojave/icons/turf/walls/drought/siding.dmi'
	frill_icon = 'mojave/icons/turf/walls/drought/siding_frill.dmi'
	sheet_type = WALL_MATS_WOOD

/turf/closed/wall/ms13/siding/Initialize()
	. = ..()
	var/state = rand(1,4)
	switch(state)
		if(1)
			icon = 'mojave/icons/turf/walls/drought/siding_1.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_1_frill.dmi'
		if(2)
			icon = 'mojave/icons/turf/walls/drought/siding_2.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_2_frill.dmi'
		if(3)
			icon = 'mojave/icons/turf/walls/drought/siding_3.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_3_frill.dmi'
		else
			return

/turf/closed/wall/ms13/siding/blue
	name = "sided wall"
	desc = ""
	icon = 'mojave/icons/turf/walls/drought/siding_blue.dmi'
	frill_icon = 'mojave/icons/turf/walls/drought/siding_blue_frill.dmi'

/turf/closed/wall/ms13/siding/blue/Initialize()
	. = ..()
	var/state = rand(1,4) // it has to be like this instead of the usual return because otherwise it'll roll and do an uncoloured siding wall instead
	switch(state)
		if(1)
			icon = 'mojave/icons/turf/walls/drought/siding_blue_1.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_blue_1_frill.dmi'
		if(2)
			icon = 'mojave/icons/turf/walls/drought/siding_blue_2.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_blue_2_frill.dmi'
		if(3)
			icon = 'mojave/icons/turf/walls/drought/siding_blue_3.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_blue_3_frill.dmi'
		if(4)
			icon = 'mojave/icons/turf/walls/drought/siding_blue.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_blue_frill.dmi'

/turf/closed/wall/ms13/siding/green
	name = "sided wall"
	desc = ""
	icon = 'mojave/icons/turf/walls/drought/siding_green.dmi'
	frill_icon = 'mojave/icons/turf/walls/drought/siding_green_frill.dmi'

/turf/closed/wall/ms13/siding/green/Initialize()
	. = ..()
	var/state = rand(1,4) // it has to be like this instead of the usual return because otherwise it'll roll and do an uncoloured siding wall instead
	switch(state)
		if(1)
			icon = 'mojave/icons/turf/walls/drought/siding_green_1.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_green_1_frill.dmi'
		if(2)
			icon = 'mojave/icons/turf/walls/drought/siding_green_2.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_green_2_frill.dmi'
		if(3)
			icon = 'mojave/icons/turf/walls/drought/siding_green_3.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_green_3_frill.dmi'
		if(4)
			icon = 'mojave/icons/turf/walls/drought/siding_green.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_green_frill.dmi'

/turf/closed/wall/ms13/siding/red
	name = "sided wall"
	desc = ""
	icon = 'mojave/icons/turf/walls/drought/siding_red.dmi'
	frill_icon = 'mojave/icons/turf/walls/drought/siding_red_frill.dmi'

/turf/closed/wall/ms13/siding/red/Initialize()
	. = ..()
	var/state = rand(1,4) // it has to be like this instead of the usual return because otherwise it'll roll and do an uncoloured siding wall instead
	switch(state)
		if(1)
			icon = 'mojave/icons/turf/walls/drought/siding_red_1.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_red_1_frill.dmi'
		if(2)
			icon = 'mojave/icons/turf/walls/drought/siding_red_2.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_red_2_frill.dmi'
		if(3)
			icon = 'mojave/icons/turf/walls/drought/siding_red_3.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_red_3_frill.dmi'
		if(4)
			icon = 'mojave/icons/turf/walls/drought/siding_red.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/siding_red_frill.dmi'

TYPEINFO_DEF(/turf/closed/wall/ms13/prison)
	default_armor = list(BLUNT = 60, PUNCTURE = 40, SLASH = 80, LASER = 75, ENERGY = 25, BOMB = 50, BIO = 100, FIRE = 50, ACID = 75)

/turf/closed/wall/ms13/prison
	bullet_damage_ratio = 0.5
	name = "prison wall"
	desc = ""
	icon = 'mojave/icons/turf/walls/drought/prison.dmi'
	frill_icon = 'mojave/icons/turf/walls/drought/prison_frill.dmi'
	max_integrity = 800
	damage_deflection = 30
	bullet_damage_ratio = 0.5 // its sturdy
	sheet_type = WALL_MATS_STEEL

/turf/closed/wall/ms13/prison/Initialize()
	. = ..()
	var/state = rand(1,4)
	switch(state)
		if(1)
			icon = 'mojave/icons/turf/walls/drought/prison_1.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/prison_1_frill.dmi'
		if(2)
			icon = 'mojave/icons/turf/walls/drought/prison_2.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/prison_2_frill.dmi'
		if(3)
			icon = 'mojave/icons/turf/walls/drought/prison_3.dmi'
			frill_icon = 'mojave/icons/turf/walls/drought/prison_3_frill.dmi'
		else
			return

TYPEINFO_DEF(/turf/closed/wall/ms13/brick)
	default_armor = list(BLUNT = 50, PUNCTURE = 25, SLASH = 80, LASER = 75, ENERGY = 25, BOMB = 25, BIO = 100, FIRE = 25, ACID = 50)

/turf/closed/wall/ms13/brick
	bullet_damage_ratio = 0.7
	name = "brick wall"
	desc = "A brick wall. Try banging your head against this."
	icon = 'mojave/icons/turf/walls/brick.dmi'
	frill_icon = 'mojave/icons/turf/walls/brick_frill.dmi'
	max_integrity = 800
	damage_deflection = 15
	bullet_damage_ratio = 0.9
	sheet_type = list(/obj/item/stack/sheet/ms13/ceramic = 4)

/turf/closed/wall/ms13/brick/alt
	icon = 'mojave/icons/turf/walls/brickalt.dmi'
	frill_icon = 'mojave/icons/turf/walls/brickalt_frill.dmi'

/turf/closed/wall/ms13/brick/gray
	icon = 'mojave/icons/turf/walls/brickgray.dmi'
	frill_icon = 'mojave/icons/turf/walls/brickgray_frill.dmi'

TYPEINFO_DEF(/turf/closed/wall/ms13/metal/reinforced)
	default_armor = list(BLUNT = 75, PUNCTURE = 75, SLASH = 80, LASER = 75, ENERGY = 25, BOMB = 50, BIO = 100, FIRE = 50, ACID = 75)

/turf/closed/wall/ms13/metal/reinforced
	bullet_damage_ratio = 0.2
	name = "reinforced metal wall"
	desc = "A heavy duty, reinforced metal wall."
	icon = 'mojave/icons/turf/walls/rmetal.dmi'
	frill_icon = 'mojave/icons/turf/walls/rmetal_frill.dmi'
	max_integrity = 2000
	damage_deflection = 40
	sheet_type = WALL_MATS_STEEL_REINF

/turf/closed/wall/ms13/metal/reinforced/industrial
	desc = "A reinforced metal wall with some patches of rust."
	icon = 'mojave/icons/turf/walls/rusty_industrial.dmi'
	frill_icon = 'mojave/icons/turf/walls/rusty_industrial_frill.dmi'

/turf/closed/wall/ms13/metal/reinforced/rust
	name = "rusted reinforced metal wall"
	desc = "A rusty but still quite sturdy reinforced metal wall."
	icon = 'mojave/icons/turf/walls/rrustmetal.dmi'
	frill_icon = 'mojave/icons/turf/walls/rrustmetal_frill.dmi'

TYPEINFO_DEF(/turf/closed/wall/ms13/concrete)
	default_armor = list(BLUNT = 50, PUNCTURE = 85, SLASH = 80, LASER = 50, ENERGY = 25, BOMB = 25, BIO = 100, FIRE = 25, ACID = 50)

/turf/closed/wall/ms13/concrete
	bullet_damage_ratio = 0.6
	name = "concrete wall"
	desc = "A tough concrete wall."
	icon = 'mojave/icons/turf/walls/concrete.dmi'
	frill_icon = 'mojave/icons/turf/walls/concrete_frill.dmi'
	max_integrity = 1000
	damage_deflection = 20

/turf/closed/wall/ms13/concrete/alt
	icon = 'mojave/icons/turf/walls/concretealt.dmi'
	frill_icon = 'mojave/icons/turf/walls/concretealt_frill.dmi'

/turf/closed/wall/ms13/sewer
	name = "sewer wall"
	desc = "A sewer wall. Gross."
	icon = 'mojave/icons/turf/walls/sewer.dmi'
	frill_icon = 'mojave/icons/turf/walls/sewer_frill.dmi'
	sheet_type = WALL_MATS_STEEL

TYPEINFO_DEF(/turf/closed/wall/ms13/bunker)
	default_armor = list(BLUNT = 65, PUNCTURE = 85, SLASH = 80, LASER = 75, ENERGY = 50, BOMB = 50, BIO = 100, FIRE = 75, ACID = 75)

/turf/closed/wall/ms13/bunker
	name = "bunker wall"
	desc = "A bunker wall. Serious business."
	icon = 'mojave/icons/turf/walls/bunker.dmi'
	frill_icon = 'mojave/icons/turf/walls/bunker_frill.dmi'
	damage_deflection = 30
	bullet_damage_ratio = 0.3
	sheet_type = WALL_MATS_STEEL_REINF

/turf/closed/indestructible/ms13/metal
	name = "metal wall"
	desc = "A sturdy metal wall."
	icon = 'mojave/icons/turf/walls/metal.dmi'
	frill_icon = 'mojave/icons/turf/walls/metal_frill.dmi'
	icon_state = "wall-0"
	base_icon_state = "wall"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_MS13_WALL
	// low walls and windows already list SMOOTH_GROUP_MS13_WALL in their own canSmoothWith, expecting walls
	// to smooth toward them back - without this, that's one-directional, producing mismatched junctions.
	canSmoothWith = SMOOTH_GROUP_MS13_LOW_WALL + SMOOTH_GROUP_MS13_WINDOW + SMOOTH_GROUP_MS13_WALL + SMOOTH_GROUP_SHUTTERS_BLASTDOORS

/turf/closed/indestructible/ms13/comb
	name = "comb wall"
	desc = "Honeybeast comb, lining the walls. They subtly drip a substance."
	icon = 'mojave/icons/turf/walls/comb.dmi'
	frill_icon = 'mojave/icons/turf/walls/comb_frill.dmi'
	icon_state = "wall-0"
	base_icon_state = "wall"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_MS13_WALL
	// low walls and windows already list SMOOTH_GROUP_MS13_WALL in their own canSmoothWith, expecting walls
	// to smooth toward them back - without this, that's one-directional, producing mismatched junctions.
	canSmoothWith = SMOOTH_GROUP_MS13_LOW_WALL + SMOOTH_GROUP_MS13_WINDOW + SMOOTH_GROUP_MS13_WALL + SMOOTH_GROUP_SHUTTERS_BLASTDOORS

// Vault Walls //

TYPEINFO_DEF(/turf/closed/wall/ms13/vault)
	default_armor = list(BLUNT = 65, PUNCTURE = 85, SLASH = 80, LASER = 75, ENERGY = 50, BOMB = 50, BIO = 100, FIRE = 75, ACID = 75)

/turf/closed/wall/ms13/vault
	name = "vault wall"
	desc = "A secure vault wall."
	icon = 'mojave/icons/turf/walls/vault_wall.dmi'
	frill_icon = 'mojave/icons/turf/walls/vault_wall_rust_frill.dmi'
	max_integrity = 2000
	damage_deflection = 35
	bullet_damage_ratio = 0.2
	sheet_type = WALL_MATS_STEEL_REINF

/turf/closed/wall/ms13/vault/vent
	name = "vent section"
	icon_state = "wall-141"
	icon = 'mojave/icons/turf/walls/vault_vent.dmi'
	frill_icon = 'mojave/icons/turf/walls/vault_vent_frill.dmi'

/turf/closed/wall/ms13/vault/rust
	name = "rusted vault wall"
	desc = "A rusted vault wall."
	icon = 'mojave/icons/turf/walls/vault_wall_rust.dmi'
	frill_icon = 'mojave/icons/turf/walls/vault_wall_rust_frill.dmi'

/turf/closed/wall/ms13/vault/rust/vent
	name = "rusted vent section"
	icon_state = "wall-141"
	icon = 'mojave/icons/turf/walls/vault_vent_rust.dmi'
	frill_icon = 'mojave/icons/turf/walls/vault_vent_rust_frill.dmi'

// Dungeon Walls //

TYPEINFO_DEF(/turf/closed/wall/ms13/dungeon)
	default_armor = list(BLUNT = 75, PUNCTURE = 90, SLASH = 80, LASER = 75, ENERGY = 75, BOMB = 75, BIO = 100, FIRE = 75, ACID = 100)

/turf/closed/wall/ms13/dungeon
	name = "reinforced bunker wall"
	desc = "A reinforced bunker wall. The pinnacle of pre-war engineering."
	icon = 'mojave/icons/turf/walls/dungeon_1.dmi'
	frill_icon = 'mojave/icons/turf/walls/dungeon_1_frill.dmi'
	max_integrity = 4000
	damage_deflection = 50
	bullet_damage_ratio = 0.15
	sheet_type = WALL_MATS_SUPER_REINF

/turf/closed/wall/ms13/dungeon/Initialize()
	. = ..()
	var/state = rand(1,4)
	switch(state)
		if(1)
			icon = 'mojave/icons/turf/walls/dungeon_1.dmi'
			frill_icon = 'mojave/icons/turf/walls/dungeon_1_frill.dmi'
		if(2)
			icon = 'mojave/icons/turf/walls/dungeon_2.dmi'
			frill_icon = 'mojave/icons/turf/walls/dungeon_2_frill.dmi'
		if(3)
			icon = 'mojave/icons/turf/walls/dungeon_3.dmi'
			frill_icon = 'mojave/icons/turf/walls/dungeon_3_frill.dmi'
		if(4)
			icon = 'mojave/icons/turf/walls/dungeon_4.dmi'
			frill_icon = 'mojave/icons/turf/walls/dungeon_4_frill.dmi'
		else
			return

/turf/closed/wall/ms13/dungeon/rust
	name = "rusted reinforced bunker wall"
	desc = "A rusted reinforced bunker wall. Still stands strong."
	icon = 'mojave/icons/turf/walls/dungeon_rust_1.dmi'
	frill_icon = 'mojave/icons/turf/walls/dungeon_rust_1_frill.dmi'

/turf/closed/wall/ms13/dungeon/rust/Initialize()
	. = ..()
	var/state = rand(1,4)
	switch(state)
		if(1)
			icon = 'mojave/icons/turf/walls/dungeon_rust_1.dmi'
			frill_icon = 'mojave/icons/turf/walls/dungeon_rust_1_frill.dmi'
		if(2)
			icon = 'mojave/icons/turf/walls/dungeon_rust_2.dmi'
			frill_icon = 'mojave/icons/turf/walls/dungeon_rust_2_frill.dmi'
		if(3)
			icon = 'mojave/icons/turf/walls/dungeon_rust_3.dmi'
			frill_icon = 'mojave/icons/turf/walls/dungeon_rust_3_frill.dmi'
		if(4)
			icon = 'mojave/icons/turf/walls/dungeon_rust_4.dmi'
			frill_icon = 'mojave/icons/turf/walls/dungeon_rust_4_frill.dmi'
		else
			return

//Player Craftable Walls

/turf/closed/wall/ms13/craftable
	name = "base class craftable wall"
	desc = "God has abandoned us, with functionality"
	baseturfs = /turf/open/floor/plating/ms13/ground/desert
	weldable = TRUE

/turf/closed/wall/ms13/craftable/deconstruction_hints(mob/user)
	return span_notice("You could use a <b>welder</b> to cut through this wall.")

/turf/closed/wall/ms13/craftable/scrap
	bullet_damage_ratio = 1
	name = "crude scrap wall"
	desc = "A crude wall made of scrap metal. This looks very recently constructed."
	icon = 'mojave/icons/turf/walls/roughscrap.dmi'
	frill_icon = 'mojave/icons/turf/walls/roughscrap_1_frill.dmi'
	sheet_type = list(/obj/item/stack/sheet/ms13/scrap = 6)
	slicing_duration = 30 SECONDS

/turf/closed/wall/ms13/craftable/scrap/Initialize()
	. = ..()
	var/state = rand(1,3)
	switch(state)
		if(1)
			icon = 'mojave/icons/turf/walls/roughscrap_2.dmi'
			frill_icon = 'mojave/icons/turf/walls/roughscrap_2_frill.dmi'
		if(2)
			icon = 'mojave/icons/turf/walls/roughscrap_3.dmi'
			frill_icon = 'mojave/icons/turf/walls/roughscrap_3_frill.dmi'
		else
			return

/turf/closed/wall/ms13/craftable/wood
	bullet_damage_ratio = 0.5
	name = "crude log wall"
	desc = "A freshly made, crude log wall. This looks very recently constructed."
	icon = 'mojave/icons/turf/walls/woodfresh.dmi'
	frill_icon = 'mojave/icons/turf/walls/woodfresh_frill.dmi'
	sheet_type = list(/obj/item/stack/sheet/ms13/wood/log = 2)
	slicing_duration = 30 SECONDS

//Wall Supports

/obj/structure/girder/ms13
	name = "base class wall support"
	desc = "No more girder spam, circa mojave sun - 2021"
	can_displace = FALSE
	icon = 'mojave/icons/turf/walls/girder.dmi'
	/// Sheet type -> list(wall it plates into, sheets it takes).
	var/list/platings = list()

/obj/structure/girder/ms13/examine(mob/user)
	. = ..()
	var/list/options = list()
	for(var/obj/item/stack/sheet/sheet as anything in platings)
		var/turf/closed/wall/wall = platings[sheet][1]
		options += "[platings[sheet][2]] [initial(sheet.name)] for  [initial(wall.name)]"
	if(length(options))
		. += span_notice("Plate it with [english_list(options, and_text = " or ")].")

/obj/structure/girder/ms13/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	var/obj/item/stack/sheet/sheets = tool
	var/list/plating = istype(sheets) && platings[sheets.merge_type]
	if(!plating)
		return ..()
	var/needed = plating[2]
	if(sheets.get_amount() < needed)
		to_chat(user, span_warning("You need [needed] of [sheets] to plate [src]."))
		return ITEM_INTERACT_BLOCKING
	to_chat(user, span_notice("You start plating [src]..."))
	if(!do_after(user, src, 15 SECONDS, DO_PUBLIC, display = sheets) || QDELETED(src) || sheets.get_amount() < needed)
		return ITEM_INTERACT_BLOCKING
	var/turf/closed/wall/ms13/wall = plate(sheets)
	user.visible_message(span_notice("[user] finishes  [wall]."), span_notice("You finish 	he [wall]."))
	return ITEM_INTERACT_SUCCESS

/// Uses up the plating and puts the wall up where the supports stood. Player walls cut down with a welder.
/obj/structure/girder/ms13/proc/plate(obj/item/stack/sheet/sheets)
	var/list/plating = platings[sheets.merge_type]
	sheets.use(plating[2])
	var/turf/spot = get_turf(src)
	qdel(src)
	var/turf/closed/wall/ms13/wall = spot.PlaceOnTop(plating[1])
	wall.weldable = TRUE
	return wall

/obj/structure/girder/ms13/welder_act(mob/living/user, obj/item/tool)
	to_chat(user, span_notice("You start cutting [src] apart..."))
	if(tool.use_tool(src, user, 10 SECONDS, volume = 50))
		deconstruct(TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/structure/girder/ms13/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/ms13/scrap(loc, disassembled ? 4 : 2)
	qdel(src)

TYPEINFO_DEF(/obj/structure/girder/ms13/bars)
	default_armor = list(BLUNT = 50, PUNCTURE = 35, SLASH = 50, LASER = 50, ENERGY = 25, BOMB = 25, BIO = 100, FIRE = 25, ACID = 50)

/obj/structure/girder/ms13/bars
	name = "rebar supports"
	desc = "Cheap building supports for makeshift construction projects."
	icon_state = "rebar"
	max_integrity = 300
	platings = list(
		/obj/item/stack/sheet/ms13/scrap = list(/turf/closed/wall/ms13/craftable/scrap, 4),
		/obj/item/stack/sheet/ms13/wood/log = list(/turf/closed/wall/ms13/craftable/wood, 3),
		/obj/item/stack/sheet/ms13/wood/plank = list(/turf/closed/wall/ms13/siding, 6),
		/obj/item/stack/sheet/ms13/scrap_steel = list(/turf/closed/wall/ms13/metal, 4),
		/obj/item/stack/sheet/ms13/refined_steel = list(/turf/closed/wall/ms13/metal/reinforced, 3),
		/obj/item/stack/sheet/ms13/ceramic = list(/turf/closed/wall/ms13/brick, 6),
	)
	projectile_passchance = 50

/obj/structure/girder/ms13/bars/Initialize()
	. = ..()
	AddElement(/datum/element/climbable, 3 SECONDS, climb_stun = 0)

#ifdef UNIT_TESTS
/datum/unit_test/ms13_wall_building
	name = "WALLS: Supports Take Plating, And Walls Fall To Their Own Sheets"

/datum/unit_test/ms13_wall_building/Run()
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
	var/floor_type = spot.type
	var/obj/structure/girder/ms13/bars/supports = allocate(/obj/structure/girder/ms13/bars, spot)
	var/obj/item/stack/sheet/ms13/scrap_steel/sheets = allocate(/obj/item/stack/sheet/ms13/scrap_steel/four, spot)
	var/turf/closed/wall/ms13/wall = supports.plate(sheets)
	if(!istype(wall, /turf/closed/wall/ms13/metal) || !wall.weldable || !QDELETED(sheets) || !QDELETED(supports))
		Fail("Plating wall supports with scrap steel didn't make a weldable metal wall from all four sheets.")
		return
	var/list/expected = wall.sheet_type.Copy()
	wall.dismantle_wall()
	if(spot.type != floor_type)
		Fail("A dismantled wall didn't leave the floor it was built on.")
	if(locate(/obj/structure/girder) in spot)
		Fail("A dismantled MS13 wall left a girder.")
	if(locate(/obj/item/stack/sheet/iron) in spot)
		Fail("A dismantled MS13 wall dropped iron sheets.")
	for(var/sheet_type in expected)
		var/obj/item/stack/dropped = locate(sheet_type) in spot
		if(dropped?.amount != expected[sheet_type])
			Fail("A dismantled metal wall dropped [dropped?.amount || 0] of [sheet_type], not [expected[sheet_type]].")
#endif

#undef WALL_MATS_SCRAP
#undef WALL_MATS_METAL
#undef WALL_MATS_STEEL
#undef WALL_MATS_WOOD
#undef WALL_MATS_STEEL_REINF
#undef WALL_MATS_SUPER_REINF
