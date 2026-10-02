//For non-table sub-type crafting benches

// Benches share the existing timed crafting component; Ctrl-click belongs to it, not pulling.
/datum/component/personal_crafting
	/// Set only while a terminal is running a queued job on this bench.
	var/datum/weakref/work_terminal
	COOLDOWN_DECLARE(workshop_effect_cooldown)

/datum/component/personal_crafting/Initialize(bench_type = CRAFTING_BENCH_HANDS)
	. = ..()
	crafting_interface = bench_type

/obj/structure/CtrlClick(mob/user, list/params)
	var/datum/component/personal_crafting/crafting = GetComponent(/datum/component/personal_crafting)
	if(!crafting || istype(src, /obj/structure/ms13/chem_set))
		return ..()
	if(crafting.work_terminal)
		to_chat(user, span_notice("[src] is working on a terminal job."))
		return TRUE
	if(IsReachableBy(user) && crafting.can_work(user))
		crafting.ui_interact(user)
	return TRUE

/// Work at the bench itself, or at a powered terminal placed beside it.
/datum/component/personal_crafting/proc/can_work(mob/user)
	if(QDELETED(parent) || QDELETED(user) || !isliving(user) || user.incapacitated() || !isturf(user.loc))
		return FALSE
	if(ismob(parent))
		return user == parent
	if(work_terminal)
		var/obj/machinery/ms13/terminal/terminal = work_terminal.resolve()
		return terminal && terminal.workshop_running && !terminal.workshop_cancelled && terminal.workshop_operator?.resolve() == user && terminal.terminal_available(user) && (parent in terminal.workshop_benches())
	var/obj/structure/bench = parent
	if(!istype(bench) || !isturf(bench.loc))
		return FALSE
	if(bench.IsReachableBy(user))
		return user.canUseTopic(bench, USE_CLOSE|USE_DEXTERITY)
	for(var/obj/machinery/ms13/terminal/terminal in range(1, bench))
		if(terminal.IsReachableBy(user) && terminal.terminal_available(user) && (bench in terminal.workshop_benches()))
			return TRUE
	return FALSE

/datum/component/personal_crafting/ui_status(mob/user, datum/ui_state/state)
	if(work_terminal || (!ismob(parent) && !can_work(user)))
		return UI_CLOSE
	return ..()

/datum/component/personal_crafting/ui_interact(mob/user, datum/tgui/ui)
	if(work_terminal)
		return
	if(!ismob(parent))
		if(!can_work(user))
			return
		// The imported benches have categories absent from DD's default hand-crafting list.
		categories = list()
		var/list/data = ui_static_data(user)
		var/list/recipes = data["crafting_recipes"]
		for(var/category in recipes)
			var/list/subcategories = recipes[category]
			if(subcategories["has_subcats"])
				categories[category] = list()
				for(var/subcategory in subcategories)
					if(subcategory != "has_subcats")
						categories[category] += subcategory
			else
				categories[category] = CAT_NONE
		if(!length(categories))
			to_chat(user, span_notice("You don't know any recipes for this equipment."))
			return
	return ..()

/datum/component/personal_crafting/get_environment(atom/source, list/blacklist = null, radius_range = 1)
	// Both requirement checks and consumption use the bench's ingredients, including from a terminal.
	return ..(ismob(parent) ? source : parent, blacklist, radius_range)

/datum/component/personal_crafting/construct_item(atom/source, datum/crafting_recipe/recipe)
	if(!recipe)
		return ", unknown recipe."
	return ..()

/// The existing timed action owns this callback, so effects cannot outlive the job.
/datum/component/personal_crafting/proc/workshop_tick(mob/user, datum/crafting_recipe/recipe)
	if(!work_terminal || !can_work(user))
		return FALSE
	if(COOLDOWN_FINISHED(src, workshop_effect_cooldown))
		var/list/surroundings = get_surroundings(user, recipe.blacklist)
		if(!check_contents(user, recipe, surroundings) || !check_tools(user, recipe, surroundings))
			return FALSE
		playsound(parent, 'sound/items/ratchet.ogg', 35, TRUE)
		do_sparks(2, FALSE, parent)
		COOLDOWN_START(src, workshop_effect_cooldown, 2 SECONDS)
	return TRUE

/datum/component/personal_crafting/check_contents(atom/source, datum/crafting_recipe/recipe, list/contents)
	// Called again after do_after, before consuming anything.
	if(!can_work(source) || !knows_recipe(source, recipe))
		return FALSE
	return ..()

/datum/component/personal_crafting/proc/knows_recipe(mob/user, datum/crafting_recipe/recipe)
	if(!recipe || !(recipe.crafting_interface & crafting_interface))
		return FALSE
	if(!recipe.always_available && !(recipe.type in user.mind?.learned_recipes))
		return FALSE
	if(recipe.trait && (!user.mind || !HAS_TRAIT(user.mind, recipe.trait)))
		return FALSE
	return TRUE

/datum/component/personal_crafting/ui_act(action, params)
	if(action == "make" && busy)
		return TRUE
	return ..()

TYPEINFO_DEF(/obj/structure/ms13/smelter)
	default_armor = list(BLUNT = 50, PUNCTURE = 20, SLASH = 50, LASER = 50, ENERGY = 60, BOMB = 40, BIO = 100, FIRE = 40, ACID = 100)

/obj/structure/ms13/smelter
	name = "makeshift smelter"
	desc = "A crude, makeshift smelter used to refine or melt down ingots. At least it works.... probably."
	icon = 'mojave/icons/structure/smelter.dmi'
	icon_state = "smelter"
	max_integrity = 200
	density = TRUE
	anchored = TRUE
	projectile_passchance = 75
	pixel_y = 12

/obj/structure/ms13/smelter/examine(mob/user)
	. = ..()
	. += "<span class='notice'>Use <b>CTRL + CLICK</b> on [src] to begin smelting.</span>"

/obj/structure/ms13/smelter/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	. = ..()

	if (isnull(held_item))
		context[SCREENTIP_CONTEXT_CTRL_LMB] = "Start smelting"
		return CONTEXTUAL_SCREENTIP_SET

/obj/structure/ms13/smelter/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/personal_crafting, CRAFTING_BENCH_SMELTER)
	register_context()

/obj/structure/ms13/smelter/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/ms13/scrap(loc, 4)
	qdel(src)

TYPEINFO_DEF(/obj/structure/ms13/chem_set)
	default_armor = list(BLUNT = 15, PUNCTURE = 10, SLASH = 15, LASER = 20, ENERGY = 20, BOMB = 0, BIO = 100, FIRE = 40, ACID = 100)

/obj/structure/ms13/chem_set
	name = "chemistry set"
	desc = "A set of chemistry equipment, heaters, beakers, and filters for synthesizing and brewing concoctions."
	icon = 'mojave/icons/structure/chemset.dmi'
	icon_state = "chemicalset"
	max_integrity = 100
	density = TRUE
	anchored = FALSE
	projectile_passchance = 75
	pixel_y = 6

/obj/structure/ms13/chem_set/examine(mob/user)
	. = ..()
	. += "<span class='notice'>Use <b>ALT + CLICK</b> on [src] to begin mixing, or <b>CTRL + CLICK</b> to grab and move it.</span>"

/obj/structure/ms13/chem_set/AltClick(mob/user)
	var/datum/component/personal_crafting/crafting = GetComponent(/datum/component/personal_crafting)
	if(IsReachableBy(user) && crafting?.can_work(user))
		crafting.ui_interact(user)
	return TRUE

/obj/structure/ms13/chem_set/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	. = ..()

	if (isnull(held_item))
		context[SCREENTIP_CONTEXT_ALT_LMB] = "Begin mixing"
		context[SCREENTIP_CONTEXT_CTRL_LMB] = "Grab / move"
		return CONTEXTUAL_SCREENTIP_SET

/obj/structure/ms13/chem_set/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/personal_crafting, CRAFTING_BENCH_CHEM)
	register_context()

/obj/structure/ms13/chem_set/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		new /obj/item/stack/sheet/ms13/glass(loc, 4)
		new /obj/item/stack/sheet/ms13/scrap(loc, 2)
	qdel(src)

#ifdef UNIT_TESTS
/datum/unit_test/ms13_workstation
	name = "CRAFTING: Benches And Terminal Workstations"
	var/area/test_area
	var/old_requires_power
	var/craft_result
	var/datum/crafting_recipe/queued_recipe

/datum/unit_test/ms13_workstation/Destroy()
	GLOB.crafting_recipes -= queued_recipe
	if(test_area)
		test_area.requires_power = old_requires_power
	return ..()

/datum/unit_test/ms13_workstation/proc/mix(datum/component/personal_crafting/crafting, mob/user, datum/crafting_recipe/recipe)
	craft_result = crafting.construct_item(user, recipe)
	if(ismovable(craft_result))
		allocated += craft_result

/datum/unit_test/ms13_workstation/proc/supply(datum/crafting_recipe/recipe, turf/site)
	for(var/path in recipe.reqs)
		for(var/index in 1 to recipe.reqs[path])
			allocate(path, site)

/datum/unit_test/ms13_workstation/Run()
	var/turf/site = get_step(get_step(run_loc_floor_bottom_left, NORTHEAST), NORTHEAST)
	test_area = get_area(site)
	old_requires_power = test_area.requires_power
	test_area.requires_power = FALSE
	var/obj/machinery/ms13/terminal/wasteland/terminal = allocate(/obj/machinery/ms13/terminal/wasteland, site)
	terminal.rigged = FALSE
	var/obj/structure/ms13/chem_set/bench = allocate(/obj/structure/ms13/chem_set, get_step(site, EAST))
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, get_step(bench, SOUTH))
	var/datum/component/personal_crafting/crafting = bench.GetComponent(/datum/component/personal_crafting)
	if(crafting.crafting_interface != CRAFTING_BENCH_CHEM)
		return Fail("The chemistry set ignored its bench type.")
	if(!bench.AltClick(user) || user.is_grabbing(bench) || crafting.cur_category == CAT_NONE)
		Fail("Alt-click did not open chemistry crafting, or also grabbed the bench.")
	crafting.cur_category = CAT_NONE
	bench.CtrlClick(user)
	if(bench.anchored || !user.is_grabbing(bench) || crafting.cur_category != CAT_NONE)
		Fail("Ctrl-click did not grab the movable chemistry set, or also opened crafting.")
	user.release_all_grabs()
	var/list/other_benches = list(/obj/structure/ms13/smelter = CRAFTING_BENCH_SMELTER, /obj/structure/table/ms13/crafting/workbench = CRAFTING_BENCH_GENERAL)
	for(var/path in other_benches)
		var/obj/structure/other = allocate(path, get_step(site, NORTH))
		var/datum/component/personal_crafting/other_crafting = other.GetComponent(/datum/component/personal_crafting)
		if(other_crafting.crafting_interface != other_benches[path] || !(other in terminal.workshop_benches()))
			Fail("A sibling bench lost its recipes or was absent from the terminal.")
		qdel(other)
	user.forceMove(get_step(site, WEST))
	if(bench.IsReachableBy(user) || !terminal.open_workbench(bench, user) || !crafting.can_work(user))
		return Fail("An adjacent terminal could not operate a bench outside the user's reach.")
	terminal.password_needed = TRUE
	if(crafting.can_work(user) || terminal.open_workbench(bench, user))
		Fail("A locked terminal allowed bench access.")
	terminal.unlocked = TRUE
	var/datum/crafting_recipe/recipe = allocate(/datum/crafting_recipe/hydra)
	recipe.time = 1 SECONDS
	supply(recipe, get_turf(bench))
	recipe.crafting_interface = CRAFTING_BENCH_GENERAL
	if(crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("A forged recipe bypassed the bench filter.")
	recipe.crafting_interface = CRAFTING_BENCH_CHEM
	recipe.always_available = FALSE
	if(crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("An unlearned recipe was accepted.")
	recipe.always_available = TRUE
	mix(crafting, user, recipe)
	if(!istype(craft_result, recipe.result))
		return Fail("Terminal crafting did not produce the item: [craft_result].")
	if(crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("Crafting produced an item without consuming its ingredients.")
	supply(recipe, get_turf(bench))
	craft_result = null
	INVOKE_ASYNC(src, PROC_REF(mix), crafting, user, recipe)
	sleep(1)
	terminal.set_machine_stat(NOPOWER)
	sleep(2 SECONDS)
	if(!istext(craft_result) || crafting.ui_status(user, crafting.ui_state(user)) != UI_CLOSE)
		Fail("Losing terminal power did not cancel the craft and close access.")
	terminal.set_machine_stat(NONE)
	if(!crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("An interrupted craft consumed its ingredients.")
	mix(crafting, user, recipe)
	if(!istype(craft_result, recipe.result))
		Fail("Restoring terminal power did not allow crafting again.")
	queued_recipe = recipe
	GLOB.crafting_recipes += recipe
	supply(recipe, get_turf(bench))
	supply(recipe, get_turf(bench))
	var/list/old_products = user.loc.contents.Copy()
	if(!terminal.queue_recipe(bench, recipe, user) || !terminal.queue_recipe(bench, recipe, user) || !terminal.start_workshop(user))
		Fail("The terminal could not queue and start two valid recipes.")
	sleep(4 SECONDS)
	if(terminal.workshop_running || length(terminal.workshop_queue) || crafting.busy || crafting.work_terminal)
		Fail("A completed recipe queue left work or a bench reservation behind.")
	var/product_count = 0
	for(var/obj/item/reagent_containers/ms13/inhaler/hydra/product in get_turf(user))
		if(product in old_products)
			continue
		product_count++
		allocated += product
	if(product_count != 2 || crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("The two queued recipes did not produce exactly two items and consume their ingredients.")
	supply(recipe, get_turf(bench))
	terminal.queue_recipe(bench, recipe, user)
	terminal.start_workshop(user)
	sleep(1)
	terminal.set_machine_stat(NOPOWER)
	sleep(2 SECONDS)
	if(terminal.workshop_running || length(terminal.workshop_queue) != 1 || crafting.busy || crafting.work_terminal)
		Fail("A power interruption lost the queued job or stranded the bench reservation.")
	terminal.set_machine_stat(NONE)
	if(!crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("An interrupted queued job consumed ingredients.")
	terminal.start_workshop(user)
	sleep(2 SECONDS)
	if(length(terminal.workshop_queue) || terminal.workshop_running)
		Fail("A paused queue did not resume after power returned.")
	for(var/obj/item/reagent_containers/ms13/inhaler/hydra/product in get_turf(user))
		allocated |= product
	supply(recipe, get_turf(bench))
	terminal.queue_recipe(bench, recipe, user)
	terminal.start_workshop(user)
	sleep(1)
	terminal.stop_workshop(user)
	sleep(2 SECONDS)
	if(length(terminal.workshop_queue) || terminal.workshop_running || !crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("Stopping a queue still consumed ingredients or left work running.")
	bench.forceMove(get_step(get_step(site, EAST), EAST))
	if(terminal.open_workbench(bench, user) || crafting.can_work(user))
		Fail("Moving the bench left a stale terminal link.")

/datum/unit_test/ms13_workstation/tools
	name = "CRAFTING: Active Workstations And Tool Fuel"

/datum/unit_test/ms13_workstation/tools/Run()
	var/turf/site = get_step(get_step(run_loc_floor_bottom_left, NORTHEAST), NORTHEAST)
	test_area = get_area(site)
	old_requires_power = test_area.requires_power
	test_area.requires_power = FALSE
	var/obj/machinery/ms13/terminal/wasteland/terminal = allocate(/obj/machinery/ms13/terminal/wasteland, site)
	terminal.rigged = FALSE
	var/obj/structure/ms13/chem_set/bench = allocate(/obj/structure/ms13/chem_set, get_step(site, EAST))
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, get_step(site, WEST))
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, get_step(bench, SOUTH))
	var/datum/component/personal_crafting/crafting = bench.GetComponent(/datum/component/personal_crafting)
	var/datum/crafting_recipe/recipe = allocate(/datum/crafting_recipe/hydra)
	queued_recipe = recipe
	GLOB.crafting_recipes += recipe
	recipe.time = 3 SECONDS
	recipe.tool_behaviors = list(TOOL_WELDER, TOOL_SCREWDRIVER)
	recipe.tool_paths = list(/obj/item/weldingtool)
	supply(recipe, get_turf(bench))
	mix(crafting, user, recipe)
	if(!istext(craft_result))
		Fail("Crafting without required tools succeeded.")
	var/obj/item/weldingtool/empty = allocate(/obj/item/weldingtool, get_turf(bench))
	empty.reagents.clear_reagents()
	var/obj/item/screwdriver/driver = allocate(/obj/item/screwdriver, get_turf(bench))
	terminal.queue_recipe(bench, recipe, user)
	terminal.start_workshop(user)
	sleep(1)
	if(terminal.workshop_running || crafting.work_terminal || crafting.workshop_effect_cooldown || !crafting.can_work(bystander))
		Fail("An unfuelled job locked the bench or played work effects.")
	var/obj/item/weldingtool/mini/welder = allocate(/obj/item/weldingtool/mini, get_turf(bench))
	if(crafting.check_tools(user, recipe, crafting.get_surroundings(user)))
		Fail("A switched-off welder was usable for crafting.")
	// Avoid the welder's independent idle fuel drain when measuring the recipe's charge.
	welder.welding = TRUE
	var/fuel_before = welder.get_fuel()
	terminal.start_workshop(user)
	sleep(3)
	if(!crafting.work_terminal || COOLDOWN_FINISHED(crafting, workshop_effect_cooldown))
		Fail("An active terminal job did not emit its bench effects.")
	if(crafting.ui_status(user, crafting.ui_state(user)) != UI_CLOSE || crafting.ui_status(bystander, crafting.ui_state(bystander)) != UI_CLOSE || terminal.open_workbench(bench, user))
		Fail("The operator or a bystander could open manual controls during a job.")
	crafting.cur_category = CAT_NONE
	bench.AltClick(bystander)
	if(crafting.cur_category != CAT_NONE || bystander.is_grabbing(bench) || !crafting.ui_act("make", list("recipe" = REF(recipe))))
		Fail("Alt-click or an existing UI bypassed the active bench lock.")
	terminal.stop_workshop(user)
	sleep(1 SECONDS)
	if(crafting.busy || crafting.work_terminal || welder.get_fuel() != fuel_before || !crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("Stopping work stranded a lock or consumed recipe materials/fuel.")
	var/last_effect = crafting.workshop_effect_cooldown
	if(crafting.workshop_tick(user, recipe) || crafting.workshop_effect_cooldown != last_effect || !crafting.can_work(bystander))
		Fail("A stopped job kept emitting effects or blocked manual work.")
	bench.AltClick(bystander)
	if(crafting.cur_category == CAT_NONE)
		Fail("Manual bench use did not recover after stopping the job.")
	terminal.queue_recipe(bench, recipe, user)
	terminal.start_workshop(user)
	sleep(3)
	driver.forceMove(run_loc_floor_top_right)
	sleep(4 SECONDS)
	if(terminal.workshop_running || length(terminal.workshop_queue) != 1 || welder.get_fuel() != fuel_before || !crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("Removing a tool mid-craft failed to pause without consumption.")
	driver.forceMove(get_turf(bench))
	terminal.start_workshop(user)
	sleep(3)
	welder.reagents.clear_reagents()
	sleep(4 SECONDS)
	if(terminal.workshop_running || length(terminal.workshop_queue) != 1 || !crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("Running out of welding fuel failed to pause without consuming ingredients.")
	welder.reagents.add_reagent(/datum/reagent/fuel, 5)
	welder.welding = TRUE
	terminal.start_workshop(user)
	sleep(4 SECONDS)
	if(terminal.workshop_running || length(terminal.workshop_queue) || welder.get_fuel() != 4 || crafting.check_contents(user, recipe, crafting.get_surroundings(user)))
		Fail("Refuelled queue did not finish and charge exactly one fuel unit for the shared tool.")
	for(var/obj/item/reagent_containers/ms13/inhaler/hydra/product in get_turf(user))
		allocated |= product
	// Manual crafting uses the same rules, including tools carried by the operator.
	welder.forceMove(user)
	supply(recipe, get_turf(bench))
	mix(crafting, user, recipe)
	if(!istype(craft_result, recipe.result) || welder.get_fuel() != 3)
		Fail("Manual crafting bypassed tool fuel, or failed to find a carried tool.")
	welder.forceMove(run_loc_floor_top_right)
	recipe.tool_paths = null
	var/obj/item/gun/energy/plasmacutter/cutter = allocate(/obj/item/gun/energy/plasmacutter, get_turf(bench))
	cutter.cell.charge = 0
	if(crafting.check_tools(user, recipe, crafting.get_surroundings(user)))
		Fail("An empty powered welding tool was usable.")
	cutter.cell.charge = cutter.charge_weld * 2
	if(!crafting.check_tools(user, recipe, crafting.get_surroundings(user), consume = TRUE) || cutter.cell.charge != cutter.charge_weld)
		Fail("Powered tools did not pay their native energy cost.")
#endif
