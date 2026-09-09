// Tuning knobs for mojave/code/modules/mob/living/carbon/pain_debilitation.dm.
// DD's stock pain.dm forces Unconscious() once pain/shock crosses a threshold; these raise how much
// pain/shock it takes to hit that point, scaled off DD's own defines (code/__DEFINES/pain.dm) so they
// track any upstream rebalance instead of drifting from it.

/// How much pain a mojave character can take before collapsing outright, vs DD's PAIN_AMT_PASSOUT.
#define MS13_PAIN_AMT_PASSOUT (PAIN_AMT_PASSOUT * 1.6)

/// Raised shock ceiling/tiers to match the higher pain passout above.
#define MS13_SHOCK_MAXIMUM (SHOCK_MAXIMUM * 1.5)
#define MS13_SHOCK_TIER_COLLAPSE (SHOCK_TIER_6 * 1.5)
#define MS13_SHOCK_TIER_LIMP (SHOCK_TIER_7 * 1.5)

// Debilitation response - conscious and still capable of acting, just severely hampered.
// The movement slowdown itself is already handled by DD's stock life.dm (it applies
// /datum/movespeed_modifier/shock automatically once shock_stage >= SHOCK_TIER_1); these are the
// extra effects layered on top once pain/shock crosses the collapse threshold above.
/// Minimum time between stumble/drop-item rolls, so they don't reapply every tick.
#define MS13_PAIN_DEBILITATION_COOLDOWN (4 SECONDS)
/// Eye blur amount applied per debilitation pulse.
#define MS13_PAIN_DEBILITATION_BLUR 4
#define MS13_PAIN_DEBILITATION_JITTER (6 SECONDS)
#define MS13_PAIN_DEBILITATION_STUTTER (6 SECONDS)
/// Base percent chance per pulse to stumble, scaled by severity.
#define MS13_PAIN_DEBILITATION_STUMBLE_CHANCE 25
#define MS13_PAIN_DEBILITATION_STUMBLE_DURATION (1.5 SECONDS)
/// Base percent chance per pulse to drop the held item, scaled by severity.
#define MS13_PAIN_DEBILITATION_DROP_CHANCE 30
