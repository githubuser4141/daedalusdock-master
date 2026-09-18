# WIP surface impacts

This directory holds the first, deliberately constrained version of the dynamic-content idea.

Use the admin debug verb **MS13 - Spawn Surface Impact**. It prompts for theme (including random),
standard/elite strength, footprint size, warning time, and whether to target your current tile or a
datum marked through View Variables. No map template is involved: the encounter is assembled from
existing turf, mob, structure, and item type paths at runtime.

Current safety limits:

- Impacts only run on the map's middle surface z-level (a level with both `Up` and `Down` traits).
- The whole footprint must be outdoor `/turf/open/floor/plating/ms13/ground`; buildings, caves,
  protected terrain, landmarks, docking ports, map edges, and overlapping impacts are rejected.
- Humans receive the selected marked warning, are moved just beyond the footprint, and take impact
  damage. Other living mobs inside are gibbed. Existing objects in the footprint are lost.
- Generation is immediate and procedural. It does not yet schedule random impacts, save/restorable
  pre-impact terrain, create multi-z sinkholes, or use hand-authored `.dmm` rooms.

To add a theme, subtype `/datum/ms13_surface_impact`, set `abstract = FALSE`, and supply terrain,
mob, feature, and loot pools. An elite subtype can set `elite = TRUE` to use the shared larger,
denser, more dangerous profile and override any pool that needs higher-tier content.
