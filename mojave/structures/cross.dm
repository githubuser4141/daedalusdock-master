#define VIABLE_MOB_CHECK(X) (isliving(X) && !issilicon(X) && !isbot(X))

/obj/structure/kitchenspike/ms13
	max_integrity = 200

/obj/structure/kitchenspike/ms13/crowbar_act(mob/living/user, obj/item/I)
	return

/obj/structure/kitchenspike/ms13/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/ms13/scrap(loc)
	qdel(src)

TYPEINFO_DEF(/obj/structure/kitchenspike/ms13/cross)
	default_armor = list(BLUNT = 15, PUNCTURE = 15, SLASH = 15, LASER = 20, ENERGY = 20, BOMB = 0, BIO = 100, FIRE = 40, ACID = 100)

/obj/structure/kitchenspike/ms13/cross
	name = "cross"
	icon = 'mojave/icons/structure/cross.dmi'
	icon_state = "cross"
	desc = "A makeshift cross, used for inhumane execution over time."
	anchored = TRUE
	max_integrity = 750
	bound_height = 64

/obj/structure/kitchenspike/ms13/cross/crowbar_act(mob/living/user, obj/item/I)
	if(has_buckled_mobs())
		to_chat(user, "<span class='notice'>You can't do that while something's on the cross!</span>")
		return FALSE
	if(I.use_tool(src, user, 20, volume=100))
		deconstruct()
	return TRUE

/obj/structure/kitchenspike/ms13/cross/deconstruct()
//	new /obj/item/stack/sheet/mineral/wood(src.loc, 10)
	qdel(src)

// AI EDIT: user.pulling/grab_state don't exist in DD - the old pull system was replaced with a grab_datum system
// (code/modules/grab/). The equivalent of "who/how hard is user currently grabbing" is
// user.get_active_grab().affecting / .current_grab.damage_stage (see e.g. code/modules/grab/human_grab.dm for the
// same GRAB_AGGRESSIVE comparison pattern in DD's own code).
// do_mob(user, target, time) doesn't exist in DD - confirmed against github.com/Mojave-Sun/mojave-sun-13
// (code/__HELPERS/mobs.dm) that this was the real signature there. DD consolidated do_mob/do_after_mob/do_after
// into a single /proc/do_after(user, target, time, timed_action_flags, ...) - same positional order, so this is a
// straight rename.
/obj/structure/kitchenspike/ms13/cross/attack_hand(mob/user)
	// get_active_grab() is /mob/living-specific; user.pulling/grab_state were being read just as loosely before
	var/mob/living/living_user = user
	var/obj/item/hand_item/grab/active_grab = living_user.get_active_grab()
	if(VIABLE_MOB_CHECK(active_grab?.affecting) && active_grab.current_grab.damage_stage == GRAB_AGGRESSIVE && !has_buckled_mobs())
		var/mob/living/L = active_grab.affecting
		if(do_after(user, src, 120))
			if(has_buckled_mobs()) //to prevent spam/queing up attacks
				return
			if(L.buckled)
				return
			if(living_user.get_active_grab()?.affecting != L)
				return
			playsound(src.loc, "sound/effects/ms13/crossed.ogg", 20, 1) // thanks hippie
			L.visible_message("<span class='danger'>[user] ties [L] to the cross!</span>", "<span class='userdanger'>[user] ties you to the cross!</span>")
			L.forceMove(drop_location())
			L.setDir(2)
			buckle_mob(L, force=1)
			L.pixel_y = 26
			L.overlays += image('mojave/icons/structure/cross.dmi', "lashing")
		to_chat(user, "<span class='danger'>You can't use that on the cross!</span>")
	else if (has_buckled_mobs())
		for(var/mob/living/L in buckled_mobs)
			user_unbuckle_mob(L, user)
	else
		..()

/obj/structure/kitchenspike/ms13/cross/user_unbuckle_mob(mob/living/buckled_mob, mob/living/carbon/human/user)
	if(buckled_mob && buckled_mob.buckled == src)
		var/mob/living/M = buckled_mob
		if(M != user)
			M.visible_message(\
				"[user] tries to pull [M] free of the [src]!",\
				"<span class='notice'>[user.name] is trying to pull you off the [src], opening up fresh wounds!</span>",\
				"<span class='italics'>You hear rope being unraveled.</span>")
			if(!do_after(user, 300, target = src))
				if(M && M.buckled)
					M.visible_message(\
					"[user] fails to free [M]!",\
					"<span class='notice'>[user] fails to pull you off of the [src].</span>")
				return

		else
			M.visible_message(\
			"<span class='warning'>[M] struggles to break free from the [src]!</span>",\
			"<span class='notice'>You struggle to break free from the [src], exacerbating your wounds! (Stay still for two minutes.)</span>",\
			"<span class='italics'>You hear violent scraping and struggling.</span>")
			M.adjustBruteLoss(20)
			if(!do_after(M, 5 MINUTES, target = src))
				if(M && M.buckled)
					to_chat(M, "<span class='warning'>You fail to free yourself!</span>")
				return
		if(!M.buckled)
			return
		untie_mob(M)

/obj/structure/kitchenspike/ms13/cross/proc/untie_mob(mob/living/M)
	M.pixel_y = "[initial(pixel_y)]"
	M.adjustBruteLoss(15)
	src.visible_message(text("<span class='danger'>[M] falls free of [src]!</span>"))
	unbuckle_mob(M,force=1)
	M.overlays -= image('mojave/icons/structure/cross.dmi', "lashing")

/obj/structure/kitchenspike/ms13/cross/Destroy()
	if(has_buckled_mobs())
		for(var/mob/living/L in buckled_mobs)
			untie_mob(L)
	return ..()

#undef VIABLE_MOB_CHECK
