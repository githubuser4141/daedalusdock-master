#ifndef MS13_SQUAD_NPCS_INCLUDED
#define MS13_SQUAD_NPCS_INCLUDED

// Experimental, opt-in human squads. Nothing is spawned on existing maps.
GLOBAL_LIST_EMPTY(ms13_squad_units)
GLOBAL_LIST_INIT(ms13_squad_orders, list("Move", "Guard", "Follow", "Patrol", "Attack", "Fire at area", "Fire direction", "Use", "Sit", "Break", "Pick up", "Deliver", "Hold"))
GLOBAL_LIST_INIT(ms13_squad_fire_modes, list("Careful" = 1 SECONDS, "Precise" = 2 SECONDS, "Rapid" = 0.25 SECONDS))

// Living's basic-mob attack implementation skips atom's attack notification.
/mob/living/attack_basic_mob(mob/living/basic/user, list/modifiers)
	. = ..()
	if(.)
		SEND_SIGNAL(src, COMSIG_ATOM_ATTACK_BASIC_MOB, user)

/datum/outfit/ms13_squad
	name = "Squad NPC: basic equipment"
	uniform = /obj/item/clothing/under/ms13/wasteland/worn
	shoes = /obj/item/clothing/shoes/ms13/brownie
	l_pocket = /obj/item/flashlight/ms13
	r_pocket = /obj/item/knife/ms13/combat

/datum/outfit/ms13_squad/sidearm
	name = "Squad NPC: sidearm"
	r_hand = /obj/item/gun/ballistic/automatic/pistol/ms13/m10mm
	back = /obj/item/storage/ms13/leather_backpack
	backpack_contents = list(/obj/item/ammo_box/magazine/ms13/m10mm = 2)
	suit = /obj/item/clothing/suit/armor/ms13/leatherarmor

/datum/outfit/ms13_squad/rifleman
	name = "Squad NPC: rifleman"
	r_hand = /obj/item/gun/ballistic/automatic/ms13/semi/service
	back = /obj/item/storage/ms13/leather_backpack
	backpack_contents = list(/obj/item/ammo_box/magazine/ms13/r20 = 2)
	suit = /obj/item/clothing/suit/armor/ms13/leatherarmor

/datum/outfit/ms13_squad/marksman
	name = "Squad NPC: marksman"
	r_hand = /obj/item/gun/ballistic/automatic/ms13/semi/marksman
	back = /obj/item/storage/ms13/leather_backpack
	backpack_contents = list(/obj/item/ammo_box/magazine/ms13/r20 = 2)
	suit = /obj/item/clothing/suit/armor/ms13/combat

/datum/outfit/ms13_squad/support
	name = "Squad NPC: support gunner"
	r_hand = /obj/item/gun/ballistic/automatic/ms13/full/smg45
	back = /obj/item/storage/ms13/military
	backpack_contents = list(/obj/item/ammo_box/magazine/ms13/smgm45 = 2)
	suit = /obj/item/clothing/suit/armor/ms13/combat

/datum/outfit/ms13_squad/guard
	name = "Squad NPC: armored guard"
	r_hand = /obj/item/gun/ballistic/automatic/ms13/semi/battle
	back = /obj/item/storage/ms13/military
	backpack_contents = list(/obj/item/ammo_box/magazine/ms13/r308_10 = 2)
	suit = /obj/item/clothing/suit/armor/ms13/combat
	head = /obj/item/clothing/head/helmet/ms13/army

/mob/living/carbon/human/ms13_squad
	name = "squad recruit"
	ai_controller = /datum/ai_controller/ms13_squad
	/// Give one leader and their recruits the same nonempty ID in the mapper.
	var/squad_id = ""
	var/datum/outfit/squad_outfit = /datum/outfit/ms13_squad
	var/squad_order = "Guard"
	var/order_status = "Standing by"
	var/datum/weakref/order_target
	var/turf/guard_position
	var/turf/patrol_origin
	var/fire_direction = NONE
	var/datum/weakref/threat
	var/threat_until = 0
	var/datum/weakref/cargo
	var/acting = FALSE
	var/order_deadline = 0
	var/order_serial = 0
	var/fire_mode = "Careful"
	var/next_shot = 0
	var/datum/weakref/aim_target
	var/datum/weakref/aim_weapon
	var/aim_ready_at = 0
	var/datum/weakref/service_weapon
	var/next_enemy_scan = 0
	var/weapon_recovery_deadline = 0
	var/next_weapon_recovery = 0

/mob/living/carbon/human/ms13_squad/sidearm
	name = "squad pistol guard"
	squad_outfit = /datum/outfit/ms13_squad/sidearm

/mob/living/carbon/human/ms13_squad/rifleman
	name = "squad rifleman"
	squad_outfit = /datum/outfit/ms13_squad/rifleman

/mob/living/carbon/human/ms13_squad/marksman
	name = "squad marksman"
	squad_outfit = /datum/outfit/ms13_squad/marksman
	fire_mode = "Precise"

/mob/living/carbon/human/ms13_squad/support
	name = "squad support gunner"
	squad_outfit = /datum/outfit/ms13_squad/support
	fire_mode = "Rapid"

/mob/living/carbon/human/ms13_squad/guard
	name = "squad armored guard"
	squad_outfit = /datum/outfit/ms13_squad/guard

/mob/living/carbon/human/ms13_squad/Initialize(mapload)
	. = ..()
	if(!(fire_mode in GLOB.ms13_squad_fire_modes))
		fire_mode = "Careful"
	GLOB.ms13_squad_units += src
	guard_position = get_turf(src)
	if(squad_outfit)
		equipOutfit(squad_outfit)
	for(var/obj/item/gun/gun in contents)
		service_weapon = WEAKREF(gun)
		break
	RegisterSignal(src, COMSIG_PARENT_ATTACKBY, PROC_REF(attacked_with_item))
	RegisterSignal(src, COMSIG_ATOM_ATTACK_HAND, PROC_REF(attacked_unarmed))
	RegisterSignal(src, COMSIG_ATOM_ATTACK_PAW, PROC_REF(attacked_unarmed))
	RegisterSignal(src, COMSIG_ATOM_ATTACK_ANIMAL, PROC_REF(attacked_by_animal))
	RegisterSignal(src, COMSIG_ATOM_ATTACK_BASIC_MOB, PROC_REF(attacked_by_animal))
	RegisterSignal(src, COMSIG_MOB_ATTACK_ALIEN, PROC_REF(attacked_unarmed))
	RegisterSignal(src, COMSIG_ATOM_BULLET_ACT, PROC_REF(shot_at))
	RegisterSignal(src, COMSIG_ATOM_HITBY, PROC_REF(hit_by_item))
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(reset_aim))

/mob/living/carbon/human/ms13_squad/Destroy()
	GLOB.ms13_squad_units -= src
	order_target = null
	guard_position = null
	patrol_origin = null
	threat = null
	cargo = null
	reset_aim()
	return ..()

/mob/living/carbon/human/ms13_squad/examine(mob/user)
	. = ..()
	. += span_notice("Squad: [squad_id ? html_encode(squad_id) : "unassigned"]. Order: [squad_order]. Fire: [fire_mode]. [order_status].")

/mob/living/carbon/human/ms13_squad/proc/squad_leader()
	if(!squad_id)
		return null
	// ponytail: linear roster lookup suits small opt-in squads; index by ID if deployed in bulk.
	for(var/mob/living/carbon/human/ms13_squad/leader in GLOB.ms13_squad_units)
		if(leader.is_squad_leader && leader.squad_id == squad_id && leader.stat != DEAD && !QDELETED(leader))
			return leader

/mob/living/carbon/human/ms13_squad/proc/squad_friendly(mob/other)
	if(other == src)
		return TRUE
	if(istype(other, /mob/living/carbon/human/ms13_squad))
		var/mob/living/carbon/human/ms13_squad/unit = other
		if(squad_id && unit.squad_id == squad_id)
			return TRUE
	var/mob/living/carbon/human/ms13_squad/leader = squad_leader()
	return other && other == leader?.commander?.resolve()

/mob/living/carbon/human/ms13_squad/proc/retaliate(mob/living/attacker)
	if(QDELETED(attacker) || squad_friendly(attacker) || attacker.stat == DEAD || get_dist(src, attacker) > 7 || attacker.z != z)
		return
	threat = WEAKREF(attacker)
	threat_until = world.time + 15 SECONDS
	// A physical leader shares a firing target without replacing the squad's standing orders.
	var/mob/living/carbon/human/ms13_squad/leader = squad_leader()
	if(leader && leader.stat == CONSCIOUS && get_dist(src, leader) <= 7 && leader.z == z)
		for(var/mob/living/carbon/human/ms13_squad/unit as anything in leader.members())
			if(unit.z == z && get_dist(unit, leader) <= 7)
				unit.threat = WEAKREF(attacker)
				unit.threat_until = threat_until

/mob/living/carbon/human/ms13_squad/proc/attacked_with_item(datum/source, obj/item/item, mob/living/attacker)
	SIGNAL_HANDLER
	if(item.force > 0 && item.damtype != STAMINA)
		retaliate(attacker)

/mob/living/carbon/human/ms13_squad/proc/attacked_unarmed(datum/source, mob/living/attacker, list/modifiers)
	SIGNAL_HANDLER
	if(attacker.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		retaliate(attacker)

/mob/living/carbon/human/ms13_squad/proc/attacked_by_animal(datum/source, mob/living/attacker)
	SIGNAL_HANDLER
	if(attacker.melee_damage_upper > 0)
		retaliate(attacker)

/mob/living/carbon/human/ms13_squad/proc/shot_at(datum/source, obj/projectile/projectile)
	SIGNAL_HANDLER
	if(!projectile.nodamage && projectile.damage > 0 && isliving(projectile.firer))
		retaliate(projectile.firer)

/mob/living/carbon/human/ms13_squad/proc/hit_by_item(datum/source, atom/movable/mover)
	SIGNAL_HANDLER
	if(isitem(mover))
		var/obj/item/item = mover
		if(item.throwforce > 0)
			var/mob/living/thrower = item.thrownby?.resolve()
			if(istype(thrower))
				retaliate(thrower)

/mob/living/carbon/human/ms13_squad/proc/set_order(new_order, atom/target, direction = NONE)
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	brain.stop_travel()
	brain.route_stairs = null
	brain.next_stair_search = 0
	reset_aim()
	if(istype(buckled, /obj/structure/chair/ms13_vehicle_seat) && (new_order in list("Move", "Guard", "Follow", "Patrol", "Attack", "Use", "Break", "Pick up", "Deliver", "Sit")) && !(new_order == "Sit" && target == buckled))
		buckled.user_unbuckle_mob(src, src)
	order_serial++
	squad_order = new_order
	order_target = target ? WEAKREF(target) : null
	guard_position = get_turf(src)
	patrol_origin = guard_position
	fire_direction = direction
	threat = null
	order_deadline = world.time + 45 SECONDS
	order_status = "Acknowledged"

/// Use inventory APIs, including no-drop and hand availability checks.
/mob/living/carbon/human/ms13_squad/proc/ready_item(obj/item/item)
	if(QDELETED(item) || item.loc != src)
		return FALSE
	if(!(item in held_items))
		var/obj/item/held = get_active_held_item()
		if(held?.wielded)
			held.unwield(src)
		if(!length(get_empty_held_indexes()))
			return FALSE
		if(!temporarilyRemoveItemFromInventory(item))
			return FALSE
		if(!put_in_hands(item))
			return FALSE
	var/index = get_held_index_of_item(item)
	if(index != active_hand_index)
		try_swap_hand(index)
	return get_active_held_item() == item

/mob/living/carbon/human/ms13_squad/proc/ready_weapon(ranged_only = FALSE)
	for(var/obj/item/gun/gun in contents)
		if(gun.can_fire() && ready_item(gun))
			service_weapon = WEAKREF(gun)
			return gun
	if(ranged_only)
		return null
	for(var/obj/item/knife/knife in contents)
		if(ready_item(knife))
			return knife
	return null

/// Use carried magazines and normal gun controls; never manufacture ammunition.
/mob/living/carbon/human/ms13_squad/proc/reload_weapon()
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	for(var/obj/item/gun/ballistic/gun in contents)
		if(gun.can_fire() || !ready_item(gun))
			continue
		if(gun.is_jammed || gun.magazine?.ammo_count())
			brain.stop_travel()
			order_status = gun.is_jammed ? "Clearing jam" : "Chambering a round"
			gun.attack_self(src)
			return TRUE
		if(gun.internal_magazine)
			continue
		for(var/obj/item/ammo_box/magazine/spare as anything in get_all_contents_type(/obj/item/ammo_box/magazine))
			if(!istype(spare, gun.mag_type) || !spare.ammo_count() || spare == gun.magazine)
				continue
			if(spare.loc != src && (spare.loc.loc != src || !spare.loc.atom_storage))
				continue
			gun.unwield(src)
			if(!(spare in held_items))
				var/hand = get_empty_held_index()
				if(!hand || !pickup_item(spare, hand))
					continue
			brain.stop_travel()
			order_status = "Reloading"
			if(gun.magazine)
				gun.eject_magazine(src)
			gun.attackby(spare, src)
			if(gun.magazine == spare && !gun.can_fire())
				gun.attack_self(src)
			changeNext_move(CLICK_CD_MELEE)
			return TRUE
	return FALSE

/// Do not deliberately shoot through squadmates. Ordinary projectiles still handle walls and collisions.
/mob/living/carbon/human/ms13_squad/proc/safe_shot(atom/target)
	if(!target || target.z != z || get_dist(src, target) > 7 || !(get_turf(target) in view(7, src)))
		return FALSE
	for(var/turf/tile as anything in get_line(src, target))
		for(var/mob/living/occupant in tile)
			if(occupant != src && squad_friendly(occupant))
				return FALSE
	return TRUE

/mob/living/carbon/human/ms13_squad/proc/fight(atom/target, suppress = FALSE)
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	if(!ready_weapon(TRUE) && reload_weapon())
		return
	var/obj/item/weapon = ready_weapon(suppress)
	if(istype(weapon, /obj/item/gun))
		if(safe_shot(target))
			var/obj/item/gun/gun = weapon
			if(!gun.wielded && length(get_empty_held_indexes()))
				gun.wield(src)
			if(ms13_shot_quality(src, target, ignore_braced = TRUE) < (fire_mode == "Rapid" ? 0.01 : fire_mode == "Precise" ? 0.8 : 0.6))
				reset_aim()
				if(suppress)
					brain.stop_travel()
					order_status = "Waiting for a clear shot"
				else
					brain.approach(target, 0)
					order_status = "Repositioning for a clear shot"
				return
			brain.stop_travel()
			if(fire_mode == "Precise")
				if(aim_target?.resolve() != target || aim_weapon?.resolve() != gun)
					aim_target = WEAKREF(target)
					aim_weapon = WEAKREF(gun)
					aim_ready_at = world.time + GLOB.ms13_squad_fire_modes[fire_mode]
				if(world.time < aim_ready_at || current_gun_recoil() > 0.25)
					order_status = "Taking aim"
					return
			// A click during gun lockout falls through to a melee swing.
			if(world.time < next_shot || !gun.can_fire(TRUE))
				return
			brain.PawnClick(target, TRUE)
			next_shot = world.time + GLOB.ms13_squad_fire_modes[fire_mode]
			reset_aim()
			order_status = "Firing"
		else if(!suppress && !(get_turf(target) in view(7, src)))
			reset_aim()
			brain.approach(target, 0)
		else
			reset_aim()
			brain.stop_travel()
			order_status = "Fire lane blocked"
	else if(suppress)
		reset_aim()
		brain.stop_travel()
		order_status = "Needs a loaded gun"
	else if(brain.approach(target, 1) && target.IsReachableBy(src))
		reset_aim()
		brain.PawnClick(target, TRUE)
		order_status = "Fighting"

/mob/living/carbon/human/ms13_squad/proc/reset_aim()
	SIGNAL_HANDLER
	aim_target = null
	aim_weapon = null
	aim_ready_at = 0

/// Runs through the normal AI ticker. Sleeping interactions cannot overlap another click.
/mob/living/carbon/human/ms13_squad/proc/act_on_order()
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	if(acting || client || !brain.able_to_run() || !isturf(loc) || next_move > world.time)
		return
	acting = TRUE
	perform_order()
	acting = FALSE

/mob/living/carbon/human/ms13_squad/proc/perform_order()
	var/datum/ai_controller/ms13_squad/brain = ai_controller
	var/turf/ground = get_turf(src)
	if(ground?.get_lumcount() < 0.3)
		for(var/obj/item/flashlight/light in contents)
			if(!light.on)
				light.attack_self(src)
	// Recover only our own weapon, never take a weapon from another holder.
	var/obj/item/gun/dropped = service_weapon?.resolve()
	if(dropped && isturf(dropped.loc) && dropped.z == z && get_dist(src, dropped) <= 7 && !dropped.anchored && squad_order != "Hold" && world.time >= next_weapon_recovery)
		if(!weapon_recovery_deadline)
			weapon_recovery_deadline = world.time + 10 SECONDS
		if(world.time >= weapon_recovery_deadline)
			weapon_recovery_deadline = 0
			next_weapon_recovery = world.time + 30 SECONDS
			brain.stop_travel()
		else if(brain.approach(dropped, dropped.IsReachableBy(src) ? 1 : 0) && dropped.IsReachableBy(src))
			var/obj/item/held = get_active_held_item()
			if(held?.wielded)
				held.unwield(src)
			if(!length(get_empty_held_indexes()) && istype(held, /obj/item/knife))
				dropItemToGround(held)
			var/list/empty_hands = get_empty_held_indexes()
			if(length(empty_hands))
				try_swap_hand(empty_hands[1])
			if(pickup_item(dropped))
				weapon_recovery_deadline = 0
			else
				next_weapon_recovery = world.time + 30 SECONDS
				weapon_recovery_deadline = 0
		if(weapon_recovery_deadline)
			order_status = "Recovering weapon"
			return
	if(world.time >= next_enemy_scan && squad_order != "Hold" && !threat?.resolve())
		next_enemy_scan = world.time + 2 SECONDS
		for(var/mob/living/candidate in view(7, src))
			if(candidate.stat == DEAD || squad_friendly(candidate) || faction_check_atom(candidate))
				continue
			var/mob/living/simple_animal/hostile/hostile = candidate
			if((istype(hostile) && hostile.CanAttack(src) && !istype(hostile, /mob/living/simple_animal/hostile/retaliate)) || istype(candidate, /mob/living/basic/ms13/raider))
				retaliate(candidate)
				break
	var/mob/living/enemy = threat?.resolve()
	if(enemy && enemy.stat != DEAD && !squad_friendly(enemy) && enemy.z == z && world.time < threat_until && get_dist(src, enemy) <= 7)
		fight(enemy)
		return
	threat = null
	var/atom/target = order_target?.resolve()
	if(squad_order == "Hold")
		brain.stop_travel()
		return
	if(squad_order == "Guard" && !target)
		target = guard_position
	if(!target || (target.z == z && get_dist(src, target) > 30))
		set_order("Guard", get_turf(src))
		order_status = "Target lost; guarding here"
		return
	if(squad_order == "Sit" && buckled == target)
		brain.stop_travel()
		order_status = "Seated"
		return
	if(squad_order in list("Use", "Break", "Pick up", "Deliver", "Move", "Sit"))
		if(world.time > order_deadline)
			set_order("Guard", get_turf(src))
			order_status = "Order timed out; ready for new orders"
			return
	if(target.z != z)
		brain.approach(target, 0)
		return
	switch(squad_order)
		if("Sit")
			var/obj/structure/chair/ms13_vehicle_seat/seat = target
			if(!istype(seat) || !seat.parent_frame?.vehicle || length(seat.buckled_mobs))
				set_order("Guard", get_turf(src))
				order_status = "Seat unavailable"
				return
			if(brain.approach(seat, 0) && seat.IsReachableBy(src))
				order_status = seat.user_buckle_mob(src, src) ? "Seated" : "Cannot buckle in"
		if("Attack")
			var/mob/living/victim = target
			if(!istype(victim) || victim.stat == DEAD || squad_friendly(victim))
				set_order("Guard", guard_position)
				return
			fight(victim)
		if("Fire at area", "Fire direction")
			brain.stop_travel()
			if(squad_order == "Fire direction")
				var/list/visible_tiles = view(7, src)
				target = get_turf(src)
				for(var/turf/tile as anything in get_line(src, get_ranged_target_turf(src, fire_direction, 7)))
					if(!(tile in visible_tiles))
						break
					target = tile
				if(target == get_turf(src))
					order_status = "No visible firing lane"
					return
			else if(fire_mode != "Precise")
				var/turf/center = get_turf(target)
				var/list/tiles = RANGE_TURFS(1, center)
				target = pick(tiles)
			fight(target, TRUE)
		if("Follow")
			var/mob/living/following = target
			if(!istype(following) || following.stat == DEAD)
				set_order("Guard", get_turf(src))
				return
			brain.approach(target, 2)
		if("Patrol")
			if(brain.approach(target, 0))
				order_target = WEAKREF(patrol_origin)
				patrol_origin = get_turf(target)
		if("Move", "Guard")
			if(brain.approach(target, 0))
				guard_position = get_turf(target)
				squad_order = "Guard"
				order_status = "Guarding"
		if("Use", "Pick up")
			if(!brain.approach(target, (squad_order == "Use" || target.IsReachableBy(src)) ? 1 : 0) || !target.IsReachableBy(src))
				return
			var/obj/item/held = get_active_held_item()
			if(held?.wielded)
				held.unwield(src)
			if(get_active_held_item())
				var/list/empty_hands = get_empty_held_indexes()
				if(!length(empty_hands))
					order_status = "Needs a free hand"
					return
				try_swap_hand(empty_hands[1])
			if(squad_order == "Pick up" && (!isitem(target) || !isturf(target.loc)))
				set_order("Guard", get_turf(src))
				return
			var/started_order = order_serial
			brain.PawnClick(target, FALSE)
			if(order_serial != started_order)
				return
			if(!QDELETED(target) && (target in held_items))
				cargo = WEAKREF(target)
				if(istype(target, /obj/item/gun))
					service_weapon = WEAKREF(target)
			set_order("Guard", get_turf(src))
			order_status = "Interaction attempted"
		if("Break")
			if(brain.approach(target, 1) && target.IsReachableBy(src))
				ready_weapon()
				brain.PawnClick(target, TRUE)
		if("Deliver")
			var/obj/item/item = cargo?.resolve()
			if(!item || !(item in held_items))
				cargo = null
				set_order("Guard", get_turf(src))
				order_status = "No carried item to deliver"
				return
			if(brain.approach(target, 0))
				var/delivered = dropItemToGround(item)
				if(delivered)
					cargo = null
					if(service_weapon?.resolve() == item)
						service_weapon = null
				set_order("Guard", get_turf(src))
				order_status = delivered ? "Delivery finished" : "Cannot release cargo"

/datum/ai_controller/ms13_squad
	default_behavior = /datum/ai_behavior/ms13_squad
	ai_movement = /datum/ai_movement/astar/ms13_squad
	max_target_distance = 30
	var/travel_distance = 1
	var/obj/structure/stairs/route_stairs
	var/next_stair_search = 0

/datum/ai_controller/ms13_squad/get_minimum_distance()
	return travel_distance

/datum/ai_controller/ms13_squad/proc/stop_travel()
	ai_movement.stop_moving_towards(src)
	set_move_target(null)

/datum/ai_controller/ms13_squad/CancelActions()
	. = ..()
	stop_travel()
	route_stairs = null
	if(ai_status == AI_STATUS_ON)
		PauseAi(2 SECONDS)

/datum/ai_controller/ms13_squad/proc/approach(atom/target, distance)
	if(pawn.z != target.z)
		return approach_stairs(target)
	var/datum/ms13_ground_vehicle/destination_vehicle = get_ms13_ground_vehicle_at(target)
	if(destination_vehicle && get_ms13_ground_vehicle_at(pawn) != destination_vehicle)
		distance = 0
	if(get_dist(pawn, target) <= distance)
		stop_travel()
		return TRUE
	var/mob/living/unit = pawn
	if(unit.buckled)
		stop_travel()
		return FALSE
	travel_distance = distance
	if(current_movement_target != target || blackboard[BB_CURRENT_MIN_MOVE_DISTANCE] != distance)
		stop_travel()
		set_move_target(target)
	if(ai_movement.moving_controllers[src] != target)
		ai_movement.start_moving_towards(src, target, distance)
	return FALSE

/datum/ai_behavior/ms13_squad
	action_cooldown = 1 SECONDS

/datum/ai_behavior/ms13_squad/get_cooldown(datum/ai_controller/controller)
	var/mob/living/carbon/human/ms13_squad/unit = controller.pawn
	return unit.fire_mode == "Rapid" ? 0.25 SECONDS : 0.5 SECONDS

/datum/ai_behavior/ms13_squad/perform(delta_time, datum/ai_controller/controller)
	var/mob/living/carbon/human/ms13_squad/unit = controller.pawn
	INVOKE_ASYNC(unit, TYPE_PROC_REF(/mob/living/carbon/human/ms13_squad, act_on_order))
	return BEHAVIOR_PERFORM_COOLDOWN

#include "squad_commands.dm"
#include "squad_navigation.dm"
#include "squad_cryopods.dm"
#include "bodycams.dm"

// Manual MS13 doors intentionally ignore ordinary bump-opening.
/mob/living/carbon/human/ms13_squad/Bump(atom/obstacle)
	. = ..()
	if(istype(obstacle, /obj/machinery/door/unpowered/ms13) || istype(obstacle, /obj/structure/window/ms13_vehicle_wall/solid/door))
		INVOKE_ASYNC(src, PROC_REF(open_path_door), obstacle)

/obj/machinery/door/unpowered/ms13/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(density && istype(pass_info.caller_ref?.resolve(), /mob/living/carbon/human/ms13_squad) && (locked || bolted || (ms13_flags_1 & LOCKABLE_1 && lock_locked)))
		return FALSE
	return ..()

/obj/structure/window/ms13_vehicle_wall/solid/door/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(istype(pass_info.caller_ref?.resolve(), /mob/living/carbon/human/ms13_squad) && !locked)
		return TRUE
	return ..()

/mob/living/carbon/human/ms13_squad/proc/open_path_door(obj/door)
	if(acting || client || !ai_controller.able_to_run() || !Adjacent(door) || !door.density)
		return
	if(istype(door, /obj/machinery/door))
		var/obj/machinery/door/machine_door = door
		if(machine_door.operating)
			return
	else if(istype(door, /obj/structure/window/ms13_vehicle_wall/solid/door))
		var/obj/structure/window/ms13_vehicle_wall/solid/door/vehicle_door = door
		if(vehicle_door.locked)
			return
	acting = TRUE
	var/obj/item/held = get_active_held_item()
	if(held?.wielded)
		held.unwield(src)
	var/list/empty_hands = get_empty_held_indexes()
	if(length(empty_hands))
		try_swap_hand(empty_hands[1])
		ai_controller.PawnClick(door, FALSE)
	acting = FALSE

#ifdef UNIT_TESTS
#include "squad_npcs_tests.dm"
#endif

#endif
