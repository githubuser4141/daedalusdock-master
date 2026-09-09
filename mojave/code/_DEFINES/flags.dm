//Flags specfically for MS13 content; no more dealing with upstream flags
//To be used with the ms13_flags_1 variable; kinda equivalent to the TG flags_1
//WILL NOT WORK OUTSIDE OF THE /mojave folder

// For objects able to be locked, slap this on and it should work, preventing you from interacting
#define LOCKABLE_1 (1<<0)

// The actual ms13_flags_1 var was never ported over with the flags above - declared here so both live together.
/obj
	var/ms13_flags_1 = NONE

// Base-game item_flags only goes up to (1<<20) with gaps at (1<<8) and (1<<13); this claims the (1<<8) gap.
// Marks an item as a lock you can attach to an /obj that has LOCKABLE_1 set (see obj_defines.dm).
#define LOCKING_ITEM (1<<8)

// Base-game sharpness only defines SHARP_EDGED and SHARP_POINTY; this claims the next free bit for axe-specific
// interactions (tree chopping, furniture destruction) that check for it on top of SHARP_EDGED.
#define SHARP_AXE (1<<2)

// Base-game flags_1 (on /atom) goes up to (1<<19); this claims the next free bit. Checked by
// mojave/code/datums/components/transparency.dm but never set anywhere, so it's currently always FALSE either way.
#define CRITICAL_ATOM_1 (1<<20)

// Used by living_armor.dm's weak_against_armour branch; weak_against_armour is never actually set TRUE anywhere in
// mojave/, so this multiplier is currently unreachable dead code either way.
#define ARMOR_WEAKENED_MULTIPLIER 1.5

// AI EDIT: admin VV dropdown key for objs.dm's "Modify subarmor values" option - only needs to be a unique string,
// matching the same pattern as the base game's VV_HK_* defines.
#define VV_HK_SUBARMOR_MOD "modifysubarmor"

// AI EDIT: moved here from mojave/code/modules/mob/robots/trader.dm back when that file was deleted entirely.
// trader.dm has since been restored (scoped to the /ms13 trader subtype, see that file's header comment) but
// without its unused AI-node restock/patrol system, which is what originally declared these - left here since
// generic_animal_patrol.dm/generic_patrol_animal.dm still use these two identifier strings.
#define IDENTIFIER_GENERIC_SIMPLE "identifies_generic_simple"
#define IDENTIFIER_EYEBOT "identifies_eyebot"

// AI EDIT: mojave/flora/agriculture.dm's own hydrotray setter signals - only ever sent (SEND_SIGNAL), never
// listened for anywhere, so these were just never declared. Only needed to be unique strings.
#define COMSIG_HYDROTRAY_SET_SEED "hydrotray_set_seed"
#define COMSIG_HYDROTRAY_SET_SELFSUSTAINING "hydrotray_set_selfsustaining"
#define COMSIG_HYDROTRAY_SET_NITROLEVEL "hydrotray_set_nitrolevel"
#define COMSIG_HYDROTRAY_SET_PHOSLEVEL "hydrotray_set_phoslevel"
#define COMSIG_HYDROTRAY_SET_POTLEVEL "hydrotray_set_potlevel"
#define COMSIG_HYDROTRAY_SET_WATERLEVEL "hydrotray_set_waterlevel"
#define COMSIG_HYDROTRAY_SET_PLANT_HEALTH "hydrotray_set_plant_health"
#define COMSIG_HYDROTRAY_SET_TOXIC "hydrotray_set_toxic"
#define COMSIG_HYDROTRAY_SET_PLANT_STATUS "hydrotray_set_plant_status"
#define COMSIG_HYDROTRAY_PLANT_DEATH "hydrotray_plant_death"
#define COMSIG_HYDROTRAY_ON_HARVEST "hydrotray_on_harvest"

// AI EDIT: mojave/hud/screen_objects.dm's custom HUD background icons used this layer value but it was never
// declared anywhere in DD - just needs to be a low value so the background renders behind the icons on top of it.
#define HUD_BACKGROUND_LAYER 1

#define GAME_PLANE_UPPER -4
#define ABOVE_GAME_PLANE -3
#define DISPLACEMENT_MAP_PLANE -2
#define VAPOUR_PLANE -13
#define VAPOUR_LAYER 5.2
