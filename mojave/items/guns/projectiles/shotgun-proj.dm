/obj/projectile/bullet/pellet/ms13
	icon = 'mojave/icons/objects/projectiles/projectiles.dmi'
	icon_state = "buckshot"
	name = "base mojave sun shotgun pellet"
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL
	embedding = null

//12 gauge
TYPEINFO_DEF(/obj/projectile/bullet/pellet/ms13/buckshot)
	default_armor = BUCKSHOT
/obj/projectile/bullet/pellet/ms13/buckshot
	icon_state = "buckshot"
	name = "buckshot pellet"
	damage = 25
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL

/obj/projectile/bullet/pellet/ms13/buckshot/junk
	name = "junkshot pellet"
	speed = BULLET_SPEED_BASELINE + (BULLET_SPEED_PISTOL - 0.05)
	damage = 20

/obj/projectile/bullet/pellet/ms13/buckshot/triple
	name = "000 buckshot pellet"
	damage = 15

TYPEINFO_DEF(/obj/projectile/bullet/pellet/ms13/flechette)
	default_armor = ANTI_MATERIEL
/obj/projectile/bullet/pellet/ms13/flechette
	icon_state = "nail"
	name = "flechette dart"
	damage = 15

TYPEINFO_DEF(/obj/projectile/bullet/ms13/slug)
	default_armor = SLUG
/obj/projectile/bullet/ms13/slug
	icon_state = "slug"
	name = "12g slug"
	damage = 70
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL
