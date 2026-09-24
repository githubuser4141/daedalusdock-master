// Punching things. A bare-handed swing in combat mode at anything solid lands the same punch a person would
// take - Strength and all - against the thing's own damage_deflection and armor. Whatever it won't take comes
// back into the hand.

/// Share of a punch the target refuses that comes back up the arm.
#define PUNCH_RECOIL 0.5
/// Share of what a glass pane takes from a punch that it gives back as cuts.
#define PUNCH_GLASS_CUT 0.5

/mob/living/carbon/human/resolve_unarmed_attack(atom/attack_target, list/modifiers)
	var/obj/item/bodypart/arm = hand_bodyparts[active_hand_index]
	if(!combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK) || !arm || arm.bodypart_disabled || !isobj(attack_target) || isitem(attack_target))
		return ..()
	if(!attack_target.density || !attack_target.uses_integrity || (attack_target.resistance_flags & INDESTRUCTIBLE))
		return ..()
	var/obj/target = attack_target
	changeNext_move(CLICK_CD_MELEE)
	do_attack_animation(target, arm.unarmed_attack_effect)
	stamina_swing(STAMINA_SWING_COST_UNARMED)
	target.add_fingerprint(src)
	var/punch = rand(arm.unarmed_damage_low, arm.unarmed_damage_high)
	var/dealt = target.take_damage(punch, BRUTE, BLUNT, TRUE, get_dir(target, src)) || 0
	visible_message(
		span_danger("[src] punches [target][dealt ? "" : ", without leaving a mark"]!"),
		span_danger("You punch [target][dealt ? "" : ", without leaving a mark"]!"),
		vision_distance = COMBAT_MESSAGE_RANGE,
	)
	log_combat(src, target, "punched", addition = "[round(dealt, 0.1)]/[punch] damage")
	target.punch_recoil(src, arm, punch, dealt)
	return TRUE

/// What a bare-handed hit costs the hand that threw it.
/obj/proc/punch_recoil(mob/living/carbon/human/puncher, obj/item/bodypart/arm, punch, dealt)
	puncher.take_punch_recoil(arm, (punch - dealt) * PUNCH_RECOIL)

/// Glass that gives way cuts the fist that broke it.
/obj/structure/window/ms13/punch_recoil(mob/living/carbon/human/puncher, obj/item/bodypart/arm, punch, dealt)
	..()
	puncher.take_punch_recoil(arm, dealt * PUNCH_GLASS_CUT, SHARP_EDGED)

/// Knuckles are covered by gloves as well as whatever covers the arm.
/mob/living/carbon/human/proc/take_punch_recoil(obj/item/bodypart/arm, amount, sharpness = NONE)
	if(amount <= 0)
		return
	var/armor_type = sharpness ? SLASH : BLUNT
	var/protection = checkarmor(arm, armor_type) + (gloves ? gloves.returnArmor().getRating(armor_type) : 0)
	apply_damage(amount, BRUTE, arm, clamp(protection, 0, 100), sharpness = sharpness)

#undef PUNCH_RECOIL
#undef PUNCH_GLASS_CUT

#ifdef UNIT_TESTS
/// An average fist can't dent a mech and hurts for trying; a strong one dents it.
/datum/unit_test/ms13_punching
	name = "PUNCHING: Fists Dent What They're Strong Enough To, And Hurt On What They Aren't"

/datum/unit_test/ms13_punching/Run()
	var/mob/living/carbon/human/puncher = allocate(/mob/living/carbon/human/consistent)
	var/obj/vehicle/sealed/ms13_mech/ripley/mech = allocate(/obj/vehicle/sealed/ms13_mech/ripley)
	puncher.set_combat_mode(TRUE)
	var/obj/item/bodypart/arm = puncher.hand_bodyparts[puncher.active_hand_index]
	var/integrity = mech.get_integrity()
	puncher.resolve_unarmed_attack(mech, list())
	if(mech.get_integrity() != integrity)
		Fail("An average fist dented a mech.")
	if(arm.get_damage() <= 0)
		Fail("Punching a mech didn't hurt the hand.")
	puncher.set_special_base(SPECIAL_STRENGTH, 10)
	puncher.resolve_unarmed_attack(mech, list())
	if(mech.get_integrity() >= integrity)
		Fail("A strong fist didn't dent a mech.")
#endif
