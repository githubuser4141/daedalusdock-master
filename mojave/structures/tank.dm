TYPEINFO_DEF(/obj/structure/ms13/tank)
	default_armor = list(BLUNT = 50, PUNCTURE = 25, LASER = 50, ENERGY = 60, BOMB = 40, BIO = 100, FIRE = 40, ACID = 100)

/obj/structure/ms13/tank
	name = "storage tank"
	desc = "A large empty storage tank. The contents have long since evaporated."
	icon = 'mojave/icons/structure/tank.dmi'
	icon_state = "largetank"
	max_integrity = 300
	density = TRUE
	anchored = TRUE

/obj/structure/ms13/tank/pipe
	name = "piped storage tank"
	desc = "A large chemical storage tank with pipes running from it. They don't seem to be attached."
	icon_state = "largetank_pipe"

/obj/structure/ms13/tank/chemical
	name = "chemical storage tank"
	desc = "A large chemical storage tank. It's covered in forboding symbols."
	icon_state = "largetank_chemical"

TYPEINFO_DEF(/obj/structure/ms13/tank/chemical/huge)
	default_armor = list(BLUNT = 50, PUNCTURE = 30, LASER = 50, ENERGY = 60, BOMB = 40, BIO = 100, FIRE = 40, ACID = 100)

/obj/structure/ms13/tank/chemical/huge
	name = "huge chemical storage tank"
	desc = "A huge chemical storage tank with pipes running from it. It's covered in forboding symbols."
	icon_state = "largetank_chemical_huge"
	pixel_x = -9

/obj/structure/ms13/tank/chemical/container
	name = "chemical container tank"
	desc = "A wide chemical container tank. It has one giant forboding symbol in the middle."
	icon_state = "chemical_container"
	bound_width = 64

/obj/structure/ms13/tank/chemical/container/broken
	name = "chemical container tank"
	desc = "A wide chemical container tank. It has one giant forboding symbol in the middle, it also appears it has exploded from the inside."
	icon_state = "chemical_container_broken"

TYPEINFO_DEF(/obj/structure/ms13/tank/massive)
	default_armor = list(BLUNT = 50, PUNCTURE = 35, LASER = 50, ENERGY = 60, BOMB = 40, BIO = 100, FIRE = 40, ACID = 100)

/obj/structure/ms13/tank/massive
	name = "massive storage tank"
	desc = "A massive empty storage tank. The contents have long since evaporated."
	icon = 'mojave/icons/structure/tank_large.dmi'
	icon_state = "big_tank"
	bound_width = 96

/obj/structure/ms13/tank/massive/broken
	name = "massive storage tank"
	desc = "A massive empty storage tank. It appears that it's contents have exploded it inside out."
	icon_state = "big_tank_broken"
