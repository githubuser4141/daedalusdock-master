// Spending S.P.E.C.I.A.L. points at character setup: its own tab, one number per attribute, SPECIAL_POINTS in all.
// What the character's species and traits add to an attribute shifts what its points buy (SPECIAL_POINTS_MIN/MAX); the
// tab shows the attribute with them.

/datum/preference/numeric/special
	abstract_type = /datum/preference/numeric/special
	savefile_identifier = PREFERENCE_CHARACTER
	minimum = SPECIAL_MINIMUM
	maximum = SPECIAL_MAXIMUM
	/// The attribute it sets.
	var/attribute

/datum/preference/numeric/special/create_default_value()
	return SPECIAL_BASELINE

/datum/preference/numeric/special/apply_to_human(mob/living/carbon/human/target, value)
	target.set_special_base(attribute, value)

/// Asks for the attribute as it'll be, with its modifier, offering no more than the points left to spend.
/datum/preference/numeric/special/user_edit(mob/user, datum/preferences/prefs)
	var/list/modifiers = special_setup_modifiers(prefs)
	var/modifier = modifiers[attribute] || 0
	var/points = points_on(prefs, modifier)
	var/left = SPECIAL_POINTS - special_points_spent(prefs, modifiers)
	var/input = tgui_input_number(user, "[explanation]: [special_description(attribute)] [left] point\s left to spend.", "S.P.E.C.I.A.L.", points + modifier, min(SPECIAL_POINTS_MAX(modifier), points + max(left, 0)) + modifier, SPECIAL_POINTS_MIN(modifier) + modifier)
	if(isnull(input))
		return
	return prefs.update_preference(src, input - modifier)

/datum/preference/numeric/special/get_button(datum/preferences/prefs)
	var/list/modifiers = special_setup_modifiers(prefs)
	return button_element(prefs, points_on(prefs, modifiers[attribute]) + modifiers[attribute], "pref_act=[type]")

/// The points on this attribute, within what they can buy with modifier on top.
/datum/preference/numeric/special/proc/points_on(datum/preferences/prefs, modifier)
	return clamp(prefs.read_preference(type), SPECIAL_POINTS_MIN(modifier), SPECIAL_POINTS_MAX(modifier))

/proc/special_points_spent(datum/preferences/prefs, list/modifiers)
	modifiers ||= special_setup_modifiers(prefs)
	. = 0
	for(var/pref_type in subtypesof(/datum/preference/numeric/special))
		var/datum/preference/numeric/special/pref = GLOB.preference_entries[pref_type]
		. += pref.points_on(prefs, modifiers[pref.attribute])

/// What the character's species and traits add to each attribute: attribute = amount. out_sources gets who adds what,
/// attribute = list(source = amount).
/proc/special_setup_modifiers(datum/preferences/prefs, list/out_sources)
	. = list()
	var/datum/species/species_type = prefs.read_preference(/datum/preference/choiced/species)
	var/list/sources = list("[format_text(initial(species_type.name))]" = species_type)
	var/list/all_quirks = SSquirks.get_quirks()
	for(var/quirk_name in prefs.read_preference(/datum/preference/blob/quirks))
		sources[quirk_name] = all_quirks[quirk_name]
	for(var/source in sources)
		var/list/amounts = special_modifiers_of(sources[source])
		for(var/attribute in amounts)
			.[attribute] += amounts[attribute]
			if(out_sources)
				LAZYSET(out_sources[attribute], source, amounts[attribute])

/// Keeps the points on each attribute within what it can take with the character's species and traits, and the whole
/// within SPECIAL_POINTS, taking any overspend off the highest.
/proc/fit_special_prefs(datum/preferences/prefs)
	var/list/modifiers = special_setup_modifiers(prefs)
	var/list/points = list()
	var/over = -SPECIAL_POINTS
	for(var/pref_type in subtypesof(/datum/preference/numeric/special))
		var/datum/preference/numeric/special/pref = GLOB.preference_entries[pref_type]
		points[pref] = pref.points_on(prefs, modifiers[pref.attribute])
		over += points[pref]
	while(over > 0)
		var/datum/preference/numeric/special/highest
		for(var/datum/preference/numeric/special/pref as anything in points)
			if(points[pref] > SPECIAL_POINTS_MIN(modifiers[pref.attribute]) && (!highest || points[pref] > points[highest]))
				highest = pref
		if(!highest)
			break
		points[highest]--
		over--
	for(var/datum/preference/numeric/special/pref as anything in points)
		prefs.update_preference(pref, points[pref])

/datum/preferences/update_preference(datum/preference/preference, preference_value)
	. = ..()
	if(. && (istype(preference, /datum/preference/choiced/species) || istype(preference, /datum/preference/blob/quirks)))
		fit_special_prefs(src)

/datum/preference/numeric/special/strength
	explanation = "Strength"
	savefile_key = "special_strength"
	attribute = SPECIAL_STRENGTH

/datum/preference/numeric/special/perception
	explanation = "Perception"
	savefile_key = "special_perception"
	attribute = SPECIAL_PERCEPTION

/datum/preference/numeric/special/endurance
	explanation = "Endurance"
	savefile_key = "special_endurance"
	attribute = SPECIAL_ENDURANCE

/datum/preference/numeric/special/charisma
	explanation = "Charisma"
	savefile_key = "special_charisma"
	attribute = SPECIAL_CHARISMA

/datum/preference/numeric/special/intelligence
	explanation = "Intelligence"
	savefile_key = "special_intelligence"
	attribute = SPECIAL_INTELLIGENCE

/datum/preference/numeric/special/agility
	explanation = "Agility"
	savefile_key = "special_agility"
	attribute = SPECIAL_AGILITY

/datum/preference/numeric/special/luck
	explanation = "Luck"
	savefile_key = "special_luck"
	attribute = SPECIAL_LUCK

/datum/preference_group/category/special
	name = "S.P.E.C.I.A.L."
	priority = 90

/datum/preference_group/category/special/get_content(datum/preferences/prefs)
	. = ..()
	var/list/sources = list()
	var/list/modifiers = special_setup_modifiers(prefs, sources)
	var/left = SPECIAL_POINTS - special_points_spent(prefs, modifiers)
	. += {"
	<fieldset class='computerPaneNested' style='display: inline-block;min-width:60%;max-width:60%'>
		<legend class='computerLegend'><b>S.P.E.C.I.A.L.</b></legend>
		<p class='computerText'>Every attribute starts at [SPECIAL_BASELINE], give or take your species and traits. [left] point\s left to spend: lower one to raise another.</p>
	<table style='width:100%'>
	"}
	for(var/pref_type in subtypesof(/datum/preference/numeric/special))
		var/datum/preference/numeric/special/pref = GLOB.preference_entries[pref_type]
		var/list/from = list()
		for(var/source in sources[pref.attribute])
			var/amount = sources[pref.attribute][source]
			from += "[amount > 0 ? "+" : ""][amount] [source]"
		. += {"
			<tr>
				<td style='padding: 4px 8px'><span class='computerText'>[pref.explanation]</span></td>
				<td style='padding: 4px 8px'>[pref.get_button(prefs)]</td>
				<td style='padding: 4px 8px'><span class='computerText'>[jointext(from, ", ")]</span></td>
				<td style='padding: 4px 8px'><span class='computerText'>[special_description(pref.attribute)]</span></td>
			</tr>
		"}
	. += "</table></fieldset>"

#ifdef UNIT_TESTS
/// A trait that trades SPECIAL about leaves the points alone, shifts what they buy, and sits on its holder while held.
/datum/unit_test/ms13_special_traits
	name = "SPECIAL: Species And Traits Shift What Points Buy"

/datum/unit_test/ms13_special_traits/Run()
	var/datum/preferences/prefs = new(new /datum/client_interface)
	var/datum/preference/blob/quirks = GLOB.preference_entries[/datum/preference/blob/quirks]
	var/list/special = list()
	for(var/pref_type in subtypesof(/datum/preference/numeric/special))
		var/datum/preference/numeric/special/pref = GLOB.preference_entries[pref_type]
		special[pref.attribute] = pref
		prefs.update_preference(pref, SPECIAL_BASELINE)
	var/spent = special_points_spent(prefs)
	var/list/species_modifiers = special_setup_modifiers(prefs)
	// -2 Perception, +1 Strength, +1 Endurance: the character shows it, and has the same points left.
	prefs.update_preference(quirks, list(/datum/quirk/ms13_special_test::name))
	var/list/modifiers = special_setup_modifiers(prefs)
	var/list/trade = list(SPECIAL_PERCEPTION = -2, SPECIAL_STRENGTH = 1, SPECIAL_ENDURANCE = 1, SPECIAL_LUCK = 0)
	for(var/attribute in trade)
		var/datum/preference/numeric/special/pref = special[attribute]
		if(pref.points_on(prefs, modifiers[attribute]) + modifiers[attribute] != SPECIAL_BASELINE + species_modifiers[attribute] + trade[attribute])
			Fail("Setup didn't show [attribute] with the trait on it.")
	if(special_points_spent(prefs) != spent)
		Fail("Taking a trait that trades SPECIAL about changed the points spent.")
	if(SPECIAL_POINTS_MAX(-2) - 2 != 8)
		Fail("A -2 attribute could be bought past 8.")

	// Perception already dumped to 1 can't lose two more: the 2 points it costs come off the highest others.
	prefs.update_preference(quirks, list())
	var/list/spend = list(SPECIAL_STRENGTH = 7, SPECIAL_PERCEPTION = 1, SPECIAL_ENDURANCE = 7, SPECIAL_CHARISMA = 7, SPECIAL_INTELLIGENCE = 6, SPECIAL_AGILITY = 6, SPECIAL_LUCK = 6)
	for(var/attribute in spend)
		prefs.update_preference(special[attribute], spend[attribute])
	if(special_points_spent(prefs) != SPECIAL_POINTS)
		Fail("The test character didn't spend every point.")
	prefs.update_preference(quirks, list(/datum/quirk/ms13_special_test::name))
	var/datum/preference/numeric/special/perception = special[SPECIAL_PERCEPTION]
	if(perception.points_on(prefs, -2) != 3 || special_points_spent(prefs) != SPECIAL_POINTS)
		Fail("Perception 1 under a -2 trait didn't cost 3 points, or left the character off budget.")

	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent)
	var/list/before = list()
	for(var/attribute in trade)
		before[attribute] = person.get_special(attribute)
	person.add_quirk(/datum/quirk/ms13_special_test)
	for(var/attribute in trade)
		if(person.get_special(attribute) != before[attribute] + trade[attribute])
			Fail("A trait's [attribute] didn't reach its holder.")
	person.remove_quirk(/datum/quirk/ms13_special_test)
	for(var/attribute in trade)
		if(person.get_special(attribute) != before[attribute])
			Fail("A trait's [attribute] outlasted the trait.")

/datum/quirk/ms13_special_test
	name = "MS13 SPECIAL test trade"
	desc = "Unit test only: -2 Perception, +1 Strength, +1 Endurance."
	icon = "ms13-special-test"
	special_modifiers = list(SPECIAL_PERCEPTION = -2, SPECIAL_STRENGTH = 1, SPECIAL_ENDURANCE = 1)
#endif
