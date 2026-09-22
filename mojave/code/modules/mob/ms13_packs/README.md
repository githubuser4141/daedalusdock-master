# Mob packs

Mobs nobody is near fall asleep together, and wake together. It works on any map, and for mobs
spawned mid-round, with nothing to place: `SSms13_packs` finds them itself.

Every 10 seconds the subsystem gathers awake mobs that aren't fighting into packs: the same faction,
within 5 tiles of the pack's leader, up to 12 each. A pack falls asleep after two passes with no
living player within the wake range of its leader and none of its members fighting (a living
target, or hurt in the last 30 seconds). Stragglers more than 5 tiles from the leader then leave
and form packs of their own.

A sleeping mob's AI is off (basic mobs' controller, simple animals' `AIStatus`) and its `Life()` runs
one tick in ten (`stasis_level`). The leader has a wake area: its members' sight range plus 3. Any of
these wakes the pack:

- a living player in the wake area;
- a mob of another faction, with its AI running, that comes into it;
- any member being hurt.

Mobs already nearby when the pack fell asleep never wake it, sleeping or not, so neighbouring packs
of different factions can't keep each other awake. A shot flying past doesn't wake a pack; a hit does.

The wake area costs next to nothing. A sleeping pack listens to the four to nine spatial grid cells
(17x17 tiles) around its leader, and only hears when a mob crosses into one of them. While a player,
or a hostile mob that crossed in, is inside those cells but not yet in range, it checks again once a
second.

The leader wakes at once and the others 0.2 seconds apart, so a large pack doesn't all start
thinking in the same tick.

Awake, only the leader looks for targets. Followers take the leader's target, skipping their own
`hearers()` scans (basic mobs' `find_potential_targets`, simple hostiles' `ListTargets()`). They
trail the leader while idle, and fight for themselves for 5 seconds after being hurt. A legacy
ranged robot that can't see the target fires at a tile around where it is, rather than at it. When
the leader dies or leaves, a random member takes over and the followers drop the target they were
given until the new leader calls one.

Every mob with an AI takes part. Set `ms13_can_sleep = FALSE` on a mob, or a type, to keep it
always awake; the types that do are listed at the top of `packs.dm`. Mobs a player has been in
(`key` set) never sleep. There is no respawning.

Regression: `/datum/unit_test/ms13_mob_packs`.
