// Tuning knobs for mojave/code/modules/surgery/organs/vessel.dm - the beginning of a basic blood
// vessel system: one physical, damageable /obj/item/organ/vessel per limb. No cross-limb network yet
// (anatomical adjacency between bodyparts doesn't exist anywhere in DD - out of scope for now, see
// vessel.dm's header comment). When a vessel is destroyed, it severs the limb's artery using DD's own
// real BP_ARTERY_CUT mechanic (code/modules/surgery/bodyparts/injuries.dm) rather than inventing a
// second bleed source.

/// New organ slots - one vessel per limb. Not touching DD's own ORGAN_SLOT_* defines (code/__DEFINES/DNA.dm).
#define ORGAN_SLOT_VESSEL_HEAD "vessel_head"
#define ORGAN_SLOT_VESSEL_CHEST "vessel_chest"
#define ORGAN_SLOT_VESSEL_L_ARM "vessel_l_arm"
#define ORGAN_SLOT_VESSEL_R_ARM "vessel_r_arm"
#define ORGAN_SLOT_VESSEL_L_LEG "vessel_l_leg"
#define ORGAN_SLOT_VESSEL_R_LEG "vessel_r_leg"

/// How much damage a vessel can take before it ruptures. Fragile relative to other organs (heart is 45).
#define MS13_VESSEL_MAX_HEALTH 20
/// Weight in the same pick_weight() pool as the limb's other organs (base default is 25, heart/eyes/
/// ears/tongue/appendix are 5, kidneys is 10, lungs/liver are 60). Vessels are the ONLY organ in arms
/// and legs, so they take 100% of any organ-hit roll there regardless of this value.
#define MS13_VESSEL_RELATIVE_SIZE 10
