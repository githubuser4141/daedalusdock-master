/**
 * Normalized physical properties for material-driven WIP systems.
 *
 * These are gameplay coefficients, not SI units: 1 is an ordinary structural metal. They are
 * intentionally generic so shaped charges, armor, tools, and future fabrication can share one
 * material model instead of maintaining per-feature material switch statements.
 */
/datum/material
	/// Relative mass per volume; primarily controls momentum and jet mass.
	var/density = 1
	/// Resistance to deformation; feeds projectile integrity/hardness.
	var/hardness = 1
	/// Ability to stretch into a coherent jet before separating.
	var/ductility = 0.5
	/// Resistance to compression; controls how efficiently an explosive impulse couples into it.
	var/bulk_modulus = 1

// Mojave metal values are balance placeholders. See material_physics.md beside this file.
/datum/material/ms13/scrap
	density = 0.75
	hardness = 0.55
	ductility = 0.4
	bulk_modulus = 0.55

/datum/material/ms13/scrap_steel
	density = 0.78
	hardness = 0.8
	ductility = 0.35
	bulk_modulus = 0.8

/datum/material/ms13/refined_steel
	density = 0.78
	hardness = 1
	ductility = 0.45
	bulk_modulus = 1

/datum/material/ms13/scrap_lead
	density = 1.13
	hardness = 0.15
	ductility = 0.45
	bulk_modulus = 0.35

/datum/material/ms13/refined_lead
	density = 1.13
	hardness = 0.25
	ductility = 0.6
	bulk_modulus = 0.45

/datum/material/ms13/scrap_brass
	density = 0.85
	hardness = 0.4
	ductility = 0.65
	bulk_modulus = 0.6

/datum/material/ms13/refined_brass
	density = 0.85
	hardness = 0.55
	ductility = 0.75
	bulk_modulus = 0.7

/datum/material/ms13/scrap_alu
	density = 0.27
	hardness = 0.35
	ductility = 0.65
	bulk_modulus = 0.45

/datum/material/ms13/refined_alu
	density = 0.27
	hardness = 0.45
	ductility = 0.8
	bulk_modulus = 0.55

/datum/material/ms13/scrap_silver
	density = 1.05
	hardness = 0.3
	ductility = 0.7
	bulk_modulus = 0.55

/datum/material/ms13/refined_silver
	density = 1.05
	hardness = 0.4
	ductility = 0.85
	bulk_modulus = 0.65

/datum/material/ms13/scrap_gold
	density = 1.93
	hardness = 0.2
	ductility = 0.8
	bulk_modulus = 0.45

/datum/material/ms13/refined_gold
	density = 1.93
	hardness = 0.3
	ductility = 0.95
	bulk_modulus = 0.55

/datum/material/ms13/scrap_copper
	density = 0.9
	hardness = 0.4
	ductility = 0.75
	bulk_modulus = 0.65

/datum/material/ms13/refined_copper
	density = 0.9
	hardness = 0.5
	ductility = 0.95
	bulk_modulus = 0.75

// MS stacks predate material_type; declaring it here makes their material datum discoverable generically.
/obj/item/stack/sheet/ms13/scrap
	material_type = /datum/material/ms13/scrap
/obj/item/stack/sheet/ms13/scrap_steel
	material_type = /datum/material/ms13/scrap_steel
/obj/item/stack/sheet/ms13/refined_steel
	material_type = /datum/material/ms13/refined_steel
/obj/item/stack/sheet/ms13/scrap_lead
	material_type = /datum/material/ms13/scrap_lead
/obj/item/stack/sheet/ms13/refined_lead
	material_type = /datum/material/ms13/refined_lead
/obj/item/stack/sheet/ms13/scrap_brass
	material_type = /datum/material/ms13/scrap_brass
/obj/item/stack/sheet/ms13/refined_brass
	material_type = /datum/material/ms13/refined_brass
/obj/item/stack/sheet/ms13/scrap_alu
	material_type = /datum/material/ms13/scrap_alu
/obj/item/stack/sheet/ms13/refined_alu
	material_type = /datum/material/ms13/refined_alu
/obj/item/stack/sheet/ms13/scrap_silver
	material_type = /datum/material/ms13/scrap_silver
/obj/item/stack/sheet/ms13/refined_silver
	material_type = /datum/material/ms13/refined_silver
/obj/item/stack/sheet/ms13/scrap_gold
	material_type = /datum/material/ms13/scrap_gold
/obj/item/stack/sheet/ms13/refined_gold
	material_type = /datum/material/ms13/refined_gold
/obj/item/stack/sheet/ms13/scrap_copper
	material_type = /datum/material/ms13/scrap_copper
/obj/item/stack/sheet/ms13/refined_copper
	material_type = /datum/material/ms13/refined_copper

// Explosives expose energy and brisance in the same data-driven style as liner materials.
/obj/item/ms13/component/gunpowder
	var/shaped_charge_energy = 0.85
	var/shaped_charge_brisance = 0.7

/obj/item/ms13/component/gunpowder/hq
	shaped_charge_energy = 1.15
	shaped_charge_brisance = 1.1
