// Mojave-only variants keep the asteroid tuning out of DD's globally used mobs.
/mob/living/simple_animal/hostile/netherworld/migo/ms13_impact
	health = 140
	maxHealth = 140
	obj_damage = 30
	melee_damage_lower = 32
	melee_damage_upper = 52
	faction = list("cdda_surface_impact")

/mob/living/simple_animal/hostile/zombie/ms13_impact
	name = "shambling zombie"
	health = 150
	maxHealth = 150
	obj_damage = 25
	melee_damage_lower = 25
	melee_damage_upper = 30
	faction = list("cdda_surface_impact")
