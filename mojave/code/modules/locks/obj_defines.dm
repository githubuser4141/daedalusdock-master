//MOJAVE MODULAR BASE OBJ TWEAKS FILE//

//all these changes are for locks interacting ON structures, not the locks themselves
/obj
	//check if object is being picked if can be picked
	var/being_picked = FALSE
	//check if lock can be picked
	var/can_be_picked = TRUE
	//check if obj has lock and can be picked
	var/lock_locked = FALSE
	//tells the element what difficulty the objs picking is at (1 Master, 5 Expert, 10 Standard, 17 Novice, 20+ Beginner)
	var/lock_difficulty
	//allows for players to attach their own lock
	var/can_have_lock = FALSE
	//moves the lock to the obj so it can be taken off etc.
	var/obj/item/ms13/lock/lock
	//non-null means any key sharing this exact string unlocks/locks this obj too - lets one key
	//cover a whole group of containers instead of needing a separate key per container (doors keep
	//their own separate 1:1 matching_door WEAKREF system - see mojave/structures/doors.dm)
	var/lock_group

//for storage items that open when lockpicked
/obj/proc/unlock_storage()
	if(atom_storage)
		atom_storage.locked = FALSE //unlocks the storage
	return TRUE

//for denying access/interaction with general locked items
/obj/attack_hand(mob/user, list/modifiers)
	if(.)
		return
	if(ms13_flags_1 & LOCKABLE_1 && lock_locked)
		to_chat(user, span_warning("The [name] is locked."))
		return TRUE
	. = ..()

//for item interaction overrides on all general objects for placing locked items
/obj/attackby(obj/item/I, mob/living/user, params)
	if(lock_group && istype(I, /obj/item/ms13/key))
		var/obj/item/ms13/key/key = I
		if(key.lock_group == lock_group)
			if(lock_locked)
				lock_locked = FALSE
				if(lock)
					lock.item_lock_locked = FALSE
					lock.lock_open = TRUE
				RemoveElement(/datum/element/lockpickable)
				to_chat(user, span_notice("You unlock [src] with [key]."))
				playsound(src, 'mojave/sound/ms13effects/lock_close.ogg', 50, TRUE)
			else if(lock)
				lock.lock_open = FALSE
				lock.item_lock_locked = TRUE
				AddElement(/datum/element/lockpickable, lock.lock_difficulty)
				to_chat(user, span_notice("You lock [src] with [key]."))
				playsound(src, 'mojave/sound/ms13effects/lock_close.ogg', 50, TRUE)
			return
	if(I.item_flags & LOCKING_ITEM && ms13_flags_1 & LOCKABLE_1)
		if(lock_locked)
			to_chat(user, span_warning("The [name] already has a lock."))
			return
		if(!can_be_picked)
			return
		var/obj/item/ms13/lock/L = I
		if(!L.lock_open)
			to_chat(user, span_warning("The [name] is closed."))
			return
		if(!user.transferItemToLoc(L, src))
			return
		lock = I
		to_chat(user, span_notice("You attach the [lock.name] to the [name]."))
		update_appearance()
		return
	. = ..()

//for taking the lock off of objects if its open
/obj/attack_hand_secondary(mob/user, list/modifiers)
	if(.)
		return
	if(lock)
		if(lock.lock_open)
			var/list/choices = list("Close Lock", "Remove Lock")
			var/choice = tgui_input_list(user, "What do you wish to do to the lock?", "Lock Adjustment", choices)
			switch(choice)
				if("Close Lock")
					lock.lock_open = FALSE
					to_chat(user, span_notice("You close the [lock.name] not yet locked."))
					return
				if("Remove Lock")
					user.put_in_hands(lock)
					lock = null
					to_chat(user, span_notice("You take the [lock.name] off the [name]."))
					update_appearance()
					return
		if(!(lock.lock_open))
			if(lock.item_lock_locked)
				to_chat(user, span_notice("The [lock.name] is locked."))
				playsound(src, 'mojave/sound/ms13effects/door_locked.ogg', 20, TRUE)
				return
			if(!(lock.item_lock_locked))
				var/list/choices = list("Lock It", "Open Lock")
				var/choice = tgui_input_list(user, "What do you wish to do to the lock?", "Lock Adjustment", choices)
				switch(choice)
					if("Lock It")
						if(do_after(user, 0.5 SECONDS))
							to_chat(user, span_notice("You shut and clasp the [lock.name]."))
							lock.item_lock_locked = TRUE
							AddElement(/datum/element/lockpickable, lock.lock_difficulty)
							playsound(src, 'mojave/sound/ms13effects/lock_close.ogg', 50, TRUE)
							return
					if("Open Lock")
						lock.lock_open = TRUE
						to_chat(user, span_notice("You swing open the [lock.name], still attached to the door."))
						return
	. = ..()

//Lock on examine updates, for checking the lock states
/obj/examine(mob/user)
	. = ..()
	if(lock)
		if(lock.lock_open)
			. += "<u>The [lock.name] is open and able to be removed or closed.</u>."
		if(!(lock.lock_open) && !(lock.item_lock_locked))
			. += "<u>The [lock.name] is closed and able to be clasped shut or opened.</u>."
		if(!(lock.lock_open) && lock.item_lock_locked)
			. += "<u>The [lock.name] is closed and clasped shut.</u>."
		. += "<u>It seems fairly new compared to the things around it.</u>."
