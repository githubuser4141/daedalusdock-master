// Bridge the existing Mojave metadata to DD's actual wielding and inventory lifecycle.
/obj/item/Initialize(mapload)
	. = ..()
	var/datum/wield_info/info = GLOB.path_to_wield_info[wield_info]
	if(!info || !(info.wield_flags & WIELD_WIELDABLE))
		return
	if(!isnull(info.force_unwielded))
		force = info.force_unwielded
	if(isnull(force_wielded))
		force_wielded = isnull(info.force_wielded) ? force * (info.force_multiplier || 1) : info.force_wielded
	if(info.wielded_hitsound)
		wielded_hitsound = info.wielded_hitsound
	if(info.wield_sound)
		wield_sound = info.wield_sound
	if(info.unwield_sound)
		unwield_sound = info.unwield_sound
	if(info.wield_flags & WIELD_ALWAYS_TWOHANDED)
		ADD_TRAIT(src, TRAIT_NEEDS_TWO_HANDS, "ms13_wield_info")

/obj/item/wield(mob/living/user)
	var/datum/wield_info/info = GLOB.path_to_wield_info[wield_info]
	if(info && !(info.wield_flags & WIELD_WIELDABLE))
		return FALSE
	. = ..()
	if(.)
		user.wield_ui_update(TRUE)

/obj/item/unwield(mob/living/user, show_message = TRUE, dropping = FALSE)
	. = ..()
	if(.)
		user?.wield_ui_update(FALSE)

/obj/item/build_worn_icon(mob/living/carbon/wearer, default_layer = 0, default_icon_file = null, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state = null, override_file = null, fallback = null)
	var/datum/wield_info/info = GLOB.path_to_wield_info[wield_info]
	if(isinhands && wielded && !override_state && (info?.wield_flags & WIELD_HAS_INHANDS))
		var/wielded_state = "[inhand_icon_state || icon_state]_wielded"
		if(wielded_state in icon_states(override_file || default_icon_file))
			override_state = wielded_state
	return ..()

#ifdef UNIT_TESTS
#include "wielding_unit_test.dm"
#endif
