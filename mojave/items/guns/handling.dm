// What each gun asks of whoever holds it (strength_to_handle, intelligence_to_handle) and the ways it fires
// (firemodes), in one place for tuning. Short of a requirement a gun still fires, wider and kicking harder
// (mojave/code/modules/projectiles/gun.dm). An average human has Strength 4 (5, less their species' 1).
// Strength follows the kick and weight of what it fires; Intelligence, how much there is to understand.

// Pistols
/obj/item/gun/ballistic/automatic/pistol/ms13/pistol22
	strength_to_handle = 2
/obj/item/gun/ballistic/automatic/pistol/ms13/m9mm
	strength_to_handle = 3
/obj/item/gun/ballistic/automatic/pistol/ms13/m10mm
	strength_to_handle = 4
/obj/item/gun/ballistic/automatic/pistol/ms13/pistol45
	strength_to_handle = 4
/obj/item/gun/ballistic/automatic/pistol/ms13/m12mm
	strength_to_handle = 6
/obj/item/gun/ballistic/automatic/pistol/ms13/deagle
	strength_to_handle = 6

// Revolvers and break-actions
/obj/item/gun/ballistic/revolver/ms13/derringer
	strength_to_handle = 4
/obj/item/gun/ballistic/revolver/ms13/rev10mm
	strength_to_handle = 4
/obj/item/gun/ballistic/revolver/ms13/rev357
	strength_to_handle = 5
/obj/item/gun/ballistic/revolver/ms13/rev556
	strength_to_handle = 5
/obj/item/gun/ballistic/revolver/ms13/rev44
	strength_to_handle = 6
/obj/item/gun/ballistic/revolver/ms13/huntingrev
	strength_to_handle = 7
/obj/item/gun/ballistic/revolver/ms13/caravan
	strength_to_handle = 5
/obj/item/gun/ballistic/revolver/ms13/caravan/sawed
	strength_to_handle = 6
/obj/item/gun/ballistic/revolver/ms13/single
	strength_to_handle = 5
/obj/item/gun/ballistic/revolver/ms13/mts
	strength_to_handle = 5
/obj/item/gun/ballistic/revolver/ms13/mts/shorty
	strength_to_handle = 6

// Bolt and lever actions
/obj/item/gun/ballistic/rifle/ms13/varmint
	strength_to_handle = 3
/obj/item/gun/ballistic/rifle/ms13/hunting
	strength_to_handle = 4
/obj/item/gun/ballistic/rifle/ms13/hunting/scoped/amr
	strength_to_handle = 8
/obj/item/gun/ballistic/rifle/ms13/jezzail
	strength_to_handle = 5
/obj/item/gun/ballistic/rifle/ms13/antique_sniper
	strength_to_handle = 5
/obj/item/gun/ballistic/rifle/ms13/m79
	strength_to_handle = 4
/obj/item/gun/ballistic/shotgun/ms13/lever
	strength_to_handle = 5
/obj/item/gun/ballistic/shotgun/ms13/lever/trail
	strength_to_handle = 4
/obj/item/gun/ballistic/shotgun/ms13/lever/cowboy
	strength_to_handle = 4
/obj/item/gun/ballistic/shotgun/ms13/lever/brush
	strength_to_handle = 6
/obj/item/gun/ballistic/shotgun/ms13/huntingshot
	strength_to_handle = 5
/obj/item/gun/ballistic/shotgun/automatic/ms13/sks
	strength_to_handle = 4

// Semi-automatic rifles
/obj/item/gun/ballistic/automatic/ms13/semi/service
	strength_to_handle = 4
/obj/item/gun/ballistic/automatic/ms13/semi/marksman
	strength_to_handle = 4
/obj/item/gun/ballistic/automatic/ms13/semi/sniper
	strength_to_handle = 5
/obj/item/gun/ballistic/automatic/ms13/semi/battle
	strength_to_handle = 6

// Select-fire: a sub or assault rifle switches between single shots and automatic. The .22 sub gun and the
// stripped-down Dakka only ever run away with themselves.
/obj/item/gun/ballistic/automatic/ms13/full/smg22
	strength_to_handle = 3
/obj/item/gun/ballistic/automatic/ms13/full/smg9mm
	strength_to_handle = 4
	firemodes = list(/datum/gun_firemode/semi, /datum/gun_firemode/auto)
/obj/item/gun/ballistic/automatic/ms13/full/smg10mm
	strength_to_handle = 4
	firemodes = list(/datum/gun_firemode/semi, /datum/gun_firemode/auto)
/obj/item/gun/ballistic/automatic/ms13/full/smg45
	strength_to_handle = 5
	firemodes = list(/datum/gun_firemode/semi, /datum/gun_firemode/auto)
/obj/item/gun/ballistic/automatic/ms13/full/smg12mm
	strength_to_handle = 6
	firemodes = list(/datum/gun_firemode/semi, /datum/gun_firemode/auto)
/obj/item/gun/ballistic/automatic/ms13/full/assaultrifle
	strength_to_handle = 4
	firemodes = list(/datum/gun_firemode/semi, /datum/gun_firemode/auto)
/obj/item/gun/ballistic/automatic/ms13/full/assaultrifle/proto_service
	firemodes = list(/datum/gun_firemode/semi, /datum/gun_firemode/burst, /datum/gun_firemode/auto)
/obj/item/gun/ballistic/automatic/ms13/full/assaultrifle/dakka
	strength_to_handle = 5
	firemodes = list(/datum/gun_firemode/auto)
/obj/item/gun/ballistic/automatic/ms13/full/assaultrifle/chinese
	strength_to_handle = 5

// Energy weapons: light to hold, harder to understand.
/obj/item/gun/energy/ms13/laser/pistol
	strength_to_handle = 2
	intelligence_to_handle = 4
/obj/item/gun/energy/ms13/laser/pistol/wattz
	intelligence_to_handle = 3
/obj/item/gun/energy/ms13/laser/pistol/wattz_heavy
	strength_to_handle = 3
	intelligence_to_handle = 4
/obj/item/gun/energy/ms13/laser/pistol/advanced
	intelligence_to_handle = 6
/obj/item/gun/energy/ms13/laser/rifle
	strength_to_handle = 3
	intelligence_to_handle = 4
/obj/item/gun/energy/ms13/laser/rifle/wattz
	intelligence_to_handle = 3
/obj/item/gun/energy/ms13/laser/rifle/advanced
	intelligence_to_handle = 6
/obj/item/gun/energy/ms13/laser/rcw
	strength_to_handle = 3
	intelligence_to_handle = 5
/obj/item/gun/energy/ms13/laser/scatter
	strength_to_handle = 3
	intelligence_to_handle = 5
/obj/item/gun/energy/ms13/plasma/pistol
	strength_to_handle = 3
	intelligence_to_handle = 6
/obj/item/gun/energy/ms13/plasma/rifle
	strength_to_handle = 4
	intelligence_to_handle = 6
/obj/item/gun/energy/ms13/plasma/multi
	strength_to_handle = 5
	intelligence_to_handle = 7
/obj/item/gun/energy/ms13/gauss
	strength_to_handle = 5
	intelligence_to_handle = 7
/obj/item/gun/energy/ms13/gauss/pistol
	strength_to_handle = 4
/obj/item/gun/energy/ms13/gauss/sniper
	strength_to_handle = 6
/obj/item/gun/ballistic/automatic/ms13/semi/gauss/chinese
	strength_to_handle = 5
	intelligence_to_handle = 7
