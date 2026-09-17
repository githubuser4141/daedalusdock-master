/// Low-tech husbandry state for MS animals. Numbers stay internal; players read the animal's condition instead.
/datum/component/ms13_livestock
	dupe_mode = COMPONENT_DUPE_UNIQUE

	var/list/preferred_foods
	/// Product source types close enough to this animal to create a BSE risk when fed back to it.
	var/list/prion_risk_species = list(/mob/living/simple_animal/hostile/retaliate/ms13/brahmin)
	var/can_milk = FALSE
	var/domesticated = FALSE
	var/tame_chance = 10
	var/bonus_tame_chance = 15
	var/datum/callback/on_tame

	var/nutrition = 70
	var/care = 50
	var/stress = 10
	var/prion_exposure = 0
	/// 0 = clear, 1 = incubating, 2 = symptomatic, 3 = wasting.
	var/bse_stage = 0
	var/bse_progress = 0
	var/disease_elapsed = 0
	var/is_young = FALSE
	var/adult_type
	var/growth_progress = 0
	var/growth_needed = 300
	var/milk_units = 20
	var/max_milk_units = 50
	var/milk_progress = 0

/datum/component/ms13_livestock/Initialize(
	list/preferred_foods,
	can_milk = FALSE,
	domesticated = FALSE,
	tame_chance = 10,
	bonus_tame_chance = 15,
	datum/callback/on_tame,
	is_young = FALSE,
	adult_type,
	starting_nutrition = 70,
)
	if(!isanimal(parent))
		return COMPONENT_INCOMPATIBLE
	src.preferred_foods = preferred_foods?.Copy()
	src.can_milk = can_milk
	src.domesticated = domesticated
	src.tame_chance = tame_chance
	src.bonus_tame_chance = bonus_tame_chance
	src.on_tame = on_tame
	src.is_young = is_young
	src.adult_type = adult_type
	nutrition = starting_nutrition

/datum/component/ms13_livestock/RegisterWithParent()
	RegisterSignal(parent, COMSIG_PARENT_ATTACKBY, PROC_REF(on_attackby))
	RegisterSignal(parent, COMSIG_PARENT_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(parent, COMSIG_LIVING_LIFE, PROC_REF(on_life))

/datum/component/ms13_livestock/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_PARENT_ATTACKBY, COMSIG_PARENT_EXAMINE, COMSIG_LIVING_LIFE))

/datum/component/ms13_livestock/Destroy(force)
	QDEL_NULL(on_tame)
	preferred_foods = null
	return ..()

/datum/component/ms13_livestock/proc/get_product_quality()
	var/mob/living/animal = parent
	var/health_score = animal.maxHealth ? clamp(animal.health / animal.maxHealth, 0, 1) * 30 : 0
	return clamp(round(nutrition * 0.4 + care * 0.3 + health_score - stress * 0.25), 0, 100)

/datum/component/ms13_livestock/proc/is_prion_contaminated()
	return bse_stage > 0

/datum/component/ms13_livestock/proc/apply_feed(obj/item/food/feed)
	var/is_meat = istype(feed, /obj/item/food/meat) || (feed.foodtypes & MEAT)
	if(is_meat)
		// Animal protein is efficient feed. Cattle-derived or already-tainted protein creates the BSE risk.
		nutrition = min(nutrition + 40, 100)
		stress = min(stress + 3, 100)
		var/prion_tainted = feed.reagents?.has_reagent(/datum/reagent/consumable/nutriment/protein/prions)
		if(prion_tainted || is_related_meat(feed))
			prion_exposure = min(prion_exposure + (prion_tainted ? 35 : 15), 100)
			bse_stage = max(bse_stage, 1)
	else
		nutrition = min(nutrition + 20, 100)
		care = min(care + 2, 100)
	return is_meat

/datum/component/ms13_livestock/proc/is_related_meat(obj/item/food/feed)
	var/datum/component/ms13_livestock_product/product_state = feed.GetComponent(/datum/component/ms13_livestock_product)
	if(!product_state?.source_species)
		return FALSE
	for(var/species_root in prion_risk_species)
		if(ispath(product_state.source_species, species_root))
			return TRUE
	return FALSE

/datum/component/ms13_livestock/proc/on_attackby(datum/source, obj/item/used_item, mob/living/user)
	SIGNAL_HANDLER
	var/mob/living/animal = parent
	if(animal.stat != CONSCIOUS)
		return

	if(istype(used_item, /obj/item/wirebrush/stock))
		if(!domesticated)
			to_chat(user, span_warning("[animal] shies away from the brush."))
			return COMPONENT_NO_AFTERATTACK
		care = min(care + 8, 100)
		stress = max(stress - 12, 0)
		user.visible_message(span_notice("[user] brushes the dust and burrs from [animal]."), span_notice("You give [animal] a thorough brushing."))
		return COMPONENT_NO_AFTERATTACK

	if(can_milk && istype(used_item, /obj/item/reagent_containers/glass/bucket/ms13))
		milk_into(used_item, user)
		return COMPONENT_NO_AFTERATTACK

	if(!istype(used_item, /obj/item/food))
		return
	var/obj/item/food/feed = used_item
	var/preferred = is_type_in_list(feed, preferred_foods)
	var/is_meat = istype(feed, /obj/item/food/meat) || (feed.foodtypes & MEAT)
	if(!preferred && (!domesticated || !is_meat))
		return

	if(domesticated && nutrition >= 100)
		to_chat(user, span_notice("[animal] turns away; it is not hungry."))
		return COMPONENT_NO_AFTERATTACK

	user.visible_message(span_notice("[user] hand-feeds [feed] to [animal]."), span_notice("You hand-feed [feed] to [animal]."))
	apply_feed(feed)
	qdel(feed)

	if(!domesticated)
		if(prob(tame_chance))
			domesticated = TRUE
			on_tame?.Invoke(user)
		else
			tame_chance += bonus_tame_chance
	return COMPONENT_NO_AFTERATTACK

/datum/component/ms13_livestock/proc/on_life(datum/source, delta_time, times_fired)
	SIGNAL_HANDLER
	var/mob/living/animal = parent
	if(animal.stat == DEAD)
		return
	nutrition = max(nutrition - 0.02 * delta_time, 0)
	stress = max(stress - 0.01 * delta_time, 0)
	if(process_growth(delta_time))
		return
	disease_elapsed += delta_time
	if(disease_elapsed >= 30)
		process_bse(disease_elapsed)
		disease_elapsed = 0

	if(can_milk && domesticated && nutrition >= 25 && animal.health > 0)
		milk_progress += delta_time * (0.5 + get_product_quality() / 100)
		while(milk_progress >= 30 && milk_units < max_milk_units)
			milk_progress -= 30
			milk_units++


/datum/component/ms13_livestock/proc/process_growth(delta_time)
	if(!is_young || nutrition < 35 || !adult_type)
		return
	growth_progress += delta_time * nutrition / 100
	if(growth_progress < growth_needed)
		return

	var/mob/living/simple_animal/young_animal = parent
	var/mob/living/simple_animal/hostile/retaliate/ms13/brahmin/adult = new adult_type(get_turf(young_animal))
	var/datum/component/ms13_livestock/adult_livestock = adult.GetComponent(/datum/component/ms13_livestock)
	if(adult_livestock)
		adult_livestock.copy_husbandry_from(src)
	adult.tame = domesticated
	if(domesticated)
		adult.faction = list("neutral")
	young_animal.visible_message(span_notice("[young_animal] has grown into [adult]."))
	qdel(young_animal)
	return TRUE

/datum/component/ms13_livestock/proc/copy_husbandry_from(datum/component/ms13_livestock/source)
	domesticated = source.domesticated
	nutrition = source.nutrition
	care = source.care
	stress = source.stress
	prion_exposure = source.prion_exposure
	bse_stage = source.bse_stage
	bse_progress = source.bse_progress

/// Runs only twice a minute. Full pathogen processing remains on the eventual consumer, not the cow.
/datum/component/ms13_livestock/proc/process_bse(elapsed = 30)
	if(!bse_stage || !prion_exposure)
		return
	bse_progress += elapsed * prion_exposure / 100
	var/old_stage = bse_stage
	if(bse_progress >= 420)
		bse_stage = 3
	else if(bse_progress >= 180)
		bse_stage = 2

	var/mob/living/animal = parent
	if(bse_stage >= 2)
		stress = min(stress + bse_stage, 100)
	if(bse_stage >= 3)
		nutrition = max(nutrition - 1, 0)
	if(bse_stage > old_stage)
		animal.visible_message(bse_stage >= 3 ? span_warning("[animal] stumbles, trembling hard before it finds its footing.") : span_warning("[animal]'s head jerks sharply to one side, then stills."))
	else if(bse_stage == 2 && prob(15))
		animal.visible_message(span_warning("[animal] gives a brief, uneven shudder."))
	else if(bse_stage >= 3 && prob(40))
		animal.visible_message(span_warning("[animal] sways on unsteady legs."))

/datum/component/ms13_livestock/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	if(nutrition < 25)
		examine_list += span_warning("Its flanks look gaunt and hollow.")
	else if(nutrition >= 75)
		examine_list += span_notice("It looks well-fed.")
	if(care < 30)
		examine_list += span_warning("Its coat is matted and neglected.")
	else if(care >= 75)
		examine_list += span_notice("Its coat looks clean and well-kept.")
	if(stress >= 65)
		examine_list += span_warning("It watches every movement, tense and skittish.")
	if(is_young)
		if(nutrition < 35)
			examine_list += span_warning("The calf looks undersized; without better feeding it is unlikely to grow.")
		else if(growth_progress >= growth_needed * 0.75)
			examine_list += span_notice("The calf is approaching its adult size.")
	if(can_milk && domesticated)
		examine_list += span_notice(milk_units >= 10 ? "Its udders look ready for milking." : "Its udders look dry.")
	if(bse_stage == 2)
		examine_list += span_warning("There is an occasional tremor in its legs and something vacant in its stare.")
	else if(bse_stage >= 3)
		examine_list += span_warning("It is visibly wasting, with an unsteady gait and persistent tremors.")

/datum/component/ms13_livestock/proc/milk_into(obj/item/reagent_containers/glass/bucket/ms13/bucket, mob/living/user)
	var/mob/living/animal = parent
	if(!domesticated)
		to_chat(user, span_warning("[animal] will not stand still long enough to milk."))
		return FALSE
	if(milk_units <= 0)
		to_chat(user, span_warning("[animal]'s udders are dry."))
		return FALSE
	var/free_space = bucket.reagents.maximum_volume - bucket.reagents.total_volume
	if(free_space <= 0)
		to_chat(user, span_warning("[bucket] is full."))
		return FALSE

	var/quality = get_product_quality()
	var/amount = min(milk_units, free_space, 5 + round(quality / 20))
	bucket.reagents.add_reagent(/datum/reagent/consumable/milk, amount)
	milk_units -= amount
	if(quality >= 70)
		bucket.reagents.add_reagent(/datum/reagent/consumable/nutriment/vitamin, min(0.5, bucket.reagents.maximum_volume - bucket.reagents.total_volume))
	copy_trace_reagents(bucket, 0.5)
	user.visible_message(span_notice("[user] milks [animal] into [bucket]."), span_notice("You milk [animal]; the yield looks [quality >= 70 ? "rich" : quality < 35 ? "thin" : "sound"]."))
	return TRUE

/datum/component/ms13_livestock/proc/copy_trace_reagents(atom/product, limit = 2)
	var/mob/living/animal = parent
	if(!animal.reagents || !product.reagents || limit <= 0)
		return
	var/remaining = limit
	for(var/datum/reagent/reagent as anything in animal.reagents.reagent_list)
		var/amount = min(reagent.volume * 0.05, 0.5, remaining)
		if(amount <= 0)
			continue
		product.reagents.add_reagent(reagent.type, amount, reagent.data)
		remaining -= amount
		if(remaining <= 0)
			break

/// Called when a carcass stash materializes an actual food item.
/datum/component/ms13_livestock/proc/apply_to_product(atom/movable/product)
	if(!istype(product, /obj/item/food))
		return
	var/mob/living/animal = parent
	var/list/trace_reagents = list()
	if(animal.reagents)
		var/remaining = 2
		for(var/datum/reagent/reagent as anything in animal.reagents.reagent_list)
			var/amount = min(reagent.volume * 0.05, 0.5, remaining)
			if(amount <= 0)
				continue
			trace_reagents[reagent.type] = amount
			remaining -= amount
			if(remaining <= 0)
				break
	product.AddComponent(/datum/component/ms13_livestock_product, get_product_quality(), is_prion_contaminated(), trace_reagents, animal.get_static_viruses(), animal.type)

/// Carries husbandry quality, bloodstream traces, and disease state through carcass cutting and grilling.
/datum/component/ms13_livestock_product
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/quality
	var/prion_contaminated = FALSE
	var/list/trace_reagents
	var/list/datum/pathogen/diseases
	var/source_species

/datum/component/ms13_livestock_product/Initialize(quality, prion_contaminated, list/trace_reagents, list/datum/pathogen/diseases, source_species)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	src.quality = clamp(quality, 0, 100)
	src.prion_contaminated = prion_contaminated
	src.trace_reagents = trace_reagents?.Copy()
	src.diseases = diseases
	src.source_species = source_species
	apply_to(parent)

/datum/component/ms13_livestock_product/RegisterWithParent()
	RegisterSignal(parent, COMSIG_PARENT_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(parent, COMSIG_ATOM_PROCESSED, PROC_REF(on_processed))
	RegisterSignal(parent, COMSIG_GRILL_COMPLETED, PROC_REF(on_grilled))

/datum/component/ms13_livestock_product/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_PARENT_EXAMINE, COMSIG_ATOM_PROCESSED, COMSIG_GRILL_COMPLETED))

/datum/component/ms13_livestock_product/Destroy(force)
	QDEL_LIST(diseases)
	trace_reagents = null
	return ..()

/datum/component/ms13_livestock_product/proc/apply_to(atom/movable/product)
	if(istype(product, /obj/item/food))
		var/obj/item/food/food_product = product
		food_product.quality = max(food_product.quality, round(quality / 5))
		// Carcass sections carry the component; their cut meat receives the actual contaminants.
		if(food_product.reagents && !istype(food_product, /obj/item/food/meat/slab/ms13/carcass))
			for(var/reagent_type in trace_reagents)
				food_product.reagents.add_reagent(reagent_type, trace_reagents[reagent_type])
			if(prion_contaminated)
				food_product.reagents.add_reagent(/datum/reagent/consumable/nutriment/protein/prions, 2)
	if(length(diseases))
		var/list/datum/pathogen/disease_copies = list()
		for(var/datum/pathogen/disease as anything in diseases)
			disease_copies += disease.Copy()
		product.AddComponent(/datum/component/infective, disease_copies)

/datum/component/ms13_livestock_product/proc/copy_to(atom/movable/product)
	var/list/datum/pathogen/disease_copies = list()
	for(var/datum/pathogen/disease as anything in diseases)
		disease_copies += disease.Copy()
	product.AddComponent(/datum/component/ms13_livestock_product, quality, prion_contaminated, trace_reagents, disease_copies, source_species)

/datum/component/ms13_livestock_product/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	if(quality < 35)
		examine_list += span_warning("The flesh is lean, stringy, and poorly marbled.")
	else if(quality >= 70)
		examine_list += span_notice("The flesh is firm and well marbled.")
	if(prion_contaminated)
		examine_list += span_warning("There are odd pale flecks around the nerves. It does not look right.")

/datum/component/ms13_livestock_product/proc/on_processed(datum/source, mob/living/user, obj/item/tool, list/atom/results)
	SIGNAL_HANDLER
	for(var/atom/movable/result as anything in results)
		copy_to(result)

/datum/component/ms13_livestock_product/proc/on_grilled(datum/source, atom/movable/result)
	SIGNAL_HANDLER
	copy_to(result)

/// Placeholder sprite: this uses the existing wirebrush until dedicated ranching art exists.
/obj/item/wirebrush/stock
	name = "stock brush"
	desc = "A stiff hand brush for working dust, burrs, and loose hair out of livestock coats. The bristles are a little harsh, but wasteland animals are hardier than they look."

// Brahmin are the first concrete user of the framework. Brahmiluff inherit meat quality but cannot be milked.
/mob/living/simple_animal/hostile/retaliate/ms13/brahmin/Initialize(mapload)
	. = ..()
	var/datum/component/old_taming = GetComponent(/datum/component/tameable)
	qdel(old_taming)
	AddComponent(/datum/component/ms13_livestock, food_type, gender == FEMALE && !istype(src, /mob/living/simple_animal/hostile/retaliate/ms13/brahmin/brahmiluff), tame, tame_chance, bonus_tame_chance, CALLBACK(src, PROC_REF(tamed)))

/mob/living/simple_animal/hostile/retaliate/ms13/brahmin/tamed(mob/living/tamer)
	. = ..()
	var/datum/component/ms13_livestock/livestock = GetComponent(/datum/component/ms13_livestock)
	if(livestock)
		livestock.domesticated = TRUE

/mob/living/simple_animal/ms13/brahminyoung/Initialize(mapload)
	. = ..()
	var/datum/component/old_taming = GetComponent(/datum/component/tameable)
	qdel(old_taming)
	AddComponent(/datum/component/ms13_livestock, food_type, FALSE, tame, tame_chance, bonus_tame_chance, CALLBACK(src, PROC_REF(tamed)), TRUE, adult_type, 20)

/mob/living/simple_animal/ms13/brahminyoung
	food_type = list(
		/obj/item/food/grown/ms13/tato,
		/obj/item/food/grown/ms13/potato,
		/obj/item/food/grown/ms13/razorgrain,
		/obj/item/food/grown/ms13/baifan,
		/obj/item/food/grown/ms13/cabbage,
	)

/mob/living/simple_animal/ms13/brahminyoung/tamed(mob/living/tamer)
	. = ..()
	var/datum/component/ms13_livestock/livestock = GetComponent(/datum/component/ms13_livestock)
	if(livestock)
		livestock.domesticated = TRUE
