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
/// One-time blood_volume hit (out of BLOOD_VOLUME_NORMAL 560) applied when a major_vessel (head/chest -
/// carotid/aorta) ruptures, on top of the ongoing +4 bleed_rate every severed artery already causes via
/// refresh_bleed_rate(). Represents the sudden/immediate nature of a core vessel letting go vs a limb one.
#define MS13_MAJOR_VESSEL_BLOOD_BURST 60
/// Weight in the same pick_weight() pool as the limb's other organs (base default is 25, heart/eyes/
/// ears/tongue/appendix are 5, kidneys is 10, lungs/liver are 60). Vessels are the ONLY organ in arms
/// and legs, so they take 100% of any organ-hit roll there regardless of this value.
#define MS13_VESSEL_RELATIVE_SIZE 10

// --- mojave/code/modules/surgery/organs/vessel_local_blood.dm ---
/// Max local blood a single bodypart can hold. Same for every zone for now - not scaling per body size yet.
#define MS13_LOCAL_BLOOD_MAX 60
/// Per-tick local blood regen while the local vessel is undamaged, pulled from the mob's global blood_volume.
#define MS13_LOCAL_BLOOD_REGEN 2
/// Global blood_volume is left alone below this - a limb won't top up its local supply by draining the body dry.
#define MS13_LOCAL_BLOOD_REGEN_FLOOR BLOOD_VOLUME_OKAY
/// Per-tick local blood lost, per point of current vessel damage, while a vessel is hurt but not yet ruptured.
#define MS13_VESSEL_BLEED_LOCAL_PER_DAMAGE 0.4
/// Per-tick GLOBAL blood_volume lost (via the real bleed() proc) per point of current vessel damage - on top
/// of, not instead of, the flat +4 bleed_rate a fully severed artery already causes.
#define MS13_VESSEL_BLEED_GLOBAL_PER_DAMAGE 0.1
/// Minimum local_blood_volume (out of MS13_LOCAL_BLOOD_MAX) a vessel's own limb needs before that vessel is
/// allowed to use DD's base handle_regeneration() self-heal at all - a quarter tank of local blood or less
/// and there's not enough supply reaching the injury to knit it back together.
#define MS13_VESSEL_REGEN_MIN_LOCAL_BLOOD (MS13_LOCAL_BLOOD_MAX * 0.25)
