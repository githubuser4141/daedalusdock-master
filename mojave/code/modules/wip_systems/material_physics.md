# WIP material physics

`material_physics.dm` adds normalized `density`, `hardness`, `ductility`, and `bulk_modulus` fields to
the shared material datum. The existing material system already supplies strength, integrity, armor,
value, and item/turf sound overrides; these four fields fill the physical gap needed by shaped charges
and future hand-fabrication systems.

The Mojave metal values are gameplay-oriented placeholders, broadly ordered by real material behavior
rather than expressed in SI units. Before using them for detailed simulation, centralize a researched
dataset and retune every consumer together. New systems should read these fields generically instead of
switching on individual material paths.

The file also connects legacy MS metal stacks to their existing `material_type` datums. This is needed
for any generic material consumer and should eventually be moved beside each stack definition once the
MS material port is consolidated.
