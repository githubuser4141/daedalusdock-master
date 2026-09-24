/obj/projectile
	/// Heard when what fires it has no sound of its own: a mob with no projectilesound, a turret with no fire_sound.
	var/fallback_fire_sound

// Each kind sounds like the guns that fire it.
/obj/projectile/bullet/ms13/c22
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/22/22pistol.ogg'
/obj/projectile/bullet/ms13/c9mm
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/9mm/9mm2.ogg'
/obj/projectile/bullet/ms13/c10mm
	fallback_fire_sound = 'mojave/sound/ms13weapons/10mm_fire_02.ogg'
/obj/projectile/bullet/ms13/c45
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/45/45auto1.ogg'
/obj/projectile/bullet/ms13/m12mm
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/12mm/m12mm1.ogg'
/obj/projectile/bullet/ms13/a357
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/357/357fire3.ogg'
/obj/projectile/bullet/ms13/m44
	fallback_fire_sound = 'mojave/sound/ms13weapons/44mag.ogg'
/obj/projectile/bullet/ms13/c4570
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/huntingrev/huntingrev5.ogg'
/obj/projectile/bullet/ms13/a556
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/service/service_3.ogg'
/obj/projectile/bullet/ms13/a762
	fallback_fire_sound = 'mojave/sound/ms13weapons/chinesearfire.ogg'
/obj/projectile/bullet/ms13/slug
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/caravan/caravan.ogg'
/obj/projectile/bullet/pellet/ms13
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/caravan/caravan.ogg'
/obj/projectile/bullet/ms13/gauss
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/gauss/gauss_fire_heavy.ogg'
/obj/projectile/bullet/ms13/plasma
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/plasrifle/plasma_3.ogg'
/obj/projectile/beam/ms13
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/laspistol/las_pistol_1.ogg'
/obj/projectile/energy/electrode/ms13
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/bb/wpn_bbgun_fire_2d.ogg'
/obj/projectile/bullet/bmg50
	fallback_fire_sound = 'mojave/sound/ms13weapons/gunsounds/amr/amrfire.ogg'
/obj/projectile/bullet/ms13/vehicle_autocannon
	fallback_fire_sound = 'mojave/sound/ms13vehicles/2a72.ogg'
/obj/projectile/bullet/cannonball/ms13_vehicle
	fallback_fire_sound = 'mojave/sound/ms13vehicles/artillery_outgoing.ogg'
/obj/projectile/bullet/pellet/ms13/buckshot/canister
	fallback_fire_sound = 'mojave/sound/ms13vehicles/artillery_outgoing.ogg'

/obj/projectile/bullet/ms13
	fallback_fire_sound = 'mojave/sound/ms13weapons/hunting_rifle.ogg'
	icon = 'mojave/icons/objects/projectiles/projectiles.dmi'
	icon_state = "medium_bullet"
	speed = 0.5 //Vanilla tg is 0.8
	wound_falloff_tile = 0
	embedding = null
	damage = 0

/obj/projectile/bullet/ms13/needle
	name = "needle"
	icon_state = "cbbolt"
	damage = 30
	armor_penetration = 30
	bullet_mass = 1

/* /obj/projectile/bullet/ms13/a762m
	damage = 0
	armor_penetration = 10

/obj/projectile/bullet/ms13/c4570SP
	damage = 45
	armor_penetration = 20*/
