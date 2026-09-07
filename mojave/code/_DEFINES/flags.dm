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
