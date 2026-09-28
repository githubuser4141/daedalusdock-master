These movement loops are edits of recordings already shipped in this repository; no external assets were added.

- `vehicle_road_loop.ogg`: excerpt of `buggy_loop.ogg`.
- `vehicle_rail_loop.ogg`: slowed `tank_treads.ogg` with a filtered `generator_on.ogg` motor bed.
- `vehicle_blast_door_loop.ogg`: excerpt of `doorgear_open.ogg`.

Run `python tools/distant_sounds/make_vehicle_loops.py` from the repository root to regenerate them. The script records the exact source paths and edits, makes two-second wrap-crossfaded loops, and checks the decoded output for length, clipping and silence. Original asset licensing continues to apply.
