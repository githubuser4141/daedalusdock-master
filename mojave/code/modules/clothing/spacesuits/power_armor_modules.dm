#define MAIN_MODULE_PA "mainmodulepa"
#define PASSIVE_MODULE_PA "passivemodulepa"

/obj/item/ms13/pa_module
	name = "circuit board"
	icon = 'icons/obj/module.dmi'
	icon_state = "circuit_map"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/misc/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	var/class_type = MAIN_MODULE_PA
	var/list/actions_modules = null
	var/zone = null
	var/obj/item/ms13/power_armor/part_pa = null

/obj/item/ms13/pa_module/proc/added_to_pa()
	return

/obj/item/ms13/pa_module/proc/removed_from_pa()
	return

/obj/item/ms13/pa_module/Initialize(mapload)
	. = ..()
	for(var/i in actions_modules)
		actions_modules -= i
		actions_modules += new i(src)

/obj/item/ms13/pa_module/Destroy(force)
	if(part_pa)
		if(part_pa.modules[class_type] == src)
			part_pa.modules[class_type] = null
		LAZYREMOVE(part_pa.actions_modules, actions_modules)
	removed_from_pa()
	part_pa = null
	QDEL_LIST(actions_modules)
	return ..()

/obj/item/ms13/pa_module/minimap
	name = "Circuit board minimap"
	zone = BODY_ZONE_HEAD

/obj/item/ms13/pa_module/kinesis
	name = "power armor kinesis module"
	desc = "A right-arm gravity manipulator. Toggle Kinesis, then middle-click to grab or launch; right-click to release. It can also drive a manual generator. Uses the armor's cell."
	icon = 'icons/obj/clothing/modsuit/mod_modules.dmi'
	icon_state = "kinesis"
	zone = BODY_ZONE_R_ARM
	actions_modules = list(/datum/action/item_action/ms13_kinesis)
	var/obj/item/mod/module/anomaly_locked/kinesis/power_armor/controller
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/installed_frame

/obj/item/ms13/pa_module/kinesis/Initialize(mapload)
	. = ..()
	controller = new(src)

/obj/item/ms13/pa_module/kinesis/Destroy()
	QDEL_NULL(controller)
	return ..()

/obj/item/ms13/pa_module/kinesis/added_to_pa()
	removed_from_pa()
	installed_frame = part_pa?.frame
	if(!installed_frame)
		return
	RegisterSignal(installed_frame, COMSIG_PARENT_QDELETING, PROC_REF(removed_from_pa))
	installed_frame.update_actions()
	LAZYOR(installed_frame.actions, actions_modules)
	var/mob/living/carbon/human/wearer = installed_frame.loc
	if(istype(wearer) && wearer.wear_suit == installed_frame)
		for(var/datum/action/action as anything in actions_modules)
			action.Grant(wearer)

/obj/item/ms13/pa_module/kinesis/removed_from_pa()
	disable()
	for(var/datum/action/action as anything in actions_modules)
		if(action.owner)
			action.Remove(action.owner)
	if(installed_frame)
		UnregisterSignal(installed_frame, COMSIG_PARENT_QDELETING)
		LAZYREMOVE(installed_frame.actions, actions_modules)
		installed_frame.update_actions()
		installed_frame = null

/obj/item/ms13/pa_module/kinesis/ui_action_click(mob/living/user)
	if(controller.kinesis_user)
		disable()
		balloon_alert(user, "kinesis off")
		return
	controller.kinesis_user = user
	if(!controller.check_power(controller.use_power_cost))
		controller.kinesis_user = null
		balloon_alert(user, "armor unpowered or damaged!")
		return
	RegisterSignal(user, COMSIG_MOB_MIDDLECLICKON, PROC_REF(on_middle_click))
	balloon_alert(user, "kinesis on: middle-click to use")

/obj/item/ms13/pa_module/kinesis/proc/disable()
	if(!controller)
		return
	if(controller.kinesis_user)
		UnregisterSignal(controller.kinesis_user, COMSIG_MOB_MIDDLECLICKON)
	controller.clear_grab(FALSE)
	controller.kinesis_user = null

/obj/item/ms13/pa_module/kinesis/proc/on_middle_click(mob/source, atom/target)
	SIGNAL_HANDLER
	if(!controller.check_power(controller.use_power_cost / 10))
		disable()
		return COMSIG_MOB_CANCEL_CLICKON
	if(COOLDOWN_FINISHED(controller, cooldown_timer))
		controller.use_kinesis(target)
		COOLDOWN_START(controller, cooldown_timer, controller.cooldown_time)
	return COMSIG_MOB_CANCEL_CLICKON

/datum/action/item_action/ms13_kinesis
	name = "Toggle Kinesis"

/datum/action/item_action/ms13_kinesis/Remove(mob/remove_from)
	var/obj/item/ms13/pa_module/kinesis/module = target
	module?.disable()
	return ..()

/// Use the MOD controller's beam, cursor, sounds and throws with the PA cell.
/obj/item/mod/module/anomaly_locked/kinesis/power_armor
	accepted_anomalies = null

/obj/item/mod/module/anomaly_locked/kinesis/power_armor/check_power(amount)
	var/obj/item/ms13/pa_module/kinesis/module = loc
	if(!istype(module) || QDELETED(module.part_pa) || module.loc != module.part_pa)
		return FALSE
	var/obj/item/clothing/suit/space/hardsuit/ms13/power_armor/frame = module.part_pa.frame
	var/mob/living/carbon/human/wearer = kinesis_user
	if(QDELETED(frame) || !istype(wearer) || QDELETED(wearer) || wearer.wear_suit != frame || frame.loc != wearer)
		return FALSE
	if(frame.module_armor[module.part_pa.zone] != module.part_pa || frame.get_integrity() <= 0 || module.part_pa.get_integrity() <= 0)
		return FALSE
	return frame.cell?.charge >= max(amount, 0.01)

/obj/item/mod/module/anomaly_locked/kinesis/power_armor/drain_power(amount)
	if(!check_power(amount))
		return FALSE
	var/obj/item/ms13/pa_module/kinesis/module = loc
	return module.part_pa.frame.cell.use(amount)

