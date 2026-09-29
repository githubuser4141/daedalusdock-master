TYPEINFO_DEF(/obj/machinery/door/airlock/ms13)
	default_armor = list(BLUNT = 90, PUNCTURE = 90, SLASH = 90, LASER = 100, ENERGY = 100, BOMB = 50, BIO = 100, FIRE = 75, ACID = 75)

/obj/machinery/door/airlock/ms13
	name = "mechanical door"
	desc = "The very pinnacle of door technology. Even after all this time, still usually reliably opens and closes! Don't stick your head in it."
	icon = 'mojave/icons/objects/airlocks/generic.dmi'
	overlays_file = 'mojave/icons/objects/airlocks/overlays.dmi'
	normal_integrity = 800 // big metal door
	security_level = 1
	layer = 4.5
	closingLayer = CLOSED_DOOR_LAYER
	hackProof = TRUE
	ms13_flags_1 = LOCKABLE_1
	doorOpen = 'mojave/sound/ms13machines/doorblast_open.ogg'
	doorClose = 'mojave/sound/ms13machines/doorblast_close.ogg'
	assemblytype = /obj/item/stack/sheet/ms13/scrap/two
	resistance_flags = INDESTRUCTIBLE
	hitted_sound = 'mojave/sound/ms13effects/impact/metal/metal_generic_2.wav'
	/// Time to pull an unpowered, unsecured door open by hand.
	var/manual_open_time = 10 SECONDS

// AI EDIT: Bumped() doesn't exist in DD - renamed to BumpedBy() (code/game/atom/atoms.dm), same single-arg signature
/obj/machinery/door/airlock/ms13/BumpedBy(atom/movable/AM)
	return

//TEMP AIRLOCK LOCKING (will be replaced by hacking)
/obj/machinery/door/airlock/ms13/attackby(obj/item/I, mob/living/M, params)
	. = ..()
	if(locked && !(M.combat_mode))
		to_chat(M, "<span class='warning'> The [name] is locked.</span>")
		playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 50, TRUE)
		return

/obj/machinery/door/airlock/ms13/attack_hand(mob/living/M)
	if(locked)
		to_chat(M, "<span class='warning'> The [name] is locked.</span>")
		playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 50, TRUE)
		return
	if(ms13_flags_1 & LOCKABLE_1 && lock_locked)
		to_chat(M, span_warning("The [name] is locked."))
		playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 50, TRUE)
		return
	if(density && !hasPower())
		if(prying_so_hard || !can_manually_open(M))
			return
		prying_so_hard = TRUE
		to_chat(M, span_notice("You begin slowly pulling [src] open..."))
		var/finished = do_after(M, src, manual_open_time, extra_checks = CALLBACK(src, PROC_REF(can_manually_open), M))
		prying_so_hard = FALSE
		if(finished && can_manually_open(M))
			return open(2)
		return
	. = ..()

/obj/machinery/door/airlock/ms13/proc/can_manually_open(mob/living/user)
	return !QDELETED(src) && density && !hasPower() && !operating && !locked && !welded && !seal && !lock_locked && user.canUseTopic(src, USE_CLOSE|USE_DEXTERITY)

/obj/machinery/door/airlock/ms13/screwdriver_act(mob/living/user, obj/item/tool)
	return

//// Town Doors ////

/obj/machinery/door/airlock/ms13/town

/obj/machinery/door/airlock/ms13/town/mayor
	req_access = list(ACCESS_TOWN_MAYOR)

/obj/machinery/door/airlock/ms13/town/security
	req_access = list(ACCESS_TOWN_LAW)

/obj/machinery/door/airlock/ms13/town/doctor
	req_access = list(ACCESS_TOWN_DOCTOR)

/obj/machinery/door/airlock/ms13/town/worker
	req_access = list(ACCESS_TOWN_WORKER)

/obj/machinery/door/airlock/ms13/town/all
	req_access = list(ACCESS_TOWN_ALL)

//// Brotherhood doors ////

/obj/machinery/door/airlock/ms13/brotherhood
	req_access = list(ACCESS_BROTHERHOOD)

/obj/machinery/door/airlock/ms13/brotherhood/hpaladin
	req_access = list(ACCESS_BROTHERHOOD, ACCESS_BROTHERHOOD_HPALADIN)


//// Barony doors ////

/obj/machinery/door/airlock/ms13/barony
	req_access = list(ACCESS_BARONY_RESTRICTED)

/obj/machinery/door/airlock/ms13/barony/quarters
	req_access = list(ACCESS_BARON_QUARTERS)

/obj/machinery/door/airlock/ms13/barony/doctor
	req_access = list(ACCESS_BARONY_DOCTOR)
