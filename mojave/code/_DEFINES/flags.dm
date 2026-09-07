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
