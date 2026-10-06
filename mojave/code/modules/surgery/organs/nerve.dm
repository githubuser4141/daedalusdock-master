// One /obj/item/organ/nerve per arm and leg, alongside vessel, muscle and bone, and in the chest the spinal cord and
// both brachial plexuses that the limbs' own nerves run back through. A limb's muscle only works as well as its nerves
// signal it (get_nerve_signal(), read by get_muscle_performance() in muscle_movement.dm): a hurt nerve weakens the
// limb, a blow to it can numb the limb outright for a while, and a destroyed one numbs it until it's mended. Numb, the
// muscle reads as critically weak, so DD's own disable cascade drops what the hand held or folds the leg. A chest
// nerve does the same to every limb it serves: the spine to both legs, a plexus to its arm. Endurance shakes a blow
// off quicker and more often.
// Sprite ported from CEV-Eris (icons/obj/surgery.dmi, AGPL-3.0) into mojave/icons/objects/organs/tissue_organs.dmi.

TYPEINFO_DEF(/obj/item/organ/nerve)
	default_armor = list(BLUNT = 15, PUNCTURE = 2, SLASH = 5, LASER = 10, ENERGY = 0, BOMB = 0, BIO = 100, FIRE = 25, ACID = 25)

/obj/item/organ/nerve
	name = "nerve"
	desc = "A bundle of nerve fibres. Best left where it is."
	icon = 'mojave/icons/objects/organs/tissue_organs.dmi'
	icon_state = "nerve"
	w_class = WEIGHT_CLASS_TINY
	organ_flags = NONE
	ms13_tissue = TRUE
	maxHealth = MS13_NERVE_MAX_HEALTH
	relative_size = MS13_NERVE_RELATIVE_SIZE
	low_threshold_passed = span_info("Pins and needles prickle down the limb...")
	high_threshold_passed = span_warning("The limb tingles and won't quite answer.")
	now_failing = span_userdanger("All feeling drains out of the limb!")
	now_fixed = span_info("Feeling creeps back into the limb.")
	high_threshold_cleared = span_info("The tingling fades.")
	bullet_hit_chance = MS13_NERVE_BULLET_HIT_CHANCE
	bullet_depth = BULLET_DEPTH_MIDDLE
	/// world.time a blow numbed it until.
	var/tmp/numb_until = 0
	/// For a chest nerve, the limb zones it carries signal on to. A limb's own nerve serves just its limb.
	var/list/relays_to
	/// What goes numb, said to its owner, if not its own limb's name.
	var/numb_name
	/// Whether numb_name is plural ("legs").
	var/numb_plural = FALSE

/obj/item/organ/nerve/l_arm
	name = "left arm nerve"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_NERVE_L_ARM

/obj/item/organ/nerve/r_arm
	name = "right arm nerve"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_NERVE_R_ARM

/obj/item/organ/nerve/l_leg
	name = "left leg nerve"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_NERVE_L_LEG

/obj/item/organ/nerve/r_leg
	name = "right leg nerve"
	zone = BODY_ZONE_R_LEG
	slot = ORGAN_SLOT_NERVE_R_LEG

/obj/item/organ/nerve/spine
	name = "spinal cord"
	desc = "The cord every signal to the legs runs down. Very much best left where it is."
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_NERVE_SPINE
	maxHealth = MS13_SPINE_MAX_HEALTH
	bullet_hit_chance = MS13_SPINE_BULLET_HIT_CHANCE
	bullet_depth = BULLET_DEPTH_INNER
	relays_to = list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	numb_name = "legs"
	numb_plural = TRUE

/obj/item/organ/nerve/plexus_l
	name = "left brachial plexus"
	desc = "The knot of nerves at the shoulder that the whole arm answers to."
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_NERVE_L_PLEXUS
	bullet_hit_chance = MS13_PLEXUS_BULLET_HIT_CHANCE
	relays_to = list(BODY_ZONE_L_ARM)
	numb_name = "left arm"

/obj/item/organ/nerve/plexus_r
	name = "right brachial plexus"
	desc = "The knot of nerves at the shoulder that the whole arm answers to."
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_NERVE_R_PLEXUS
	bullet_hit_chance = MS13_PLEXUS_BULLET_HIT_CHANCE
	relays_to = list(BODY_ZONE_R_ARM)
	numb_name = "right arm"

/// 0-100: how well it carries signal. Numb or destroyed, not at all.
/obj/item/organ/nerve/proc/get_signal()
	if((organ_flags & ORGAN_DEAD) || world.time < numb_until)
		return 0
	return round(100 * (1 - MS13_NERVE_DAMAGE_SIGNAL_LOSS * damage / maxHealth), 1)

/// 0-100: its own nerve's signal, times that of whatever chest nerve it runs back through. 100 (no-op) without them.
/obj/item/bodypart/proc/get_nerve_signal()
	. = 100
	for(var/obj/item/organ/nerve/N in contained_organs)
		if(!N.relays_to)
			. = N.get_signal()
	var/obj/item/bodypart/chest = owner?.get_bodypart(BODY_ZONE_CHEST)
	if(!chest || chest == src)
		return
	for(var/obj/item/organ/nerve/relay in chest.contained_organs)
		if(body_zone in relay.relays_to)
			. = . * relay.get_signal() / 100

/// The limbs it signals.
/obj/item/organ/nerve/proc/get_served_limbs()
	if(!relays_to)
		return ownerlimb ? list(ownerlimb) : list()
	. = list()
	for(var/zone in relays_to)
		var/obj/item/bodypart/limb = owner?.get_bodypart(zone)
		if(limb)
			. += limb

/obj/item/organ/nerve/proc/refresh_served_limbs()
	for(var/obj/item/bodypart/limb as anything in get_served_limbs())
		limb.refresh_muscle_effects()

/// A blow may numb what it serves on the spot: the harder it is, and the less enduring its owner, the likelier and longer.
/obj/item/organ/nerve/applyOrganDamage(damage_amount, maximum = maxHealth, silent, updating_health = TRUE, cause_of_death = "Organ failure")
	var/signal = get_signal()
	. = ..()
	if(!owner || !ownerlimb)
		return
	if(damage_amount > 0 && !(organ_flags & ORGAN_DEAD))
		var/blow = damage_amount / maxHealth * max(1 - MS13_NERVE_ENDURANCE_RESIST * owner.get_special_offset(SPECIAL_ENDURANCE), 0.2)
		if(prob(blow * MS13_NERVE_NUMB_CHANCE))
			numb(MS13_NERVE_NUMB_TIME * (0.5 + blow))
	if(get_signal() != signal)
		refresh_served_limbs()

/obj/item/organ/nerve/proc/numb(time)
	var/was_numb = world.time < numb_until
	numb_until = max(numb_until, world.time + time)
	addtimer(CALLBACK(src, PROC_REF(feel_again)), numb_until - world.time, TIMER_UNIQUE|TIMER_OVERRIDE)
	if(was_numb || !owner || !ownerlimb)
		return
	var/legs = FALSE
	for(var/obj/item/bodypart/limb as anything in get_served_limbs())
		limb.refresh_muscle_effects()
		legs ||= limb.bodypart_flags & BP_IS_MOVEMENT_LIMB
	var/what = numb_name || ownerlimb.plaintext_zone
	// A leg that goes dead mid-stride takes its owner down with it.
	if(legs && owner.body_position == STANDING_UP)
		owner.visible_message(
			span_danger("[owner]'s [what] [numb_plural ? "give" : "gives"] way under [owner.p_them()]!"),
			span_userdanger("Your [what] [numb_plural ? "go" : "goes"] numb and fold[numb_plural ? "" : "s"] under you!"),
		)
		owner.Knockdown(MS13_NERVE_BUCKLE_TIME)
	else
		to_chat(owner, span_userdanger("Your [what] [numb_plural ? "go" : "goes"] numb!"))

/obj/item/organ/nerve/proc/feel_again()
	if(!owner || !ownerlimb)
		return
	if(!(organ_flags & ORGAN_DEAD))
		to_chat(owner, span_notice("Feeling floods back into your [numb_name || ownerlimb.plaintext_zone]."))
	refresh_served_limbs()

/obj/item/organ/nerve/set_organ_dead(failing, cause_of_death)
	. = ..()
	if(.)
		refresh_served_limbs()

/obj/item/organ/nerve/Insert(mob/living/carbon/reciever, special = FALSE, drop_if_replaced = TRUE)
	. = ..()
	refresh_served_limbs()

/obj/item/organ/nerve/Remove(mob/living/carbon/organ_owner, special = FALSE)
	var/list/served = get_served_limbs()
	. = ..()
	for(var/obj/item/bodypart/limb as anything in served)
		limb.refresh_muscle_effects()

/// The worst of the nerves in this limb.
/obj/item/bodypart/proc/get_nerve_examine_text()
	. = null
	for(var/obj/item/organ/nerve/N in contained_organs)
		if(N.organ_flags & ORGAN_DEAD)
			return span_alert("Pinching [N.relays_to ? "the [N.numb_name]" : "it"] gets no reaction at all. The [N.name] is gone.")
		if(world.time < N.numb_until)
			. = span_warning("[N.relays_to ? "The [N.numb_name] [N.numb_plural ? "are" : "is"]" : "It's"] numb - a pinch barely registers.")
		else if(!. && N.damage > N.maxHealth * N.low_threshold)
			. = span_notice("Feeling in [N.relays_to ? "the [N.numb_name]" : "it"] is patchy and dull.")

#ifdef UNIT_TESTS
/// A blow to a nerve numbs its limb at once and for a while, disabling it; a hurt one weakens it; a destroyed one
/// numbs it until mended; and Endurance shakes blows off.
/datum/unit_test/ms13_nerves
	name = "NERVES: A Struck Nerve Numbs Its Limb For A While"

/datum/unit_test/ms13_nerves/Run()
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = person.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/organ/nerve/nerve = locate() in arm.contained_organs
	if(!nerve)
		return Fail("A human arm has no nerve.")
	var/performance = arm.get_muscle_performance()

	nerve.damage = nerve.maxHealth / 2
	if(arm.get_muscle_performance() >= performance)
		Fail("A hurt nerve didn't weaken its limb.")
	nerve.damage = 0

	nerve.numb(10 SECONDS)
	if(nerve.get_signal() || !arm.bodypart_disabled)
		Fail("A numb limb still worked.")
	nerve.numb_until = world.time
	nerve.feel_again()
	if(arm.bodypart_disabled || arm.get_muscle_performance() != performance)
		Fail("Feeling coming back didn't bring the limb back.")

	nerve.applyOrganDamage(nerve.maxHealth)
	if(!(nerve.organ_flags & ORGAN_DEAD) || !arm.bodypart_disabled)
		Fail("A destroyed nerve didn't numb its limb.")
	nerve.applyOrganDamage(-nerve.maxHealth)
	nerve.check_failing_thresholds(TRUE)
	if(arm.bodypart_disabled)
		Fail("A mended nerve left its limb numb.")

	var/obj/item/bodypart/leg = person.get_bodypart(BODY_ZONE_L_LEG)
	var/obj/item/organ/nerve/leg_nerve = locate() in leg.contained_organs
	leg_nerve.numb(5 SECONDS)
	if(!person.IsKnockdown())
		Fail("A leg going numb didn't take its owner down.")
	if(person.get_stat(SPECIAL_AGILITY) >= person.get_special(SPECIAL_AGILITY))
		Fail("A numb leg didn't cost Agility.")
	leg_nerve.numb_until = world.time
	leg_nerve.feel_again()
	person.SetKnockdown(0)

	// The spine takes both legs with it, a plexus its arm.
	var/obj/item/bodypart/chest = person.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/organ/nerve/spine/spine = locate() in chest.contained_organs
	var/obj/item/organ/nerve/plexus_l/plexus = locate() in chest.contained_organs
	if(!spine || !plexus)
		return Fail("A human chest has no spinal cord or brachial plexus.")
	spine.numb(5 SECONDS)
	plexus.numb(5 SECONDS)
	if(!leg.bodypart_disabled || !person.get_bodypart(BODY_ZONE_R_LEG).bodypart_disabled || !person.get_bodypart(BODY_ZONE_L_ARM).bodypart_disabled || arm.bodypart_disabled)
		Fail("A numb spine or plexus didn't take what it serves with it, or took more.")
	spine.numb_until = world.time
	plexus.numb_until = world.time
	spine.feel_again()
	plexus.feel_again()
	person.SetKnockdown(0)
	if(leg.bodypart_disabled || person.get_bodypart(BODY_ZONE_L_ARM).bodypart_disabled)
		Fail("Feeling coming back to the spine or plexus didn't bring the limbs back.")

	// A quarter of its health in one blow numbs a frail arm more often than a hardy one.
	person.set_special_base(SPECIAL_ENDURANCE, 1)
	var/mob/living/carbon/human/consistent/hardy = allocate(/mob/living/carbon/human/consistent)
	hardy.set_special_base(SPECIAL_ENDURANCE, 10)
	var/obj/item/bodypart/hardy_arm = hardy.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/organ/nerve/hardy_nerve = locate() in hardy_arm.contained_organs
	var/frail_numbs = 0
	var/hardy_numbs = 0
	for(var/i in 1 to 40)
		nerve.numb_until = 0
		hardy_nerve.numb_until = 0
		nerve.applyOrganDamage(nerve.maxHealth / 4)
		hardy_nerve.applyOrganDamage(hardy_nerve.maxHealth / 4)
		frail_numbs += world.time < nerve.numb_until
		hardy_numbs += world.time < hardy_nerve.numb_until
		nerve.applyOrganDamage(-nerve.damage)
		hardy_nerve.applyOrganDamage(-hardy_nerve.damage)
	if(frail_numbs <= hardy_numbs)
		Fail("Endurance didn't shake off nerve blows ([frail_numbs] frail against [hardy_numbs] hardy, of 40).")
#endif
