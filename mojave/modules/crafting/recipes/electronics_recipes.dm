//Recipes for all kinds of electronics crafting

//ELECTRONICS CRAFTING

/datum/crafting_recipe/shart_flashlight
	name = "homemade flashlight"
	result = /obj/item/flashlight/ms13/crafted
	time = 6 SECONDS
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/light/ms13/bulb = 1,
				/obj/item/ms13/component/cell = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 2,
				/obj/item/stack/sheet/ms13/scrap_electronics = 2)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_GENERAL | CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/flashlight
	name = "flashlight"
	result = /obj/item/flashlight/ms13
	time = 12 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/ms13/component/cell = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 4,
				/obj/item/stack/sheet/ms13/scrap_electronics = 4,
				/obj/item/stack/sheet/ms13/refined_alu = 1,
				/obj/item/stack/sheet/ms13/scrap_parts = 2,
				/obj/item/stack/sheet/ms13/glass = 4,
				/obj/item/stack/sheet/ms13/circuits = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/stick_flashlight
	name = "stick flashlight"
	result = /obj/item/flashlight/ms13/mag
	time = 20 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WRENCH)
	tool_paths = list(/obj/item/wirecutters/ms13)
	trait = TRAIT_SCRIBE_TRAINING
	reqs = list(/obj/item/ms13/component/cell = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 6,
				/obj/item/stack/sheet/ms13/scrap_electronics = 6,
				/obj/item/stack/sheet/ms13/refined_alu = 2,
				/obj/item/stack/sheet/ms13/scrap_parts = 6,
				/obj/item/stack/sheet/ms13/glass = 6,
				/obj/item/stack/sheet/ms13/circuits = 4)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/receiver_radio
	name = "receiver hand radio"
	result = /obj/item/radio/ms13
	time = 12 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/ms13/component/cell = 1,
				/obj/item/ms13/component/vacuum_tube = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 4,
				/obj/item/stack/sheet/ms13/scrap_electronics = 4,
				/obj/item/stack/sheet/ms13/plastic = 5,
				/obj/item/stack/sheet/ms13/scrap_parts = 2,
				/obj/item/stack/sheet/ms13/circuits = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/broadcast_radio
	name = "broadcast hand radio"
	result = /obj/item/radio/ms13/broadcast
	time = 18 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/radio/ms13 = 1,
				/obj/item/ms13/component/cell = 1,
				/obj/item/ms13/component/vacuum_tube = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 5,
				/obj/item/stack/sheet/ms13/scrap_electronics = 5,
				/obj/item/stack/sheet/ms13/scrap_parts = 2,
				/obj/item/stack/sheet/ms13/circuits = 2)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/advanced_radio
	name = "advanced hand radio"
	result = /obj/item/radio/ms13/broadcast/advanced
	time = 20 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	trait = TRAIT_SCRIBE_TRAINING
	reqs = list(/obj/item/radio/ms13/broadcast = 1,
				/obj/item/ms13/component/cell = 1,
				/obj/item/ms13/component/vacuum_tube = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 6,
				/obj/item/stack/sheet/ms13/scrap_electronics = 6,
				/obj/item/stack/sheet/ms13/scrap_parts = 3,
				/obj/item/stack/sheet/ms13/circuits = 4)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/energy_cell
	name = "energy cell"
	result = /obj/item/stock_parts/cell/ms13/ec
	time = 10 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/ms13/component/cell = 1,
				/obj/item/stack/sheet/ms13/refined_copper = 2,
				/obj/item/stack/sheet/ms13/scrap_electronics = 3,
				/obj/item/stack/sheet/ms13/plastic = 2)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/mfc
	name = "microfusion cell"
	result = /obj/item/stock_parts/cell/ms13/mfc
	time = 12 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	trait = TRAIT_SCRIBE_TRAINING
	reqs = list(/obj/item/ms13/component/cell = 2,
				/obj/item/stack/sheet/ms13/refined_copper = 3,
				/obj/item/stack/sheet/ms13/scrap_electronics = 5,
				/obj/item/stack/sheet/ms13/refined_lead = 1,
				/obj/item/stack/sheet/ms13/plastic = 3)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ecp
	name = "electron charge pack"
	result = /obj/item/stock_parts/cell/ms13/ecp
	time = 15 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	trait = TRAIT_SCRIBE_TRAINING
	reqs = list(/obj/item/ms13/component/cell = 2,
				/obj/item/stack/sheet/ms13/refined_copper = 4,
				/obj/item/stack/sheet/ms13/scrap_electronics = 6,
				/obj/item/stack/sheet/ms13/refined_lead = 2,
				/obj/item/stack/sheet/ms13/plastic = 3)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/pc
	name = "plasma cell"
	result = /obj/item/stock_parts/cell/ms13/pc
	time = 15 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	trait = TRAIT_SCRIBE_TRAINING
	reqs = list(/obj/item/ms13/component/plasma_battery = 2,
				/obj/item/stack/sheet/ms13/refined_copper = 4,
				/obj/item/stack/sheet/ms13/refined_lead = 2,
				/obj/item/stack/sheet/ms13/plastic = 4)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

//WIRING AND ASSEMBLIES

/datum/crafting_recipe/ms13_cable_coil
	name = "cable coil"
	result = /obj/item/stack/cable_coil/ten
	time = 6 SECONDS
	tool_behaviors = list()
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_copper = 2,
				/obj/item/stack/sheet/ms13/rubber = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_GENERAL | CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_signaler
	name = "remote signaler"
	result = /obj/item/assembly/signaler
	time = 12 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 1,
				/obj/item/stack/sheet/ms13/scrap_electronics = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 2,
				/obj/item/stack/sheet/ms13/plastic = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_timer
	name = "timer"
	result = /obj/item/assembly/timer
	time = 8 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_electronics = 2,
				/obj/item/stack/sheet/ms13/scrap_parts = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_igniter
	name = "igniter"
	result = /obj/item/assembly/igniter
	time = 8 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_electronics = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 2,
				/obj/item/stack/sheet/ms13/scrap = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_GENERAL | CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_prox_sensor
	name = "proximity sensor"
	result = /obj/item/assembly/prox_sensor
	time = 12 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 1,
				/obj/item/stack/sheet/ms13/scrap_electronics = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 1,
				/obj/item/stack/sheet/ms13/glass = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_infrared
	name = "infrared tripwire"
	result = /obj/item/assembly/infra
	time = 12 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/circuits = 1,
				/obj/item/stack/sheet/ms13/scrap_electronics = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 2,
				/obj/item/stack/sheet/ms13/glass = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

//LIGHTING

/datum/crafting_recipe/ms13_light_bulb
	name = "light bulb"
	result = /obj/item/light/ms13/bulb
	time = 5 SECONDS
	tool_behaviors = list()
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/glass = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_light_tube
	name = "light tube"
	result = /obj/item/light/ms13/tube
	time = 6 SECONDS
	tool_behaviors = list()
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/glass = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 1,
				/obj/item/stack/sheet/ms13/scrap_electronics = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_light_fixture
	name = "light fixture"
	result = /obj/item/wallframe/light_fixture/ms13
	time = 8 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/scrap = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 2,
				/obj/item/stack/sheet/ms13/scrap_electronics = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_bulb_fixture
	name = "bulb fixture"
	result = /obj/item/wallframe/light_fixture/ms13/bulb
	time = 6 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/scrap = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_makeshift_lamp
	name = "makeshift lamp"
	result = /obj/structure/ms13/lamp/makeshift
	time = 8 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/light/ms13/bulb = 1,
				/obj/item/ms13/component/cell = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 3)
	category = CAT_UTILITY
	crafting_interface = CRAFTING_BENCH_GENERAL | CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_table_lamp
	name = "table lamp"
	result = /obj/structure/ms13/lamp
	time = 12 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/light/ms13/bulb = 1,
				/obj/item/ms13/component/cell = 1,
				/obj/item/stack/sheet/ms13/scrap = 3,
				/obj/item/stack/sheet/ms13/scrap_parts = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 2)
	category = CAT_UTILITY
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_mining_lamp
	name = "mining lamp"
	result = /obj/structure/ms13/lamp/mining_lamp
	time = 10 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/light/ms13/bulb = 1,
				/obj/item/ms13/component/cell = 1,
				/obj/item/stack/sheet/ms13/scrap = 2,
				/obj/item/stack/sheet/ms13/scrap_parts = 1,
				/obj/item/stack/sheet/ms13/scrap_copper = 1)
	category = CAT_UTILITY
	crafting_interface = CRAFTING_BENCH_GENERAL | CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_lantern
	name = "electric lantern"
	result = /obj/item/flashlight/lantern/ms13
	time = 10 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/light/ms13/bulb = 1,
				/obj/item/ms13/component/cell = 1,
				/obj/item/stack/sheet/ms13/scrap = 2,
				/obj/item/stack/sheet/ms13/glass = 2,
				/obj/item/stack/sheet/ms13/scrap_copper = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_GENERAL | CRAFTING_BENCH_ELECTRIC

//POWER AND MACHINES

/datum/crafting_recipe/ms13_petrol_generator
	name = "petrol generator"
	result = /obj/machinery/ms13/fusion_generator/petrol
	time = 30 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WRENCH, TOOL_WELDER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_steel = 6,
				/obj/item/stack/sheet/ms13/scrap_parts = 6,
				/obj/item/stack/sheet/ms13/scrap_copper = 6,
				/obj/item/stack/sheet/ms13/scrap_electronics = 3,
				/obj/item/stack/sheet/ms13/rubber = 2)
	category = CAT_UTILITY
	crafting_interface = CRAFTING_BENCH_GENERAL

/datum/crafting_recipe/ms13_utility_box
	name = "utility box frame"
	result = /obj/item/wallframe/ms13_utility_box
	time = 15 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/scrap = 3,
				/obj/item/stack/sheet/ms13/scrap_copper = 4,
				/obj/item/stack/sheet/ms13/scrap_electronics = 2,
				/obj/item/stack/sheet/ms13/scrap_parts = 1)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC

/datum/crafting_recipe/ms13_door_motor
	name = "door motor"
	result = /obj/item/ms13/door_motor
	time = 15 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WRENCH)
	tool_paths = list(/obj/item/wirecutters/ms13)
	reqs = list(/obj/item/stack/sheet/ms13/scrap_steel = 2,
				/obj/item/stack/sheet/ms13/scrap_parts = 4,
				/obj/item/stack/sheet/ms13/scrap_copper = 4,
				/obj/item/stack/sheet/ms13/scrap_electronics = 2)
	category = CAT_ELECTRONICS
	crafting_interface = CRAFTING_BENCH_ELECTRIC
