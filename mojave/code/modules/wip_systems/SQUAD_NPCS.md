# Experimental human squads

Spawn `/mob/living/carbon/human/ms13_squad` recruits and Alt-click one from beside
them to start a squad. Further unassigned recruits join your nearest commanded
leader within seven tiles when Alt-clicked. The first recruit becomes the physical
leader. The explicit `/leader` subtype starts a separate squad when claimed.

For preset map squads, place one `/leader` and recruits with the same nonempty
`squad_id`. Use a unique ID for each squad and exactly one leader per ID. Nothing
is automatically added to existing maps.

These are real humans: clothing, hands, injury, mobility, item access, weapon
ammunition and normal item interactions apply. They start with worn clothes,
shoes, a flashlight and a combat knife. They have no default firearm. Set
`squad_outfit` to another `/datum/outfit` for a mapper/coder/admin loadout; set it
to null for an unequipped recruit. A custom outfit can supply a gun in `r_hand`
or `l_hand`, ammunition, armor or an access card.

Equipped mob subtypes are available under `/mob/living/carbon/human/ms13_squad`:

| Subtype | Weapon | Default fire mode |
| --- | --- | --- |
| `sidearm` | 10mm pistol, leather armor | Careful |
| `rifleman` | Service rifle, leather armor | Careful |
| `marksman` | Marksman carbine, combat armor | Precise |
| `support` | .45 SMG, combat armor | Rapid |
| `guard` | Battle rifle, combat armor and helmet | Careful |
| `bos` | Brotherhood initiate, 10mm pistol, helmet bodycam | Careful |
| `bos/rifleman` | Brotherhood knight, service rifle, combat armor, helmet bodycam | Careful |
| `vault` | Vault security, 10mm pistol | Careful |
| `ncr` | NCR trooper, service rifle | Careful |
| `legion` | Legion veteran, battle rifle | Careful |

Each also carries two matching spare magazines in its backpack, plus the base
clothes, flashlight and knife. NPCs reload with their actual spare magazines,
chamber rounds and clear jams. The corresponding outfit can also be assigned to a leader's
`squad_outfit`. Default recruits and leaders still spawn without guns.

## Taking command

Alt-click a conscious NPC from beside them to recruit or reopen its squad. Other players
cannot replace a living assigned commander. This grants a **Squad command** HUD action
and opens its panel. Select the whole squad or an individual, choose an order,
then click a world target. Right-click cancels designation; the HUD action reopens
the panel. Use **Release command** to let someone else claim the squad. If the
commander dies, another player can claim it at the surviving leader.

The leader is a physical, vulnerable NPC. An unconscious, dead or player-controlled
leader cannot relay player orders. Existing orders continue, but a deleted leader
removes their command action. A player controlling a recruit suspends its AI;
disconnecting returns it to the normal AI lifecycle.

## Orders

| Order | Target and result |
| --- | --- |
| Move / Guard | Walk onto the selected tile, then guard that position. |
| Follow | Follow the commander or another squad member at two tiles. |
| Patrol | Shuttle between the recruit's starting position and the clicked location. |
| Attack | Engage a living enemy, or breach an obstacle using the selected breach method. |
| Fire at area | Fire at locations within one tile of the designation, from the current position. |
| Fire direction | Shoot along the direction from the leader to the designation, from each recruit's position. |
| Hold | Stop movement and the previous order. Recruits still retaliate if attacked again. |
| Use | Walk to and operate a button or door with an empty hand; ordinary access and power checks apply. |
| Sit | Select one recruit and a vehicle seat: board through an unlocked door and buckle in. Hold keeps them seated; a movement order unbuckles them. |
| Destroy | Approach a destructible wall, structure or machine and use the strongest effective carried melee tool. Uses normal damage and cooldowns, never explosives or gun ammunition. |
| Breach | Clear an anchored structure, machine or closed turf using the recruit's breach method. |
| Pick up | Collect a loose item with a free hand. This is how players supply loaded guns. |
| Deliver | Carry the last picked-up item onto the destination and drop it. |

Use, Sit, Pick up and Deliver require an individual selection to avoid several
recruits toggling or grabbing the same object. Order status is shown in the panel
and on examine. Destroy can use the whole squad; Breach automatically assigns
one available recruit, or uses the selected recruit. Failed interaction/movement
jobs time out after 45 seconds and return to guard; a new order can replace them
at any time. Guard/follow/patrol retry navigation after temporary obstructions.

Set **Auto**, **Melee**, **Guns** or **Explosives** for one recruit or the squad.
Auto tries an effective melee tool first, then a loaded gun, then a carried charge.
Explicit methods do not silently switch to another method. Ranged breaching uses
real ammunition and the selected fire mode; ineffective tools report why work stopped.

Supply charges through Pick up or the NPC's backpack. Breach never creates or
replenishes explosives. The planter announces the clearance distance; nearby NPCs
temporarily clear the danger zone, and planting waits for the commander and other
friendlies to leave. Clearance includes X4's forward blast and a shaped charge's
jet and fragments. No escape route means no arming. Planting can be interrupted
by a new order or a friendly re-entering the blast area. Once planted, the real
fuse continues (at least 20 seconds, increased for slower movement); changing
orders cannot disarm it. Units retreat and wait before resuming their orders.
The explosion uses normal damage, so a heavily protected target may survive.

Recruits retaliate against weapon, hand, animal, projectile and thrown-item
attacks. A conscious nearby NPC leader shares the attacker with nearby squad
members as a temporary firing target. After the threat expires or disappears,
they resume their standing orders. Squadmates and the assigned commander are
excluded as deliberate attack targets. A line check prevents deliberate fire
through them; moving into an already-fired projectile can still cause friendly
fire. Area fire is live fire and can hit other bystanders.

## Fire modes

The command panel and linked terminal can change an individual or the whole
squad's fire mode without replacing its movement/combat order. The mapper may
also set `fire_mode` to `Careful`, `Precise` or `Rapid`.

- **Careful:** spaced shots, at least one second apart, requiring a reasonably
  clear shot through cover.
- **Precise:** two seconds of stationary aim before firing, a clearer firing
  lane, and a wait for accumulated recoil to settle. Movement, a changed target
  or weapon, and a blocked lane cancel aim. Area fire uses the designated center.
- **Rapid:** frequent trigger pulls, limited by the actual gun and the normal
  action cooldowns. Recoil accumulates normally; ammunition, heat and jams still
  apply. A weapon's own burst setting is preserved.

All modes retain the squadmate line check and use two hands when available.
No mode grants extra damage or ammunition. NPCs use A* pathfinding and their
actual ID access. They operate unlocked manual MS13 doors while travelling;
locked or bolted MS13 doors are excluded from their route. Use can also operate
an explicitly designated door. They do not pick locks or invent access rights.

## Cryopods

Place `/obj/machinery/ms13/npc_cryopod` and configure:

- `mob_type`: the living mob type to release, including any equipped squad subtype.
- `squad_id`: assigned to released squad NPCs.
- `pod_id`: displayed label; defaults to the pod's coordinates.
- `network_id`: optionally matches `cryo_network` on one or more terminals.
  Leave blank for automatic discovery by terminals within seven tiles on the same level.
- `dir`: the adjacent exit tile; keep it clear.

The terminal's **Cryopod control** page is always available and lists nearby
unassigned pods and every matching network pod, with coordinates,
occupant type and status. Wake one or all ready pods remotely, including across
levels. Both pod and terminal require power. Each pod contains one occupant;
repeated commands cannot create duplicates. Blocked exits do not consume the
occupant, so clearing the exit and retrying works. Clicking the pod allows local
release, with feedback for an empty, offline, inaccessible or blocked pod.
Terminal passwords and the pod's normal access restrictions still apply.

## Body cameras

`/obj/item/ms13/bodycam` pairs with a powered, accessible terminal when tapped
against it while held. It can pair with multiple terminals. Click a person with
the camera: head/eyes/mouth selects their helmet; other zones select covering
armor, falling back to their uniform. Clothing can also be clicked directly.
BoS presets start with a transmitting helmet camera. Alt-right-click its clothing to remove
it. Use the camera in hand to toggle transmission. One camera fits per garment.

Choose **Body cameras** on a paired terminal. Its camera window uses the existing
embedded map panel, with a searchable feed list; the operator's main view is
unchanged. Squad controls stay beside the feed: select a recruit and an order,
then click the feed to designate a visible tile or object. Field command can also
designate through an open terminal feed. Leaving the terminal, losing power or
losing the feed prevents remote orders. Feeds update as wearers move or nearby doors change. Only a camera on
worn clothing transmits; removal, switching it off, destruction or EMP disables
its feed. Pairings do not expose cameras to the ordinary security-camera network.

## Terminals

Every `/obj/machinery/ms13/terminal` (including `wasteland`) has **Squad command**
on its home screen. An unconfigured terminal lists NPCs within seven tiles.
Select one to recruit it or open your squad. The terminal remembers that squad
so it remains controllable when its leader moves away. Nearby unassigned recruits
can then be added to it. Another player's commanded NPCs cannot be taken over.
Mapper `squad_id` assignments still link a terminal directly to a specific squad.

The terminal must be active, powered, unlocked, on the leader's level and within
the operator's reach. These checks run again when an order is submitted, including
after coordinate prompts. Moving away, losing power or deleting the terminal
invalidates that terminal session. Alt-click the leader again to return to field
command mode. **Order by coordinates** supports movement/patrol and fire orders
without walking the operator to their target. It uses the panel's selected order
and the terminal's current z-level; arbitrary object references are not accepted.

## Current WIP limits

- Field command range and order destinations are limited to 30 tiles of the
  leader, on the same z-level. Field clicks must also be in the player's view.
- Gun engagement range is seven tiles. Area/directional fire holds position and
  waits for a loaded gun; it does not generate ammunition or send an unarmed
  recruit charging toward the designation.
- Ballistic magazine-fed guns use matching carried magazines. Internal-magazine
  loading, tactical cover selection, formations and autonomous looting remain WIP.
- Recruits recover their own dropped gun and retrieve ammunition, demolition
  tools and charges from carried storage. Full hands can prevent object work.
- Patrol has two points. There is no route editor or task queue.
- These are ordinary living humans, not invulnerable RTS units. There is no
  autonomous medical care, eating or sleeping schedule yet.
- The roster uses a linear lookup suitable for small opt-in squads. Benchmark
  before populating whole maps with them.

## Verification

The adjacent `squad_npcs_tests.dm` contains focused unit tests: authority and
terminal recovery, real inventory/button/container interaction, real ammunition
and friendly-fire checks, and live A* movement/patrol/recovery. Enable UNIT_TESTS
in an isolated wrapper and focus `ms13_squad_authority`, `ms13_squad_inventory`,
`ms13_squad_combat` and `ms13_squad_movement`. Expansion tests are
`ms13_squad_fire_modes`, `ms13_squad_loadouts`, `ms13_squad_cryopods`,
`ms13_squad_doors` and `ms13_bodycams`. Demolition tests are
`ms13_squad_destroy`, `ms13_squad_breach_cancel` and `ms13_squad_breach_live`;
the last one waits for an actual native charge detonation after the units retreat.
