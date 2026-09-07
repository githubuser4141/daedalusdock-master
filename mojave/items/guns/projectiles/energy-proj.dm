// Laser Projectiles //

/obj/projectile/beam/ms13
	speed = 0.2 //Vanilla tg is 0.8
	var/damage_constant = 1
	damage = 0
	armor_penetration = 0
	eyeblur = 0

/obj/projectile/beam/ms13/laser
	name = "laser beam"
	range = 28
	hitscan = TRUE
	hitscan_light_color_override = COLOR_SOFT_RED
	muzzle_flash_color_override = COLOR_SOFT_RED
	impact_light_color_override = COLOR_SOFT_RED
	tracer_type = /obj/effect/projectile/tracer/ms13/laser
	muzzle_type = /obj/effect/projectile/muzzle/ms13/laser
	impact_type = /obj/effect/projectile/impact/ms13/laser
	hitscan_light_intensity = 2
	hitscan_light_range = 0.50
	muzzle_flash_intensity = 4
	muzzle_flash_range = 1
	impact_light_intensity = 5
	impact_light_range = 1.25

/obj/projectile/beam/ms13/laser/yellow
	hitscan_light_color_override = COLOR_YELLOW
	muzzle_flash_color_override = COLOR_YELLOW
	impact_light_color_override = COLOR_YELLOW
	tracer_type = /obj/effect/projectile/tracer/ms13/laser/yellow
	muzzle_type = /obj/effect/projectile/muzzle/ms13/laser/yellow
	impact_type = /obj/effect/projectile/impact/ms13/laser/yellow

/obj/projectile/beam/ms13/laser/wattz_pistol
	name = "weak laser beam"
	range = 21
	damage = 15
	subtractible_armour_penetration = 5

/obj/projectile/beam/ms13/laser/wattz_pistol/magneto
	name = "laser beam"
	range = 25
	damage = 15
	subtractible_armour_penetration = 20

/obj/projectile/beam/ms13/laser/stan_pistol
	name = "weak laser beam"
	range = 21
	damage = 20
	subtractible_armour_penetration = 15

/obj/projectile/beam/ms13/laser/wattz_rifle
	name = "weak laser beam"
	range = 28
	damage = 25
	subtractible_armour_penetration = 5

/obj/projectile/beam/ms13/laser/wattz_heavypistol
	name = "laser beam"
	range = 28
	damage = 25
	subtractible_armour_penetration = 15

/obj/projectile/beam/ms13/laser/sniper
	name = "concentrated laser beam"
	range = 36
	damage = 35
	subtractible_armour_penetration = 30

/obj/projectile/beam/ms13/laser/adv_rifle
	name = "concentrated laser beam"
	range = 28
	damage = 30
	subtractible_armour_penetration = 30

/obj/projectile/beam/ms13/laser/stan_rifle
	name = "laser beam"
	range = 28
	damage = 25
	subtractible_armour_penetration = 30

/obj/projectile/beam/ms13/laser/adv_pistol
	name = "laser beam"
	range = 21
	damage = 25
	subtractible_armour_penetration = 25

/obj/projectile/beam/ms13/laser/las_defender
	name = "laser beam"
	range = 21
	damage = 25
	subtractible_armour_penetration = 35

/obj/projectile/beam/ms13/laser/las_rcw
	name = "weak laser beam"
	range = 21
	damage = 15
	subtractible_armour_penetration = 25

/obj/projectile/beam/ms13/laser/scatter
	name = "scatter laser beam"
	range = 16
	damage = 15
	subtractible_armour_penetration = 35


// Laser Projectile Effects //

/obj/effect/projectile/impact/ms13/laser
	name = "laser impact"
	icon_state = "laser_impact"
	icon = 'mojave/icons/objects/projectiles/projectiles_impact.dmi'

/obj/effect/projectile/muzzle/ms13/laser
	name = "muzzle flash"
	icon_state = "laser_muzzle"
	icon = 'mojave/icons/objects/projectiles/projectiles_muzzle.dmi'

/obj/effect/projectile/tracer/ms13/laser
	name = "laser beam"
	icon_state = "laser"
	icon = 'mojave/icons/objects/projectiles/projectiles_tracer.dmi'

/obj/effect/projectile/impact/ms13/laser/blue
	icon_state = "institute_impact"

/obj/effect/projectile/muzzle/ms13/laser/blue
	icon_state = "institute_muzzle"

/obj/effect/projectile/tracer/ms13/laser/blue
	icon_state = "institute"

/obj/effect/projectile/impact/ms13/laser/yellow
	icon_state = "recharger_impact"

/obj/effect/projectile/muzzle/ms13/laser/yellow
	icon_state = "recharger_muzzle"

/obj/effect/projectile/tracer/ms13/laser/yellow
	icon_state = "recharger"


// Plasma Projectiles //

/obj/projectile/bullet/ms13/plasma
	name = "plasma bolt"
	icon = 'mojave/icons/objects/projectiles/projectiles.dmi'
	damage_type = BURN
	armor_flag = ENERGY // AI EDIT: flag doesn't exist - DD's real armor-check var name on projectiles
	icon_state = "plasma"
	armor_penetration = 0
	damage = 0
	speed = 0.95

/obj/projectile/bullet/ms13/plasma/stan_pistol
	damage = 30
	subtractible_armour_penetration = 5

/obj/projectile/bullet/ms13/plasma/adv_pistol
	name = "concentrated plasma bolt"
	damage = 35
	subtractible_armour_penetration = 25

/obj/projectile/bullet/ms13/plasma/plas_defender
	damage = 30
	subtractible_armour_penetration = 20

/obj/projectile/bullet/ms13/plasma/plas_carbine
	damage = 35
	subtractible_armour_penetration = 10

/obj/projectile/bullet/ms13/plasma/plas_rifle
	name = "concentrated plasma bolt"
	damage = 40
	subtractible_armour_penetration = 25

/obj/projectile/bullet/ms13/plasma/scatter
	name = "multiplas bolt"
	range = 21
	damage = 15
	subtractible_armour_penetration = 20
// Gauss Projectiles //

/obj/projectile/bullet/ms13/gauss
	name = "gauss bullet"
	icon = 'mojave/icons/objects/projectiles/projectiles.dmi'
	icon_state = "gauss"
	armor_penetration = 0
	damage = 0
	speed = 0.25

/obj/projectile/bullet/ms13/gauss/pistol
	damage = 30
	subtractible_armour_penetration = 60

/obj/projectile/bullet/ms13/gauss/rifle
	damage = 40
	subtractible_armour_penetration = 75

/obj/projectile/bullet/ms13/gauss/sniper
	damage = 35
	subtractible_armour_penetration = 65
