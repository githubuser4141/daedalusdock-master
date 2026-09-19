# Ground vehicle controls and power

Click the driver's seat or its full-size dashboard monitor from inside in non-combat mode.
Buckling into the driver's seat also opens the controls automatically (without duplicating an
already open menu for that user). Nearby passengers can also reach the controls while the driver
is seated, but cannot take an occupied seat. The monitor stays on the cabin tile and follows rotation.
The input menu repeats after toggles;
Drive switches on ignition, attempts a battery-powered start, and buckles you in. Engine toggle
starts/stops without buckling (ignition must already be on). Exit closes the menu; Unbuckle leaves
the seat without applying the brakes. The horn has a one-second cooldown.

Forward/reverse input selects successive speed bands; opposite input brakes, even without power.
Stop immediately sets speed to zero. Stopping the engine (including fuel loss) sheds one speed band
per movement tick until stopped. Releasing the controls or leaving the seat preserves powered momentum.
Brakes mode stops current motion and uses input-only steps, at most one tile per second: release the
key to stop. Normal gear delays are divided by 1.25 across all vehicles for a 25% nominal speed increase.
Turning can reduce speed; an obstacle that survives a ram stops it. Impacts use speed squared and
the actual leading panel's blunt armor, falling back to the frame on exposed edges. Objects and
turfs use their normal integrity/armor/destruction behavior; indestructible terrain stays intact.
This is deliberately arcade physics, not a mass simulation.

Prone/unbuckled mobs are run over instead of repeatedly shoved. Each tile-step over them deals
damage without explicit gibbing. They remain under the floor and cannot stand until uncovered;
dead basic/simple-animal NPCs skip damage processing entirely.
Destroying a frame tile leaves ten scrap-steel sheets; administrative deletion does not create salvage.

Each engine installation includes a non-dense battery housing at the pivot. It contains a standard
high-capacity cell: screwdriver to remove, insert another cell to replace. Ignition enables the
electrical bus; turning it off also stops the engine. Starting costs 100 cell charge. Running engines
burn 0.01 fuel/second at idle plus the existing fuel-per-tile consumption, and charge 20 units/second.
Instruments use 1 unit/second, each enabled cabin light/camera 1, each exterior lamp 2. Autocannons
use 25 units/shot; tank guns 50. Hand-operated machine guns do not need battery power.

M113 and armored truck constructors fit front lamps, a rear work lamp, and side/rear cameras.
The jeep has a headlamp; Civ96 vehicles have paired front/rear lamps. Accessories are independently
damageable exterior images, hidden from the cabin like existing wheels. Exterior lamps have no
local toggle. The driver alone sees through the hull edge carrying an enabled, working camera;
it does not make a physical window or expose occupants to NPC vision. Cameras do not add x-ray
vision through terrain or increase the client's view distance.

Regression checks: `ms13_vehicle_electrical`, `ms13_vehicle_obstacle_impact`, the existing ground
vehicle tests and Civ96 assembly tests under `code/modules/unit_tests/`.
