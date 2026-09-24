// Tuning knobs for mojave/code/modules/surgery/organs/vessel.dm - the beginning of a basic blood
// vessel system: one physical, damageable /obj/item/organ/vessel per limb. No cross-limb network yet
// (anatomical adjacency between bodyparts doesn't exist anywhere in DD - out of scope for now, see
// vessel.dm's header comment). When a vessel is destroyed, it severs the limb's artery using DD's own
// real BP_ARTERY_CUT mechanic (code/modules/surgery/bodyparts/injuries.dm) rather than inventing a
// second bleed source.

/// Master switch for ms13_medical_debug() (vessel.dm) - private to_chat messages exposing otherwise-silent
/// vessel/muscle mechanics (exact numbers, gate checks, etc) for testing. Not meant as permanent flavor -
/// flip to FALSE (or delete every call site later) once the systems are verified.
#define MS13_MEDICAL_DEBUG_ENABLED FALSE

/// Everyone bleeds out through open wounds this much faster than DD's default, and leaves that much more on the floor.
#define MS13_EXTERNAL_BLEED_MULT 1.2

/// New organ slots - one vessel per limb. Not touching DD's own ORGAN_SLOT_* defines (code/__DEFINES/DNA.dm).
#define ORGAN_SLOT_VESSEL_HEAD "vessel_head"
#define ORGAN_SLOT_VESSEL_CHEST "vessel_chest"
#define ORGAN_SLOT_VESSEL_L_ARM "vessel_l_arm"
#define ORGAN_SLOT_VESSEL_R_ARM "vessel_r_arm"
#define ORGAN_SLOT_VESSEL_L_LEG "vessel_l_leg"
#define ORGAN_SLOT_VESSEL_R_LEG "vessel_r_leg"

/// How much damage a vessel can take before it ruptures. Fragile relative to other organs (heart is 45).
#define MS13_VESSEL_MAX_HEALTH 20
/// One-time blood_volume hit (out of BLOOD_VOLUME_NORMAL 560), PER POINT of the rupturing vessel's own
/// vessel_size (see vessel.dm), applied on rupture - on top of the ongoing +5 bleed_rate every severed
/// artery already causes via refresh_bleed_rate(). A bigger vessel (aorta, vessel_size 3) bursts harder
/// than a small one (brachial, vessel_size 1) - represents the sudden/immediate nature of a core vessel
/// letting go vs a limb one.
#define MS13_VESSEL_BLOOD_BURST_PER_SIZE 20
/// Weight in the same pick_weight() pool as the limb's other organs (base default is 25, heart/eyes/
/// ears/tongue/appendix are 5, kidneys is 10, lungs/liver are 60). Vessels are the ONLY organ in arms
/// and legs, so they take 100% of any organ-hit roll there regardless of this value.
#define MS13_VESSEL_RELATIVE_SIZE 10

// --- mojave/code/modules/surgery/organs/vessel_local_blood.dm ---
/// Max local blood each bodypart type can hold - scaled by roughly how much of the body's blood supply
/// actually sits there. MS13_LOCAL_BLOOD_MAX is the generic /obj/item/bodypart fallback (used by any zone
/// that doesn't get one of the four specific overrides below, e.g. non-human anatomy).
#define MS13_LOCAL_BLOOD_MAX 60
#define MS13_LOCAL_BLOOD_CHEST 250
#define MS13_LOCAL_BLOOD_HEAD 80
#define MS13_LOCAL_BLOOD_ARM 40
#define MS13_LOCAL_BLOOD_LEG 60
/// Per-tick local blood regen while the local vessel is undamaged, pulled from the mob's global blood_volume.
#define MS13_LOCAL_BLOOD_REGEN 2
/// Global blood_volume is left alone below this - a limb won't top up its local supply by draining the body dry.
#define MS13_LOCAL_BLOOD_REGEN_FLOOR BLOOD_VOLUME_OKAY
/// Per-tick local blood lost, per point of current vessel damage, while a vessel is hurt but not yet ruptured.
#define MS13_VESSEL_BLEED_LOCAL_PER_DAMAGE 0.4
/// Per-tick GLOBAL blood_volume lost (via the real bleed() proc) per point of current vessel damage - on top
/// of, not instead of, the flat +5 bleed_rate a fully severed artery already causes.
#define MS13_VESSEL_BLEED_GLOBAL_PER_DAMAGE 0.1
/// Fraction of THIS limb's own local_blood_volume_max (not a flat number - limbs hold different amounts,
/// see MS13_LOCAL_BLOOD_CHEST etc above) a vessel's limb needs before that vessel is allowed to use DD's
/// base handle_regeneration() self-heal at all - a quarter tank of local blood or less and there's not
/// enough supply reaching the injury to knit it back together.
#define MS13_VESSEL_REGEN_MIN_LOCAL_BLOOD_PCT 0.25
/// Same idea, generalized to every other organ sharing the bodypart (heart/lungs/liver/stomach in a
/// starved chest, brain/eyes in a starved head) - a bit more lenient than the vessel's own threshold.
#define MS13_ORGAN_REGEN_MIN_LOCAL_BLOOD_PCT 0.15
/// Per-tick organ damage to everything else sharing a bodypart once its local_blood_volume hits 0 outright -
/// slow ischemic damage, not a death sentence, but a prolonged rupture will start costing real organ health.
#define MS13_ISCHEMIA_DAMAGE_PER_TICK 0.5
/// Hard ceiling on ischemic damage, as a fraction of the STARVED ORGAN's own maxHealth - ischemia alone can
/// never push an organ to full failure (damage >= maxHealth) no matter how long it's starved for.
#define MS13_ISCHEMIA_DAMAGE_CAP 0.7
/// Internal (local_blood_volume) / external (bleed(), visible on the floor) bleed multipliers for a blunt
/// hit (no sharpness) - a vessel ruptured by blunt trauma has no open path out, so it mostly pools
/// internally instead of spilling out.
#define MS13_BLEED_RATIO_BLUNT_INTERNAL_MULT 1.6
#define MS13_BLEED_RATIO_BLUNT_EXTERNAL_MULT 0.4
/// Same, for a sharp hit (edged/pointy/impaling) - an open wound bleeds out visibly instead of pooling.
#define MS13_BLEED_RATIO_SHARP_INTERNAL_MULT 0.5
#define MS13_BLEED_RATIO_SHARP_EXTERNAL_MULT 2.5
