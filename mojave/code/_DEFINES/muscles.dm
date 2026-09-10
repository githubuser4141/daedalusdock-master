// Tuning knobs for mojave/code/modules/surgery/organs/muscle.dm - one damageable /obj/item/organ/muscle per
// arm/leg (not head/chest - muscles are limb tissue), sitting alongside the vessel already in each limb.

/// New organ slots - one muscle per limb. Not touching DD's own ORGAN_SLOT_* defines (code/__DEFINES/DNA.dm).
#define ORGAN_SLOT_MUSCLE_L_ARM "muscle_l_arm"
#define ORGAN_SLOT_MUSCLE_R_ARM "muscle_r_arm"
#define ORGAN_SLOT_MUSCLE_L_LEG "muscle_l_leg"
#define ORGAN_SLOT_MUSCLE_R_LEG "muscle_r_leg"

/// How much damage a muscle can take before it's destroyed.
#define MS13_MUSCLE_MAX_HEALTH 30
/// pick_weight() slot vs the limb's vessel (10) - muscle is bulkier tissue, slightly more likely to be hit.
#define MS13_MUSCLE_RELATIVE_SIZE 15
/// A missing muscle (surgically removed, never replaced) floors that limb's performance here instead of 0 -
/// there's presumably more muscle tissue than just this one organ models.
#define MS13_MUSCLE_MISSING_PERFORMANCE_FLOOR 20
/// Performance (0-100) below which a limb counts as critically weak for update_disabled() purposes - see
/// code/modules/surgery/bodyparts/_bodyparts.dm's update_disabled() override.
#define MS13_MUSCLE_CRITICAL_PERFORMANCE 15
/// Rhabdomyolysis-style tissue breakdown releases myoglobin into the bloodstream, not direct toxin damage -
/// see /datum/reagent/toxin/myoglobin in muscle.dm, which deals its own toxin damage as it metabolizes
/// (same pattern as kidneys.dm's potassium: a real, separate value with its own effect, not a shortcut).
/// Per-tick amount added per point of CURRENT muscle damage while merely hurt (not yet destroyed).
#define MS13_MUSCLE_WASTE_PER_DAMAGE 0.05
/// One-time burst added on top when a muscle is destroyed outright (set_organ_dead(TRUE)).
#define MS13_MUSCLE_RUPTURE_WASTE_BURST 20
/// Per-muscle share of the myoglobin ceiling - the actual ceiling is this times how many muscles are
/// CURRENTLY damaged (see get_myoglobin_ceiling()), not a flat cap. One smashed limb should be bounded and
/// survivable on its own; a person smashed up everywhere should be in genuine danger, not protected by the
/// same ceiling as someone with a single bruised arm. adjustToxLoss() (code/modules/mob/living/carbon/
/// damage_procs.dm) prioritizes kidneys/liver for organ damage, and their own on_life() reactions to that
/// damage produce more toxin damage in turn, so this still exists to stop a single limb's damage from
/// climbing unboundedly forever - it just scales with how many limbs are actually contributing.
#define MS13_MUSCLE_WASTE_MAX_VOLUME_PER_MUSCLE 15

/// How much walking/crawling slowdown (deciseconds) a fully-average-zero-performance pair of legs adds, on
/// top of (not instead of) DD's existing /datum/movespeed_modifier/limbless binary "legs missing" penalty.
#define MS13_MUSCLE_LEG_MAX_SLOWDOWN 4
/// Every life tick, a leg below this performance has a chance to buckle (a brief, recoverable stumble - not
/// a permanent floor, see /obj/item/organ/muscle/proc/check_buckle()).
#define MS13_MUSCLE_BUCKLE_PERFORMANCE_THRESHOLD 35
/// Percent chance per life tick to buckle while at MS13_MUSCLE_BUCKLE_PERFORMANCE_THRESHOLD - scales up as
/// performance drops further below that.
#define MS13_MUSCLE_BUCKLE_BASE_CHANCE 4
/// How much extra dragging/grabbing slowdown (deciseconds) a fully-zero-performance grabbing arm adds, on
/// top of (not instead of) DD's existing per-grab slowdown - see update_pull_movespeed() in muscle.dm.
#define MS13_MUSCLE_DRAG_MAX_SLOWDOWN 3

/// Three-way split for a BRUTE hit to a limb with an intact muscle, applied separately from and after
/// external armor/subarmor (code/modules/mob/living/damage_procs.dm's apply_damage()) - same "some energy
/// gone, some absorbed by the component, the rest passes through" idea as power armor
/// (human_armor.dm), just with the body's own muscle as the component. Both fractions scale down as the
/// muscle takes damage (1 - MS13_MUSCLE_ARMOR_GONE_FRACTION - MS13_MUSCLE_ARMOR_ABSORB_FRACTION always
/// passes through even at full health - muscle blunts a hit, it doesn't stop it).
#define MS13_MUSCLE_ARMOR_GONE_FRACTION 0.15
#define MS13_MUSCLE_ARMOR_ABSORB_FRACTION 0.25
