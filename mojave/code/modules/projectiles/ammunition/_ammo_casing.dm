/obj/item/ammo_casing
	/// What this casing can be stacked into
	var/obj/item/ammo_box/magazine/stack_type
	/// TRUE if the ammo stack is generic and we should give it info based on the casing
	var/generic_stacking = TRUE
	/// Maximum size an ammo stack of this casing can reach
	var/stack_size = 20
	/// Used if we don't have a pre-made inventory sprite - Resorts to the barbaric methods of random gen icon state
	var/no_inventory_sprite = FALSE

/obj/item/ammo_casing/attackby(obj/item/attacking_item, mob/user, params)
	if(istype(attacking_item, /obj/item/ammo_box) && user.is_holding(src))
		add_fingerprint(user)
		var/obj/item/ammo_box/ammo_box = attacking_item
		var/obj/item/ammo_casing/other_casing = ammo_box.get_round(TRUE)
		if(try_stacking(other_casing, user))
			ammo_box.stored_ammo -= other_casing
			ammo_box.update_ammo_count()
		return
	else if(istype(attacking_item, /obj/item/ammo_box/magazine/ammo_stack))
		add_fingerprint(user)
		var/obj/item/ammo_box/magazine/ammo_stack = attacking_item
		if(isturf(loc))
			var/boolets = 0
			for(var/obj/item/ammo_casing/bullet in loc)
				if(bullet == src)
					continue
				if(!bullet.loaded_projectile)
					continue
				if(length(ammo_stack.stored_ammo) >= ammo_stack.max_ammo)
					break
				if(ammo_stack.give_round(bullet, FALSE))
					boolets++
					break
			if((boolets <= 0) && loaded_projectile && !(length(ammo_stack.stored_ammo) >= ammo_stack.max_ammo))
				if(ammo_stack.give_round(src, FALSE))
					boolets++
			if(boolets > 0)
				ammo_stack.update_ammo_count()
				to_chat(user, span_notice("You collect [boolets] shell\s. [ammo_stack] now contains [length(ammo_stack.stored_ammo)] shell\s."))
			else
				to_chat(user, span_warning("You fail to collect anything!"))
		return
	else if(istype(attacking_item, /obj/item/ammo_casing))
		try_stacking(attacking_item, user)
		return
	return ..()

/obj/item/ammo_casing/attackby_secondary(obj/item/weapon, mob/user, params)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return
	if(istype(weapon, /obj/item/ammo_box) || istype(weapon, /obj/item/ammo_casing))
		weapon.attackby(src, user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/item/ammo_casing/proc/try_stacking(obj/item/ammo_casing/other_casing, mob/living/user)
	if(user)
		add_fingerprint(user)
	if(!other_casing.stack_type)
		if(user)
			to_chat(user, span_warning("[other_casing] can't be stacked."))
		return
	if(!stack_type)
		if(user)
			to_chat(user, span_warning("[src] can't be stacked."))
		return
	if(caliber != other_casing.caliber)
		if(user)
			to_chat(user, span_warning("I can't stack different calibers."))
		return
	if(stack_type != other_casing.stack_type)
		if(user)
			to_chat(user, span_warning("I can't stack [other_casing] with [src]."))
		return
	if(!loaded_projectile || !other_casing.loaded_projectile)
		if(user)
			to_chat(user, span_warning("I can't stack empty casings."))
		return
	if((item_flags & IN_STORAGE) || (other_casing.item_flags & IN_STORAGE))
		if(user)
			to_chat(user, span_warning("Can't stack while casings while they are inside storage."))
		return
	var/obj/item/ammo_box/magazine/ammo_stack/ammo_stack = other_casing.stack_with(src)
	if(user)
		user.put_in_hands(ammo_stack)
		to_chat(user, span_notice("[src] has been stacked with [other_casing]."))
	return ammo_stack

/obj/item/ammo_casing/proc/stack_with(obj/item/ammo_casing/other_casing)
	var/obj/item/ammo_box/magazine/ammo_stack/ammo_stack = new stack_type(drop_location())
	if(generic_stacking)
		ammo_stack.name = "[caliber] rounds"
		ammo_stack.base_icon_state = initial(icon_state)
		if(istype(ammo_stack))
			ammo_stack.world_icon_state = initial(icon_state)
		ammo_stack.caliber = caliber
	ammo_stack.max_ammo = stack_size
	ammo_stack.no_inventory_sprite = no_inventory_sprite
	ammo_stack.give_round(src)
	ammo_stack.give_round(other_casing)
	ammo_stack.update_ammo_count()
	return ammo_stack

/obj/item/ammo_casing
	/// Spent casings of this type heaped here as this one object, rather than lying about loose.
	var/pile_size = 1

/obj/item/ammo_casing/bounce_away(still_warm = FALSE, bounce_delay = 3)
	. = ..()
	if(heavy_metal)
		addtimer(CALLBACK(src, PROC_REF(join_pile)), 1 SECONDS)

/obj/item/ammo_casing/fire_casing(atom/target, mob/living/user, params, distro, quiet, zone_override, spread, atom/fired_from)
	. = ..()
	// Fired from the ground, as mobs do, the spent casing is left there.
	if(. && isturf(loc))
		addtimer(CALLBACK(src, PROC_REF(join_pile)), 1 SECONDS)

/// Spent and on the ground, it joins a pile of its own type on its tile.
/obj/item/ammo_casing/proc/join_pile()
	if(loaded_projectile || !isturf(loc))
		return
	for(var/obj/item/ammo_casing/pile in loc)
		if(pile != src && pile.type == type && !pile.loaded_projectile)
			pile.pile_size += pile_size
			pile.update_appearance()
			qdel(src)
			return

/// Picking at a pile takes one casing out of it.
/obj/item/ammo_casing/attack_hand(mob/user, list/modifiers)
	if(pile_size <= 1 || !isturf(loc))
		return ..()
	var/obj/item/ammo_casing/taken = new type(loc)
	QDEL_NULL(taken.loaded_projectile)
	taken.update_appearance()
	pile_size--
	update_appearance()
	return taken.attack_hand(user, modifiers)

/obj/item/ammo_casing/examine(mob/user)
	. = ..()
	if(pile_size > 1)
		. += span_notice("There are [pile_size] of them piled up here.")

/obj/item/ammo_casing/update_overlays()
	. = ..()
	// A few drawn, however big the pile. Fixed spots, so it doesn't reshuffle as casings land.
	for(var/i in 1 to min(pile_size - 1, 8))
		var/mutable_appearance/casing = mutable_appearance(icon, icon_state)
		casing.pixel_x = (i * 7) % 13 - 6
		casing.pixel_y = (i * 5) % 11 - 5
		casing.dir = GLOB.alldirs[i]
		. += casing

#ifdef UNIT_TESTS
/// Spent casings of one type heap into one pile on their tile; another type or a live round stays apart.
/datum/unit_test/ms13_casing_piles/Run()
	var/turf/tile = run_loc_floor_bottom_left
	var/list/spent = list()
	for(var/i in 1 to 3)
		spent += allocate(/obj/item/ammo_casing/ms13/c45, tile)
	var/obj/item/ammo_casing/junk = allocate(/obj/item/ammo_casing/ms13/c45/junk, tile)
	var/obj/item/ammo_casing/live = allocate(/obj/item/ammo_casing/ms13/c45, tile)
	spent += junk
	for(var/obj/item/ammo_casing/casing as anything in spent)
		QDEL_NULL(casing.loaded_projectile)
		casing.join_pile()
	live.join_pile()
	var/obj/item/ammo_casing/pile = spent[1]
	if(!(QDELETED(spent[2]) && QDELETED(spent[3]) && pile.pile_size == 3))
		Fail("Spent casings of one type did not heap into one pile.")
	if(QDELETED(junk) || junk.pile_size != 1)
		Fail("A different type of casing joined the pile.")
	if(QDELETED(live) || live.pile_size != 1)
		Fail("A live round joined a pile of spent casings.")
	var/mob/living/carbon/human/consistent/picker = allocate(/mob/living/carbon/human/consistent, tile)
	pile.attack_hand(picker)
	var/obj/item/ammo_casing/held = picker.get_active_held_item()
	if(!(pile.pile_size == 2 && istype(held, /obj/item/ammo_casing/ms13/c45) && !held.loaded_projectile && held.pile_size == 1))
		Fail("Picking at a pile did not take one spent casing out of it.")
#endif
