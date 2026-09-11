//.44
TYPEINFO_DEF(/obj/projectile/bullet/ms13/m44)
	default_armor = HIGH_CAL_PISTOL
/obj/projectile/bullet/ms13/m44
	name = ".44 bullet"
	icon_state = "medium_bullet"
	damage = MAGNUM_DAMAGE
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_MAGNUM

/obj/projectile/bullet/ms13/m44/junk
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL

TYPEINFO_DEF(/obj/projectile/bullet/ms13/m44/ap)
	default_armor = HIGH_CAL_AP_PISTOL
/obj/projectile/bullet/ms13/m44/ap

/obj/projectile/bullet/ms13/m44/fmj
	damage = MAGNUM_DAMAGE

/obj/projectile/bullet/ms13/m44/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_SMG

//45-70
TYPEINFO_DEF(/obj/projectile/bullet/ms13/c4570)
	default_armor = HIGH_CAL_RIFLE
/obj/projectile/bullet/ms13/c4570
	name = ".45-70 bullet"
	icon_state = "medium_bullet"
	damage = BIG_RIFLE_DAMAGE
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_SMG

TYPEINFO_DEF(/obj/projectile/bullet/ms13/c4570/ap)
	default_armor = HIGH_CAL_AP_RIFLE
/obj/projectile/bullet/ms13/c4570/ap

/obj/projectile/bullet/ms13/c4570/fmj

/obj/projectile/bullet/ms13/c4570/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RIFLE

//.357
TYPEINFO_DEF(/obj/projectile/bullet/ms13/a357)
	default_armor = FMJ_PISTOL
/obj/projectile/bullet/ms13/a357
	name = ".357 bullet"
	icon_state = "medium_bullet"
	damage = MAGNUM_DAMAGE - 10
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_MAGNUM

/obj/projectile/bullet/ms13/a357/junk
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_PISTOL

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a357/ap)
	default_armor = AP_PISTOL
/obj/projectile/bullet/ms13/a357/ap

/obj/projectile/bullet/ms13/a357/fmj

/obj/projectile/bullet/ms13/a357/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_SMG
