//7.62

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a762)
	default_armor = FMJ_RIFLE

/obj/projectile/bullet/ms13/a762
	name = "7.62 bullet"
	icon_state = "bigroilfe_bullet"
	damage = 70

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a762/junk)
	default_armor = HP_RIFLE

/obj/projectile/bullet/ms13/a762/junk

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a762/ap)
	default_armor = AP_RIFLE

/obj/projectile/bullet/ms13/a762/ap

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a762/fmj)
	default_armor = FMJ_RIFLE

/obj/projectile/bullet/ms13/a762/fmj
	damage = 30

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a762/hv)
	default_armor = FMJ_RIFLE

/obj/projectile/bullet/ms13/a762/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RIFLE_VFAST

#warn standard: ap is more armored, junk is slower, hv is faster fmj, standard is softpoint, fmj is fmj

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a308)
	default_armor = SOFTPOINT_RIFLE

//.308
/obj/projectile/bullet/ms13/a308
	name = ".308 bullet"
	icon_state = "bigroilfe_bullet"
	damage = 80
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RIFLE

/obj/projectile/bullet/ms13/a308/junk
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_SMG

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a308/ap)
	default_armor = AP_RIFLE

/obj/projectile/bullet/ms13/a308/ap

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a308/fmj)
	default_armor = FMJ_RIFLE

/obj/projectile/bullet/ms13/a308/fmj
	damage = 80

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a308/hv)
	default_armor = FMJ_RIFLE

/obj/projectile/bullet/ms13/a308/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RIFLE_VFAST

//5.56

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a556)
	default_armor = SOFTPOINT_RIFLE

/obj/projectile/bullet/ms13/a556
	name = "5.56 bullet"
	icon_state = "medium_bullet"
	damage = 50
	bulletTipType = BULLET_SHARP

	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RIFLE_VFAST

/obj/projectile/bullet/ms13/a556/junk
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_SMG

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a556/ap)
	default_armor = AP_RIFLE

/obj/projectile/bullet/ms13/a556/ap

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a556/fmj)
	default_armor = FMJ_RIFLE

/obj/projectile/bullet/ms13/a556/fmj

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a556/hv)
	default_armor = FMJ_RIFLE

/obj/projectile/bullet/ms13/a556/hv
	speed =  BULLET_SPEED_BASELINE + BULLET_SPEED_INSANE

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a50MG)
	default_armor = GIANT_CAL_RIFLE

//50 BMG
/obj/projectile/bullet/ms13/a50MG
	name = ".50 BMG bullet"
	icon_state = "lightfifty_bullet"
	damage = 150
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RIFLE
	bulletTipType = BULLET_SHARP

TYPEINFO_DEF(/obj/projectile/bullet/ms13/a50MG/ap)
	default_armor = ANTI_MATERIEL

/obj/projectile/bullet/ms13/a50MG/ap

/obj/projectile/bullet/ms13/a50MG/hv
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RIFLE_VFAST

TYPEINFO_DEF(/obj/projectile/bullet/ms13/gauss)
	default_armor = ANTI_MATERIEL

//2mmEC
/obj/projectile/bullet/ms13/gauss
	icon_state = "gauss"
	damage = 200
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_RAILGUN
	bulletTipType = BULLET_ULTRASHARP
