# QoL changes: practical test checklist

Use a fresh server running the newly compiled `daedalus.dmb`. Spawn the destructive test encounters away from your normal play area. No live `.dmm` files were edited for these features.

## 1. StrongDMM

Start `J:\daedalusmojave\StrongDMM\dst\Open-Drought.cmd`, or run `StrongDMM-QoL.exe` in that directory. The source and build script are in `J:\daedalusmojave\StrongDMM`; the complete controls are in `dst\QOL.md`.

- Open Drought. Its existing `_below` and `_above` siblings should open as linked, separate editable maps.
- Move and zoom somewhere distinctive. Use Page Up / Page Down or the level buttons. The same X/Y and zoom should remain in view, including when clicking linked tabs.
- Enable **View > Multi-Z Rendering**. Open-space tiles should show the lower map. Clicking the upper map must edit that map, not the preview underneath.
- Hover a tile and press **M**. Switch floors: the pin should remain at the same X/Y. Check the signed offsets in the status bar, **Go to pin**, and **Shift+M** to clear it.
- Enable **Mojave / MS13 only**, select `/turf`, and search by name or type path. Try **Browse only this branch**, **Favorites**, and **Recent**. Type sorting should visibly order results by path.
- Use **R / Replace** on a turf obscured by an object. It should replace the turf without stacking terrain. Undo should restore it.
- Try a round or square brush; **[ / ]** changes size (1–15). Fast drags should leave continuous strokes. **2 / Fill** makes rectangles, Ctrl makes their borders, and **5 / Flood Fill** fills matching connected turfs/areas. One undo should remove one stroke/fill on its original map.
- Check middle-drag / Space panning and cursor-centred zoom. Dragging onto the canvas from an unrelated UI control must not paint accidentally.

The editor preview does not execute DM initialization, lighting or smoothing. Automatic linking uses the `name_below`, `name`, `name_above` convention in one folder.

## 2. Hivemind movement, pursuit and recovery

Use **Debug > MS13 - Spawn Terrain Hivemind** and choose **DS13 necromorph corruption** or **Necromorph Marker (power/public radio)**. Start with a contained/regional hive. Units need a network: spawning a bare unit type directly is not a valid setup. To force a strain, use View Variables on the core's `network` and call `spawn_unit(unit_type, origin)` with a suitable turf and enough resources.

Unit types share `/mob/living/simple_animal/hostile/ms13/terrain_hivemind`, with `/footsoldier`, `/heavy`, `/hauler`, `/converter`, `/ranged`, `/siege`, `/regenerator` and other specialized children.

- Let a hostile pursue a living player. Break line of sight around a corner: it should investigate the last seen position instead of immediately forgetting the player.
- Put dense indestructible rock or an armour-deflecting structure between it and a target. It should use an open route around it. If pathfinding fails and there is no useful adjacent breach, it abandons that job immediately; the **10-second** no-progress timeout also catches other stalls. Failed goals are avoided for **30 seconds**.
- Compare a small unit and a heavy against the same tough barrier. A unit skips damage-based breaches needing more than **50 hits after armour**. Even if someone keeps repairing a barrier it could otherwise break, it gives up after fifty attempted hits and can retry after its cooldown. Open routes take priority over breaching, and native heavy wall-smashing remains available.
- Remove the obstruction. It should reacquire reachable work, rather than remain permanently disabled by its earlier failure.
- Give a hauler a corpse, then block the route to its converter/core. It should try alternatives and eventually release the corpse after bounded failed deliveries; another unit should be able to claim it.
- Interrupt a haul by repeatedly breaking the grab, stunning the unit, disabling its AI, or destroying the core. Claims and movement tasks should release cleanly.
- Repeat around stairs/ladders and between levels. Failed connectors should be avoided temporarily while other routes remain available.
- Destroy the core while a survivor has an enemy nearby. It should retain native hostile behaviour rather than keep a dead network task forever.

These checks cover recovery, not a guarantee that every possible map geometry has a viable path. A genuinely sealed destination should be abandoned, not reached through an impassable wall.

## 3. Strains, charges, conversion and necromorph bodies

Absolute necromorph tuning lives in `mojave/code/modules/wip_systems/terrain_hiveminds/terrain_hiveminds.dm`, in the necromorph `strain_stats` list. Each strain has explicit health, melee bounds, structure damage, movement delay, regeneration and resource cost; charging strains also specify ram damage. Other hive themes retain their existing defaults unless given their own table.

Useful examples: footsoldier **100 HP / 20 resources**, heavy **250 HP / 90 resources**, siege **400 HP / 150 resources**. The Marker retains its additional restrictions/costs for growing units without corpses.

- Compare a heavy with a footsoldier in View Variables; changing a network's old base multiplier should not change the explicit necromorph values.
- Stand 2–8 tiles from a heavy/siege unit. Once its charge winds up, sidestep: the charge should continue through its committed line. Test a breakable door/wall along that line. Bolstered obstacles that it cannot hurt should not trap it in an attack loop.
- Give a dead human recognizable clothes, backpack and held items. Convert the body. The gear should drop at the conversion site.
- Kill a necromorph. It should leave a lying body, not disappear. After its **20-second reanimation lockout**, a suitable hive/converter with resources should be able to revive it.
- Kill another and keep attacking the corpse. After **75 effective additional damage**, it should gib and become unavailable for reanimation. Revival should consume resources and should not duplicate the population count.

## 4. Mapper deposits, slow mining and stamina

Place these object types in your editor:

| Type | Contents |
| --- | --- |
| `/obj/structure/ms13/ore_deposit/random` | Weighted mixture of common and valuable ores |
| `/obj/structure/ms13/ore_deposit/random/low` | Coal, iron, copper, lead, aluminium, zinc |
| `/obj/structure/ms13/ore_deposit/random/high` | Silver or gold |

Each has `/drought` and `/mammoth` children for explicit rock art. Otherwise nearby terrain determines the theme. Ordinary fixed deposits also receive rock on map load. Set `encase_on_mapload = FALSE` to map an exposed deposit; `enclosing_rock_type` can select the surrounding mineable rock explicitly.

Mineable wall types are `/turf/closed/mineral/random/ms13`, `/drought`, and `/mammoth`. The existing `/turf/closed/indestructible/rock/ms13` family remains indestructible for boundaries.

- Load the map: random placeholders should become real ore deposits enclosed in a destructible rock wall. Mine the rock to reveal the deposit, then mine the deposit for nuggets.
- Use `/obj/item/pickaxe/ms13`. One click should continue the timed action automatically. At baseline STR, a normal pick takes about **5 seconds per swing** and about **35 seconds of uninterrupted swinging per wall**; resting may extend that.
- Compare higher and lower STR. Higher STR should shorten swings, with a **2–10 second** limit.
- Watch stamina: each completed swing costs **25**, with reduced recovery while working. Exhaustion stops the action. Rest, then click again to resume.
- Click a second deposit while mining the first. It must not start a second simultaneous action. Move away, drop the pick, or put it away: work should stop without phantom damage or a stuck mining lock.

## 5. Cave-ins and supports

- Dig a tunnel into the mineable rock. Each newly excavated tile receives a fixed random support distance of **3–5 tiles**. The original entrance acts as a natural support.
- Continue beyond supported ground. Dust and a warning should precede collapse by **10–15 seconds**.
- Build **mine support beams** from the wood-plank construction menu (**4 planks**, **8 seconds**), or map `/obj/structure/ms13/cave_decor/support/beams`.
- Place a support during the warning: collapse should be cancelled if the tile is now supported. Supports cannot protect through intact rock or around a route longer than the allowed spacing; broken wall supports do not count.
- Leave another section unsupported. It should damage/knock down occupants and leave dense, mineable rubble. Clear it with the pick. Without fixing the support problem, the roof can fail again.
- Destroy a support serving excavated tiles. Newly unsupported ground should be checked again.

## 6. Wielding, hand display and firearm handling

- Put a pickaxe or service rifle in the **right hand**, leave the other free, select it, then press **V** or the wield HUD button. Repeat from the left hand.
- The other hand should become reserved. Both hand slots should indicate the two-handed grip, the wield button should reflect its state, and weapons with existing wielded in-hand art should use it.
- Press V again: it should unwield once, not toggle twice because of an old saved keybinding. Drop the item: the reserved hand and wielded state should clear.
- Occupy the other hand and try wielding. It should refuse without displacing that item. An empty opposite hand must not produce the old incorrect “occupied” message.
- Try a fire axe: wielding should apply its existing **45 force**, returning to **15** unwielded.
- Fire the same rifle one-handed, wielded, wielded with high STR, and wielded in functioning power armour. Compare sustained bursts as well as single shots. The inherited fixed SS13 one-handed penalties and duplicate camera kick are removed; wielded kick now benefits from actual body strength, including the armour frame.

Not every tool has separate two-handed sprite art; the hand reservation and HUD indication still apply. Guns retain their individual recoil and handling differences.

## 7. Admin and automatic surface impacts

Use **Debug > MS13 - Spawn Surface Impact**. Mark a turf/object through View Variables, then choose **Marked datum** (or use your current tile).

- Explicitly choose a basement, an upper floor, a roofed location and a location near the edge. The impact should use that exact centre rather than reject it solely for its level, roof or border position.
- Choose automatic placement. It should keep the entire footprint away from map transitions/edges and out from under thick roofing, including a thick floor higher in the column above thin roofing.
- Thin sheet/wood/asphalt roof types permit automatic impacts. Solid floors/closed terrain above and heavy metal roofs block them. Mappers can override `ms13_blocks_surface_impacts` on a roof turf.
- Automatic placement also retains infrastructure/vehicle protection and evacuation checks. Explicit placement retains collision reservations and refuses to trap a player when there is no evacuation tile.

## 8. Remote power, terminals, doors and cameras

Place `/obj/machinery/ms13/terminal/control` in a powered control room. Its **Utili-Dock** page exposes mapped links. Wall terminals also support controls; Alt-click flips a flippable wall terminal open.

| Device | Mapper setup |
| --- | --- |
| Terminal link | Set `signal_title_1 = "Room power"`, `signal_id_1 = "room-power"`; use slots 1–6 for more circuits. |
| Power conduit | Place `/obj/machinery/power/apc/ms13/conduit` in the target area, connected like an existing utility box; set `id_tag = "room-power"`. Use its directional children for wall placement. Existing MS13 utility boxes can also use `id_tag`. |
| Physical switch | Place `/obj/machinery/button/ms13_power`; set `id = "room-power"`. It can restore the breaker even in an unpowered room. |
| Shutter | Set the shutter's `id` to the terminal link's circuit ID. |
| Motorised MS13 door | Set `id_tag` to the circuit ID; install a door motor or map `motorised = TRUE`. Supply a live knotted cable under the door. |
| Vehicle blast door | Set its `id` to the circuit ID and provide its existing powered rail/feeder/stops setup. The terminal uses the real vehicle drive. |
| Security cameras | Set the terminal's `camera_network = "facility"`; put cameras on `list("facility")` and give them distinct `c_tag` names. Use the Security Cameras link on Utili-Dock. |

- Toggle a conduit: lighting, equipment and environmental power in its area should switch together. Restore it with the separate switch. Keep the terminal on a different powered area if it must remotely restore the target room.
- Link several shutters to one ID. A click should open the group when any are closed; another closes it. Test a motor door without power, with cut motor wiring, and with its bolts engaged: the terminal must respect these restrictions.
- Trigger a rail blast door. It should actually travel to its stop. An unavailable/blocked device should not be reported as successfully activated.
- Set `signal_title_single` and `signal_id_single`. Opening the page must not consume it. A successful activation consumes it once; a failed command should remain usable.
- Set `password_needed = TRUE` and a password. A wrong password should fail; the correct one should grant access. Power loss or moving out of range should close camera access and prevent further control commands.
- Check a camera on another network: it should not appear. Delete the terminal: its viewer should disappear too.
- Custom document titles/content should survive initialization; predefined document names should still load their associated text.

## 9. Mojave sound effects

Inherited DD defaults now resolve centrally to Mojave recordings, covering SFX tokens and direct file calls. Listen for:

- Ordinary explosions nearby, farther away and at the edge of hearing: the original Mojave `explosion_1..3`, `explosion_far_1..3`, and `explosion_distant_1..3` families.
- Punches, generic blunt hits, heavy smashes, blade slashes and stabbing/projectile hit defaults.
- Glass breakage, mined rock and bodies falling.
- Flashlight switches and wall-light startup using their existing Mojave recordings.

Specific gun, creature and material sounds retain their own recordings. Fire grenades and necromorph exploders keep their specialized blasts. Existing wood/metal/glass hit assignments were traced rather than replaced with one generic sound. Not every unused file in the sound library is appropriate for a current gameplay action; music, ambience and unused content are not forced into unrelated events.

The distance-sound generator preserves authored explosion tiers, creates the new rock/heavy-hit distance recordings, and avoids turning the Marker's local ambient loop into a map-wide battle cry. Its output writes are now atomic, and its Windows encoder uses a sufficient stack for long recordings.

## 10. Marker lighting atmosphere

Place an unsuppressed Marker and powered wall lights/electrical handheld flashlights within its **30-tile lighting radius on the same floor**. Set the Marker's mapper variable `light_flicker_radius` to adjust it independently of hallucination/corpse reach; **0 disables Marker lighting effects**, including on its own tile. The setting survives initialization of a mapped Marker.

- Turn an APC off and back on without a Marker: fixtures give two quick startup dips, then stay at full brightness. Near a Marker, startup instead gives four deeper dips over about **2.8 seconds**, then settles to **20% dimmer**. An already-lit lamp entering Marker influence just dims; the periodic influence pulse does not restart startup.
- Watch several lights for a few minutes. After the startup burst, each light independently waits **1–3 minutes** between single **0.4-second** dips. The regular influence pulses must not restart the startup burst. Flames/flares are excluded.
- Switch a flashlight off during a flicker: it must stay off. Carry it beyond the radius: normal brightness should return on the next object-processing tick.
- Suppress or destroy the Marker: affected lights should recover. Repeated pulses or overlapping Markers must not compound the dimming.
- Changing a light's normal brightness while affected should still restore the new brightness when the effect ends.
- Cut APC power during startup: the fixture must stay off. Routine refreshes and visual dips must not add bulb wear; real switch-ons still do. After an EMP, switch-on burnout is **90% less likely for 90 seconds** (including the usual one-minute APC recovery).
- EMP a utility box or pulse/cut its power wires: it must never enter the inherited APC **shorted** state. EMP channel shutdown and ordinary breaker operation remain separate.

## 11. Train stops on other floors

- Rails over ordinary terminal stairs now connect routes upwards and downwards, using the same crossing for route discovery, line power and whole-car movement. Dedicated paired `/obj/structure/ms13_rail/ramp` inclines still work.
- Pick a stop across the stairs, ride there with a passenger and loose cargo, then return. The route board should show the stop on its correct floor. A blocked landing must stop the entire car rather than split it across levels.
- Test the second-level tunnel stop in `Drought`: the rail/stair connection at **(115,171)** joins it to `Drought_below`. The leftover third-level stop in `Drought_above` at **(115,177)** is separate and is not the destination for this check. No map files were edited for this fix.
- The return stop is **(104,195) in Drought_below**. The upper stair entrance at **(115,171)** is open space without a rail object; route discovery, feeder discovery and movement must still descend to the railed stairs below. A covered opening or an approach against the stairs' direction must not create a connection.

## 29 September follow-up checks

- **Mountain Bunker generator:** start a fresh round and turn on the generator serving the utility box at map coordinates **(96,175) in Drought_below**. In the current centered runtime map this is **(111,202,2)**. The brief light startup should finish and the APC should stop repeatedly thunking. The map loader now keeps differently named MS13 rooms separate instead of merging Mountain Bunker, Brotherhood Tram and BoS Mines into one area controlled by competing APCs. This requires reloading the map in a new round/server; recompiling cannot split an already-running area's objects.
- **Conduit:** click `/obj/machinery/power/apc/ms13/conduit` to turn its area power off/on. It must open no UI. Remote switches and linked terminals still operate it. Normal utility boxes retain their existing interface.
- **Conduit startup on plant power:** the conduit is industrial switchgear and no longer inherits household fusebox burnout or bulb surges from plant voltage. A mapped conduit should remain intact on a powered plant circuit and still toggle its area. Ordinary utility boxes still require stepped-down voltage, and physical damage can still break a conduit.
- **Mines blast-door button:** your saved button at **(94,195)** and mines door at **(88,194)** now both use `bos_blast_mines`; the separate tram crossing door at **(110,193)** uses `bos_blast_door`. No map edits were made by this agent. Automatic travel now accounts for the complete slab length on unmarked tracks, so it parks inside the wall pocket. Check opening and closing with the linked button.
- **One area controller:** Brotherhood Tram currently contains a utility box at **(96,195)** and a conduit at **(97,197)**. Use one APC/conduit per area to avoid competing power settings; a remote button or terminal can control that one device from elsewhere by ID.
- **StrongDMM measuring stick:** restart either desktop StrongDMM copy. Select the second tool and drag: the status bar shows inclusive length for a line, or width, height and tile area for a rectangle. Hold Ctrl for its border tile count. Reverse-direction drags give the same measurements. Release and Undo should behave normally. A named backup is at `J:\daedalusmojave\StrongDMM\dst\StrongDMM-QoL-measurement-2026-09-29.exe`.
- **Necromorph corpses:** kill a necromorph; its sprite should fall onto its side. Reanimation should restore the upright pose. Damaging the corpse enough still produces gibs and prevents revival.
- **Small swarmers:** they now use their own soft attack effect and no challenge roar. Killing one produces a quiet, short-range splat and gibs immediately, even after its Marker is destroyed. Larger necromorphs retain their fallen, revivable bodies.
- **Barricades:** put a wooden `/obj/structure/ms13/barricade` across a slasher's route. It should break the edge actually blocking it, from either side and in all four orientations. Ordinary breaching still uses the 50-hit budget and actual armor/damage checks.
- **Last-resort destruction:** slashers and heavy strains with no fight, corpse job, healing destination or workable patrol may damage reachable nearby objects, including nonblocking or unusually tough objects. Better work can preempt it on the next decision. Immune objects are skipped, attacks are paced, and repeated ineffective/repaired barriers retain bounded retry.
- **Automatic revival:** intact necromorphs in the Marker's corpse reach (45 tiles, including linked adjacent floors) revive automatically after the 20-second lockout on a subsequent 10-second pulse. An infector/hauler claim no longer prevents it, and an existing body does not require room for a newly spawned unit. Cost is one quarter of the strain's conversion cost, rounded up: a slasher costs **5**, a 90-cost brute **23**. A strain may override this with `revive_cost`. Player-held bodies, containment, sight/sunlight, population limits and destroyed/gibbed bodies still prevent revival as appropriate.
- **Vehicle movement:** drive a wheeled vehicle, an electric train and a vehicle blast door. They now use separate road, heavy rail and geared-door loops, derived from existing recordings. Blast-door slabs and their roofs use `icons/obj/doors/blastdoor.dmi` / `closed` rather than vehicle flooring.

- **Marker revival:** away from its biomass, watch an eligible corpse from the front: it must stay dead, including when visible through open space from above. Look away or block the sight line with an opaque obstacle: revival may resume. Blind/unconscious/dead observers do not prevent it. Direct sunlight, including sunlight spilling under a roof, blocks revival from sunrise through sunset; outdoor darkness and electric lighting do not. A patch of that Marker's biomass under the body overrides both observation and sunlight restrictions. Suppression, cooldowns, population and resource requirements still apply. The same rule covers remote pulses, unit conversion and structures; blocked attempts preserve prior progress and spend no resources.
- **Lighting radius:** map a Marker with `light_flicker_radius = 2`; lights two tiles away should be affected and lights three tiles away should not. Set it to 0: existing lights recover on their next processing tick, and future APC startups use the ordinary brief flicker. Re-enable it to restore the atmosphere.
- **Containment EMP:** examine the Marker while contained to see its remaining charge time. The default requires **five uninterrupted minutes**; switching its projector off after that releases one EMP. Switching it off sooner reports that the feedback dissipated without an EMP. `containment_emp_arm_time`, `containment_emp_heavy_range` and `containment_emp_light_range` now survive mapped Marker initialization; defaults are five minutes, 45 tiles and 90 tiles respectively. For a quick test, set the charge time to 100 deciseconds (ten seconds), wait until examination says charged, then switch the shield off.

## 12. Wildlife, themed dens and regrowing flora

See [the wildlife and flora mapper guide](WILDLIFE_AND_FLORA.md) for all type paths, mapper variables and a seven-step manual checklist.

- Reopen the DME in StrongDMM, then search **Drought predator**, **Drought prey**, **Mammoth predator**, or **Mammoth prey**. Each theme has three predator and three prey presets. These are invisible home-point spawners using existing animals; decorate their surroundings with the map's existing scenery. No map placements were changed.
- Place predator/prey dens and flora nearby. Animals patrol home territory, defend it, hunt suitable prey, haul kills home, graze, retreat and heal. Try blocking their home route: failed jobs release carried food and allow other movement instead of leaving animals permanently stuck.
- Fire near wildlife away from its den: smaller animals are more likely to flee. Existing non-den mobs retain their shared-target coordination and fast pursuit. Den animals explicitly opt out of that pack system.
- Flora supports exact-tile, radius and area placement. Harvesting uses existing regrowth; removed plants can respawn after the configured delay. Buildings, roads and occupied tiles must remain clear.

## Automated verification

Latest rail, necromorph and flexible-den verification, 29 September 2026:

- Playable build: **`daedalus_updated.dmb`**, with **`daedalus_updated.rsc`** beside it in the repository root. Select this DMB in DreamDaemon. The running game locked the usual `daedalus.rsc`, so it was left running and a separate output pair was built. Final compile: **0 errors / 17 existing warnings**, `data/rail-hive-dens-playable-compile.log`.
- **17 combined checks passed**: `data/rail-hive-dens-combined-results.json`, `data/logs/2026/09/29/round-11.05.25/tests.log`. Includes the actual Drought train round trip with rider/cargo, blast-door wall pockets, new vehicle art/sound selection, conduit plant-voltage immunity, directional barricades, idle destruction, revival, EMP, lighting, terminals, den presets and existing pack coordination.
- After the final mapper size-override correction, **all five focused wildlife/flora checks passed**, including successful-hit scorpion venom: `data/den-traits-final-results.json`, `data/logs/2026/09/29/round-11.12.05/tests.log`. The test compile had **0 errors / 20 existing warnings** (`data/den-traits-final-tests-compile.log`).
- The combined test run, final wildlife run and final normal boot all had **zero handled or native runtime errors**. Final normal boot: `data/logs/2026/09/29/round-11.12.07/runtime.log`; startup: `data/den-traits-final-game-startup.log`. Only verification servers were stopped; existing game servers were left alone.
- Three new movement loops decode as finite, non-silent, unclipped two-second mono audio. Source edits are reproducible with `tools/distant_sounds/make_vehicle_loops.py`.
- Your saved mines button and door IDs now agree. The remaining map setup issue is the duplicate area controller in Brotherhood Tram, described above. Map placements and your strain-balance edits were preserved. No commit or push was made.

Wildlife and den verification, 29 September 2026:

- Normal build: **0 errors, 17 existing warnings**, `data/wildlife-game-compile.log`. Combined test build: **0 errors, 20 existing warnings**, `data/wildlife-qol-compile.log`.
- All **22 checks passed**, including every themed den preset, wildlife decisions/recovery, live hunting and hauling around an obstacle, flora regrowth and existing pack coordination, alongside all 17 earlier follow-up checks. Results: `data/wildlife-final-results.json`; test log: `data/logs/2026/09/29/round-08.54.21/tests.log`.
- The test run and normal game boot both had **zero handled or native runtime errors**. Normal boot: `data/logs/2026/09/29/round-08.54.23/runtime.log`, `data/wildlife-final-game-startup.log`.
- Live hauling exposed a shared scheduling defect: negative additive slowdown could schedule the next AI movement step in the past, leaving a fast animal stalled. The shared movement-delay getter now clamps to one world tick; normal pack speed settings and pursuit logic were not retuned.

Follow-up verification, 29 September 2026:

- Normal build: **0 errors, 17 existing warnings**, `data/qol-september29-game-compile.log`.
- All **17 focused checks passed**, including Marker visibility/sunlight, corpse sprite rotation, mapped lighting radius, conduit clicks, separate named areas and generator startup. Build: **0 errors, 20 existing unit-build warnings**. Archived results: `data/qol-september29-results.json`; tests: `data/logs/2026/09/29/round-08.05.29/tests.log`.
- Both the focused run and normal boot had **zero handled or native runtime errors**. Checked `runtime.log` and native `dd.log`/startup output. Normal boot: `data/logs/2026/09/29/round-08.05.01/runtime.log`, `data/qol-september29-clean-game-startup.log`. Area deletion now also clears its registries safely when the sorting cache was invalidated.
- The earlier live bunker probe at **(111,202,2)** confirmed one APC and sustained power with roughly **5.36 kW demand / 10 kW supply**; `data/logs/2026/09/29/round-07.15.00/tests.log`.
- StrongDMM: full Go suite passed, plus `TestDroughtEditorWorkflow` using the real Drought maps, including measurement, release and Undo. Log: `J:\daedalusmojave\StrongDMM\dst\qol-measurement-ui-tests.log`. Both desktop executables match the dated backup.

Final verification, 28 September 2026:

- Normal `daedalus.dme` build: **0 errors, 17 existing warnings** (`data/lighting-rail-hive-game-compile.log`). Playable output: `J:\daedalusmojave\daedalusdock-master\daedalus.dmb`.
- Focused test build: **0 errors, 20 warnings**, then **14/14 tests passed** in DreamDaemon (`data/lighting-rail-hive-results.json`; `data/logs/2026/09/28/round-21.51.56/tests.log`). Includes dense-rock detours, the final **50-hit** breach limit and repaired barriers, rail/stair return trips, normal and Marker APC startup, EMP bulb protection and utility-box short-circuit immunity.
- Focused server runtime log: **0 `Runtime in` entries** (`round-21.51.56/runtime.log`).
- Separate normal-game boot completed initialization; its fresh runtime log also has **0 `Runtime in` entries** (`data/logs/2026/09/28/round-21.51.58/runtime.log`).
- **17 recordings** (nine authored explosion tiers and eight generated rock/heavy-hit tiers) decoded successfully as finite, non-silent audio.
- StrongDMM's Go suite, rendering tests and full-window Drought workflow passed; logs are in its `dst` directory. The real editor workflow checked separate linked maps, camera/zoom retention and paint/undo without saving the maps.
- StrongDMM was restored after its upstream auto-updater overwrote the custom executable. Both desktop copies now match the rebuilt QoL executable. This build blocks upstream update checks and replacement, even when automatic updates were previously enabled. The new protection test and repeated real Drought workflow passed (`dst/qol-restored-build.log`, `dst/qol-restored-ui-tests.log`); its verified binary hash is saved in `dst/qol-restored-sha256.txt`.

The game servers used for verification were temporary and were stopped after checking their results. Listening, the appearance of the HUD/lighting, and balance during normal play still need the numbered manual checks above. No changes were committed or pushed.

The focused DM tests exercise the above state transitions in a running DreamDaemon. Source tests live alongside mining, wielding, terminals, sounds and the hivemind implementation. A compile/test pass does not replace the listening and visual checks above.

To rerun from the repository root:

```powershell
& 'C:\Users\Tiger\Documents\BYOND\bin\dm.exe' ms13_qol_tests.dme
& 'C:\Users\Tiger\Documents\BYOND\bin\DreamDaemon.exe' ms13_qol_tests.dmb 48651 -trusted -close -invisible
```

Use an unused port. The focused server runs its tests and exits; results are in `data/unit_tests.json` and the fresh `data/logs/<date>/round-*/tests.log` and `runtime.log`. This runner creates its own DMB and does not replace the normal game build. Compile `daedalus.dme` for normal play.

## Marker as an SM-like engineering system: proposal only

No SM-style redesign is implemented in this work. The Marker already has a power feed, suppression and containment consequences. A future version could make those systems interact more like an engine operators actively manage:

1. **Variable output with an observable cost.** Replace constant power with adjustable excitation/output. Higher output increases signal strength, local heat and biomass demand, so operators choose a sustainable level.
2. **Separate readings for separate problems.** Expose core stability, field strength, thermal load and biological activity on a terminal, with trends and concrete warnings. A single hidden instability score would make failure feel arbitrary.
3. **Maintainable containment.** Let coolant flow, power isolation and projector coverage each solve a specific failure. Give the control room an independent supply so cutting the engine's output does not also disable emergency controls.
4. **Recoverable escalation.** Progress from dimming/radio noise to hallucinations, tissue growth and containment breaches, with time to reduce excitation, restore cooling or vent energy before the worst event. Repeated corrective action should measurably reverse the trend.
5. **A reward worth operating it for.** Make a well-run Marker valuable enough to justify its staffing and danger, while keeping evacuation/shutdown a valid response. Tune that reward against this map's actual power demand before choosing final numbers.

The first implementation step should be readouts and a small set of controls, followed by one tested feedback loop. Thermal/gas interactions should only be added if they create useful operator decisions.

## 29 September: species-based wildlife and Drought Goldmen

- Den choice no longer overrides the animal's diet, size, noise fear or hostility. Search for species names rather than predator/prey labels; existing type paths remain compatible.
- Hunting considers health, damage, species size and nearby support. Radroaches require an overwhelming advantage; robots are never food, and hellpigs remain very dangerous even injured.
- Test an outmatched animal with an open exit, then with its exits blocked: it should flee, then fight back when cornered. Attacks interrupt healing at its home.
- Drought's five Goldmen jobs now have zero round-start and latejoin slots. The existing Brotherhood and other faction slots were preserved exactly.
- Six focused wildlife/flora checks passed; the normal Drought boot and test run had zero runtime errors. Evidence: `data/wildlife-species-results.json` and `data/logs/2026/09/29/round-wildlife-species-{tests,game}/`. Playable build: `daedalus_updated.dmb`.
