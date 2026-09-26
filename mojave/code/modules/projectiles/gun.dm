/obj/item/gun
	/// A multiplier of the duration the recoil takes to go back to normal view, this is (recoil*recoil_backtime_multiplier)+1
	var/recoil_backtime_multiplier = 2
	/// This is how much deviation the gun recoil can have, recoil pushes the screen towards the reverse angle you shot + some deviation which this is the max.
	var/recoil_deviation = 22.5

// An ammo_stack (mojave/code/modules/projectiles/boxes_magazines/ammo_stack.dm) is itself a subtype of
// /obj/item/ammo_box/magazine (deliberately, to reuse magazine behavior) - which means DD's core
// /obj/item/gun/ballistic/attackby() (code/modules/projectiles/guns/ballistic.dm) matches it against
// its "insert this as a whole replacement magazine" branch before ever reaching the "load loose rounds
// from a box/casing" branch below it. With a magazine already loaded, that branch just refuses with
// "There is already a magazine" and the loose rounds never transfer in at all. Intercept ammo_stack
// specifically before calling the core proc so it goes through the same round-loading path a loose
// casing or ammo_box would.
/obj/item/gun/ballistic/attackby(obj/item/A, mob/user, params)
	if(magazine && istype(A, /obj/item/ammo_box/magazine/ammo_stack))
		var/num_loaded = magazine.attempt_load_round(A, user, params, TRUE)
		if(num_loaded)
			to_chat(user, span_notice("You load [num_loaded] [cartridge_wording]\s into [src]."))
			playsound(src, load_sound, load_sound_volume, load_sound_vary, SHORT_RANGE_SOUND_EXTRARANGE)
			bolt.loaded_ammo()
			A.update_appearance()
			update_appearance()
		return TRUE
	return ..()

/// A long gun slings over a suit that takes guns, however big it is. Suit storage otherwise stops at bulky, and MS13's
/// rifles and shotguns are huge, so every loadout that slung one lost it at spawn.
/datum/species/can_equip(obj/item/I, slot, disable_warning, mob/living/carbon/human/H, bypass_equip_delay_self = FALSE, ignore_equipped = FALSE)
	if(slot == ITEM_SLOT_SUITSTORE && istype(I, /obj/item/gun) && !(slot & no_equip_flags) && H.wear_suit && is_type_in_list(I, H.wear_suit.allowed))
		return (ignore_equipped || !H.get_item_by_slot(slot)) && !HAS_TRAIT(I, TRAIT_NODROP)
	return ..()

// Gun handling, after Hail-Mary's: what a gun asks of whoever holds it, fire modes, mods, and heat, wear and jams.
// Every number is a plain var on the gun, the mod or the fire mode, so a gun or mod is tuned by setting its own vars.

/// Spread for each point of Strength or Intelligence a gun needs that its shooter is short of.
#define GUN_SHORTFALL_SPREAD 4
/// Kick for each point of Strength short.
#define GUN_SHORTFALL_RECOIL 0.5
/// Fired one-handed, every gun spreads GUN_ONE_HAND_SPREAD more. One that wants two hands (a medium or heavy
/// weapon_weight) spreads and kicks more again, as much as its shooter's Strength lets it: all of it at average, down to
/// GUN_ONE_HAND_FLOOR of it at the Strength its weight wants (a strong body's for medium, a power armor frame's for heavy).
#define GUN_ONE_HAND_SPREAD 5
#define GUN_ONE_HAND_SPREAD_MEDIUM 10
#define GUN_ONE_HAND_SPREAD_HEAVY 25
#define GUN_ONE_HAND_RECOIL_MEDIUM 1
#define GUN_ONE_HAND_RECOIL_HEAVY 2
#define GUN_ONE_HAND_STRENGTH_MEDIUM 10
#define GUN_ONE_HAND_STRENGTH_HEAVY 13
#define GUN_ONE_HAND_FLOOR 0.25
/// Each shot's kick builds up on the shooter, spreading the shots after it GUN_RECOIL_SPREAD a point, up to
/// GUN_RECOIL_MAX points. Held fire, it settles by half each second and GUN_RECOIL_SETTLE more.
#define GUN_RECOIL_SPREAD 3
#define GUN_RECOIL_MAX 10
#define GUN_RECOIL_SETTLE 1
/// Tiles each shot floats the view back along it, for each point of its kick and of the recoil built up.
#define GUN_RECOIL_FLOAT 0.04

/// Where on a gun a mod goes. A gun takes one mod in each slot it has (mod_slots).
#define GUN_MOD_BARREL "barrel"
#define GUN_MOD_MUZZLE "muzzle"
#define GUN_MOD_TRIGGER "trigger"
#define GUN_MOD_STOCK "stock"
#define GUN_MOD_UNDERBARREL "underbarrel"
#define GUN_MOD_SCOPE "scope"

/obj/item/gun
	/// Strength (the body's, or a power armor frame's) it takes to handle well. Short of it, it still fires, but wider
	/// and kicking harder.
	var/strength_to_handle = 0
	/// Intelligence it takes to work well. Short of it, it still fires, but wider.
	var/intelligence_to_handle = 0
	// One-handed, it spreads and kicks by its weight and its shooter's Strength, unless a gun sets these itself.
	unwielded_spread_bonus = null
	unwielded_recoil = null
	var/tmp/one_hand_by_weight = FALSE
	/// The ways it can fire, /datum/gun_firemode types, starting with the first. Two or more and it can switch.
	var/list/firemodes
	var/firemode_index = 1
	/// The mod slots it has, and what's in them: slot = mod.
	var/list/mod_slots = list(GUN_MOD_BARREL, GUN_MOD_MUZZLE, GUN_MOD_TRIGGER, GUN_MOD_STOCK, GUN_MOD_UNDERBARREL, GUN_MOD_SCOPE)
	var/list/mods
	/// What its mods do to heat per shot and to its odds of jamming (see /obj/item/gun/ballistic).
	var/tmp/heat_mult = 1
	var/tmp/jam_mult = 1
	// Its own handling, before fire modes and mods: taken when they first change it.
	var/tmp/base_spread
	var/tmp/base_recoil
	var/tmp/base_unwielded_recoil
	var/tmp/base_fire_delay
	var/tmp/base_burst_size
	var/tmp/base_damage_mult
	var/tmp/base_slowdown
	var/tmp/base_suppressed

/obj/item/gun/Initialize(mapload)
	if(length(firemodes) > 1)
		actions_types = (actions_types || list()) + /datum/action/item_action/gun_firemode
	. = ..()
	if(isnull(unwielded_spread_bonus))
		unwielded_spread_bonus = GUN_ONE_HAND_SPREAD
		one_hand_by_weight = weapon_weight != WEAPON_LIGHT
	if(isnull(unwielded_recoil))
		unwielded_recoil = recoil
	if(length(firemodes))
		refresh_handling()

/obj/item/gun/Destroy()
	for(var/slot in mods)
		qdel(mods[slot])
	mods = null
	return ..()

/// Of the extra spread and kick a gun that wants two hands has one-handed, the share this shooter feels.
/obj/item/gun/proc/one_hand_share(mob/living/user)
	var/wants = weapon_weight == WEAPON_HEAVY ? GUN_ONE_HAND_STRENGTH_HEAVY : GUN_ONE_HAND_STRENGTH_MEDIUM
	return max(1 - (1 - GUN_ONE_HAND_FLOOR) * (user.get_body_strength() - SPECIAL_BASELINE) / (wants - SPECIAL_BASELINE), GUN_ONE_HAND_FLOOR)

/// Spread the shooter adds: short of what the gun needs, one-handed with a gun that wants two, and recoil built up.
/obj/item/gun/proc/handling_spread(mob/living/user)
	if(!isliving(user))
		return 0
	. = (max(strength_to_handle - user.get_body_strength(), 0) + max(intelligence_to_handle - user.get_special(SPECIAL_INTELLIGENCE), 0)) * GUN_SHORTFALL_SPREAD
	. += user.current_gun_recoil() * GUN_RECOIL_SPREAD
	if(!wielded && one_hand_by_weight)
		. += (weapon_weight == WEAPON_HEAVY ? GUN_ONE_HAND_SPREAD_HEAVY : GUN_ONE_HAND_SPREAD_MEDIUM) * one_hand_share(user)

/// How hard a shot kicks its shooter: the gun's own, and more short of its Strength or one-handed with it.
/obj/item/gun/proc/shot_kick(mob/living/user)
	. = wielded ? recoil : unwielded_recoil
	if(!isliving(user))
		return
	. += max(strength_to_handle - user.get_body_strength(), 0) * GUN_SHORTFALL_RECOIL
	if(!wielded && one_hand_by_weight)
		. += (weapon_weight == WEAPON_HEAVY ? GUN_ONE_HAND_RECOIL_HEAVY : GUN_ONE_HAND_RECOIL_MEDIUM) * one_hand_share(user)

/obj/item/gun/do_fire_gun(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	return ..(target, user, message, params, zone_override, bonus_spread + handling_spread(user))

/obj/item/gun/after_firing(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = 1)
	. = ..()
	if(!isliving(user) || tk_firing(user))
		return
	var/kick = shot_kick(user)
	// The view floats back along the shot, the further the more recoil has built up, and settles.
	if(kick && pbtarget)
		recoil_camera(user, 1, kick * recoil_backtime_multiplier + 1, (kick + user.current_gun_recoil()) * GUN_RECOIL_FLOAT, get_angle(pbtarget, user) + rand(-recoil_deviation, recoil_deviation))
	user.add_gun_recoil(kick)

/mob/living
	/// Recoil built up from firing, spreading the shots after it until it settles.
	var/tmp/gun_recoil = 0
	var/tmp/gun_recoil_time = 0

/// The recoil built up now, having settled since the last shot.
/mob/living/proc/current_gun_recoil()
	var/seconds = (world.time - gun_recoil_time) / (1 SECONDS)
	gun_recoil = max(gun_recoil * 0.5 ** seconds - GUN_RECOIL_SETTLE * seconds, 0)
	gun_recoil_time = world.time
	return gun_recoil

/mob/living/proc/add_gun_recoil(amount)
	gun_recoil = min(current_gun_recoil() + amount, GUN_RECOIL_MAX)

/// Sets its handling from its own, its fire mode's and its mods'.
/obj/item/gun/proc/refresh_handling()
	if(isnull(base_spread))
		base_spread = spread
		base_recoil = recoil
		base_unwielded_recoil = unwielded_recoil
		base_fire_delay = fire_delay
		base_burst_size = burst_size
		base_damage_mult = projectile_damage_multiplier
		base_slowdown = slowdown
		base_suppressed = suppressed
	var/spread_mult = 1
	var/recoil_mult = 1
	var/delay_mult = 1
	var/damage_mult = 1
	var/slowdown_add = 0
	var/quiet = FALSE
	heat_mult = 1
	jam_mult = 1
	for(var/slot in mods)
		var/obj/item/gun_mod/mod = mods[slot]
		spread_mult *= mod.spread_mult
		recoil_mult *= mod.recoil_mult
		delay_mult *= mod.fire_delay_mult
		damage_mult *= mod.damage_mult
		slowdown_add += mod.slowdown_add
		heat_mult *= mod.heat_mult
		jam_mult *= mod.jam_mult
		quiet ||= mod.suppresses
	spread = base_spread * spread_mult
	recoil = base_recoil * recoil_mult
	unwielded_recoil = base_unwielded_recoil * recoil_mult
	projectile_damage_multiplier = base_damage_mult * damage_mult
	slowdown = base_slowdown + slowdown_add
	suppressed = quiet || base_suppressed
	var/datum/gun_firemode/mode = length(firemodes) ? firemodes[firemode_index] : null
	burst_size = mode ? initial(mode.burst_size) : base_burst_size
	fire_delay = (mode && !isnull(initial(mode.fire_delay)) ? initial(mode.fire_delay) : base_fire_delay) * delay_mult
	var/datum/component/automatic_fire/auto = GetComponent(/datum/component/automatic_fire)
	if(mode)
		if(!initial(mode.auto_delay))
			qdel(auto)
		else if(auto)
			auto.autofire_shot_delay = initial(mode.auto_delay) * delay_mult
		else
			AddComponent(/datum/component/automatic_fire, initial(mode.auto_delay) * delay_mult)
	else if(auto && fire_delay)
		auto.autofire_shot_delay = fire_delay
	if(ismob(loc))
		var/mob/holder = loc
		holder.update_equipment_speed_mods()

/**
 * A way a gun fires. A gun lists the ones it has (firemodes) and switches between them with a button; make a new one as
 * a subtype, setting only what it changes.
 */
/datum/gun_firemode
	var/name = "semi-automatic"
	/// Rounds each trigger pull fires.
	var/burst_size = 1
	/// Deciseconds after a pull (and between a burst's rounds) before it fires again. Null keeps the gun's own.
	var/fire_delay
	/// Deciseconds between rounds while the trigger's held. Null fires once a pull.
	var/auto_delay

/datum/gun_firemode/semi

/datum/gun_firemode/burst
	name = "three-round burst"
	burst_size = 3
	fire_delay = 1.5

/datum/gun_firemode/auto
	name = "automatic"
	auto_delay = 1.5

/datum/action/item_action/gun_firemode
	name = "Switch Fire Mode"

/obj/item/gun/ui_action_click(mob/user, actiontype)
	if(!istype(actiontype, /datum/action/item_action/gun_firemode) || length(firemodes) < 2)
		return ..()
	firemode_index = firemode_index % length(firemodes) + 1
	refresh_handling()
	var/datum/gun_firemode/mode = firemodes[firemode_index]
	to_chat(user, span_notice("You switch [src] to [initial(mode.name)]."))
	playsound(user, 'sound/weapons/empty.ogg', 50, TRUE)

/**
 * A gun mod. Use it on a gun to fit it, and a screwdriver on the gun to take it off. Each var below is what it does to
 * the gun it's on, and does nothing at its default: make a new mod as a subtype, setting only what it changes.
 */
/obj/item/gun_mod
	name = "gun mod"
	desc = "A part to fit to a gun."
	icon = 'icons/obj/improvised.dmi'
	icon_state = "receiver"
	w_class = WEIGHT_CLASS_SMALL
	/// Where it goes (GUN_MOD_*).
	var/slot = GUN_MOD_BARREL
	/// Guns it fits: these types and their subtypes.
	var/list/fits = list(/obj/item/gun)
	var/spread_mult = 1
	var/recoil_mult = 1
	var/fire_delay_mult = 1
	var/damage_mult = 1
	/// Added to how much it slows whoever carries the gun.
	var/slowdown_add = 0
	/// Heat each shot adds, and a ballistic gun's odds of jamming.
	var/heat_mult = 1
	var/jam_mult = 1
	/// Muffles the shots.
	var/suppresses = FALSE
	/// Tiles a scope lets you see further; 0 for no scope.
	var/zoom = 0
	/// How long fitting or taking it off takes.
	var/fit_time = 2 SECONDS

/obj/item/gun_mod/suppressor
	name = "suppressor"
	desc = "Screws onto a muzzle and swallows most of the bang, and a little of the punch."
	icon = 'icons/obj/guns/ballistic.dmi'
	icon_state = "suppressor"
	slot = GUN_MOD_MUZZLE
	suppresses = TRUE
	damage_mult = 0.95

/obj/item/gun_mod/compensator
	name = "compensator"
	desc = "Vents the muzzle blast upward, fighting the climb."
	icon = 'icons/obj/guns/ballistic.dmi'
	icon_state = "suppressor"
	color = "#b08a5a"
	slot = GUN_MOD_MUZZLE
	recoil_mult = 0.7
	spread_mult = 1.1

/obj/item/gun_mod/long_barrel
	name = "long barrel"
	desc = "A longer barrel: truer, but heavier to swing about."
	color = "#8a8a8a"
	slot = GUN_MOD_BARREL
	spread_mult = 0.8
	slowdown_add = 0.1

/obj/item/gun_mod/padded_stock
	name = "padded stock"
	desc = "Soaks up the kick into the shoulder."
	icon_state = "riflestock"
	slot = GUN_MOD_STOCK
	recoil_mult = 0.8

/obj/item/gun_mod/match_trigger
	name = "match trigger"
	desc = "A light, crisp trigger. Fires sooner, and heats the gun sooner doing it."
	color = "#c0a040"
	slot = GUN_MOD_TRIGGER
	fire_delay_mult = 0.85
	heat_mult = 1.2

/obj/item/gun/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/gun_mod))
		return fit_mod(user, tool)
	return ..()

/obj/item/gun/proc/fit_mod(mob/living/user, obj/item/gun_mod/mod)
	if(!(mod.slot in mod_slots) || !is_type_in_list(src, mod.fits))
		to_chat(user, span_warning("[mod] doesn't fit [src]."))
		return ITEM_INTERACT_BLOCKING
	if(LAZYACCESS(mods, mod.slot))
		to_chat(user, span_warning("[src] already has [mods[mod.slot]] fitted there."))
		return ITEM_INTERACT_BLOCKING
	if(mod.zoom && GetComponent(/datum/component/scope))
		to_chat(user, span_warning("[src] already has a scope."))
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, src, mod.fit_time, DO_PUBLIC, display = mod) || LAZYACCESS(mods, mod.slot) || !user.transferItemToLoc(mod, src))
		return ITEM_INTERACT_BLOCKING
	take_mod(mod)
	to_chat(user, span_notice("You fit [mod] to [src]."))
	return ITEM_INTERACT_SUCCESS

/// Mod goes on, and the gun handles as it does with it.
/obj/item/gun/proc/take_mod(obj/item/gun_mod/mod)
	mod.forceMove(src)
	LAZYSET(mods, mod.slot, mod)
	if(mod.zoom)
		AddComponent(/datum/component/scope, range_modifier = mod.zoom)
	refresh_handling()

/// Mod comes off, into whoever took it off's hands.
/obj/item/gun/proc/drop_mod(obj/item/gun_mod/mod, mob/living/user)
	LAZYREMOVE(mods, mod.slot)
	if(mod.zoom)
		qdel(GetComponent(/datum/component/scope))
	mod.forceMove(drop_location())
	user?.put_in_hands(mod)
	refresh_handling()

/// With mods on, a screwdriver takes one off; otherwise it does what it does to any gun.
/obj/item/gun/screwdriver_act(mob/living/user, obj/item/tool)
	if(!length(mods))
		return ..()
	var/list/fitted = list()
	for(var/slot in mods)
		fitted += mods[slot]
	var/obj/item/gun_mod/mod = length(fitted) == 1 ? fitted[1] : tgui_input_list(user, "Take which off?", "[src]", fitted)
	if(!mod || !tool.use_tool(src, user, mod.fit_time, volume = 50) || LAZYACCESS(mods, mod.slot) != mod)
		return TRUE
	drop_mod(mod, user)
	to_chat(user, span_notice("You take [mod] off [src]."))
	return TRUE

/obj/item/gun/examine(mob/user)
	. = ..()
	if(length(firemodes) > 1)
		var/datum/gun_firemode/mode = firemodes[firemode_index]
		. += span_info("It's set to [initial(mode.name)].")
	for(var/slot in mods)
		. += span_info("It has \a [mods[slot]] fitted.")
	if(isliving(user))
		var/mob/living/holder = user
		if(strength_to_handle > holder.get_body_strength())
			. += span_warning("It's heavier than you can handle well.")
		if(intelligence_to_handle > holder.get_special(SPECIAL_INTELLIGENCE))
			. += span_warning("You aren't sure you understand how it works.")

// Heat, wear and jams, for guns that feed rounds.

/// Percent chance a shot cooks off the next round, for each point of heat past cookoff_heat.
#define GUN_COOKOFF_CHANCE_PER_HEAT 2
/// Condition under which a jam is a double feed, slower to clear.
#define GUN_DOUBLE_FEED_CONDITION 30
/// Condition under which a gun can jam however cool it is.
#define GUN_WORN_CONDITION 50
/// How long clearing a jam, or a double feed, takes at average Intelligence.
#define GUN_JAM_CLEAR_TIME (1.5 SECONDS)
#define GUN_DOUBLE_FEED_CLEAR_TIME (4 SECONDS)

/obj/item/gun/ballistic
	/// How worn it is, 100 as new to 0. Worn, it jams more; badly worn, it double-feeds.
	var/condition = 100
	/// Condition each shot wears off.
	var/wear_per_shot = 0.05
	/// Heat each shot adds, and heat it sheds each second.
	var/heat_per_shot = 5
	var/heat_decay = 10
	/// Past jam_heat each shot may jam it; past cookoff_heat the round it chambers may go off by itself.
	var/jam_heat = 50
	var/cookoff_heat = 100
	/// Percent chance a shot jams it: for each point of heat past jam_heat, and each point of condition under 50.
	var/jam_chance_per_heat = 1
	var/jam_chance_per_wear = 0.2
	var/tmp/gun_heat = 0
	var/tmp/heat_time = 0
	/// It won't fire until the jam is cleared, by using it in hand.
	var/tmp/is_jammed = FALSE
	var/tmp/double_feed = FALSE

/// Its heat now, having shed some since it was last fired.
/obj/item/gun/ballistic/proc/current_heat()
	gun_heat = max(gun_heat - (world.time - heat_time) / (1 SECONDS) * heat_decay, 0)
	heat_time = world.time
	return gun_heat

/obj/item/gun/ballistic/after_firing(mob/living/user, pointblank, atom/pbtarget, message)
	. = ..()
	gun_heat = current_heat() + heat_per_shot * heat_mult
	condition = max(condition - wear_per_shot, 0)
	var/chance = (max(gun_heat - jam_heat, 0) * jam_chance_per_heat + max(GUN_WORN_CONDITION - condition, 0) * jam_chance_per_wear) * jam_mult
	if(isliving(user))
		// A lucky or sharp-eyed shooter feeds it cleaner.
		chance *= max(1 - 0.05 * (user.get_special_offset(SPECIAL_LUCK) + user.get_special_offset(SPECIAL_PERCEPTION)), 0.25)
	if(prob(chance))
		jam(user)
	else if(gun_heat > cookoff_heat && prob((gun_heat - cookoff_heat) * GUN_COOKOFF_CHANCE_PER_HEAT))
		addtimer(CALLBACK(src, PROC_REF(cook_off)), rand(5, 15))

/obj/item/gun/ballistic/proc/jam(mob/living/user)
	is_jammed = TRUE
	double_feed = condition < GUN_DOUBLE_FEED_CONDITION
	if(user)
		to_chat(user, span_warning(double_feed ? "[src] chokes on a double feed!" : "[src] jams!"))
	playsound(src, 'sound/weapons/jammed.ogg', 50, TRUE)

/// The round in a hot chamber goes off by itself, the way the gun's pointing, in whoever's hands it's in.
/obj/item/gun/ballistic/proc/cook_off()
	var/mob/living/holder = loc
	if(!istype(holder) || is_jammed || !chambered?.loaded_projectile || current_heat() <= cookoff_heat)
		return
	holder.visible_message(span_danger("[src] goes off in [holder]'s hands!"), span_userdanger("[src] cooks off in your hands!"))
	chambered.fire_casing(get_ranged_target_turf(holder, pick(holder.dir, turn(holder.dir, 45), turn(holder.dir, -45)), 7), holder, null, 0, suppressed, BODY_ZONE_CHEST, rand(-10, 10), src)
	play_fire_sound()
	update_chamber()

/obj/item/gun/ballistic/can_fire(check_lockout = FALSE)
	return !is_jammed && ..()

/obj/item/gun/ballistic/shoot_with_empty_chamber(mob/living/user)
	if(!is_jammed)
		return ..()
	to_chat(user, span_warning("[src] is jammed! Use it in hand to clear it."))
	playsound(src, 'sound/weapons/jammed.ogg', 50, TRUE)

/obj/item/gun/ballistic/attack_self(mob/living/user)
	if(!is_jammed)
		return ..()
	clear_jam(user)

/// Works the stuck round out, a double feed longer, a clever shooter quicker.
/obj/item/gun/ballistic/proc/clear_jam(mob/living/user)
	var/time = (double_feed ? GUN_DOUBLE_FEED_CLEAR_TIME : GUN_JAM_CLEAR_TIME) * max(1 - 0.1 * user.get_special_offset(SPECIAL_INTELLIGENCE), 0.3)
	to_chat(user, span_notice("You work at [src]'s [double_feed ? "double feed" : "jam"]..."))
	if(!do_after(user, src, time, DO_PUBLIC) || !is_jammed)
		return
	unjam()
	to_chat(user, span_notice("You clear [src]."))

/obj/item/gun/ballistic/proc/unjam()
	is_jammed = FALSE
	double_feed = FALSE
	if(chambered)
		chambered.forceMove(drop_location())
		chambered = null
	chamber_round()
	update_appearance()

/// Gun maintenance supplies bring it back to good order.
/obj/item/gun/ballistic/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/gun_maintenance_supplies))
		return ..()
	to_chat(user, span_notice("You start cleaning and oiling [src]..."))
	if(!do_after(user, src, 10 SECONDS, DO_PUBLIC, display = tool))
		return ITEM_INTERACT_BLOCKING
	maintain()
	qdel(tool)
	to_chat(user, span_notice("[src] is in good order again."))
	return ITEM_INTERACT_SUCCESS

/obj/item/gun/ballistic/proc/maintain()
	condition = 100
	if(is_jammed)
		unjam()

/obj/item/gun/ballistic/examine(mob/user)
	. = ..()
	switch(condition)
		if(80 to INFINITY)
			. += span_info("It's in good order.")
		if(GUN_WORN_CONDITION to 80)
			. += span_info("It's seen some use.")
		if(GUN_DOUBLE_FEED_CONDITION to GUN_WORN_CONDITION)
			. += span_warning("It's worn, and jams more than it should.")
		else
			. += span_warning("It's badly worn.")
	if(is_jammed)
		. += span_warning("It's jammed.")

#ifdef UNIT_TESTS
/datum/unit_test/ms13_slung_long_guns
	name = "GUNS: Long Guns Sling Over Armor"

/datum/unit_test/ms13_slung_long_guns/Run()
	var/mob/living/carbon/human/consistent/trooper = allocate(/mob/living/carbon/human/consistent)
	trooper.equip_to_slot_or_del(allocate(/obj/item/clothing/suit/armor/ms13/ncr), ITEM_SLOT_OCLOTHING)
	var/obj/item/gun/ballistic/automatic/ms13/semi/service/rifle = allocate(/obj/item/gun/ballistic/automatic/ms13/semi/service)
	if(rifle.w_class <= WEIGHT_CLASS_BULKY)
		Fail("The service rifle isn't a long gun any more; pick another for this test.")
	if(!trooper.equip_to_slot_if_possible(rifle, ITEM_SLOT_SUITSTORE, disable_warning = TRUE))
		Fail("A service rifle wouldn't sling over NCR armor.")
	var/obj/item/gun/ballistic/automatic/ms13/semi/service/second = allocate(/obj/item/gun/ballistic/automatic/ms13/semi/service)
	if(trooper.equip_to_slot_if_possible(second, ITEM_SLOT_SUITSTORE, disable_warning = TRUE))
		Fail("Two long guns slung over one suit.")
/// A gun asks for what it needs, fires one-handed worse the heavier it is, switches fire modes, takes mods, and heats,
/// wears and jams.
/datum/unit_test/ms13_gun_handling
	name = "GUNS: Handling, Fire Modes, Mods And Jams"

/datum/unit_test/ms13_gun_handling/Run()
	var/obj/item/gun/ballistic/automatic/ms13/semi/service/rifle = allocate(/obj/item/gun/ballistic/automatic/ms13/semi/service)
	var/obj/item/gun/ballistic/automatic/pistol/ms13/m9mm/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol/ms13/m9mm)
	var/mob/living/carbon/human/consistent/weakling = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/brute = allocate(/mob/living/carbon/human/consistent)
	brute.set_special_base(SPECIAL_STRENGTH, 10)
	var/mob/living/carbon/human/consistent/armored = allocate(/mob/living/carbon/human/consistent)
	armored.equip_to_slot_if_possible(allocate(/obj/item/clothing/suit/space/hardsuit/ms13/power_armor), ITEM_SLOT_OCLOTHING, TRUE, TRUE, bypass_equip_delay_self = TRUE)
	// One-handed, a heavy gun spreads and kicks less the stronger its shooter, a power armor frame least; two-handed, or a
	// light one, not at all.
	var/weak_spread = rifle.handling_spread(weakling)
	var/strong_spread = rifle.handling_spread(brute)
	var/armored_spread = rifle.handling_spread(armored)
	if(!(weak_spread > strong_spread && strong_spread > armored_spread && armored_spread > 0) || rifle.shot_kick(armored) <= rifle.recoil || pistol.handling_spread(weakling))
		Fail("One-handed, a heavy gun's spread and kick didn't ease with Strength down to a power armor frame's, or a light gun had any.")
	rifle.wielded = TRUE
	if(rifle.handling_spread(weakling) || rifle.shot_kick(weakling) != rifle.recoil)
		Fail("Two-handed, a heavy gun still spread or kicked as if one-handed.")

	rifle.strength_to_handle = 8
	if(rifle.handling_spread(weakling) != 3 * GUN_SHORTFALL_SPREAD || rifle.handling_spread(brute) || rifle.shot_kick(weakling) <= rifle.shot_kick(brute))
		Fail("Being short of a gun's Strength didn't cost spread and kick, or being strong enough did.")
	rifle.strength_to_handle = 0

	// Kicks build up, spreading the shots after them, and settle once fire's held.
	brute.add_gun_recoil(4)
	if(rifle.handling_spread(brute) != 4 * GUN_RECOIL_SPREAD)
		Fail("Built-up recoil didn't spread the next shot.")
	brute.gun_recoil_time = world.time - 5 SECONDS
	if(brute.current_gun_recoil())
		Fail("Built-up recoil didn't settle with fire held.")
	rifle.wielded = FALSE

	rifle.firemodes = list(/datum/gun_firemode/semi, /datum/gun_firemode/burst, /datum/gun_firemode/auto)
	var/datum/action/item_action/gun_firemode/switcher = new(rifle)
	rifle.ui_action_click(brute, switcher)
	if(rifle.burst_size != 3)
		Fail("Switching to burst didn't fire bursts.")
	rifle.ui_action_click(brute, switcher)
	if(rifle.burst_size != 1 || !rifle.GetComponent(/datum/component/automatic_fire))
		Fail("Switching to automatic didn't fire automatically.")
	rifle.ui_action_click(brute, switcher)
	if(rifle.GetComponent(/datum/component/automatic_fire))
		Fail("Switching back to semi-automatic kept firing automatically.")
	qdel(switcher)

	var/recoil_before = rifle.recoil
	var/obj/item/gun_mod/compensator/compensator = allocate(/obj/item/gun_mod/compensator)
	rifle.take_mod(compensator)
	if(rifle.recoil != recoil_before * compensator.recoil_mult)
		Fail("A compensator didn't take the kick down.")
	rifle.drop_mod(compensator)
	if(rifle.recoil != recoil_before)
		Fail("Taking a compensator off didn't put the kick back.")
	rifle.mod_slots = list(GUN_MOD_MUZZLE)
	if(rifle.fit_mod(brute, allocate(/obj/item/gun_mod/padded_stock)) != ITEM_INTERACT_BLOCKING)
		Fail("A mod went into a slot the gun hasn't got.")

	rifle.gun_heat = 1000
	rifle.heat_time = world.time
	rifle.jam_chance_per_heat = 100
	rifle.after_firing(brute, FALSE, weakling)
	if(!rifle.is_jammed || rifle.can_fire())
		Fail("A red-hot gun didn't jam, or fired jammed.")
	rifle.unjam()
	if(rifle.is_jammed)
		Fail("Clearing a jam didn't clear it.")
	rifle.condition = 10
	rifle.jam(brute)
	if(!rifle.double_feed)
		Fail("A badly worn gun jammed but didn't double-feed.")
	rifle.maintain()
	if(rifle.condition != 100 || rifle.is_jammed)
		Fail("Gun maintenance supplies didn't bring a gun back to good order.")
#endif
