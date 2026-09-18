/obj/item/grenade/ms13/Initialize()
	. = ..()
	inhand_icon_state = initial(icon_state)
	AddElement(/datum/element/world_icon, null, icon, 'mojave/icons/objects/throwables/grenades_inventory.dmi')

/obj/item/grenade/ms13/examine(mob/user)
	return

/obj/item/grenade/frag/ms13 //nasty code right here, stinks of hekzder
	name = "frag grenade"
	desc = "The average frag grenade, if you could even say that. Utilizing an explosive payload to blast shrapnel around a large area. Great for clearing rooms."
	icon = 'mojave/icons/objects/throwables/grenades_world.dmi'
	lefthand_file = 'mojave/icons/mob/inhands/weapons/grenades_inhand_left.dmi'
	righthand_file = 'mojave/icons/mob/inhands/weapons/grenades_inhand_right.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	throwforce = 10
	display_timer = FALSE
	throw_speed = 2
	throw_range = 6

/obj/item/grenade/frag/ms13/Initialize()
	. = ..()
	AddElement(/datum/element/world_icon, null, icon, 'mojave/icons/objects/throwables/grenades_inventory.dmi')

/obj/item/grenade/frag/ms13/arm_grenade(mob/user, delayoverride, msg, volume)
	. = ..()
	icon_state = initial(icon_state) + "_active"
	inhand_icon_state = icon_state
	playsound(src, 'mojave/sound/ms13weapons/grenade_pin.wav', 20, TRUE)

/obj/item/grenade/frag/ms13/unequipped(mob/user, silent)
	. = ..()
	playsound(src, 'mojave/sound/ms13weapons/grenade.wav', 20, TRUE)

/obj/item/grenade/frag/ms13/charge
	name = "explosive charge"
	desc = "An explosive charge used for thundersticks."

/obj/item/grenade/frag/ms13/scrap //nasty code right here, stinks of hekzder
	name = "scrap grenade"
	desc = "A homebrew grenade. Quite shifty- You're unsure if you'll work, but pehaps it's worth a shot?"
	icon_state = "tinbomb"
	inhand_icon_state = "tinbomb"
	shrapnel_type = /obj/projectile/bullet/ms13/nail
	shrapnel_radius = 3
	ex_heavy = 2
	///how big of a light explosion radius on prime
	ex_light = 1
	///how big of a flame explosion radius on prime
	ex_flame = 0
	var/list/times
	var/range = 3

/obj/item/grenade/frag/ms13/scrap/Initialize(mapload)
	. = ..()
	times = list("5" = 10, "-1" = 20, "[rand(30, 80)]" = 50, "[rand(65, 180)]" = 20)// "Premature, Dud, Short Fuse, Long Fuse"=[weighting value]
	det_time = text2num(pick_weight(times))
	if(det_time < 0) //checking for 'duds'
		range = 1
		det_time = rand(30, 80)
	else
		range = pick(2, 2, 2, 3, 3, 3, 4)

/obj/item/grenade/ms13/molotov
	name = "molotov cocktail"
	desc = "The firestarters best friend, a very simple grenade consisting of a rag and a bottle of alcohol. Light those suckers up."
	icon = 'mojave/icons/objects/throwables/grenades_world.dmi'
	lefthand_file = 'mojave/icons/mob/inhands/weapons/grenades_inhand_left.dmi'
	righthand_file = 'mojave/icons/mob/inhands/weapons/grenades_inhand_right.dmi'
	icon_state = "molotov"
	throwforce = 10
	throw_speed = 1.5
	w_class = WEIGHT_CLASS_NORMAL //Kind of weird but I don't want people running around with pocket molotovs - Hekzder
	var/extra_POWER // Used for scaling flame power based on alcoholpwr. This number, usually 0-100, will be divided by 75 to get the flame radius.
	//grid_width = 32
	//grid_height = 96
	var/arm_sound = 'sound/items/welder.ogg'

/obj/item/grenade/ms13/molotov/Initialize()
	. = ..()
	det_time = rand(25,60) //2.5-6 seconds

/obj/item/grenade/ms13/molotov/attackby(obj/item/I, mob/user, params)
	if(I.get_temperature() && !active)
		arm_grenade()
		to_chat(user, "<span class='info'>You light [src] on fire.</span>")
		return

/obj/item/grenade/ms13/molotov/attack_self(mob/user)
	return //lighting only

/obj/item/grenade/ms13/molotov/arm_grenade(mob/user, delayoverride, msg = TRUE, volume = 60)
	var/turf/T = get_turf(src)
	log_grenade(user, T) //Inbuilt admin procs already handle null users
	if(user)
		add_fingerprint(user)
		if(msg)
			to_chat(user, "<span class='warning'>You prime [src]! [capitalize(DisplayTimeText(det_time))]!</span>")
	if(shrapnel_type && shrapnel_radius)
		shrapnel_initialized = TRUE
		AddComponent(/datum/component/pellet_cloud, projectile_type=shrapnel_type, magnitude=shrapnel_radius)
	playsound(src, arm_sound, volume, TRUE)
	active = TRUE
	icon_state = icon_state + "_active"
	inhand_icon_state = icon_state
	SEND_SIGNAL(src, COMSIG_GRENADE_ARMED, det_time, delayoverride)
	addtimer(CALLBACK(src, PROC_REF(detonate)), isnull(delayoverride)? det_time : delayoverride)
	update_icon()

/obj/item/grenade/ms13/molotov/detonate(mob/living/lanced_by)
	playsound(loc, 'sound/effects/hit_on_shattered_glass.ogg', 35, TRUE, 4)
	flame_radius(extra_POWER, get_turf(src))
	playsound(loc, 'mojave/sound/ms13effects/explosion_fire_grenade.ogg', 30, TRUE, 4)
	qdel(src)

/obj/item/grenade/ms13/molotov/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	. = ..()
	if(istype(loc, /turf/open/openspace))
		return
	if(!. && active)
		detonate()
	else
		playsound(src, "shatter", 70, TRUE)
		new /obj/item/stack/sheet/ms13/glass(src.loc)
		qdel(src)

/// A short-lived metal jet. Its coherence ends after a few tiles, where it becomes ordinary shrapnel.
/obj/projectile/bullet/ms13/shaped_charge_jet
	name = "shaped-charge jet"
	icon_state = "laser"
	damage = 50
	damage_type = BRUTE
	armor_flag = PUNCTURE
	armor_penetration = 150
	subtractible_armour_penetration = 150
	range = 5
	dismemberment = 20
	sharpness = SHARP_IMPALING
	bulletTipType = BULLET_ULTRASHARP
	bulletArmorType = PUNCTURE
	canRicochet = FALSE
	canFragment = FALSE
	bullet_mass = 2
	var/breakup_count = 4
	var/breakup_spread = 55

/obj/projectile/bullet/ms13/shaped_charge_jet/on_range()
	break_into_shrapnel()
	return ..()

/obj/projectile/bullet/ms13/shaped_charge_jet/proc/break_into_shrapnel()
	var/turf/origin = get_turf(src)
	if(!origin)
		return
	for(var/i in 1 to breakup_count)
		var/fragment_angle = Angle + rand(-breakup_spread, breakup_spread)
		var/turf/fragment_target = get_ranged_target_turf(origin, angle2dir(fragment_angle), 8)
		var/obj/projectile/bullet/shrapnel/fragment = new(origin)
		fragment.firer = firer
		fragment.fired_from = fired_from
		fragment.range = rand(5, 8)
		fragment.decayedRange = fragment.range
		if(ignored_factions)
			fragment.ignored_factions = ignored_factions.Copy()
		fragment.preparePixelProjectile(fragment_target, origin)
		fragment.fire(fragment_angle)

/// Shared delivery path for crafted charges, rockets, and hostile-mob attacks.
/proc/ms13_fire_shaped_charge_jet(turf/origin, firing_angle, jet_damage = 50, jet_penetration = 150, coherent_range = 5, fragment_count = 4, atom/movable/source, jet_hardness = 1, jet_mass = 2, jet_ductility = 0.5)
	if(!origin)
		return
	var/turf/target = get_ranged_target_turf(origin, angle2dir(firing_angle), max(2, coherent_range + 1))
	var/obj/projectile/bullet/ms13/shaped_charge_jet/jet = new(origin)
	jet.damage = jet_damage
	jet.armor_penetration = jet_penetration
	jet.subtractible_armour_penetration = jet_penetration
	jet.range = max(1, coherent_range)
	jet.decayedRange = jet.range
	jet.breakup_count = max(1, fragment_count)
	jet.bullet_mass = clamp(round(jet_mass), 1, 8)
	jet.speedLossPerTile = max(0.02, 0.15 - jet_ductility * 0.08)
	jet.setArmor(jet.returnArmor().setRating(puncture = clamp(round(50 * jet_hardness), 10, 150)))
	jet.firer = source
	jet.fired_from = source
	jet.preparePixelProjectile(target, origin)
	jet.fire(firing_angle)
	return jet

/obj/item/grenade/c4/ms13/shaped
	name = "improvised shaped charge"
	desc = "A directional explosive with a metal liner. Plant it against a target; the initial blast drives a penetrating jet in the direction it faces."
	icon_state = "plasticx40"
	inhand_icon_state = "plasticx4"
	worn_icon_state = "x4"
	gender = NEUTER
	directional = FALSE
	boom_sizes = list(-1, 0, 1)
	var/craftsmanship = 1
	var/jet_damage = 45
	var/jet_penetration = 120
	var/jet_range = 5
	var/jet_fragments = 4
	var/jet_hardness = 1
	var/jet_mass = 2
	var/jet_ductility = 0.5
	var/liner_description = "steel"
	var/payload_description = "standard powder"

/obj/item/grenade/c4/ms13/shaped/CheckParts(list/parts_list)
	. = ..()
	var/obj/item/stack/sheet/liner = locate() in contents
	var/datum/material/liner_material = liner?.material_type ? GET_MATERIAL_REF(liner.material_type) : null
	var/density = liner_material ? liner_material.density : 1
	var/hardness = liner_material ? liner_material.hardness : 1
	var/ductility = liner_material ? liner_material.ductility : 0.5
	var/bulk_modulus = liner_material ? liner_material.bulk_modulus : 1
	liner_description = liner_material ? liner_material.name : "generic metal"

	var/obj/item/ms13/component/gunpowder/powder = locate() in contents
	var/powder_energy = powder ? powder.shaped_charge_energy : 1
	var/powder_brisance = powder ? powder.shaped_charge_brisance : 1
	payload_description = powder ? powder.name : "standard powder"
	boom_sizes = powder_brisance >= 1 ? list(-1, 1, 2) : list(-1, 0, 1)

	craftsmanship = clamp(craftsmanship, 0.6, 1.4)
	jet_damage = max(1, round(50 * powder_energy * craftsmanship * (0.65 + density * 0.35) * (0.75 + bulk_modulus * 0.25)))
	jet_penetration = max(1, round(150 * powder_energy * craftsmanship * (0.35 + density * 0.65) * (0.4 + ((hardness + ductility) / 2) * 0.6)))
	jet_range = max(2, round((3 + ductility * 3 + hardness) * craftsmanship))
	jet_fragments = max(1, round(4 + density * 2 - ductility * 2 - hardness + powder_brisance * 2))
	jet_hardness = hardness
	jet_mass = 1 + density * 2
	jet_ductility = ductility

/obj/item/grenade/c4/ms13/shaped/examine(mob/user)
	. = ..()
	. += span_notice("Its [liner_description] liner and [payload_description] produce a [jet_range]-tile coherent jet ([jet_damage] damage, [jet_penetration] penetration) before it breaks into [jet_fragments] fragments.")

/obj/item/grenade/c4/ms13/shaped/detonate(mob/living/lanced_by)
	var/turf/origin = target ? get_turf(target) : get_turf(src)
	var/jet_angle = dir2angle(aim_dir)
	var/cached_damage = jet_damage
	var/cached_penetration = jet_penetration
	var/cached_range = jet_range
	var/cached_fragments = jet_fragments
	var/cached_hardness = jet_hardness
	var/cached_mass = jet_mass
	var/cached_ductility = jet_ductility
	. = ..()
	if(.)
		ms13_fire_shaped_charge_jet(origin, jet_angle, cached_damage, cached_penetration, cached_range, cached_fragments, null, cached_hardness, cached_mass, cached_ductility)

/datum/slapcraft_recipe/ms13_shaped_charge
	name = "improvised shaped charge"
	desc = "Hammer scrap into a charge body, fit a chosen metal liner and explosive payload, then wire an igniter. Liner and powder determine the jet."
	examine_hint = "This scrap could be hammered into the body of a shaped charge..."
	category = SLAP_CAT_WEAPONS
	steps = list(
		/datum/slapcraft_step/stack/ms13_shaped_casing,
		/datum/slapcraft_step/stack/ms13_shaped_liner,
		/datum/slapcraft_step/item/ms13_shaped_powder,
		/datum/slapcraft_step/item/igniter,
		/datum/slapcraft_step/stack/cable/five,
		/datum/slapcraft_step/tool/crowbar/ms13_shape_charge,
	)
	result_type = /obj/item/grenade/c4/ms13/shaped

/datum/slapcraft_recipe/ms13_shaped_charge/after_create_items(list/items_list, obj/item/slapcraft_assembly/assembly)
	var/obj/item/grenade/c4/ms13/shaped/charge = items_list[1]
	charge.craftsmanship = 0.8

/datum/slapcraft_recipe/ms13_shaped_charge/precision
	name = "precision shaped charge"
	desc = "A welded steel charge body holds the liner squarely, producing a better-focused jet."
	examine_hint = "This refined steel could become a carefully fitted shaped charge..."
	steps = list(
		/datum/slapcraft_step/stack/ms13_shaped_casing/precision,
		/datum/slapcraft_step/stack/ms13_shaped_liner,
		/datum/slapcraft_step/item/ms13_shaped_powder,
		/datum/slapcraft_step/item/igniter,
		/datum/slapcraft_step/stack/cable/five,
		/datum/slapcraft_step/tool/welder/weld_together,
	)

/datum/slapcraft_recipe/ms13_shaped_charge/precision/after_create_items(list/items_list, obj/item/slapcraft_assembly/assembly)
	var/obj/item/grenade/c4/ms13/shaped/charge = items_list[1]
	charge.craftsmanship = 1.15

/datum/slapcraft_step/stack/ms13_shaped_casing
	desc = "Hammer two pieces of scrap into a conical charge body."
	item_types = list(/obj/item/stack/sheet/ms13/scrap)
	amount = 2

/datum/slapcraft_step/stack/ms13_shaped_casing/precision
	desc = "Form two refined steel ingots into a sturdy charge body."
	item_types = list(/obj/item/stack/sheet/ms13/refined_steel)
	amount = 2

/datum/slapcraft_step/stack/ms13_shaped_liner
	desc = "Fit one material-backed sheet into a conical liner. Its physical properties determine the resulting jet."
	item_types = list(/obj/item/stack/sheet)
	amount = 1
	insert_item_into_result = TRUE

/datum/slapcraft_step/stack/ms13_shaped_liner/can_perform(mob/living/user, obj/item/item, obj/item/slapcraft_assembly/assembly, list/error_list = list())
	. = ..()
	var/obj/item/stack/sheet/sheet = item
	if(!sheet.material_type)
		error_list += "[sheet] has no physical material data to form a predictable liner."
		return FALSE

/datum/slapcraft_step/item/ms13_shaped_powder
	desc = "Pack the charge with low- or high-quality gunpowder."
	item_types = list(/obj/item/ms13/component/gunpowder)

/datum/slapcraft_step/tool/crowbar/ms13_shape_charge
	list_desc = "hammer or prying tool"
	desc = "Hammer the body tightly around the liner."
	perform_time = 4 SECONDS

// The HEDP rocket already carries a shaped warhead; add the coherent jet after its existing blast.
/obj/projectile/bullet/a84mm/do_boom(atom/target)
	var/turf/origin = get_turf(target)
	var/jet_angle = Angle
	. = ..()
	ms13_fire_shaped_charge_jet(origin, jet_angle, 65, 210, 7, 5, firer)

// The prototype eyebot's destructive self-erasure includes a small forward-facing shaped charge.
/mob/living/simple_animal/hostile/ms13/robot/eyebot/prototype/death(gibbed, cause_of_death = "Unknown")
	var/turf/origin = get_turf(src)
	var/jet_angle = dir2angle(dir)
	. = ..()
	ms13_fire_shaped_charge_jet(origin, jet_angle, 48, 150, 5, 4, src)
