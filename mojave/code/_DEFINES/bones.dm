// Tuning knobs for mojave/code/modules/surgery/organs/bone.dm - one damageable /obj/item/organ/bone per
// arm/leg, alongside vessel and muscle. Stability is bone's health-derived 0-100 output; it multiplies
// muscle performance (get_muscle_performance(), muscle_movement.dm) rather than adding to it.

#define ORGAN_SLOT_BONE_L_ARM "bone_l_arm"
#define ORGAN_SLOT_BONE_R_ARM "bone_r_arm"
#define ORGAN_SLOT_BONE_L_LEG "bone_l_leg"
#define ORGAN_SLOT_BONE_R_LEG "bone_r_leg"
#define ORGAN_SLOT_BONE_CHEST "bone_chest"
#define ORGAN_SLOT_BONE_HEAD "bone_head"

/// Skull is tougher than a rib or limb bone.
#define MS13_BONE_SKULL_EXTERNAL_DAMAGE_MODIFIER 0.2

/// Sturdier than vessel (20) or muscle (30) - bone is the hardest tissue to actually destroy.
#define MS13_BONE_MAX_HEALTH 40
/// pick_weight() slot vs vessel (10) and muscle (15).
#define MS13_BONE_RELATIVE_SIZE 12
/// Scales damage bone actually takes once it's the one picked - other organs default to 0.5 (_organ.dm),
/// bone resists better.
#define MS13_BONE_EXTERNAL_DAMAGE_MODIFIER 0.3

/// Minimum single-hit damage to bone before it can fragment at all - a scrape doesn't chip bone.
#define MS13_BONE_FRAGMENT_MIN_DAMAGE 8
/// Fragment count scales with (damage - min) times this, capped at MS13_BONE_FRAGMENT_MAX_COUNT.
#define MS13_BONE_FRAGMENT_PER_DAMAGE 0.4
#define MS13_BONE_FRAGMENT_MAX_COUNT 4
/// Damage each fragment has a chance to deal to another organ sharing the limb.
#define MS13_BONE_FRAGMENT_DAMAGE 3
#define MS13_BONE_FRAGMENT_CHANCE 50

/// One-time local (not global - "self-sealing", see bone.dm's set_organ_dead()) blood loss on a break.
#define MS13_BONE_BREAK_LOCAL_BLEED 15

/// Minimum incoming damage before bone's natural-armor layer intercepts a hit at all.
#define MS13_BONE_ARMOR_MIN_DAMAGE 3
/// Same three-way split idea as muscle's (natural_armor.dm) - bone is the harder, later layer, so it blocks
/// more of what muscle didn't already absorb.
#define MS13_BONE_ARMOR_GONE_FRACTION 0.25
#define MS13_BONE_ARMOR_ABSORB_FRACTION 0.15
