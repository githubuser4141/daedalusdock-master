# Wildlife and flora mapper guide

This is opt-in. Existing map animals keep their old AI, and existing areas keep their current vegetation unless you add a spawner or enable their flora settings. No maps were edited for this feature. Restart the game with the new build after placing objects.

Den animals use the existing `ms13_can_sleep = FALSE` exclusion from the mob-pack system. They do not borrow pack leaders' targets, receive follower movement orders, or sleep while their den ecology is running. Ordinary hostile mobs keep the existing shared targeting, wakeups and pursuit behaviour; their speed has not been retuned. The combined test runner checks both this boundary and the existing pack coordination tests.

## Wildlife dens

For the ready-made map themes, search StrongDMM for **Drought predator**, **Drought prey**, **Mammoth predator**, or **Mammoth prey**. All paths below start with `/obj/effect/spawner/ms13/wildlife_den/`:

| Region | Predator presets | Prey presets |
|---|---|---|
| Drought | `drought/predator/wolves` (2), `drought/predator/hellpig` (1), `drought/predator/golden_geckos` (2) | `drought/prey/molerats` (4), `drought/prey/pigrats` (3), `drought/prey/radroaches` (5) |
| Mammoth | `mammoth/predator/wolves` (3), `mammoth/predator/yaoguai` (1), `mammoth/predator/ice_geckos` (2) | `mammoth/prey/boars` (3), `mammoth/prey/molerats` (4), `mammoth/prey/pigrats` (4) |

Numbers are the initial living population. The folder types themselves spawn nothing; choose a named leaf subtype. These are mapper spawners/home points, not new visible den artwork. Use the map's rocks, trees and cave scenery around them. Spawn positions must have a short, clear route to the den; animals cannot appear on the other side of an inaccessible wall.

Drought uses smaller, wider-ranging wolf packs, golden geckos, burrowing mammals and insects. Mammoth uses timber-wolf packs, yao guai and the existing ice-gecko variant; its prey forage closer to shelter. Yao guai can hunt woodland boars, while wolves hunt the smaller mammals. Ice geckos also browse plants when small prey is scarce. Pair Drought prey with desert flora, and Mammoth prey with woodland or snow-compatible forage.

Place `/obj/effect/spawner/ms13/wildlife_den` on an accessible floor. It is visible in the editor and invisible in play. Its location is the animals' home; leave room around it for returning animals and corpses.

| Den suffix | Animals | Initial population | Food | Chance to flee a loud noise away from home |
|---|---|---:|---|---:|
| base type | Wolves | 3 | Smaller wildlife | 65% |
| `/hellpig` | Hellpig | 1 | Wildlife and plants | 0% |
| `/yaoguai` | Yao guai | 1 | Smaller wildlife and plants | 10% |
| `/boar` | Boars | 3 | Plants | 40% |
| `/molerat` | Molerats | 3 | Plants | 90% |
| `/gecko` | Geckos | 3 | Insects | 75% |
| `/radroach` | Radroaches | 4 | Plants | 95% |

Mapper variables:

- `animal_type`: an existing `/mob/living/basic/ms13/hostile_animal` subtype. Its health, damage, sounds and butcher drops are preserved.
- `population`: living animals per den, capped at 12. `respawn_delay` defaults to 20 minutes; replacement is gradual.
- `territory_radius`: human exclusion zone, normally 4 tiles; molerats use 2, radroaches 1. A human outside it is ignored unless they injure the animal.
- `patrol_radius`: normally 12 tiles. `leash_radius`: normally 20; animals abandon prey beyond it.
- `retreat_health` / `recover_health`: fractions of max health, default 0.35 / 0.85. `healing_per_second`: 2, only near home and after five seconds without injury.
- `eats_meat`, `eats_plants`, `prey_types`, `animal_size`: diet and predation settings. Animals do not hunt their own species or equal/larger den animals. Humans are never food.
- `meal_interval`: normally five minutes. Hunger starts after a staggered initial delay.
- `noise_flee_chance`: percentage, with a 20-second noise cooldown. Loud sounds and explosions can send an animal away from the sound for 12 seconds; inside its territory it stands its ground. Walls muffle the stimulus. Hearing a sound does not identify its maker as an enemy.

Predators claim a wildlife corpse, grab it using the normal pulling system, return it to the den and spend five seconds feeding. They leave other animals' claimed or player-dragged bodies alone. Plants are grazed over four seconds; forage uses its existing harvested/regrowth state, small foliage can be consumed, and trees lose a meal of foliage without being felled.

Unreachable jobs expire after ten seconds without progress, with a 45-second limit per trip. Failed targets are avoided for 30 seconds. A blocked home route releases carried food and permits local movement before another attempt; animals never chew indestructible scenery to path through it. Death, possession, controller replacement and den deletion release food claims and grabs. Deleting a den leaves peaceful roaming survivors that can still retaliate.

## Regrowing flora

Place one of these editor objects:

| Type under `/obj/effect/spawner/ms13/flora` | Purpose |
|---|---|
| `/single` | One exact planting tile; set `plant_types` to a one-entry list for a specific object. |
| base type | Desert vegetation patch, radius 10, up to 20 managed plants. |
| `/woodland` | Pine trees, shrubs and forage, with wider spacing. |
| `/cave` | Ordinary and glowing mushrooms. |
| `/area` | The containing area, up to 100 managed plants. |

Alternatively set an `/area/ms13` area's `flora_spawner_type` to any flora spawner subtype and `flora_population` to the desired limit. It creates one area-wide controller automatically; the subtype supplies the vegetation list. Null disables this option.

`plant_types` is a list of `/obj/structure/flora` type paths. `radius`, `area_mode`, `max_plants`, `min_spacing`, `regrow_delay_min` and `regrow_delay_max` are editable. Population is capped at 300 per controller; regrowth defaults to 16–24 minutes. Filling a large patch is gradual, with bounded work every 30 seconds. Existing vegetation encountered by the controller counts toward its managed planting limit.

Natural soil is required by default. Roads, sidewalks, ice, water, open space and indoor floors are excluded; machines, structures and mobs block placement. A reserved planting tile waits until construction or another obstruction is removed. For an intentional indoor planter, use `/single` and set `require_soil = FALSE`. No flora is placed on occupied tiles even with this option.

Plants harvested without destroying them already regenerate using their existing timers. These spawners additionally replace removed plants and felled trees at their planting points. Removing a spawner stops replacement but leaves its plants.

## Quick manual checks

1. Place a wolf den, a molerat den and a flora patch in nearby clear terrain. Watch patrols; wait for hunger, or set a wildlife controller's `hungry_at = 0` through VV. Wolves should hunt smaller wildlife, haul the body home and feed. Molerats should graze.
2. Stand outside the territory: wolves should leave you alone. Walk into it, or shoot one from outside: it should defend itself. Leave the leash radius to end pursuit.
3. Injure an animal below its retreat threshold. It should return home, heal after a quiet period, then resume activity.
4. Fire near a wolf away from its den. For a deterministic check, set `noise_flee_chance = 100`; the same setting at zero should prevent flight. A default hellpig never flees noise.
5. Block a route with dense rock or a closed enclosure. After the progress deadline, the animal should release any carried corpse and choose other work or a local escape route; it should retry home later.
6. Harvest forage and fell a managed tree. The forage should regrow normally; the removed tree should return after the spawner's delay. Build on that spot: replacement must wait until it is clear again.
7. Test `/single`, a radius patch and an area profile separately. Check that vegetation stays off roads and built floors and does not spread into neighbouring areas.

Automated checks: compile `ms13_wildlife_tests.dme`, then run its DMB on a spare port. The focused suite covers decisions, real projectile/sound hooks, corpse ownership and cleanup, population replacement, live JPS hauling, grazing, regrowth, construction blocking and area setup/cleanup.

The live route check also guards a shared movement fix: negative additive slowdown on fast animals must never schedule AI steps in the past. `get_movement_delay()` now returns at least one world tick for every AI movement implementation. The broader `ms13_qol_tests.dme` runner includes these checks, spawning all twelve themed presets, and the existing pack-coordination tests alongside the earlier fixes.

Verified on 29 September 2026: the normal build compiled with **0 errors / 17 existing warnings** and the combined test build with **0 errors / 20 existing warnings**. All **22 checks passed**, including the twelve den presets, pack coordination and live hauling around an obstacle. Results: `data/wildlife-final-results.json`; test log: `data/logs/2026/09/29/round-08.54.21/tests.log`. Both that run and the normal game boot (`round-08.54.23`) had zero handled or native runtime errors. Compile logs are `data/wildlife-game-compile.log` and `data/wildlife-qol-compile.log`; normal startup is recorded in `data/wildlife-final-game-startup.log`. The temporary verification servers have stopped. The manual checks above remain useful for judging population, territory and sound-reaction balance on your maps.
