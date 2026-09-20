# Mappable bombs (WIP)

Place `/obj/item/grenade/ms13_bomb` for medium demolition, or its `/small`, `/large`,
`/antipersonnel`, `/antiarmor`, `/thermobaric`, `/incendiary` subtypes.
`/obj/effect/spawner/random/ms13_bomb` selects one weighted random bomb.
All spawn unarmed. Pick up and activate in hand to arm. Screwdriver cycles 5/10/30/60-second
timers. Alt-click rotates an unarmed directional charge; examine reports its status.
There is no disarming. Destruction can trigger detonation, as with existing grenades.

Mapper/modder variables (set on a placed object or a new subtype):

- `det_time`: fuse in deciseconds; default 100 (10 seconds).
- `quality`: 1 is standard; `quality_variation`: random percentage, default 20. Set variation
  to 0 for fixed quality. Creation scales payload strengths once; effective quality is clamped 0.5–1.5.
- `ex_dev`, `ex_heavy`, `ex_light`, `ex_flame`: existing explosion radii in tiles (normal caps apply).
- `shrapnel_type`, `shrapnel_radius`: existing projectile cloud type and magnitude.
- `jet_damage`, `jet_penetration`, `jet_range`, `jet_fragments`, `dir`: existing bullet_math
  shaped-charge payload. Zero jet damage disables it. Anti-armor covers vehicles and power armor.
- `name`, `desc`, `icon`, `icon_state`, `color`, `w_class`, `throw_range`: presentation/handling.
  Custom art needs an accompanying `<icon_state>_active` state.

Thermobaric currently means a broad, blast-heavy payload with limited fire, not a physical
fuel-air simulation. Incendiary produces fire without demolition/shrapnel. Grenade art is a
placeholder. No crafting recipes or custom UI yet.

## Physical wired triggers

Place `/obj/machinery/power/ms13_bomb_mount` and a
`/obj/machinery/power/ms13_bomb_trigger` switch, or its `/pressure_plate` subtype.
The mount comes loaded; set its `bomb_type` to any bomb preset above and `dir` for the jet.
Use a screwdriver on the mount to cycle its fuse. Pressing the switch or stepping on the
plate starts the connected payloads' timers (10 seconds by default), not an invisible zone.

Connect them with ordinary `/obj/structure/cable` objects, with a knotted cable endpoint
under each device. Use the existing cable placement/editor states, exactly like power machines.
No generator is required. Use an **isolated circuit**: all bomb mounts sharing that network
are triggered together, even if it is a building's power grid. Exposed-floor cables are visible;
intact floors hide them normally. Wirecutters sever the connection, but do not stop a timer
already started. Broken switches/mounts cannot transmit/receive. Plates also have a manual
test interaction (clicking them fires the circuit). Flying creatures and ghosts do not trip them.

Regression: `/datum/unit_test/ms13_mappable_bombs` checks presets, art, timer guards,
native cable connection, cutting, reconnecting, and repeated triggering.
