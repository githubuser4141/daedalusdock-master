GLOBAL_LIST_INIT(perks_type, list(
PERK_SILENT_RINNING = /datum/perk/silent_rinning,
PERK_AMATEUR_ARMORER = /datum/perk/amateur_armorer,
PERK_DRAMA_QUEEN = /datum/perk/drama_queen,
PERK_PHONETIC_FANATIC = /datum/perk/phonetic_fanatic,
PERK_GRACEFUL_FALL = /datum/perk/graceful_fall,
PERK_GRABBER = /datum/perk/grabber,
PERK_INSPIRING_VOICE = /datum/perk/inspiring_voice,
PERK_CRABBY_PERSONALITY = /datum/perk/crabby_personality,
PERK_PREACHER = /datum/perk/preacher,
PERK_MUMBLER = /datum/perk/mumbler,
PERK_CHIEF_KIEFER = /datum/perk/chief_kiefer,
PERK_BLESSED = /datum/perk/blessed,
PERK_HUMAN_TORCH = /datum/perk/human_torch,
))

/datum/perk
	var/name = "ERROR: NEED CHANGE NAME VAR"
	var/full_name = "ERROR: NEED CHANGE FULL_NAME VAR"
	var/desc = "ERROR: NEED CHANGE DESC VAR"
	var/full_desc = "ERROR: NEED CHANGE FULL_DESC VAR"

	var/id = "CHANGE THIS, WHEN YOU CREATE NEW PERK"
	var/level = 1
	var/ranks = 1
	var/type_class = "p"
	var/filter = ""

	var/icon/display = null
	var/icon_state = ""

	/// What the perk adds to SPECIAL: attribute = amount.
	var/list/special_modifiers
	/// The SPECIAL attribute "level" is checked against, by type_class.
	var/static/list/class_attributes = list("s" = SPECIAL_STRENGTH, "p" = SPECIAL_PERCEPTION, "e" = SPECIAL_ENDURANCE, "o" = SPECIAL_CHARISMA, "r" = SPECIAL_INTELLIGENCE, "n" = SPECIAL_AGILITY, "l" = SPECIAL_LUCK)

	//Attached stats
	var/datum/ms13_stats/stats

	//DEV THING
	var/is_ready = FALSE

/datum/perk/New(datum/ms13_stats/stats)
	src.stats = stats

/datum/perk/Destroy(force, ...)
	stats = null
	. = ..()

/datum/perk/proc/added_effect()
	stats?.owner?.set_special_modifier("perk: [id]", special_modifiers)

/datum/perk/proc/remove_effect()
	stats?.owner?.set_special_modifier("perk: [id]", null)

/// Above 5, the attribute has to reach level; at 5 or below, it has to be no higher.
/datum/perk/proc/has_level(datum/ms13_stats/s)
	var/attribute = class_attributes[type_class]
	if(!attribute)
		return FALSE
	var/value = s.owner ? s.owner.get_special(attribute) : SPECIAL_BASELINE
	return level > 5 ? value >= level : value <= level

/datum/perk/proc/check_to_add(datum/ms13_stats/s)
	if(!has_level(s))
		return FALSE
	return TRUE
