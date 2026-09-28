// Species data for every den; the home point never changes its residents' diet or combat role.
// These vars have no effect on animals using their ordinary controller.
/mob/living/basic
	var/wildlife_size = 2
	var/wildlife_eats_meat = FALSE
	var/wildlife_eats_plants = FALSE
	var/wildlife_noise_flee_chance = 50
	var/wildlife_hostile_to_people = FALSE
	var/wildlife_ranged = FALSE
	/// Required advantage before voluntarily hunting; retaliation does not require this margin.
	var/wildlife_hunt_ratio = 1.5

/mob/living/basic/ms13/hostile_animal
	wildlife_eats_plants = TRUE

/mob/living/basic/ms13/hostile_animal/wolf
	wildlife_size = 3
	wildlife_eats_meat = TRUE
	wildlife_eats_plants = FALSE
	wildlife_noise_flee_chance = 65

/mob/living/basic/ms13/hostile_animal/hellpig
	wildlife_size = 6
	wildlife_eats_meat = TRUE
	wildlife_noise_flee_chance = 0

/mob/living/basic/ms13/hostile_animal/yaoguai
	wildlife_size = 5
	wildlife_eats_meat = TRUE
	wildlife_noise_flee_chance = 10

/mob/living/basic/ms13/hostile_animal/boar
	wildlife_size = 3
	wildlife_noise_flee_chance = 40

/mob/living/basic/ms13/hostile_animal/molerat
	wildlife_size = 1
	wildlife_noise_flee_chance = 90

/mob/living/basic/ms13/hostile_animal/pigrat
	wildlife_noise_flee_chance = 80

/mob/living/basic/ms13/hostile_animal/radroach
	wildlife_size = 1
	wildlife_eats_meat = TRUE
	wildlife_hunt_ratio = 3
	wildlife_noise_flee_chance = 95

/mob/living/basic/ms13/hostile_animal/gecko
	wildlife_eats_meat = TRUE
	wildlife_eats_plants = FALSE
	wildlife_noise_flee_chance = 75

/mob/living/basic/ms13/hostile_animal/gecko/ice
	wildlife_eats_plants = TRUE

/mob/living/basic/ms13/hostile_animal/giantant
	wildlife_eats_meat = TRUE
	wildlife_noise_flee_chance = 20

/mob/living/basic/ms13/hostile_animal/mantis
	wildlife_eats_meat = TRUE
	wildlife_eats_plants = FALSE
	wildlife_noise_flee_chance = 45

/mob/living/basic/ms13/hostile_animal/mirelurk
	wildlife_size = 4
	wildlife_eats_meat = TRUE
	wildlife_noise_flee_chance = 15

/mob/living/basic/ms13/ghoul
	wildlife_size = 3
	wildlife_eats_meat = TRUE
	wildlife_noise_flee_chance = 5
	wildlife_hostile_to_people = TRUE

/mob/living/basic/ms13/robot
	wildlife_size = 4
	wildlife_noise_flee_chance = 0
	wildlife_hostile_to_people = TRUE

/mob/living/basic/ms13/robot/handy/gun
	wildlife_ranged = TRUE

// The existing scorpion is a legacy simple_animal. This basic-mob counterpart reuses its art, balance and venom.
/mob/living/basic/ms13/hostile_animal/radscorpion
	name = "radscorpion"
	desc = "A large mutated scorpion with powerful pincers and a toxic stinger."
	icon = 'mojave/icons/mob/48x48.dmi'
	icon_state = "radscorpion"
	icon_dead = "radscorpion_dead"
	base_pixel_x = -8
	pixel_x = -8
	health = 135
	maxHealth = 135
	speed = 2
	melee_damage_lower = 20
	melee_damage_upper = 20
	subtractible_armour_penetration = 10
	sharpness = SHARP_IMPALING
	attack_verb_continuous = "stings"
	attack_verb_simple = "sting"
	attack_sound = list('mojave/sound/ms13npc/radscorp_attack1.ogg', 'mojave/sound/ms13npc/radscorp_attack2.ogg', 'mojave/sound/ms13npc/radscorp_attack3.ogg')
	deathsound = list('mojave/sound/ms13npc/radscorp_death1.ogg', 'mojave/sound/ms13npc/radscorp_death2.ogg')
	butcher_results = list(/obj/item/food/meat/slab/ms13/animal/rad_scorp = 2, /obj/item/ms13/animalitem/scorpion = 1)
	faction = list("insect")
	wildlife_size = 4
	wildlife_eats_meat = TRUE
	wildlife_eats_plants = FALSE
	wildlife_noise_flee_chance = 10
	var/poison_per_bite = 5

/mob/living/basic/ms13/hostile_animal/radscorpion/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/venomous, /datum/reagent/toxin, poison_per_bite)

/mob/living/basic/ms13/hostile_animal/radscorpion/desert
	name = "bark scorpion"
	icon = 'mojave/icons/mob/ms13animals.dmi'
	icon_state = "barkscorpion"
	icon_dead = "barkscorpion_dead"
	base_pixel_x = 0
	pixel_x = 0
	health = 90
	maxHealth = 90
	speed = 1.75
	subtractible_armour_penetration = 0
	butcher_results = list(/obj/item/food/meat/slab/ms13/animal/bark_scorp = 2)
	poison_per_bite = 3
	wildlife_size = 3
	wildlife_noise_flee_chance = 25

/obj/effect/spawner/ms13/wildlife_den/custom
	name = "custom den - choose animal_type"
	desc = "Choose any basic mob with animal_type. Its species determines diet, size and temperament; the den determines population and territory."

/obj/effect/spawner/ms13/wildlife_den/ants
	name = "wildlife den - giant ants"
	animal_type = /mob/living/basic/ms13/hostile_animal/giantant
	population = 5

/obj/effect/spawner/ms13/wildlife_den/scorpions
	name = "wildlife den - radscorpions"
	animal_type = /mob/living/basic/ms13/hostile_animal/radscorpion
	population = 2

/obj/effect/spawner/ms13/wildlife_den/scorpions/bark
	name = "wildlife den - bark scorpions"
	animal_type = /mob/living/basic/ms13/hostile_animal/radscorpion/desert

/obj/effect/spawner/ms13/wildlife_den/mantises
	name = "wildlife den - mantises"
	animal_type = /mob/living/basic/ms13/hostile_animal/mantis

/obj/effect/spawner/ms13/wildlife_den/mirelurks
	name = "wildlife den - mirelurks"
	animal_type = /mob/living/basic/ms13/hostile_animal/mirelurk
	population = 2

/obj/effect/spawner/ms13/wildlife_den/ghouls
	name = "ghoul lair - ferals"
	animal_type = /mob/living/basic/ms13/ghoul

/obj/effect/spawner/ms13/wildlife_den/ghouls/frozen
	name = "ghoul lair - frozen ferals"
	animal_type = /mob/living/basic/ms13/ghoul/frozen

/obj/effect/spawner/ms13/wildlife_den/ghouls/glowing
	name = "ghoul lair - glowing ferals"
	animal_type = /mob/living/basic/ms13/ghoul/radioactive
	population = 2

/obj/effect/spawner/ms13/wildlife_den/robots
	name = "robot depot - Mr. Handy"
	animal_type = /mob/living/basic/ms13/robot/handy
	population = 2

/obj/effect/spawner/ms13/wildlife_den/robots/saw
	name = "robot depot - saw Handies"
	animal_type = /mob/living/basic/ms13/robot/handy/saw

/obj/effect/spawner/ms13/wildlife_den/robots/gutsy
	name = "robot depot - Mr. Gutsy"
	animal_type = /mob/living/basic/ms13/robot/handy/gun

/obj/effect/spawner/ms13/wildlife_den/drought/random
	parent_type = /obj/effect/spawner/ms13/wildlife_den/custom
	name = "Drought den - random wildlife"
	animal_pool = list(/mob/living/basic/ms13/hostile_animal/molerat = 5, /mob/living/basic/ms13/hostile_animal/pigrat = 4, /mob/living/basic/ms13/hostile_animal/radroach = 4, /mob/living/basic/ms13/hostile_animal/giantant = 3, /mob/living/basic/ms13/hostile_animal/gecko/golden = 3, /mob/living/basic/ms13/hostile_animal/wolf = 2, /mob/living/basic/ms13/hostile_animal/radscorpion/desert = 2, /mob/living/basic/ms13/hostile_animal/hellpig = 1)
	population = 2

/obj/effect/spawner/ms13/wildlife_den/mammoth/random
	parent_type = /obj/effect/spawner/ms13/wildlife_den/custom
	name = "Mammoth den - random wildlife"
	animal_pool = list(/mob/living/basic/ms13/hostile_animal/molerat = 5, /mob/living/basic/ms13/hostile_animal/pigrat = 4, /mob/living/basic/ms13/hostile_animal/boar = 4, /mob/living/basic/ms13/hostile_animal/gecko/ice = 3, /mob/living/basic/ms13/hostile_animal/wolf = 2, /mob/living/basic/ms13/hostile_animal/yaoguai = 1)
	population = 2
