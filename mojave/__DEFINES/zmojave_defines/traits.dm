#define TRAIT_REMOVE_SLOWDOWN "remove_slowdown" // Used by structures if you want to remove turf slowdown below it
#define TRAIT_ADD_SLOWDOWN "add_slowdown" // Used by structures if you want to add turf slowdown above it
#define CATWALK_ON_TURF "catwalk_on_turf" // Source for adding/removing traits, namely the above trait
#define BOARDS_ON_TURF "boards_on_turf" // Like above, but for board walkways
#define STAIRS_ON_TURF "stairs_on_turf" // Like above, but for stairs!
// AI EDIT: moved to code/__DEFINES/traits.dm's "MOJAVE TRAITS" section - this file loads too late for
// code/modules/mob/living/carbon/life.dm (a base file) to see it
#define TRAIT_DUSTSTORM_IMMUNE "duststorm_immune" //MOJAVE MODULE OUTDOOR_EFFECTS
#define TRAIT_RAINSTORM_IMMUNE "rainstorm_immune" //MOJAVE MODULE OUTDOOR_EFFECTS
/// Draws cable out to adjacent power cables (/datum/element/ms13_wired_look).
#define TRAIT_MS13_WIRED_LOOK "ms13_wired_look"
