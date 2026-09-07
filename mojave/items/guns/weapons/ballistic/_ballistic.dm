//MS13 EDIT BEGIN
#define CHOKE_LOOSE -15
#define CHOKE_WIDE 0
#define CHOKE_MODERATE 7
#define CHOKE_TIGHT 11
//MS13 EDIT END

// weapon_weight and tac_reloads are used by both /obj/item/gun/ballistic and /obj/item/gun/energy ms13 guns,
// so they belong on the shared /obj/item/gun parent rather than being declared on one branch only.
/obj/item/gun
	var/weapon_weight = WEAPON_LIGHT
	var/tac_reloads = FALSE

/obj/item/gun/ballistic
	var/spread_reduction = CHOKE_WIDE //Mostly for shotguns, increases or decreases the variance of buckshot
	// bolt_locked is used by both the pistol and rifle ms13 branches below, so it lives here on the shared parent.
	var/bolt_locked = FALSE
