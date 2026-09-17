// Base types

/datum/plant/ms13
	growing_icon = 'mojave/icons/hydroponics/growing.dmi'
	// AI EDIT: potency/growthstages moved here from /obj/item/seeds/ms13 below - they're /datum/plant fields in DD
	// (confirmed against code/modules/hydroponics/plant.dm and seeds.dm), not /obj/item/seeds fields. potency isn't
	// a plain default on /datum/plant (it's gene-derived via get_effective_stat) - base_potency is its closest
	// equivalent starting value.
	base_potency = 40
	growthstages = 5
	force_single_harvest = TRUE
	var/growing_color = ""
	var/harvest_icon = 1
	var/wholeiconcolor = TRUE
	// The type of nutrient the plant consumes: 'N', 'P', or 'K'
	var/nutrient_type

/datum/plant/ms13/New(empty)
	// The imported MS crop data used "harvest amount" as yield. DD split that old stat into yield and repeat harvests.
	base_harvest_yield = base_harvest_amt
	base_harvest_amt = 1
	return ..()

/obj/item/seeds/ms13
	icon = 'mojave/icons/hydroponics/seeds.dmi'
	icon_state = "seed"
	w_class = WEIGHT_CLASS_TINY
	var/lifespan = INFINITY

/obj/item/seeds/ms13/examine(mob/user)
	. = ..()
	var/datum/plant/ms13/ms_plant = plant_datum
	if(istype(ms_plant) && ms_plant.nutrient_type)
		. += span_info("Required Nutrient: [ms_plant.nutrient_type]")

/obj/item/food/grown/ms13
	icon = 'mojave/icons/hydroponics/harvest/harvest_world.dmi'
	inhand_icon_state = "plant"
	lefthand_file = 'mojave/icons/mob/inhands/equipment/hydroponics_lefthand.dmi'
	righthand_file = 'mojave/icons/mob/inhands/equipment/hydroponics_righthand.dmi'
	can_distill = TRUE
	w_class = WEIGHT_CLASS_TINY
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/brew_sludge
	decomp_type = /obj/item/food/badrecipe/moldy/ms13
	var/can_dry = FALSE
	var/dry_time = 600
	var/dried_type
	var/time_drying = 0

/obj/item/food/grown/ms13/Initialize()
	. = ..()
	AddElement(/datum/element/world_icon, null, icon, 'mojave/icons/hydroponics/harvest/harvest_inventory.dmi')

/////////////////////////////////////////////////////////////
//////////////////////// FRUIT //////////////////////////////
/////////////////////////////////////////////////////////////

///////////////////// BARREL CACTUS /////////////////////////

/datum/plant/ms13/barrelcactus
	species = "cactus2"
	growing_color = "#a6b115"
	name = "Barrel Cactus"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/barrelcactus
	product_path = /obj/item/food/grown/ms13/barrelcactus
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 200
	base_endurance = 45
	base_harvest_amt = 3
	growthstages = 4
	base_production = 30
	base_maturation = 60
	reagents_per_potency = list(/datum/reagent/toxin = 0.04, /datum/reagent/consumable/nutriment = 0.2)
	nutrient_type = "K"

/obj/item/seeds/ms13/barrelcactus
	name = "barrel cactus seeds"
	desc = "These seeds grow into a barrel cactus."
	plant_type = /datum/plant/ms13/barrelcactus

/obj/item/food/grown/ms13/barrelcactus
	plant_datum = /datum/plant/ms13/barrelcactus
	name = "barrel cactus fruit"
	desc = "Barrel cactus fruit are found on spherical barrel cacti. Fairly firm to the touch."
	bite_consumption_mod = 2
	foodtypes = FRUIT | TOXIC
	icon_state = "barrelcactus"
	filling_color = "#a6b115"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/barrel_wine
	tastes = list("sourness" = 10, "burning" = 1)

///////////////////// MUTFRUIT /////////////////////////

/datum/plant/ms13/mutfruit
	species = "bush"
	growing_color = "#59496d"
	name = "Mutfruit Sapling"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/squash)
	seed_path = /obj/item/seeds/ms13/mutfruit
	product_path = /obj/item/food/grown/ms13/mutfruit
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 164
	base_endurance = 45
	base_harvest_amt = 3
	growthstages = 4
	base_production = 24
	base_maturation = 55
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/mutfruit
	name = "mutfruit seeds"
	desc = "These seeds grow into a mutfruit sapling."
	plant_type = /datum/plant/ms13/mutfruit

/obj/item/food/grown/ms13/mutfruit
	plant_datum = /datum/plant/ms13/mutfruit
	name = "mutfruit"
	desc = "A squishy and juicy mutfruit. It warms your hand to the touch."
	bite_consumption_mod = 2
	foodtypes = FRUIT
	icon_state = "mutfruit"
	filling_color = "#5f035f"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/mutfruit_wine
	tastes = list("warmth" = 5, "sweetness" = 2)

// CRUNCHY MUTFRUIT

/datum/plant/ms13/cmutfruit
	species = "vines"
	growing_color = "#da9249"
	name = "Crunchy Mutfruits"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/cmutfruit
	product_path = /obj/item/food/grown/ms13/cmutfruit
	possible_mutations = list()
	//lifespan = 75
	base_endurance = 35
	base_harvest_amt = 4
	growthstages = 3
	base_production = 14
	base_maturation = 32
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/cmutfruit
	name = "crunchy mutfruit husks"
	desc = "These husks grow crunchy mutfruits from the ground."
	plant_type = /datum/plant/ms13/cmutfruit

/obj/item/food/grown/ms13/cmutfruit
	plant_datum = /datum/plant/ms13/cmutfruit
	name = "crunchy mutfruit"
	desc = "A firm and stiff mutfruit. Producted a sort of hollow sound when tapped."
	foodtypes = FRUIT
	bite_consumption_mod = 2
	icon_state = "cmutfruit"
	filling_color = "#7c3e04"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/mutfruit_wine
	tastes = list("sourness" = 5, "sweetness" = 1)

// APPLE

/datum/plant/ms13/apple
	species = "tree"
	growing_color = "#9b3434"
	name = "Apple Shrub"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/apple
	product_path = /obj/item/food/grown/ms13/apple
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 96
	base_endurance = 40
	base_harvest_amt = 5
	growthstages = 5
	base_production = 20
	base_maturation = 48
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/apple
	name = "apple seeds"
	desc = "Some mutated apple shrub seeds."
	plant_type = /datum/plant/ms13/apple

/obj/item/food/grown/ms13/apple
	plant_datum = /datum/plant/ms13/apple
	name = "apple"
	desc = "A common apple. It is firm to the touch and hardy."
	bite_consumption_mod = 1
	foodtypes = FRUIT
	icon_state = "apple"
	filling_color = "#9b7470"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/apple_cider
	tastes = list("apple" = 1)

///////////////////// PRICKLY PEAR /////////////////////////

/datum/plant/ms13/pricklypear
	species = "cactus"
	growing_color = "#8a0483"
	name = "Prickly Pear Cactus"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/stinging)
	seed_path = /obj/item/seeds/ms13/pricklypear
	product_path = /obj/item/food/grown/ms13/pricklypear
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 118
	base_endurance = 35
	base_harvest_amt = 3
	growthstages = 4
	base_production = 16
	base_maturation = 64
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/pricklypear
	name = "prickly pear seeds"
	desc = "These seeds grow into a prickly pear cactus."
	plant_type = /datum/plant/ms13/pricklypear

/obj/item/food/grown/ms13/pricklypear
	plant_datum = /datum/plant/ms13/pricklypear
	name = "prickly pear fruit"
	desc = "A menacing fruit filled with spines. The flesh feels thin and easy to peel otherwise."
	icon_state = "prickly"
	filling_color = "#8a0483"
	foodtypes = FRUIT
	bite_consumption_mod = 2
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/pricklypear_wine
	tastes = list("sweetness" = 1)

/obj/item/food/grown/ms13/pricklypear/pickup(mob/living/user)
	..()
	if(!iscarbon(user))
		return FALSE
	var/mob/living/carbon/C = user
	if(C.gloves)
		return FALSE
	if(HAS_TRAIT(C, TRAIT_PIERCEIMMUNE))
		return FALSE
	var/hit_zone = (C.held_index_to_dir(C.active_hand_index) == "l"? "l_":"r_") + "arm"
	var/obj/item/bodypart/affecting = C.get_bodypart(hit_zone)
	if(affecting)
		if(affecting.receive_damage(brute = 10))
			C.update_damage_overlays()
	to_chat(C, "<span class='userdanger'>The spines pierce your bare hand!</span>")
	return TRUE

///////////////////// PUNGA /////////////////////////

/datum/plant/ms13/punga
	species = "bush"
	growing_color = "#695d19"
	name = "Punga Bush"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism, /datum/plant_gene/product_trait/squash)
	seed_path = /obj/item/seeds/ms13/punga
	product_path = /obj/item/food/grown/ms13/pungafruit
	//lifespan = 215
	base_endurance = 50
	base_harvest_amt = 3
	growthstages = 4
	base_production = 21
	base_maturation = 90
	reagents_per_potency = list(/datum/reagent/toxin = 0.04, /datum/reagent/consumable/nutriment = 0.2)
	nutrient_type = "P"

/obj/item/seeds/ms13/punga
	name = "punga pits"
	desc = "These small black pits grow into a punga bush."
	plant_type = /datum/plant/ms13/punga

/obj/item/food/grown/ms13/pungafruit
	plant_datum = /datum/plant/ms13/punga
	name = "pungafruit"
	desc = "A fleshy fruit with a yellowish-brown, thick skin. Puts off a strange smell."
	icon_state = "punga"
	bite_consumption_mod = 2
	foodtypes = FRUIT | TOXIC
	filling_color = "#695d19"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/punga_wine
	tastes = list("sourness" = 6, "warmth" = 1)

// GEIGER PUNGA

/datum/plant/ms13/geigpunga
	species = "bush"
	growing_color = "#55ff06"
	name = "Geigerpunga Bush"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism, /datum/plant_gene/product_trait/squash)
	seed_path = /obj/item/seeds/ms13/geigpunga
	product_path = /obj/item/food/grown/ms13/geigpungafruit
	//lifespan = 125
	base_endurance = 25
	base_harvest_amt = 4
	growthstages = 4
	base_production = 20
	base_maturation = 78
	reagents_per_potency = list(/datum/reagent/toxin = 0.08, /datum/reagent/consumable/nutriment = 0.2)
	nutrient_type = "P"

/obj/item/seeds/ms13/geigpunga
	name = "geiger punga pits"
	desc = "These small glowing green pits grow into a punga bush."
	plant_type = /datum/plant/ms13/geigpunga

/obj/item/food/grown/ms13/geigpungafruit
	plant_datum = /datum/plant/ms13/geigpunga
	name = "geiger pungafruit"
	desc = "A glowing fleshy fruit with a pulsing green skin. Has a harsh acidic smell."
	icon_state = "geigpunga"
	bite_consumption_mod = 2
	foodtypes = FRUIT | TOXIC
	filling_color = "#55ff06"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/geigpunga_wine
	tastes = list("acid" = 6, "burning" = 5)

///////////////////// SNAPTAIL /////////////////////////

/datum/plant/ms13/snaptail
	species = "stalk"
	growing_color = "#bda75f"
	wholeiconcolor = TRUE
	name = "Snaptail Reeds"
	seed_path = /obj/item/seeds/ms13/snaptail
	product_path = /obj/item/food/grown/ms13/snaptail
	//lifespan = 75
	base_endurance = 50
	base_harvest_amt = 5
	growthstages = 5
	base_production = 18
	base_maturation = 42
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1, /datum/reagent/consumable/sugar = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/snaptail
	name = "snaptail grains"
	desc = "These waxy grains grow into the sugary snaptail plant."
	plant_type = /datum/plant/ms13/snaptail

/obj/item/food/grown/ms13/snaptail
	plant_datum = /datum/plant/ms13/snaptail
	name = "snaptail"
	desc = "A lengthy cane. Very stiff and firm."
	icon_state = "snaptail"
	bite_consumption_mod = 1
	foodtypes = SUGAR | GROSS
	filling_color = "#caa3a3"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/snaptail_rum
	tastes = list("sugar" = 5, "reed" = 5)

///////////////////// TARBERRY /////////////////////////

/datum/plant/ms13/tarberry
	species = "vines"
	growing_color = "#2f2525ff"
	name = "Tarberry Bush"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/tarberry
	product_path = /obj/item/food/grown/ms13/tarberry
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 118
	base_endurance = 35
	base_harvest_amt = 2
	growthstages = 3
	base_production = 16
	base_maturation = 50
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/tarberry
	name = "tarberry seeds"
	desc = "These seeds grow into a tarberry bush."
	plant_type = /datum/plant/ms13/tarberry

/obj/item/food/grown/ms13/tarberry
	plant_datum = /datum/plant/ms13/tarberry
	name = "tarberry"
	desc = "A dark and sticky berry. It leaves a sap behind on your hands."
	bite_consumption_mod = 1
	foodtypes = FRUIT | GROSS
	icon_state = "tarberry"
	filling_color = "#2f2525ff"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/tarberry_wine
	tastes = list("oil" = 5, "stale berries" = 1)

// BLACKBERRY

/datum/plant/ms13/blackberry
	species = "bush"
	growing_color = "#351b3d"
	name = "Blackberry Bush"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/blackberry
	product_path = /obj/item/food/grown/ms13/blackberry
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 96
	base_endurance = 15
	base_harvest_amt = 2
	growthstages = 4
	base_production = 12
	base_maturation = 45
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.02, /datum/reagent/consumable/nutriment = 0.08)
	nutrient_type = "P"

/obj/item/seeds/ms13/blackberry
	name = "blackberry seeds"
	desc = "These seeds grow into a mutated blackberry bush."
	plant_type = /datum/plant/ms13/blackberry

/obj/item/food/grown/ms13/blackberry
	plant_datum = /datum/plant/ms13/blackberry
	name = "blackberry"
	desc = "A squishy bundle of blackberries. Bubbly and round. It gives off a faint sweet aroma."
	bite_consumption_mod = 1
	foodtypes = FRUIT
	icon_state = "blackberry"
	filling_color = "#15172a"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/blackberry_wine
	tastes = list("berries" = 5, "juice" = 1)

// RADBERRY

/datum/plant/ms13/radberry
	species = "bush2"
	growing_color = "#00ff2a"
	name = "Radberry Shrub"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/squash)
	seed_path = /obj/item/seeds/ms13/radberry
	product_path = /obj/item/food/grown/ms13/radberry
	//lifespan = 36
	base_endurance = 30
	genome = 90
	base_harvest_amt = 4
	growthstages = 3
	base_production = 12
	base_maturation = 24
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.02, /datum/reagent/consumable/nutriment = 0.08)
	nutrient_type = "P"

/obj/item/seeds/ms13/radberry
	name = "radberry pips"
	desc = "The seeds grow into the radioactive radberry."
	plant_type = /datum/plant/ms13/radberry

/obj/item/food/grown/ms13/radberry
	plant_datum = /datum/plant/ms13/radberry
	name = "radberry"
	desc = "A glowing and warm radberry. The skin fringes off and exposes the squishy core."
	icon_state = "radberry"
	bite_consumption_mod = 1
	foodtypes = FRUIT | GROSS
	filling_color = "#00ff2a"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/radberry_wine
	tastes = list("metal" = 5, "sweetness" = 1)

///////////////////// YUCCA /////////////////////////

/datum/plant/ms13/yucca
	species = "yucca"
	name = "yucca plant"
	seed_path = /obj/item/seeds/ms13/yucca
	product_path = /obj/item/food/grown/ms13/yucca
	//lifespan = 105
	base_endurance = 45
	base_harvest_amt = 3
	growthstages = 4
	base_production = 13
	base_maturation = 64
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.08, /datum/reagent/consumable/nutriment = 0.15)
	nutrient_type = "K"

/obj/item/seeds/ms13/yucca
	name = "yucca seeds"
	desc = "These seeds grow into an yucca plant."
	plant_type = /datum/plant/ms13/yucca

/obj/item/food/grown/ms13/yucca
	plant_datum = /datum/plant/ms13/yucca
	name = "yucca fruit"
	desc = "The fleshy long fruit. It gives off a faint sweet starch smell."
	icon_state = "yucca"
	bite_consumption_mod = 4
	foodtypes = FRUIT
	filling_color = "#b4a031ff"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/yucca_wine
	tastes = list("sweet" = 5, "starch" = 2)

// TOMATO

/datum/plant/ms13/tomato
	species = "bush"
	growing_color = "#a7200e"
	name = "Tomato Plant"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/squash)
	seed_path = /obj/item/seeds/ms13/tomato
	product_path = /obj/item/food/grown/ms13/tomato
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 72
	base_endurance = 20
	base_harvest_amt = 2
	growthstages = 4
	base_production = 10
	base_maturation = 40
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/tomato
	name = "tomato seeds"
	desc = "Some strange seeds."
	plant_type = /datum/plant/ms13/tomato

/obj/item/food/grown/ms13/tomato
	plant_datum = /datum/plant/ms13/tomato
	name = "tomato"
	desc = "A strange red, round fruit with a semi-thick skin. It is squishy."
	bite_consumption_mod = 2
	foodtypes = FRUIT | VEGETABLES
	icon_state = "tomato"
	filling_color = "#8d1d1d"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/tomato_wine
	tastes = list("sweetness" = 3, "tangy acid" = 2)

/////////////////////////////////////////////////////////////
/////////////////////  VEGETABLES ///////////////////////////
/////////////////////////////////////////////////////////////

//////////////////////// TATO /////////////////////////////

/datum/plant/ms13/tato
	species = "bush2"
	growing_color = "#703e2e"
	name = "Tato Plant"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/tato
	product_path = /obj/item/food/grown/ms13/tato
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 88
	base_endurance = 60
	base_harvest_amt = 3
	growthstages = 3
	base_production = 12
	base_maturation = 50
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/tato
	name = "tato sprouts"
	desc = "These tato sprouts replicate the disgusting tato plant."
	plant_type = /datum/plant/ms13/tato

/obj/item/food/grown/ms13/tato
	plant_datum = /datum/plant/ms13/tato
	name = "tato"
	desc = "An oblong and hard red plant. It smells disgusting."
	bite_consumption_mod = 3
	foodtypes = VEGETABLES | GROSS
	icon_state = "tato"
	filling_color = "#4b2727"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/tato_liquor
	tastes = list("raw eggs" = 5)

// POTATO

/datum/plant/ms13/potato
	species = "root"
	name = "Potatos"
	seed_path = /obj/item/seeds/ms13/potato
	product_path = /obj/item/food/grown/ms13/potato
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 50
	base_endurance = 60
	base_harvest_amt = 4
	growthstages = 3
	base_production = 9
	base_maturation = 28
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.25)
	nutrient_type = "K"

/obj/item/seeds/ms13/potato
	name = "potato sprouts"
	desc = "Pre-war potato sprouts, grow into clusters of potatos in the soil, highly resistant."
	plant_type = /datum/plant/ms13/potato

/obj/item/food/grown/ms13/potato
	plant_datum = /datum/plant/ms13/potato
	name = "potato"
	desc = "A strange and round vegetable. Has a faint starchy hint to it, and is seemingly rock hard."
	bite_consumption_mod = 2
	foodtypes = VEGETABLES | GROSS
	icon_state = "potato"
	filling_color = "#ada876"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/waster_vodka
	tastes = list("starch" = 5)

////////////////////// JALAPENO /////////////////////////////

/datum/plant/ms13/jalepeno
	species = "bush"
	growing_color = "#233b29"
	name = "Jalepeno Plant"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/jalepeno
	product_path = /obj/item/food/grown/ms13/jalepeno
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 90
	base_endurance = 35
	base_harvest_amt = 3
	growthstages = 4
	base_production = 13
	base_maturation = 35
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.01, /datum/reagent/consumable/nutriment = 0.05, /datum/reagent/consumable/capsaicin = 0.025)
	nutrient_type = "P"

/obj/item/seeds/ms13/jalepeno
	name = "jalapeno seeds"
	desc = "These seeds grow into long spicy desert-proof peppers."
	plant_type = /datum/plant/ms13/jalepeno

/obj/item/food/grown/ms13/jalepeno
	plant_datum = /datum/plant/ms13/jalepeno
	name = "jalapeno"
	desc = "A moderately sized thin green pepper. Has no smell to it."
	bite_consumption_mod = 1
	foodtypes = VEGETABLES
	icon_state = "jalepeno"
	filling_color = "#233b29"
	tastes = list("spicy" = 5)

// RADPEPPER

/datum/plant/ms13/radpepper
	species = "bush"
	growing_color = "#fffb02"
	name = "Radpepper Bush"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/squash)
	seed_path = /obj/item/seeds/ms13/radpepper
	product_path = /obj/item/food/grown/ms13/radpepper
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 88
	genome = 90
	base_endurance = 30
	base_harvest_amt = 3
	growthstages = 4
	base_production = 11
	base_maturation = 42
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.01, /datum/reagent/consumable/nutriment = 0.05, /datum/reagent/consumable/capsaicin = 0.25)
	nutrient_type = "P"

/obj/item/seeds/ms13/radpepper
	name = "radpepper seeds"
	desc = "The seeds grow into an even spicier and radioactive jalepeno variant."
	plant_type = /datum/plant/ms13/radpepper

/obj/item/food/grown/ms13/radpepper
	plant_datum = /datum/plant/ms13/radpepper
	name = "radpepper"
	desc = "A glowing thin green pepper. Has a palpable heat to its aroma."
	bite_consumption_mod = 1
	foodtypes = VEGETABLES | TOXIC
	icon_state = "radpepper"
	filling_color = "#837e3c"
	tastes = list("death" = 5, "pain" = 5)

//////////////////////// ONION //////////////////////////////

/datum/plant/ms13/onion
	species = "root"
	name = "Onions"
	seed_path = /obj/item/seeds/ms13/onion
	product_path = /obj/item/food/grown/ms13/onion
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 40
	base_endurance = 50
	base_harvest_amt = 4
	growthstages = 3
	base_production = 10
	base_maturation = 24
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/onion
	name = "onion sprouts"
	desc = "The sprouts grow into a hardy onion plant."
	plant_type = /datum/plant/ms13/onion

/obj/item/food/grown/ms13/onion
	plant_datum = /datum/plant/ms13/onion
	name = "onion"
	desc = "A hardy and aromatic root vegetable. Seems to have layers."
	bite_consumption_mod = 4
	foodtypes = VEGETABLES | GROSS
	icon_state = "onion"
	filling_color = "#5d5151"
	tastes = list("sour" = 5)

// GARLIC

/datum/plant/ms13/garlic
	species = "root"
	name = "Garlic Plant"
	seed_path = /obj/item/seeds/ms13/garlic
	product_path = /obj/item/food/grown/ms13/garlic
	possible_mutations = null // ponytail: was set to seed paths, not /datum/plant_mutation datums - crashed the codex. No real mutation datums exist for these yet.
	//lifespan = 60
	base_endurance = 50
	base_maturation = 38
	base_production = 9
	base_harvest_amt = 4
	genome = 15
	growthstages = 3
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/garlic
	name = "garlic seeds"
	desc = "These seeds grow into garlic."
	plant_type = /datum/plant/ms13/garlic

/obj/item/food/grown/ms13/garlic
	plant_datum = /datum/plant/ms13/garlic
	name = "garlic"
	desc = "A hard and potent smelling vegetable."
	bite_consumption_mod = 1
	foodtypes = VEGETABLES
	icon_state = "garlic"
	filling_color = "#707070"
	tastes = list("garlic" = 5, "burning" = 5)

//////////////////////// XANDER /////////////////////////////

/datum/plant/ms13/xander
	species = "root"
	name = "Xander Roots"
	seed_path = /obj/item/seeds/ms13/xander
	product_path = /obj/item/food/grown/ms13/xander
	//lifespan = 75
	base_endurance = 50
	base_maturation = 48
	base_production = 12
	base_harvest_amt = 4
	growthstages = 3
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/xander
	name = "xander roots"
	desc = "These xander roots grow in size, producing denser and healing Xander roots."
	plant_type = /datum/plant/ms13/xander

/obj/item/food/grown/ms13/xander
	plant_datum = /datum/plant/ms13/xander
	name = "xander root"
	desc = "A dark root, it is rather hard. There is no obvious smell to it."
	bite_consumption_mod = 4
	foodtypes = VEGETABLES | GROSS
	icon_state = "xander"
	filling_color = "#2f2424"
	tastes = list("bitterness" = 5)

/obj/item/food/grown/ms13/xander/MakeProcessable()
	AddElement(/datum/element/processable, TOOL_KNIFE, /obj/item/food/grown/ms13/xander/cut, 1, 30)

/obj/item/food/grown/ms13/xander/cut
	name = "sliced xander root"
	desc = "A xander root that has been cut into thinner parts, you think you could hang this to dry."
	icon_state = "cut_xander"
	can_dry = TRUE
	dry_time = 900
	dried_type = /obj/item/ms13/dried/xander

//////////////////////// CARROT /////////////////////////////

/datum/plant/ms13/carrot
	species = "root"
	name = "Carrots"
	seed_path = /obj/item/seeds/ms13/carrot
	product_path = /obj/item/food/grown/ms13/carrot
	//lifespan = 48
	base_endurance = 40
	base_harvest_amt = 4
	growthstages = 3
	base_production = 9
	base_maturation = 35
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/carrot
	name = "carrot seeds"
	desc = "Some carrot seeds."
	plant_type = /datum/plant/ms13/carrot

/obj/item/food/grown/ms13/carrot
	plant_datum = /datum/plant/ms13/carrot
	name = "carrot"
	desc = "A root vegetable, long and orange. Smells faintly sweet."
	bite_consumption_mod = 2
	foodtypes = VEGETABLES
	icon_state = "carrot"
	filling_color = "#815c1f"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/carrot_wine
	tastes = list("sweetness" = 1)

//////////////////////// RAZORGRAIN /////////////////////////

/datum/plant/ms13/razorgrain
	species = "stalk"
	growing_color = "#644e2c"
	wholeiconcolor = TRUE
	name = "Razorgrain Stalks"
	seed_path = /obj/item/seeds/ms13/razorgrain
	product_path = /obj/item/food/grown/ms13/razorgrain
	//lifespan = 70
	base_endurance = 60
	base_harvest_amt = 4
	growthstages = 5
	base_production = 13
	base_maturation = 38
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/razorgrain
	name = "razorgrain grains"
	desc = "Some hardy mutated wheat grains, a staple plant in the wasteland."
	plant_type = /datum/plant/ms13/razorgrain

/obj/item/food/grown/ms13/razorgrain
	plant_datum = /datum/plant/ms13/razorgrain
	name = "razorgrain"
	desc = "Some razorgrain. It is very bushy and flakes off dust as you brush it."
	bite_consumption_mod = 1
	foodtypes = GRAIN | GROSS
	icon_state = "razorgrain"
	filling_color = "#8f905b"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/waster_beer
	tastes = list("chalky grain" = 5)

//////////////////////// BAIFAN /////////////////////////////

/datum/plant/ms13/baifan
	species = "stalk"
	growing_color = "#688265"
	wholeiconcolor = TRUE
	name = "Baifan Stalks"
	seed_path = /obj/item/seeds/ms13/baifan
	product_path = /obj/item/food/grown/ms13/baifan
	//lifespan = 75
	base_endurance = 65
	base_harvest_amt = 5
	growthstages = 5
	base_production = 14
	base_maturation = 44
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/baifan
	name = "baifan grains"
	desc = "Some hardy mutated rice grains."
	plant_type = /datum/plant/ms13/baifan

/obj/item/food/grown/ms13/baifan
	plant_datum = /datum/plant/ms13/baifan
	name = "baifan"
	desc = "A tuft-topped stalk of baifan. Harvests a rice-like grain."
	bite_consumption_mod = 1
	foodtypes = GRAIN | GROSS
	icon_state = "baifan"
	filling_color = "#505749"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/waster_sake
	tastes = list("chalky grain" = 2, "raw rice" = 5)

/////////////////////// CABBAGE /////////////////////////////

/datum/plant/ms13/cabbage
	species = "vines"
	growing_color = "#334632"
	name = "Cabbage Plant"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/cabbage
	product_path = /obj/item/food/grown/ms13/cabbage
	//lifespan = 65
	base_endurance = 60
	base_harvest_amt = 4
	growthstages = 3
	base_production = 15
	base_maturation = 33
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/cabbage
	name = "cabbage seeds"
	desc = "Some hardy cabbage seeds."
	plant_type = /datum/plant/ms13/cabbage

/obj/item/food/grown/ms13/cabbage
	plant_datum = /datum/plant/ms13/cabbage
	name = "cabbage"
	desc = "A resilient leaf plant, only green thing out here."
	bite_consumption_mod = 4
	foodtypes = VEGETABLES
	icon_state = "cabbage"
	filling_color = "#2d382a"
	tastes = list("cabbage" = 5)

//////////////////////// PINYON /////////////////////////////

/datum/plant/ms13/pinyon
	species = "tree"
	growing_color = "#7b7c68"
	name = "Pinyon Pine"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/pinyon
	product_path = /obj/item/food/grown/ms13/pinyon
	//lifespan = 150
	base_endurance = 55
	base_harvest_amt = 4
	growthstages = 5
	base_production = 18
	base_maturation = 90
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/pinyon
	name = "pinyon nuts"
	desc = "Some pinyon nuts, grows into a pinyon pine."
	plant_type = /datum/plant/ms13/pinyon

/obj/item/food/grown/ms13/pinyon
	plant_datum = /datum/plant/ms13/pinyon
	name = "pinyon nuts"
	desc = "Small pinyon nuts."
	bite_consumption_mod = 2
	foodtypes = VEGETABLES
	icon_state = "pinyon"
	filling_color = "#7b7c68"
	tastes = list("nutty" = 4, "sourness" = 1)
	food_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/nutriment/vitamin = 1)

///////////////////////// MESQUITE //////////////////////////

/datum/plant/ms13/mesquite
	species = "bush"
	growing_color = "#525011"
	name = "Mesquite Plant"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/mesquite
	product_path = /obj/item/food/grown/ms13/mesquite
	//lifespan = 85
	base_endurance = 40
	base_harvest_amt = 3
	growthstages = 4
	base_production = 16
	base_maturation = 50
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/mesquite
	name = "mesquite seeds"
	desc = "Some honey mesquite seeds."
	plant_type = /datum/plant/ms13/mesquite

/obj/item/food/grown/ms13/mesquite
	plant_datum = /datum/plant/ms13/mesquite
	name = "mesquite"
	desc = "Long honey mesquite pods. The pod itself has the texture of old leather."
	bite_consumption_mod = 2
	foodtypes = VEGETABLES
	icon_state = "mesquite"
	filling_color = "#223a24"
	tastes = list("sour" = 5, "sweet" = 5)

/////////////////////// BUFFALO GOURD /////////////////////////////

/datum/plant/ms13/buffalo
	species = "vines"
	growing_color = "#cadca3"
	name = "Buffalo Vines"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/squash)
	seed_path = /obj/item/seeds/ms13/buffalo
	product_path = /obj/item/food/grown/ms13/buffalo
	//lifespan = 80
	base_endurance = 45
	base_harvest_amt = 5
	growthstages = 3
	base_production = 13
	base_maturation = 54
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/buffalo
	name = "buffalo seeds"
	desc = "Some buffalo gourd seeds."
	plant_type = /datum/plant/ms13/buffalo

/obj/item/food/grown/ms13/buffalo
	plant_datum = /datum/plant/ms13/buffalo
	name = "buffalo"
	desc = "A buffalo gourd, a decent ingredient, but nasty when raw."
	bite_consumption_mod = 6
	foodtypes = VEGETABLES | GROSS
	icon_state = "buffalo"
	filling_color = "#2b3325"
	tastes = list("wood" = 5)

//////////////////////// MAIZE //////////////////////////////

/datum/plant/ms13/maize
	species = "corn"
	name = "Maize Stalks"
	seed_path = /obj/item/seeds/ms13/maize
	product_path = /obj/item/food/grown/ms13/maize
	//lifespan = 70
	base_endurance = 50
	base_harvest_amt = 4
	growthstages = 3
	base_production = 12
	base_maturation = 44
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/maize
	name = "maize seeds"
	desc = "Some maize seeds."
	plant_type = /datum/plant/ms13/maize

/obj/item/food/grown/ms13/maize
	plant_datum = /datum/plant/ms13/maize
	name = "maize"
	desc = "A hardy maize crop. Has a thick husk around it."
	bite_consumption_mod = 4
	foodtypes = VEGETABLES | GRAIN
	icon_state = "maize"
	filling_color = "#bbb81c"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/waster_whiskey
	tastes = list("corn" = 5)

/////////////////////////////////////////////////////////////
///////////////////// FLOWER/HERBS //////////////////////////
/////////////////////////////////////////////////////////////

///////////////////////// ASH ROSE //////////////////////////

/datum/plant/ms13/ashrose
	species = "flower2"
	growing_color = "#612a20"
	name = "Ash Roses"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/ashrose
	product_path = /obj/item/food/grown/ms13/ashrose
	//lifespan = 144
	base_endurance = 25
	base_harvest_amt = 3
	growthstages = 3
	base_production = 18
	base_maturation = 84
	genome = 25
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/ashrose
	name = "ash rose seeds"
	desc = "Some ash rose seeds."
	plant_type = /datum/plant/ms13/ashrose

/obj/item/food/grown/ms13/ashrose
	plant_datum = /datum/plant/ms13/ashrose
	name = "ash rose"
	desc = "A pretty red colored flower. Its petals are layered with a dense core."
	bite_consumption_mod = 1
	foodtypes = GROSS
	icon_state = "ashrose"
	filling_color = "#411c19"
	tastes = list("sourness" = 5)

// RAD ROSE

/datum/plant/ms13/radrose
	species = "flower2"
	growing_color = "#18f2fa"
	name = "Rad Roses"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/radrose
	product_path = /obj/item/food/grown/ms13/radrose
	//lifespan = 118
	base_endurance = 18
	base_harvest_amt = 3
	growthstages = 3
	base_production = 12
	base_maturation = 78
	genome = 90
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/radrose
	name = "rad rose seeds"
	desc = "Some rad rose seeds."
	plant_type = /datum/plant/ms13/radrose

/obj/item/food/grown/ms13/radrose
	plant_datum = /datum/plant/ms13/radrose
	name = "rad rose"
	desc = "A vibrant cyan colored flower. It seemingly begs for your attention."
	bite_consumption_mod = 1
	foodtypes = GROSS | TOXIC
	icon_state = "radrose"
	filling_color = "#579797"
	tastes = list("warmth" = 5, "sourness" = 5, "pain" = 5)

/////////////////////////// SOOT ////////////////////////////

/datum/plant/ms13/soot
	species = "flower"
	growing_color = "#7c2292"
	name = "Soot Flowers"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/soot
	product_path = /obj/item/food/grown/ms13/soot
	//lifespan = 142
	base_endurance = 35
	base_harvest_amt = 3
	growthstages = 3
	base_production = 11
	base_maturation = 90
	genome = 25
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/soot
	name = "soot seeds"
	desc = "Some soot seeds."
	plant_type = /datum/plant/ms13/soot

/obj/item/food/grown/ms13/soot
	plant_datum = /datum/plant/ms13/soot
	name = "soot flower"
	desc = "A vibrant purple flower with a strange shape."
	bite_consumption_mod = 1
	foodtypes = GROSS | TOXIC
	icon_state = "soot"
	filling_color = "#462050"
	tastes = list("bitterness" = 5)

// TOXIC SOOT

/datum/plant/ms13/toxicsoot
	species = "flower"
	growing_color = "#229235"
	name = "Toxic Soot Flowers"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/toxicsoot
	product_path = /obj/item/food/grown/ms13/toxicsoot
	//lifespan = 136
	base_endurance = 35
	base_harvest_amt = 3
	growthstages = 3
	base_production = 18
	base_maturation = 66
	genome = 50
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/toxicsoot
	name = "toxic soot seeds"
	desc = "Some mutated soot seeds."
	plant_type = /datum/plant/ms13/toxicsoot

/obj/item/food/grown/ms13/toxicsoot
	plant_datum = /datum/plant/ms13/toxicsoot
	name = "toxic soot flower"
	desc = "A glowing flower. It has a strange shape, with multiple points sticking forward."
	bite_consumption_mod = 1
	foodtypes = GROSS | TOXIC
	icon_state = "toxsoot"
	filling_color = "#34773f"
	tastes = list("bitterness" = 10)

////////////////////////// DATURA ///////////////////////////

/datum/plant/ms13/datura
	species = "flower2"
	growing_color = "#dddddd"
	name = "Datura Flowers"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/datura
	product_path = /obj/item/food/grown/ms13/datura
	//lifespan = 118
	base_endurance = 20
	base_harvest_amt = 3
	growthstages = 3
	base_production = 14
	base_maturation = 70
	genome = 25
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/datura
	name = "datura seeds"
	desc = "Some datura seeds."
	plant_type = /datum/plant/ms13/datura

/obj/item/food/grown/ms13/datura
	plant_datum = /datum/plant/ms13/datura
	name = "datura flower"
	desc = "An unstained white flower. Has a strange smell to it."
	bite_consumption_mod = 1
	foodtypes = GROSS
	icon_state = "datura"
	filling_color = "#a7a7a7"
	tastes = list("bitterness" = 5)

// RADTURA

/datum/plant/ms13/radtura
	species = "flower2"
	growing_color = "#e8bf28"
	name = "Radtura Flowers"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/radtura
	product_path = /obj/item/food/grown/ms13/radtura
	//lifespan = 114
	base_endurance = 25
	base_harvest_amt = 3
	growthstages = 3
	base_production = 17
	base_maturation = 58
	genome = 50
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/radtura
	name = "radtura seeds"
	desc = "Some radtura seeds."
	plant_type = /datum/plant/ms13/radtura

/obj/item/food/grown/ms13/radtura
	plant_datum = /datum/plant/ms13/radtura
	name = "radtura flower"
	desc = "A pulsing yellow cup shaped flower. Has a very strange smell. You can feel a warmth resonating from it."
	bite_consumption_mod = 1
	foodtypes = GROSS
	icon_state = "radtura"
	filling_color = "#a2a36c"
	tastes = list("bitterness" = 5, "warmth" = 5)

////////////////////////// COYOTE TOBACCO ///////////////////////////

/datum/plant/ms13/coyote
	species = "root"
	name = "Coyote Tobacco"
	seed_path = /obj/item/seeds/ms13/coyote
	product_path = /obj/item/food/grown/ms13/coyote
	//lifespan = 152
	base_endurance = 18
	base_harvest_amt = 2
	growthstages = 3
	base_production = 12
	base_maturation = 85
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/coyote
	name = "coyote tobacco stems"
	desc = "Some seeds that grow into a potent native tobacco plant, it has many uses."
	plant_type = /datum/plant/ms13/coyote

/obj/item/food/grown/ms13/coyote
	plant_datum = /datum/plant/ms13/coyote
	name = "coyote tobacco"
	desc = "A coyote tobacco leaf. Smells quite nice."
	bite_consumption_mod = 1
	foodtypes = GROSS
	icon_state = "tobacco"
	filling_color = "#1d3821"
	can_dry = TRUE
	dried_type = /obj/item/ms13/dried/tobacco

////////////////////////// ASTER ////////////////////////////

/datum/plant/ms13/aster
	species = "flower"
	growing_color = "#3f4c72"
	name = "Aster Flowers"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/aster
	product_path = /obj/item/food/grown/ms13/aster
	//lifespan = 158
	base_endurance = 35
	base_harvest_amt = 4
	growthstages = 3
	base_production = 18
	base_maturation = 96
	genome = 25
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/aster
	name = "aster seeds"
	desc = "Some aster seeds."
	plant_type = /datum/plant/ms13/aster

/obj/item/food/grown/ms13/aster
	plant_datum = /datum/plant/ms13/aster
	name = "aster flower"
	desc = "A wide blue flower with a vibrant red and yellow core. Seems to have dust on it."
	bite_consumption_mod = 1
	icon_state = "aster"
	filling_color = "#1e2b2c"
	tastes = list("salt" = 5, "pepper" = 5)

/////////////////////// ASH BLOSSOM /////////////////////////

/datum/plant/ms13/ashblossom
	species = "flower2"
	growing_color = "#232b44"
	name = "Ash Blossoms"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/ashblossom
	product_path = /obj/item/food/grown/ms13/ashblossom
	//lifespan = 142
	base_endurance = 40
	base_harvest_amt = 4
	growthstages = 3
	base_production = 15
	base_maturation = 90
	genome = 25
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/ashblossom
	name = "ash blossom seeds"
	desc = "Some ash blossom seeds."
	plant_type = /datum/plant/ms13/ashblossom

/obj/item/food/grown/ms13/ashblossom
	plant_datum = /datum/plant/ms13/ashblossom
	name = "ash blossom"
	desc = "A long purple and blue flower. Has a nice aroma to it."
	bite_consumption_mod = 1
	foodtypes = GROSS
	icon_state = "ashblossom"
	filling_color = "#213436"

///////////////////////// THISTLE ///////////////////////////

/datum/plant/ms13/thistle
	species = "vines"
	growing_color = "#a64e5a"
	name = "Thistles"
	harvest_icon = 1
	innate_genes =list(/datum/plant_gene/product_trait/stinging)
	seed_path = /obj/item/seeds/ms13/thistle
	product_path = /obj/item/food/grown/ms13/thistle
	//lifespan = 25
	base_endurance = 10
	base_maturation = 6
	base_production = 3
	base_harvest_amt = 5
	genome = 25
	growthstages = 3
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/thistle
	name = "thistle seeds"
	desc = "Some thistle seeds."
	plant_type = /datum/plant/ms13/thistle

/obj/item/food/grown/ms13/thistle
	plant_datum = /datum/plant/ms13/thistle
	name = "thistle"
	desc = "A purple star shaped prickly weed."
	bite_consumption_mod = 1
	foodtypes = GROSS
	icon_state = "thistle"
	filling_color = "#a64e5a"
	tastes = list("pain" = 5)

/obj/item/food/grown/ms13/thistle/pickup(mob/living/user)
	..()
	if(!iscarbon(user))
		return FALSE
	var/mob/living/carbon/C = user
	if(C.gloves)
		return FALSE
	if(HAS_TRAIT(C, TRAIT_PIERCEIMMUNE))
		return FALSE
	var/hit_zone = (C.held_index_to_dir(C.active_hand_index) == "l"? "l_":"r_") + "arm"
	var/obj/item/bodypart/affecting = C.get_bodypart(hit_zone)
	if(affecting)
		if(affecting.receive_damage(burn = 5))
			C.update_damage_overlays()
	to_chat(C, "<span class='userdanger'>The thistles sting your bare hand!</span>")
	return TRUE

////////////////////////// AGAVE ////////////////////////////

/datum/plant/ms13/agave
	species = "cactus2"
	growing_color = "#37524e"
	name = "Agave"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/agave
	product_path = /obj/item/food/grown/ms13/agave
	//lifespan = 170
	base_endurance = 55
	base_harvest_amt = 3
	growthstages = 4
	base_production = 16
	base_maturation = 99
	genome = 25
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/agave
	name = "agave spines"
	desc = "These seeds grow into the burn healing agave plant."
	plant_type = /datum/plant/ms13/agave

/obj/item/food/grown/ms13/agave
	plant_datum = /datum/plant/ms13/agave
	name = "agave"
	desc = "A fleshy blade of plant matter. Quite firm and feels as if it will snap easily."
	bite_consumption_mod = 1
	icon_state = "agave"
	filling_color = "#37524e"
	distill_reagent = /datum/reagent/consumable/ethanol/ms13/waster_tequila
	tastes = list("bitterness" = 5)

/////////////////////// BROC FLOWER /////////////////////////

/datum/plant/ms13/brocflower
	species = "flower"
	growing_color = "#88561c"
	name = "Broc Flowers"
	harvest_icon = 1
	seed_path = /obj/item/seeds/ms13/brocflower
	product_path = /obj/item/food/grown/ms13/brocflower
	//lifespan = 148
	base_endurance = 30
	base_maturation = 84
	base_production = 14
	base_harvest_amt = 2
	growthstages = 3
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/brocflower
	name = "broc flower seeds"
	desc = "These seeds grow into broc flowers."
	plant_type = /datum/plant/ms13/brocflower

/obj/item/food/grown/ms13/brocflower
	plant_datum = /datum/plant/ms13/brocflower
	name = "broc flower"
	desc = "A vibrant, orange flower. Very soft to the touch and easy to damage."
	bite_consumption_mod = 1
	icon_state = "brocflower"
	filling_color = "#493d28"
	tastes = list("broc" = 5)
	can_dry = TRUE
	dry_time = 480
	dried_type = /obj/item/ms13/dried/broc

/////////////////////////////////////////////////////////////
//////////////////////// FUNGUS /////////////////////////////
/////////////////////////////////////////////////////////////

//////////////////////// CAVE FUNGUS ///////////////////////////

/datum/plant/ms13/cavefungus
	species = "mushroom"
	icon_harvest = "mushroom-grow4"
	growing_color = "#cd6c4b"
	wholeiconcolor = TRUE
	name = "Cave Fungus Mushrooms"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/cavefungus
	product_path = /obj/item/food/grown/ms13/cavefungus
	//lifespan = 60
	base_endurance = 65
	base_harvest_amt = 3
	growthstages = 4
	base_production = 9
	base_maturation = 38
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/cavefungus
	name = "cave fungus spores"
	desc = "These spores grow into cave fungi."
	plant_type = /datum/plant/ms13/cavefungus

/obj/item/food/grown/ms13/cavefungus
	plant_datum = /datum/plant/ms13/cavefungus
	name = "cave fungus"
	desc = "A rather plain looking mushroom. Nothing about it stands out in particular."
	bite_consumption_mod = 1
	icon_state = "cavefungus"
	foodtypes = VEGETABLES
	filling_color = "#64553b"
	tastes = list("mushroom" = 5)

// GLOW FUNGUS

/datum/plant/ms13/glowfungus
	species = "mushroom"
	icon_harvest = "mushroom-grow4"
	growing_color = "#98b752"
	wholeiconcolor = TRUE
	name = "Glowfungus Mushrooms"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism, /datum/plant_gene/product_trait/glow/ms13green)
	seed_path = /obj/item/seeds/ms13/glowfungus
	product_path = /obj/item/food/grown/ms13/glowfungus
	//lifespan = 45
	base_endurance = 40
	base_harvest_amt = 3
	growthstages = 4
	base_production = 12
	base_maturation = 30
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/glowfungus
	name = "glow fungus spores"
	desc = "These spores grow into glowing cave fungi."
	plant_type = /datum/plant/ms13/glowfungus

/obj/item/food/grown/ms13/glowfungus
	plant_datum = /datum/plant/ms13/glowfungus
	name = "glow fungus"
	desc = "A glowing mushroom. Gives off a strange warmth even just looking at it."
	bite_consumption_mod = 1
	icon_state = "glowfungus"
	foodtypes = TOXIC
	filling_color = "#357944"
	tastes = list("mushroom" = 5, "warmth" = 5)
	light_outer_range = 2
	light_power = 0.25

/datum/plant_gene/product_trait/glow/ms13green
	name = "Radioactive Bioluminescence"
	rate = 0.01
	glow_color = "#50e650"

//////////////////////// BLIGHT /////////////////////////////

/datum/plant/ms13/blight
	species = "blight"
	icon_harvest = "blight-grow4"
	name = "Blight Fungus"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/blight
	product_path = /obj/item/food/grown/ms13/blight
	//lifespan = 75
	base_endurance = 65
	base_harvest_amt = 4
	growthstages = 4
	base_production = 11
	base_maturation = 46
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/blight
	name = "blight spores"
	desc = "These spores grow into the blight mushroom."
	plant_type = /datum/plant/ms13/blight

/obj/item/food/grown/ms13/blight
	plant_datum = /datum/plant/ms13/blight
	name = "blight mushroom"
	desc = "A dark, strange spotted mushroom. Has a thick trunk and is firm."
	bite_consumption_mod = 1
	icon_state = "blight"
	foodtypes = GROSS | TOXIC
	filling_color = "#575c2a"
	tastes = list("spice" = 5, "gunk" = 5)

////////////////////// BRAIN FUNGUS /////////////////////////

/datum/plant/ms13/brainfung
	species = "brainfung"
	icon_harvest = "brainfung-grow4"
	name = "Brain Fungus"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/brainfung
	product_path = /obj/item/food/grown/ms13/brainfung
	//lifespan = 48
	base_endurance = 35
	base_harvest_amt = 3
	growthstages = 4
	base_production = 12
	base_maturation = 30
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/brainfung
	name = "brain fungus spores"
	desc = "These spores grow into the brain fungus."
	plant_type = /datum/plant/ms13/brainfung

/obj/item/food/grown/ms13/brainfung
	plant_datum = /datum/plant/ms13/brainfung
	name = "brain fungus"
	desc = "An asymmetrically shaped flesh colored mushroom. Upon close examination, it looks like it has spines."
	bite_consumption_mod = 1
	foodtypes = GROSS | TOXIC
	icon_state = "brainfung"
	filling_color = "#c87070"
	tastes = list("illness" = 5)

/obj/item/food/grown/ms13/brainfung/pickup(mob/living/user)
	..()
	if(!iscarbon(user))
		return FALSE
	var/mob/living/carbon/C = user
	if(C.gloves)
		return FALSE
	if(HAS_TRAIT(C, TRAIT_PIERCEIMMUNE))
		return FALSE
	else
		C.adjustOrganLoss(ORGAN_SLOT_BRAIN, 5)
	to_chat(C, "<span class='userdanger'>The brainfungus pierces your hand!</span>")
	return TRUE

//////////////////////// FIRECAP ////////////////////////////

/datum/plant/ms13/firecap
	species = "mushroom"
	icon_harvest = "mushroom-grow4"
	growing_color = "#eb9320"
	wholeiconcolor = TRUE
	name = "Firecap Cluster"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/firecap
	product_path = /obj/item/food/grown/ms13/firecap
	//lifespan = 48
	base_endurance = 35
	base_harvest_amt = 3
	growthstages = 4
	base_production = 9
	base_maturation = 36
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/firecap
	name = "firecap spores"
	desc = "These spores grow into the firecap mushroom."
	plant_type = /datum/plant/ms13/firecap

/obj/item/food/grown/ms13/firecap
	plant_datum = /datum/plant/ms13/firecap
	name = "firecap"
	desc = "A red bubbly mushroom cap. You can almost see fluid moving in the boils."
	bite_consumption_mod = 1
	foodtypes = TOXIC
	icon_state = "firecap"
	filling_color = "#3f2e0f"
	tastes = list("fire" = 5, "mushroom" = 1)

/obj/item/food/grown/ms13/firecap/pickup(mob/living/user)
	..()
	if(!iscarbon(user))
		return FALSE
	var/mob/living/carbon/C = user
	if(C.gloves)
		return FALSE
	if(HAS_TRAIT(C, TRAIT_PIERCEIMMUNE))
		return FALSE
	var/hit_zone = (C.held_index_to_dir(C.active_hand_index) == "l"? "l_":"r_") + "arm"
	var/obj/item/bodypart/affecting = C.get_bodypart(hit_zone)
	if(affecting)
		if(affecting.receive_damage(burn = 25))
			C.update_damage_overlays()
	to_chat(C, "<span class='userdanger'>The firecap juice rubs off on your hand!</span>")
	return TRUE

//////////////////////// GUTSHROOM ////////////////////////////

/datum/plant/ms13/gutshroom
	species = "longshroom"
	icon_harvest = "longshroom-grow4"
	growing_color = "#a33b0c"
	wholeiconcolor = TRUE
	name = "Gutshroom Cluster"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/gutshroom
	product_path = /obj/item/food/grown/ms13/gutshroom
	//lifespan = 60
	base_endurance = 50
	base_harvest_amt = 3
	growthstages = 4
	base_production = 10
	base_maturation = 38
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/gutshroom
	name = "gutshroom spores"
	desc = "These spores grow into gutshrooms."
	plant_type = /datum/plant/ms13/gutshroom

/obj/item/food/grown/ms13/gutshroom
	plant_datum = /datum/plant/ms13/gutshroom
	name = "gutshroom"
	desc = "A red button shaped mushroom. Has visible secretion and appears to be filled with juice."
	bite_consumption_mod = 1
	foodtypes = GROSS | TOXIC
	icon_state = "gutshroom"
	filling_color = "#38372a"
	tastes = list("pain" = 5)

/obj/item/food/grown/ms13/gutshroom/pickup(mob/living/user)
	..()
	if(!iscarbon(user))
		return FALSE
	var/mob/living/carbon/C = user
	if(C.gloves)
		return FALSE
	if(HAS_TRAIT(C, TRAIT_PIERCEIMMUNE))
		return FALSE
	else
		C.adjustOrganLoss(ORGAN_SLOT_STOMACH, 100)
	to_chat(C, "<span class='userdanger'>The gutshroom secretes onto you!</span>")
	return TRUE

//////////////////////// LURE WEED //////////////////////////

/datum/plant/ms13/lureweed
	species = "lureweed"
	icon_harvest = "lureweed-grow4"
	growing_color = "#735d32"
	wholeiconcolor = TRUE
	name = "Lureweeds"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/lureweed
	product_path = /obj/item/food/grown/ms13/lureweed
	//lifespan = 75
	base_endurance = 55
	base_harvest_amt = 4
	growthstages = 4
	base_production = 10
	base_maturation = 50
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/lureweed
	name = "lureweed spores"
	desc = "These spores grow into the invasive lureweed."
	plant_type = /datum/plant/ms13/lureweed

/obj/item/food/grown/ms13/lureweed
	plant_datum = /datum/plant/ms13/lureweed
	name = "lureweed"
	desc = "A long and hard, fungus. It has a leather-like appearance."
	bite_consumption_mod = 8
	icon_state = "lureweed"
	filling_color = "#383322"
	tastes = list("lureweed" = 5)

////////////////////////// NARA /////////////////////////////

/datum/plant/ms13/nara
	species = "longshroom"
	icon_harvest = "longshroom-grow4"
	growing_color = "#3c729e"
	wholeiconcolor = TRUE
	name = "Nara Fungus"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/nara
	product_path = /obj/item/food/grown/ms13/nara
	//lifespan = 60
	base_endurance = 50
	base_harvest_amt = 3
	growthstages = 4
	base_production = 7
	base_maturation = 38
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/nara
	name = "nara spores"
	desc = "These spores grow into the nara fungus."
	plant_type = /datum/plant/ms13/nara

/obj/item/food/grown/ms13/nara
	plant_datum = /datum/plant/ms13/nara
	name = "nara fungus"
	desc = "A dark and fleshy mushroom. It has a strange stench to it."
	bite_consumption_mod = 2
	icon_state = "nara"
	filling_color = "#770d0d"
	tastes = list("blood" = 5)

////////////////////// FLY AMANITA //////////////////////////

/datum/plant/ms13/flyamanita
	species = "flyamanita"
	icon_harvest = "flyamanita-grow1"
	growing_color = "#672d13"
	wholeiconcolor = TRUE
	name = "Fly Amanita"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/flyamanita
	product_path = /obj/item/food/grown/ms13/flyamanita
	//lifespan = 48
	base_endurance = 35
	base_harvest_amt = 3
	growthstages = 1
	base_production = 12
	base_maturation = 30
	reagents_per_potency = list(/datum/reagent/toxin/ms13/flyamanita = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/flyamanita
	name = "fly amanita spores"
	desc = "These spores grow into the poisonous fly amanita."
	plant_type = /datum/plant/ms13/flyamanita

/obj/item/food/grown/ms13/flyamanita
	plant_datum = /datum/plant/ms13/flyamanita
	name = "fly amanita"
	desc = "A dark red mushroom with white spots looking like nib sugar."
	bite_consumption_mod = 1
	foodtypes = TOXIC
	icon_state = "flyamanita"
	filling_color = "#c87070"
	tastes = list("illness" = 5, "bitterness" = 5)

/////////////////////// PENNY BUN ///////////////////////////

/datum/plant/ms13/pennybun
	species = "pennybun"
	icon_harvest = "pennybun-grow1"
	growing_color = "#695433"
	wholeiconcolor = TRUE
	name = "Penny Bun"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/pennybun
	product_path = /obj/item/food/grown/ms13/pennybun
	//lifespan = 30
	base_endurance = 25
	base_harvest_amt = 3
	growthstages = 1
	base_production = 14
	base_maturation = 38
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/pennybun
	name = "penny bun spores"
	desc = "These spores grow into the tasty penny bun."
	plant_type = /datum/plant/ms13/pennybun

/obj/item/food/grown/ms13/pennybun
	plant_datum = /datum/plant/ms13/pennybun
	name = "penny bun"
	desc = "A fungus with a large brown cap and prized as an ingredient in various culinary dishes."
	bite_consumption_mod = 1
	foodtypes = VEGETABLES
	icon_state = "pennybun"
	filling_color = "#695433"
	tastes = list("succulent" = 5, "mushroom" = 5)

////////////////////// CHANTERELLE //////////////////////////

/datum/plant/ms13/chanterelle
	species = "chanterelle"
	icon_harvest = "chanterelle-grow1"
	growing_color = "#875a25"
	wholeiconcolor = TRUE
	name = "Chanterelle"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/chanterelle
	product_path = /obj/item/food/grown/ms13/chanterelle
	//lifespan = 48
	base_endurance = 35
	base_harvest_amt = 4
	growthstages = 1
	base_production = 12
	base_maturation = 38
	reagents_per_potency = list(/datum/reagent/consumable/nutriment/vitamin = 0.04, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "K"

/obj/item/seeds/ms13/chanterelle
	name = "chanterelle spores"
	desc = "These spores grow into the tasty chanterelle."
	plant_type = /datum/plant/ms13/chanterelle

/obj/item/food/grown/ms13/chanterelle
	plant_datum = /datum/plant/ms13/chanterelle
	name = "chanterelle"
	desc = "A funnel-shaped yellowish mushroom which emits a fruity aroma."
	bite_consumption_mod = 1
	foodtypes = VEGETABLES
	icon_state = "chanterelle"
	filling_color = "#875a25"
	tastes = list("savory" = 5, "fruity" = 5)

/////////////////////// MINDSHROOM //////////////////////////

/datum/plant/ms13/mindshroom
	species = "mindshroom"
	icon_harvest = "mindshroom-grow1"
	growing_color = "#4468b2"
	wholeiconcolor = TRUE
	name = "Mindshroom"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism, /datum/plant_gene/product_trait/glow/ms13blue)
	seed_path = /obj/item/seeds/ms13/mindshroom
	product_path = /obj/item/food/grown/ms13/mindshroom
	//lifespan = 40
	base_endurance = 30
	base_harvest_amt = 3
	growthstages = 1
	base_production = 18
	base_maturation = 45
	reagents_per_potency = list(/datum/reagent/ms13/day_tripper = 0.03, /datum/reagent/ms13/mentats = 0.03, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "N"

/obj/item/seeds/ms13/mindshroom
	name = "mindshroom spores"
	desc = "These spores grow into the glowing mindshroom."
	plant_type = /datum/plant/ms13/mindshroom

/obj/item/food/grown/ms13/mindshroom
	plant_datum = /datum/plant/ms13/mindshroom
	name = "mindshroom"
	desc = "A glowing mushroom. You feel something at the back of your mind just looking at it."
	bite_consumption_mod = 1
	foodtypes = TOXIC
	icon_state = "mindshroom"
	filling_color = "#4468b2"
	tastes = list("spicy" = 5, "mint" = 5)
	light_outer_range = 2
	light_power = 0.25

/datum/plant_gene/product_trait/glow/ms13blue
	name = "Psionic Bioluminescence"
	rate = 0.01
	glow_color = "#4468b2"

///////////////////// GREMLIN STOOL /////////////////////////

/datum/plant/ms13/gremlinstool
	species = "gremlinstool"
	icon_harvest = "gremlinstool-grow1"
	growing_color = "#7b704c"
	wholeiconcolor = TRUE
	name = "gremlinstool"
	innate_genes =list(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
	seed_path = /obj/item/seeds/ms13/gremlinstool
	product_path = /obj/item/food/grown/ms13/gremlinstool
	//lifespan = 48
	base_endurance = 35
	base_harvest_amt = 3
	growthstages = 1
	base_production = 15
	base_maturation = 30
	reagents_per_potency = list(/datum/reagent/toxin/ms13/gunpowder = 0.05, /datum/reagent/consumable/nutriment = 0.1)
	nutrient_type = "P"

/obj/item/seeds/ms13/gremlinstool
	name = "gremlinstool spores"
	desc = "These spores grow into the invigorating gremlin stool."
	plant_type = /datum/plant/ms13/gremlinstool

/obj/item/food/grown/ms13/gremlinstool
	plant_datum = /datum/plant/ms13/gremlinstool
	name = "gremlinstool"
	desc = "A yellow-dotted mushroom that oozes a grey liquid."
	bite_consumption_mod = 1
	foodtypes = TOXIC
	icon_state = "gremlinstool"
	filling_color = "#7b704c"
	tastes = list("creamy" = 5, "fire" = 5)
