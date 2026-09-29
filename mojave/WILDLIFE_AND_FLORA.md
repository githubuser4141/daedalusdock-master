# Wildlife and flora mapper guide

This is opt-in. Existing map animals keep their old AI, and existing areas keep their current vegetation unless you add a spawner or enable their flora settings. No maps were edited for this feature. Restart the game with the new build after placing objects.

Den animals use the existing `ms13_can_sleep = FALSE` exclusion from the mob-pack system. They do not borrow pack leaders' targets, receive follower movement orders, or sleep while their den ecology is running. Ordinary hostile mobs keep the existing shared targeting, wakeups and pursuit behaviour; their speed has not been retuned. The combined test runner checks both this boundary and the existing pack coordination tests.

## Wildlife dens

Search StrongDMM for **Drought den**, **Mammoth den**, or an animal's name. Dens determine population, home and territory; the animal's own species determines diet, size, fear and hostility. There are no passive prey variants. All paths below start with `/obj/effect/spawner/ms13/wildlife_den/`.

The existing regional type paths still contain `predator` or `prey` for compatibility with placed objects. Those folders do not assign a combat role. Drought offers wolves (2), hellpig (1), golden geckos (2), molerats (4), pigrats (3), and radroaches (5). Mammoth offers wolves (3), yao guai (1), ice geckos (2), boars (3), molerats (4), and pigrats (4). The bare region/category folders spawn nothing. These are invisible home points; use existing rocks, trees and caves for den scenery.

Use **`custom`** and set `animal_type`, or use **`drought/random`** / **`mammoth/random`**. A regional random den picks one species at round start and keeps it for replacements; `animal_pool` is a weighted list. Any named den can also change `animal_type` without carrying over the old species' diet or fear. Custom dens accept `/mob/living/basic` subtypes; legacy `/simple_animal` paths require a basic-mob counterpart. Spawn positions require a short, clear route to the den.

Additional ready-made dens (under the same prefix):

| Suffix | Residents |
|---|---|
| `ants` | Giant ants, 5 |
| `scorpions`, `scorpions/bark` | Radscorpions or bark scorpions, 2; retain their venom |
| `mantises`, `mirelurks` | Mantises, 3; mirelurks, 2 |
| `ghouls`, `ghouls/frozen`, `ghouls/glowing` | Ferals, frozen ferals, or glowing ferals |
| `robots`, `robots/saw`, `robots/gutsy` | Two Handies, saw Handies, or armed Gutsies |

Ghouls and robots remain hostile to people within their leash by default (`wildlife_hostile_to_people = TRUE` on the mob). Robots do not eat or flee from noise, and Gutsies use ranged attacks. They return to their home for recovery. These are opt-in den controllers; existing placed mobs keep their original combat/pack AI.

Drought uses smaller, wider-ranging wolf packs, golden geckos, burrowing mammals and insects. Mammoth uses timber-wolf packs, yao guai and the existing ice-gecko variant; its smaller herbivores forage closer to shelter. Yao guai can hunt woodland boars, while wolves hunt the smaller mammals. Ice geckos also browse plants when small prey is scarce. Pair Drought dens with desert flora, and Mammoth dens with woodland or snow-compatible forage.

Place `/obj/effect/spawner/ms13/wildlife_den` on an accessible floor. It is visible in the editor and invisible in play. Its location is the animals' home; leave room around it for returning animals and corpses.

| Den suffix | Animals | Initial population | Food | Chance to flee a loud noise away from home |
|---|---|---:|---|---:|
| base type | Wolves | 3 | Smaller wildlife | 65% |
| `/hellpig` | Hellpig | 1 | Wildlife and plants | 0% |
| `/yaoguai` | Yao guai | 1 | Smaller wildlife and plants | 10% |
| `/boar` | Boars | 3 | Plants | 40% |
| `/molerat` | Molerats | 3 | Plants | 90% |
| `/gecko` | Geckos | 3 | Weaker wildlife | 75% |
| `/radroach` | Radroaches | 4 | Plants, carrion; live hunting only with an overwhelming advantage | 95% |

Mapper variables:

- `animal_type`: an existing `/mob/living/basic` subtype. Its health, damage, sounds and butcher drops are preserved. Diet and temperament follow the chosen species regardless of den type.
- `population`: living animals per den, capped at 12. `respawn_delay` defaults to 20 minutes; replacement is gradual.
- `territory_radius`: human exclusion zone, normally 4 tiles; molerats use 2, radroaches 1. A human outside it is ignored unless they injure the animal.
- `patrol_radius`: normally 12 tiles. `leash_radius`: normally 20; animals abandon prey beyond it.
- `retreat_health` / `recover_health`: fractions of max health, default 0.35 / 0.85. `healing_per_second`: 2, only near home and after five seconds without injury.
- Species variables live on the **mob**, not the den: `wildlife_eats_meat`, `wildlife_eats_plants`, `wildlife_size`, `wildlife_hunt_ratio`, `wildlife_noise_flee_chance`, `wildlife_hostile_to_people`. No den variable reclassifies a species as predator or prey. Robots, humans and humanoids are never food; members of the same species or den are not hunted.
- `meal_interval`: normally five minutes. Hunger starts after a staggered initial delay.
- The mob's `wildlife_noise_flee_chance` is a percentage, with a 20-second noise cooldown. Loud sounds and explosions can send an animal away from the sound for 12 seconds; inside its territory it stands its ground. Walls muffle the stimulus. Hearing a sound does not identify its maker as an enemy.

Predators claim a wildlife corpse, grab it using the normal pulling system, return it to the den and spend five seconds feeding. They leave other animals' claimed or player-dragged bodies alone. Plants are grazed over four seconds; forage uses its existing harvested/regrowth state, small foliage can be consumed, and trees lose a meal of foliage without being felled.

Hunting requires a strength advantage, based on species size, current health and melee damage. Injured animals retain at least half their estimated threat. Visible, alert den animals above their retreat threshold of the same species within three tiles contribute half strength if they can reach the fight; this does not issue pack movement or targeting orders. Hunters normally require 1.5 times the opposition's strength; radroaches require three times. A lone radroach usually grazes or scavenges; overwhelming local numbers can make small live prey viable. Hellpigs' size and combat stats make them exceptionally dangerous prey. This is a risk estimate, not a promised combat outcome or a fixed 90% roll.

Attacked animals flee if injured or outmatched, and defend themselves when cornered. Immediate danger interrupts eating, noise panic and healing at home. A fresh attack clears stale avoidance of that attacker. Diet never blocks retaliation. Escape checks reachable adjacent exits and moves onto the chosen tile before choosing another; it does not stop 'close enough' without moving or pause to rest after each step.

Outside urgent danger and injury recovery, food opportunities compete by hunger, distance and the prey's remaining health. Current work receives a small preference to avoid constant switching, but an easier meal can interrupt it. Omnivores can choose nearby plants over a risky hunt; nearby carcasses can take precedence over grazing. Idle animals sometimes pause instead of constantly patrolling. Job timeouts and failed-route recovery still apply to every choice.

Unreachable jobs expire after ten seconds without progress, with a 45-second limit per trip. Failed targets are avoided for 30 seconds. A blocked home route releases carried food and permits local movement before another attempt; animals never chew indestructible scenery to path through it. Death, possession, controller replacement and den deletion release food claims and grabs. Deleting a den leaves peaceful roaming survivors that can still retaliate.

Radroaches (including glowroaches and legacy placed radroaches) can slip under closed ordinary Mojave doors, including locked ones and ordinary doors fitted with motors, and manual mineral/CDDA doors. Sealed mechanical airlocks, shutters and blast doors remain barriers while closed. Their pathfinding uses the same rule as physical movement; other animals do not gain this ability. This applies to ordinary map radroaches as well as den wildlife.

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
4. Fire near a wolf away from its den. For a deterministic check, set the mob's `wildlife_noise_flee_chance = 100`; the same setting at zero should prevent flight. A default hellpig never flees noise.
5. Block a route with dense rock or a closed enclosure. After the progress deadline, the animal should release any carried corpse and choose other work or a local escape route; it should retry home later.
6. Harvest forage and fell a managed tree. The forage should regrow normally; the removed tree should return after the spawner's delay. Build on that spot: replacement must wait until it is clear again.
7. Test `/single`, a radius patch and an area profile separately. Check that vegetation stays off roads and built floors and does not spread into neighbouring areas.

Automated checks: compile `ms13_wildlife_tests.dme`, then run its DMB on a spare port. The focused suite covers decisions, real projectile/sound hooks, corpse ownership and cleanup, population replacement, live JPS hauling, grazing, regrowth, construction blocking and area setup/cleanup.

The live route check also guards a shared movement fix: negative additive slowdown on fast animals must never schedule AI steps in the past. `get_movement_delay()` now returns at least one world tick for every AI movement implementation. The broader `ms13_qol_tests.dme` runner includes the den presets and existing pack-coordination tests alongside the earlier fixes. The opportunity check is `/datum/unit_test/ms13_wildlife_opportunities`.

Verified on 29 September 2026: the normal build compiled with **0 errors / 17 existing warnings** and the combined test build with **0 errors / 20 existing warnings**. All **22 checks passed**, including the twelve den presets, pack coordination and live hauling around an obstacle. Results: `data/wildlife-final-results.json`; test log: `data/logs/2026/09/29/round-08.54.21/tests.log`. Both that run and the normal game boot (`round-08.54.23`) had zero handled or native runtime errors. Compile logs are `data/wildlife-game-compile.log` and `data/wildlife-qol-compile.log`; normal startup is recorded in `data/wildlife-final-game-startup.log`. The temporary verification servers have stopped. The manual checks above remain useful for judging population, territory and sound-reaction balance on your maps.


Flexible-den follow-up verification (29 September): **17 combined checks passed**, including pack coordination, followed by **five focused wildlife/flora checks** after the final size-override correction. The presets check now spawns all **25 named/regional choices**. New checks cover trait inheritance, mapper size overrides, choosing plants before a risky hunt, switching to an easy carcass, ranged robot behaviour, retaliation and scorpion venom. Results: `data/rail-hive-dens-combined-results.json` and `data/den-traits-final-results.json`. The final playable build is `daedalus_updated.dmb` with its matching RSC in the repository root; normal compile and boot passed with zero errors/runtimes. The usual output was locked by the running game.

Species-based follow-up (29 September, 12:36): all **six focused wildlife/flora checks passed**, including live escape movement, injured/cornered defence at the den, fresh-damage recovery from ignored targets, robot exclusion, hellpig risk and radroach numerical advantage. Normal and test builds compiled with **0 errors** (17 and 20 existing warnings). Both fresh boots had **zero handled/native runtime errors**. Results: `data/wildlife-species-results.json`; logs: `data/logs/2026/09/29/round-wildlife-species-tests/` and `round-wildlife-species-game/`. The playable output is `daedalus_updated.dmb` with its matching RSC. Verification servers have stopped.

To check the new behaviour in game, place the same scorpion species using any den preset: it should retain the same diet and temperament. A lone radroach should avoid a stronger attacker when it has an exit; box it in and it should fight back, even injured at home. Crowds of nearby, fit radroaches can consider weaker prey that a single roach avoids. Robots remain inedible. These are strength-based decisions, not random predator/prey assignments.
