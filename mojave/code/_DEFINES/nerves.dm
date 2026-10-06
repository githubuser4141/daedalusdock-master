// Tuning knobs for mojave/code/modules/surgery/organs/nerve.dm - one /obj/item/organ/nerve per arm and leg, alongside
// the vessel, muscle and bone already in each limb.

#define ORGAN_SLOT_NERVE_L_ARM "nerve_l_arm"
#define ORGAN_SLOT_NERVE_R_ARM "nerve_r_arm"
#define ORGAN_SLOT_NERVE_L_LEG "nerve_l_leg"
#define ORGAN_SLOT_NERVE_R_LEG "nerve_r_leg"
#define ORGAN_SLOT_NERVE_SPINE "nerve_spine"
#define ORGAN_SLOT_NERVE_L_PLEXUS "nerve_l_plexus"
#define ORGAN_SLOT_NERVE_R_PLEXUS "nerve_r_plexus"

/// The spinal cord, behind everything else in the chest: tougher than a limb nerve, and both legs go with it.
#define MS13_SPINE_MAX_HEALTH 20
#define MS13_SPINE_BULLET_HIT_CHANCE 10
/// Each brachial plexus, up at the shoulder; its arm goes with it.
#define MS13_PLEXUS_BULLET_HIT_CHANCE 6

/// Fragile next to the rest of the limb: muscle is 30, bone 40.
#define MS13_NERVE_MAX_HEALTH 15
#define MS13_NERVE_RELATIVE_SIZE 5
/// Percent chance a round through the limb crosses its nerve.
#define MS13_NERVE_BULLET_HIT_CHANCE 25
/// Share of its signal a nerve at full damage, but not yet destroyed, has lost.
#define MS13_NERVE_DAMAGE_SIGNAL_LOSS 0.6
/// Percent chance a blow numbs the limb, for each whole share of the nerve's health it takes.
#define MS13_NERVE_NUMB_CHANCE 300
/// How long a blow taking the nerve's whole health numbs the limb, at average Endurance; half of that at the least.
#define MS13_NERVE_NUMB_TIME (20 SECONDS)
/// Share of both that each point of Endurance off average takes away or adds.
#define MS13_NERVE_ENDURANCE_RESIST 0.08
/// How long a leg going numb under its owner puts them down, the same as a weak leg buckling (muscle.dm).
#define MS13_NERVE_BUCKLE_TIME (1.5 SECONDS)
