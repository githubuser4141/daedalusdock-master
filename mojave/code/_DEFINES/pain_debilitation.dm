// Tuning knobs for:
//  - mojave/code/modules/mob/living/carbon/pain_debilitation.dm (handle_pain/handle_shock overrides)
//  - mojave/code/datums/status_effects/pain_debilitation.dm (the status effects those overrides apply)
// DD's stock pain.dm forces Unconscious() once pain/shock crosses a threshold; these raise how much
// pain/shock it takes to hit that point, scaled off DD's own defines (code/__DEFINES/pain.dm) so they
// track any upstream rebalance instead of drifting from it.

/// How much pain a mojave character can take before collapsing outright, vs DD's PAIN_AMT_PASSOUT.
#define MS13_PAIN_AMT_PASSOUT (PAIN_AMT_PASSOUT * 1.6)

/// Raised shock ceiling/tiers to match the higher pain passout above.
#define MS13_SHOCK_MAXIMUM (SHOCK_MAXIMUM * 1.5)
#define MS13_SHOCK_TIER_COLLAPSE (SHOCK_TIER_6 * 1.5)
#define MS13_SHOCK_TIER_LIMP (SHOCK_TIER_7 * 1.5)

// /datum/status_effect/ms13_pain_debilitation - conscious and still capable of acting, just severely
// hampered. The movement slowdown itself needs no extra code: DD's own life.dm already applies
// /datum/movespeed_modifier/shock automatically once shock_stage >= SHOCK_TIER_1, and shock_stage is
// still driven up the same way DD does it.
/// How long the debilitation status lingers after the last time it was (re)applied.
#define MS13_PAIN_DEBILITATION_DURATION (8 SECONDS)
/// How often its tick() re-rolls the stumble/drop-item chances and refreshes blur/jitter/stutter.
#define MS13_PAIN_DEBILITATION_TICK_INTERVAL (4 SECONDS)
/// Eye blur amount applied per tick, scaled by severity.
#define MS13_PAIN_DEBILITATION_BLUR 4
#define MS13_PAIN_DEBILITATION_JITTER (6 SECONDS)
#define MS13_PAIN_DEBILITATION_STUTTER (6 SECONDS)
/// Base percent chance per tick to stumble, scaled by severity.
#define MS13_PAIN_DEBILITATION_STUMBLE_CHANCE 25
#define MS13_PAIN_DEBILITATION_STUMBLE_DURATION (1.5 SECONDS)
/// Base percent chance per tick to drop the held item, scaled by severity.
#define MS13_PAIN_DEBILITATION_DROP_CHANCE 30

// /datum/status_effect/determined/ms13_adrenaline - DD already has a real "fight-or-flight" status
// (code/datums/status_effects/wound_effects.dm: reduces bleeding and limping) that was never actually
// applied anywhere in the codebase. Granting it on a successful "shrug off pain" roll (see
// handle_shock() below) gives that roll a real, visible, felt effect instead of a silent shock_stage
// subtraction.
#define MS13_ADRENALINE_DURATION (20 SECONDS)
