// Tuning knobs for mojave/code/modules/surgery/organs/tissue_care.dm - treatment, natural healing and
// neglect for the per-limb tissue organs (bone.dm, muscle.dm, vessel.dm).
//
// The shape: tissue heals on its own, slowly, if the body can afford to. Four things decide how fast -
// blood supply to that limb, nutrition, rest, and how recently it was treated. Neglected serious injuries
// go the other way and get infected, which routes into DD's existing germ_level pipeline
// (code/modules/surgery/bodyparts/germs_bodypart.dm) rather than a second deterioration system.

/// Baseline organ damage healed per life tick, before every multiplier below. DD's own flat rate is 0.1,
/// but only ever below 10% damage - this replaces that for tissue, which needs to be able to recover from
/// real injuries and not just scratches.
#define MS13_TISSUE_HEAL_BASE 0.12

// --- Nutrition: healing costs food. ---
/// Multiplier at each nutrition band (code/__DEFINES/mobs.dm's NUTRITION_LEVEL_*).
#define MS13_TISSUE_HEAL_NUTRITION_STARVING 0.2
#define MS13_TISSUE_HEAL_NUTRITION_HUNGRY 0.6
#define MS13_TISSUE_HEAL_NUTRITION_FED 1
#define MS13_TISSUE_HEAL_NUTRITION_WELL_FED 1.15
/// Nutrition actually consumed per point of damage healed. Knitting tissue back together is expensive, and
/// this is what makes "eat and rest up" a real supply cost rather than a free idle timer.
#define MS13_TISSUE_HEAL_NUTRITION_COST 8

// --- Rest ---
#define MS13_TISSUE_HEAL_REST_STANDING 0.6
#define MS13_TISSUE_HEAL_REST_LYING 1
#define MS13_TISSUE_HEAL_REST_SLEEPING 1.6

// --- Care: bandages, splints, poultices. ---
/// How long a treatment keeps counting as fresh. After this the limb is still bandaged but the dressing is
/// stale - this is the "pace of care" term: you have to keep coming back, not treat once and walk away.
#define MS13_TISSUE_TREATMENT_DURATION (5 MINUTES)
/// Care multiplier with nothing done at all.
#define MS13_TISSUE_CARE_UNTREATED 0.3
/// Care multiplier for a limb that's dressed but whose dressing has gone stale.
#define MS13_TISSUE_CARE_STALE 0.65
/// Chem effect key for herbal medicine in the bloodstream. The topical tribal items (healing powder,
/// poultices) stabilise a limb by being applied to it; the drinkable and smokeable ones work from the
/// inside and had no way to count as care at all, which left "tribal medicine stabilises the wound" true
/// for only half the tribal tier. Not a DD define - both the setter and the reader live in mojave.
#define CE_MS13_HERBAL_CARE "ms13_herbal_care"
/// Care quality from herbal medicine alone, on a limb nobody has dressed. Above
/// MS13_TISSUE_CRITICAL_MIN_CARE, so herbal treatment on its own can keep a critical injury's slow
/// recovery alive; below MS13_TISSUE_CARE_FRESH, so a clean dressing is still the better answer.
#define MS13_TISSUE_CARE_HERBAL 0.7
/// Best care multiplier, for a freshly treated limb.
#define MS13_TISSUE_CARE_FRESH 1
/// Extra care credit for a splinted limb, when scoring a bone specifically.
#define MS13_TISSUE_CARE_SPLINT_BONUS 0.35

// --- Critical injury: destroyed tissue (ORGAN_DEAD). ---
// Surgery is the reliable answer. The body will still try on its own, but only under good conditions and
// only sometimes - a slim chance, not a reliable one.
/// Healing rate multiplier while the tissue is outright destroyed.
#define MS13_TISSUE_CRITICAL_HEAL_MULT 0.15
/// Fraction of the limb's local blood supply needed before destroyed tissue can knit at all - no perfusion,
/// no repair, which is also what makes a tourniqueted or ruptured limb genuinely need a surgeon.
#define MS13_TISSUE_CRITICAL_MIN_BLOOD 0.5
/// Care score needed before destroyed tissue can knit at all. Above MS13_TISSUE_CARE_UNTREATED, so an
/// untended critical injury never recovers on its own no matter how lucky or well-fed the patient is.
#define MS13_TISSUE_CRITICAL_MIN_CARE 0.6
/// Per-tick chance the body makes any progress at all on destroyed tissue, once the gates above are met.
/// This is the luck term - two identically-treated patients won't recover on the same schedule.
#define MS13_TISSUE_CRITICAL_HEAL_CHANCE 25

// --- Neglect: untreated injuries get infected. ---
/// Damage fraction above which tissue counts as a serious injury for infection purposes.
#define MS13_TISSUE_NEGLECT_DAMAGE_RATIO 0.5
/// germ_level added to the limb per tick per neglected serious tissue injury. DD's own germ pipeline takes
/// it from here: fever at INFECTION_LEVEL_ONE, spread to other organs and limbs at TWO, necrosis at THREE.
#define MS13_TISSUE_NEGLECT_GERM_RATE 2
/// Multiplier on that rate while the limb has an open bleeding wound - dirt gets in far faster.
#define MS13_TISSUE_NEGLECT_OPEN_WOUND_MULT 2.5
/// Infection at or above this level stops natural healing outright. The body is busy fighting the
/// infection; clear it with antibiotics before anything will knit.
#define MS13_TISSUE_HEAL_BLOCKING_GERMS INFECTION_LEVEL_TWO

// --- Pain from destroyed tissue. ---
/// Per-tick chance a piece of DESTROYED tissue registers as actively hurting. DD's base is_causing_pain()
/// excludes ORGAN_DEAD entirely and otherwise rolls prob(1), so a limb stopped hurting the moment it
/// finished being ruined. This is deliberately high: a shattered leg should hurt reliably, not once every
/// hundred ticks. Each organ that passes contributes 65 pain to its limb via handle_pain(), which
/// adjustPain() then clamps to that limb's own max_damage.
#define MS13_TISSUE_DESTROYED_PAIN_CHANCE 25

// --- Hydra (mojave/code/modules/reagents/drugs.dm). ---
// The dedicated limb-repair chem its own description always promised.
/// Tissue damage mended per unit metabolised - well above a super stimpak, and it reaches destroyed tissue.
#define MS13_HYDRA_TISSUE_HEAL 6
/// Heart damage per unit metabolised. "Causes heart damage from the overworking", per the description.
#define MS13_HYDRA_HEART_DAMAGE 1.2
/// Painkiller magnitude while it's in the blood - it "anaesthetises", which is also what makes it usable
/// on someone whose limbs are wrecked enough to otherwise put them straight into shock.
#define MS13_HYDRA_PAINKILLER 25

// --- Antibiotics (mojave/code/modules/reagents/drugs.dm). ---
// germs_bodypart.dm's thresholds are the scale here: any magnitude at all slows an infection's growth and
// cures a trivial one, 5+ stops it spreading between organs, and 30+ is what it takes to reverse an
// established INFECTION_LEVEL_THREE case.
/// Herbal remedies (blood remedy, herbal anti-toxin). Enough to keep a clean wound from turning, not
/// enough to save a limb that's already going.
#define MS13_ANTIBIOTIC_HERBAL_POTENCY 4
/// Per unit of actual antibiotics in the bloodstream. A full pill clears a serious infection given time.
#define MS13_ANTIBIOTIC_PILL_POTENCY 4

// --- Medicine strength (mojave/code/modules/reagents/drugs.dm). ---
/// Damage fraction a normal stimpak will regenerate tissue up to. Below this it closes the injury outright;
/// above it the stimpak only chips away, which is what makes super stimpaks worth carrying.
#define MS13_STIMPAK_TISSUE_THRESHOLD 0.5
/// Tissue damage a normal stimpak heals per tick, per organ, while under that threshold.
#define MS13_STIMPAK_TISSUE_HEAL 1.5
/// Same, for super stimpaks - which also work on tissue above the threshold, and on destroyed tissue.
#define MS13_SUPER_STIMPAK_TISSUE_HEAL 3
/// Brute/burn a stimpak mends per tick. heal_Rate on the reagent is the per-use budget this comes from.
#define MS13_STIMPAK_HEAL_DIVISOR 4
