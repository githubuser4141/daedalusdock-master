// Spending S.P.E.C.I.A.L. points at character setup: its own tab, one number per attribute, SPECIAL_POINTS in all.

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

/// Offers no more than the points left to spend.
/datum/preference/numeric/special/user_edit(mob/user, datum/preferences/prefs)
	var/current = prefs.read_preference(type)
	var/left = SPECIAL_POINTS - special_points_spent(prefs)
	var/input = tgui_input_number(user, "[explanation]: [special_description(attribute)] [left] point\s left to spend.", "S.P.E.C.I.A.L.", current, max(minimum, min(maximum, current + left)), minimum)
	if(isnull(input))
		return
	return prefs.update_preference(src, input)

/proc/special_points_spent(datum/preferences/prefs)
	. = 0
	for(var/pref_type in subtypesof(/datum/preference/numeric/special))
		. += prefs.read_preference(pref_type)

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
	var/left = SPECIAL_POINTS - special_points_spent(prefs)
	. += {"
	<fieldset class='computerPaneNested' style='display: inline-block;min-width:60%;max-width:60%'>
		<legend class='computerLegend'><b>S.P.E.C.I.A.L.</b></legend>
		<p class='computerText'>Every attribute starts at [SPECIAL_BASELINE]. [left] point\s left to spend: lower one to raise another.</p>
	<table style='width:100%'>
	"}
	for(var/pref_type in subtypesof(/datum/preference/numeric/special))
		var/datum/preference/numeric/special/pref = GLOB.preference_entries[pref_type]
		. += {"
			<tr>
				<td style='padding: 4px 8px'><span class='computerText'>[pref.explanation]</span></td>
				<td style='padding: 4px 8px'>[pref.get_button(prefs)]</td>
				<td style='padding: 4px 8px'><span class='computerText'>[special_description(pref.attribute)]</span></td>
			</tr>
		"}
	. += "</table></fieldset>"
