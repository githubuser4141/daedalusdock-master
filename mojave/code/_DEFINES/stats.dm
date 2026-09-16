// Tuning knobs for mojave/code/modules/stats/stat_condition.dm - the live, body-condition-driven half of
// /datum/ms13_stats (mojave/code/modules/stats/stats.dm). The datum's six vars are the character's BASE
// stats; what the game actually reads is get_stat(), which is that base scaled by how intact the body
// currently is.

/// Stat ids. These are the /datum/ms13_stats var names verbatim - get_base()/set_base() use them directly
/// with vars[], so a typo here is a runtime lookup failure rather than a compile error. Keep them in sync.
#define MS13_STAT_PERCEPTIVE "perceptive"
#define MS13_STAT_ENDURING "enduring"
#define MS13_STAT_RETAINING "retaining"
#define MS13_STAT_STRONG "strong"
#define MS13_STAT_OUTGOING "outgoing"
#define MS13_STAT_NIMBLE "nimble"

/// The "no buffs and debuffs" value /datum/ms13_stats already documents. Used as the fallback for any mob
/// that never got a stats datum (only job-spawned mobs do - see mojave/code/modules/jobs/job_types/_job.dm).
#define MS13_STAT_BASELINE 15

/// A stat can never be condition-scaled below this. Zero strength would mean literally no melee damage at
/// all, which reads as a bug rather than as being badly hurt - there should always be a feeble last swing.
#define MS13_STAT_MINIMUM 1

/// Condition inputs are multiplied together, so each one is clamped to this floor before multiplying -
/// otherwise three separate 0.3s would compound to 0.027 and one bad limb would erase the stat entirely.
#define MS13_STAT_CONDITION_INPUT_FLOOR 0.25

// --- Strength (MS13_STAT_STRONG) ---
// Inputs, in the order they're combined in get_stat_condition(): arm muscle performance (which already
// folds in bone stability and that limb's local blood - see muscle_movement.dm), whole-body circulation,
// and pain. Only strength has condition inputs wired up so far; the other five return 1 and read as their
// base value, ready to be filled in the same way.

/// Pain/shock at or above this shock_stage drops strength to its full pain penalty; below it the penalty
/// scales in linearly from nothing. SHOCK_TIER_2 is where DD already starts describing the body as failing.
#define MS13_STAT_STRONG_PAIN_FLOOR_STAGE SHOCK_TIER_3
/// Worst-case multiplier from pain alone, reached at MS13_STAT_STRONG_PAIN_FLOOR_STAGE.
#define MS13_STAT_STRONG_PAIN_MULT 0.4

/// Melee damage at MS13_STAT_BASELINE strength is unchanged (1.0). This is how much of the swing is
/// strength-dependent: at 0 effective strength a weapon still lands (1 - this), because a crowbar dropped
/// on someone hurts regardless of who dropped it.
#define MS13_STAT_STRONG_MELEE_CONTRIBUTION 0.65
