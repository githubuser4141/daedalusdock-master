//.45
TYPEINFO_DEF(/obj/projectile/bullet/ms13/c45)
	default_armor = FMJ_PISTOL
/obj/projectile/bullet/ms13/c45
	name = ".45 bullet"
	icon_state = "merehandgun_bullet"
	damage = MAGNUM_DAMAGE
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL
	bullet_mass = 2

/obj/projectile/bullet/ms13/c45/junk
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_SLOWER

/obj/projectile/bullet/ms13/c45/fmj

TYPEINFO_DEF(/obj/projectile/bullet/ms13/c45/ap)
	default_armor = AP_PISTOL
/obj/projectile/bullet/ms13/c45/ap

/obj/projectile/bullet/ms13/c45/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_MAGNUM

//.22
TYPEINFO_DEF(/obj/projectile/bullet/ms13/c22)
	default_armor = FMJ_PISTOL
/obj/projectile/bullet/ms13/c22
	name = ".22 bullet"
	icon_state = "merehandgun_bullet"
	damage = COMPACTPISTOL_DAMAGE
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL
	bullet_mass = 1

/obj/projectile/bullet/ms13/c22/junk
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_SLOWER

/obj/projectile/bullet/ms13/c22/fmj

TYPEINFO_DEF(/obj/projectile/bullet/ms13/c22/ap)
	default_armor = AP_PISTOL
/obj/projectile/bullet/ms13/c22/ap

/obj/projectile/bullet/ms13/c22/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_MAGNUM

//9mm
TYPEINFO_DEF(/obj/projectile/bullet/ms13/c9mm)
	default_armor = FMJ_PISTOL
/obj/projectile/bullet/ms13/c9mm
	name = "9mm bullet"
	icon_state = "merehandgun_bullet"
	damage = PISTOL_DAMAGE
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL
	bullet_mass = 1

/obj/projectile/bullet/ms13/c9mm/junk
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_SLOWER

/obj/projectile/bullet/ms13/c9mm/fmj

TYPEINFO_DEF(/obj/projectile/bullet/ms13/c9mm/ap)
	default_armor = AP_PISTOL
/obj/projectile/bullet/ms13/c9mm/ap

/obj/projectile/bullet/ms13/c9mm/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_MAGNUM

//10mm
/obj/projectile/bullet/ms13/c10mm
	name = "10mm bullet"
	icon_state = "merehandgun_bullet"
	damage = 25
	subtractible_armour_penetration = 15
	bullet_mass = 2

/obj/projectile/bullet/ms13/c10mm/junk
	subtractible_armour_penetration = 5

/obj/projectile/bullet/ms13/c10mm/ap
	subtractible_armour_penetration = 30

/obj/projectile/bullet/ms13/c10mm/fmj
	damage = 30

/obj/projectile/bullet/ms13/c10mm/hv
	speed = 0.4

//12.7mm
/obj/projectile/bullet/ms13/m12mm
	name = "12.7mm bullet"
	icon_state = "medium_bullet"
	damage = 40
	subtractible_armour_penetration = 35
	bullet_mass = 3

/obj/projectile/bullet/ms13/m12mm/ap
	subtractible_armour_penetration = 45

/obj/projectile/bullet/ms13/m12mm/fmj
	damage = 45

/obj/projectile/bullet/ms13/m12mm/hv
	speed = 0.4
