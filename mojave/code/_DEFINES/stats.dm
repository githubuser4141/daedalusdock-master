// S.P.E.C.I.A.L. (mojave/code/modules/stats/stats.dm), and the body-condition half of it
// (mojave/code/modules/stats/stat_condition.dm): what the game reads is get_stat(), the attribute scaled by how intact
// the body currently is.

/// The attributes, as get_special() and the rest take them.
#define SPECIAL_STRENGTH "strength"
#define SPECIAL_PERCEPTION "perception"
#define SPECIAL_ENDURANCE "endurance"
#define SPECIAL_CHARISMA "charisma"
#define SPECIAL_INTELLIGENCE "intelligence"
#define SPECIAL_AGILITY "agility"
#define SPECIAL_LUCK "luck"
#define SPECIAL_ATTRIBUTES list(SPECIAL_STRENGTH, SPECIAL_PERCEPTION, SPECIAL_ENDURANCE, SPECIAL_CHARISMA, SPECIAL_INTELLIGENCE, SPECIAL_AGILITY, SPECIAL_LUCK)

/// Where every attribute starts, and where it neither helps nor hinders.
#define SPECIAL_BASELINE 5
#define SPECIAL_MINIMUM 1
#define SPECIAL_MAXIMUM 10
/// Points to spend across all seven at character setup, as in Fallout: every one at baseline, and five more.
#define SPECIAL_POINTS 40
/// The fewest and most points an attribute takes at setup, given what species and traits add to it (modifier), so it
/// stays within SPECIAL_MINIMUM to SPECIAL_MAXIMUM: a -2 starts two down, buys back up to 8, and dumping it saves less.
#define SPECIAL_POINTS_MIN(modifier) (SPECIAL_MINIMUM + max(-(modifier), 0))
#define SPECIAL_POINTS_MAX(modifier) (SPECIAL_MAXIMUM - max((modifier), 0))

/// Each point of Strength off baseline makes what you carry and drag slow you this much less, or more.
#define SPECIAL_STRENGTH_LOAD 0.1
/// Points of Strength between two people that make one step's difference in a grab, or +1 to a shove.
#define SPECIAL_STRENGTH_CONTEST_STEP 3
/// Each point of Strength off baseline speeds metabolism this much: hunger, and how hard drugs hit and how soon they overdose.
#define SPECIAL_STRENGTH_METABOLISM 0.1
/// How much denser muscle and bone are at Strength 10 (and, by the same curve, lighter at 1). Grows with the
/// square of the distance from baseline, so it barely shows near average.
#define SPECIAL_STRENGTH_TISSUE_DENSITY 0.5
/// Each point of Endurance off baseline changes maximum stamina by this much.
#define SPECIAL_ENDURANCE_STAMINA 12
/// Each point of Endurance off baseline makes limbs take this much more damage, or less, before they give out.
#define SPECIAL_ENDURANCE_TOUGHNESS 0.05
/// Each point of Endurance off baseline makes pain hurt this much less, or more.
#define SPECIAL_ENDURANCE_PAIN 0.05
/// How much better the body rides out blood loss at Endurance 10 (and worse, by the same curve, at 1): fainting,
/// brain damage from poor circulation, and how fast wounds clot. Grows with the square of the distance from
/// baseline, so it barely shows near average.
#define SPECIAL_ENDURANCE_RESILIENCE 0.5
/// At or above this Endurance the heart holds out to lower circulation, and can start again by itself.
#define SPECIAL_ENDURANCE_HARDY 8
/// At or below this, it gives out sooner.
#define SPECIAL_ENDURANCE_FRAIL 2
/// Circulation (%) the heart's breaking point moves per point past either of those.
#define SPECIAL_ENDURANCE_HEART_STEP 5
/// Per-tick percent chance a hardy heart restarts itself, per point past SPECIAL_ENDURANCE_HARDY-1.
#define SPECIAL_ENDURANCE_HEART_RESTART 2
/// Each point of Agility off baseline makes timed actions this much faster or slower.
#define SPECIAL_AGILITY_ACTION_SPEED 0.05
/// Each point of Agility off baseline takes this much off each step, in deciseconds (a run is 4).
#define SPECIAL_AGILITY_MOVE_SPEED 0.05
/// Each point of Intelligence off baseline makes crafting this much faster or slower.
#define SPECIAL_INTELLIGENCE_CRAFT_SPEED 0.05

/// Condition inputs are multiplied together, so each one is clamped to this floor before multiplying -
/// otherwise three separate 0.3s would compound to 0.027 and one bad limb would erase the stat entirely.
#define MS13_STAT_CONDITION_INPUT_FLOOR 0.25

// --- Strength (SPECIAL_STRENGTH) ---
// Inputs, in the order they're combined in get_stat_condition(): arm muscle performance (which already
// folds in bone stability and that limb's local blood - see muscle_movement.dm), whole-body circulation,
// and pain. Only strength has condition inputs wired up so far; the other six return 1 and read as their
// base value, ready to be filled in the same way.

/// Pain/shock at or above this shock_stage drops strength to its full pain penalty; below it the penalty
/// scales in linearly from nothing. SHOCK_TIER_2 is where DD already starts describing the body as failing.
#define MS13_STAT_STRONG_PAIN_FLOOR_STAGE SHOCK_TIER_3
/// Worst-case multiplier from pain alone, reached at MS13_STAT_STRONG_PAIN_FLOOR_STAGE.
#define MS13_STAT_STRONG_PAIN_MULT 0.4

/// Melee damage at SPECIAL_BASELINE strength is unchanged (1.0). This is how much of the swing is
/// strength-dependent: at 0 effective strength a weapon still lands (1 - this), because a crowbar dropped
/// on someone hurts regardless of who dropped it.
#define MS13_STAT_STRONG_MELEE_CONTRIBUTION 0.65
