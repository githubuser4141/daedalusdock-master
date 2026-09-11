// This file contains all the math + data structures used for realistic ricochets and any procs / overrides needed

#define BM_LINE(sx,sy,ex,ey) list(sx,sy,ex,ey)
#define INDICE_STARTX 1
#define INDICE_STARTY 2
#define INDICE_ENDX 3
#define INDICE_ENDY 4
#define DIR_N "1"
#define DIR_E "2"
#define DIR_S "4"
#define DIR_W "8"

/datum/hitbox
	var/list/hitboxLines = list()
	var/datum/weakref/parentRef

/datum/hitbox/New(atom/parent)
	parentRef = parent.create_weakref()

/datum/hitbox/proc/getRelevantLines(atom/parent, list/incoming)
	return hitboxLines

// wx , wy and angle are pointer outputs.
/datum/hitbox/proc/getPointOfCollision(list/incoming, wx, wy, angle)
	var/atom/parent = parentRef.resolve()
	if(parent == null)
		return 0
	var/xTranslation = (parent.x - 1) * 32
	var/yTranslation = (parent.y - 1) * 32
	var/list/collisions = list()
	for (var/list/line in getRelevantLines(parent, incoming))
		line[INDICE_STARTX] += xTranslation
		line[INDICE_ENDX] += xTranslation
		line[INDICE_STARTY] += yTranslation
		line[INDICE_ENDY] += yTranslation

		/*---------------------------------------
		* 1.  Intersection test                *
		*--------------------------------------*/

		var/denominator = ((incoming[INDICE_ENDY] - incoming[INDICE_STARTY]) * (line[INDICE_ENDX] - line[INDICE_STARTX]) \
			             - (incoming[INDICE_ENDX] - incoming[INDICE_STARTX]) * (line[INDICE_ENDY] - line[INDICE_STARTY]))

		if (!denominator) // lines are parallel or degenerate
			goto resetLine

		var/firstRatio  = ((incoming[INDICE_ENDX] - incoming[INDICE_STARTX]) * (line[INDICE_STARTY] - incoming[INDICE_STARTY]) \
			             - (incoming[INDICE_ENDY] - incoming[INDICE_STARTY]) * (line[INDICE_STARTX] - incoming[INDICE_STARTX])) / denominator
		var/secondRatio = ((line[INDICE_ENDX]   - line[INDICE_STARTX])       * (line[INDICE_STARTY] - incoming[INDICE_STARTY]) \
			             - (line[INDICE_ENDY]   - line[INDICE_STARTY])       * (line[INDICE_STARTX] - incoming[INDICE_STARTX])) / denominator

		// ensure bullet is actually in our segment.
		if (firstRatio >= 0 && firstRatio <= 1 && secondRatio >= 0 && secondRatio <= 1)
			var/lx = line[INDICE_STARTX] + firstRatio * (line[INDICE_ENDX] - line[INDICE_STARTX])
			var/ly = line[INDICE_STARTY] + firstRatio * (line[INDICE_ENDY] - line[INDICE_STARTY])
			var/deltaLineX = (incoming[INDICE_ENDX] - incoming[INDICE_STARTX])
			var/deltaLineY = (incoming[INDICE_ENDY] - incoming[INDICE_STARTY])
			var/deltaWallX = (line[INDICE_ENDX] - line[INDICE_STARTX])
			var/deltaWallY = (line[INDICE_ENDY] - line[INDICE_STARTY])
			var/dot = deltaLineX * deltaWallX + deltaLineY* deltaWallY
			var/relativeangle = -arctan(dot, deltaLineX * deltaWallY - deltaLineY * deltaWallX) * sign(dot)
			if(relativeangle > 90)
				relativeangle = 180 - relativeangle
			collisions += 0
			collisions[length(collisions)] = list(lx,ly,relativeangle,(incoming[INDICE_STARTX] - lx)**2 + (incoming[INDICE_STARTY] - ly)**2)

		resetLine:
		line[INDICE_STARTX] -= xTranslation
		line[INDICE_ENDX] -= xTranslation
		line[INDICE_STARTY] -= yTranslation
		line[INDICE_ENDY] -= yTranslation

	for(var/i = 1 to length(collisions)-1)
		if(collisions[i][4] > collisions[i+1][4])
			var/temp = collisions[i+1]
			collisions[i+1] = collisions[i]
			collisions[i] = temp
			if(i > 1) i--

	//  No edge intersected the incoming line
	if(length(collisions))
		*wx = collisions[1][1]
		*wy = collisions[1][2]
		*angle = collisions[1][3]
	return length(collisions) == 0

/datum/hitbox/directional
	hitboxLines = list(
		DIR_N = list(
			BM_LINE(0,0,0,32),
			BM_LINE(0,32,32,32),
			BM_LINE(32,32,32,0),
			BM_LINE(32,0,0,0),
		),
		DIR_E = list(
			BM_LINE(0,0,0,32),
			BM_LINE(0,32,32,32),
			BM_LINE(32,32,32,0),
			BM_LINE(32,0,0,0),
		),
		DIR_S = list(
			BM_LINE(0,0,0,32),
			BM_LINE(0,32,32,32),
			BM_LINE(32,32,32,0),
			BM_LINE(32,0,0,0),
		),
		DIR_W = list(
			BM_LINE(0,0,0,32),
			BM_LINE(0,32,32,32),
			BM_LINE(32,32,32,0),
			BM_LINE(32,0,0,0),
		),
	)

/datum/hitbox/directional/getRelevantLines(atom/parent, list/incoming)
	return hitboxLines["[parent.dir]"]

/atom
	var/datum/hitbox/atomHitbox = null
	// the lower clamp for bullet damage. This is reached when the bullet
	// has a lot of penetration power against this
	var/minimumBulletOverpenThreshold = 0.1
	// The threshold reached when the bullet has little penetration power
	// against this
	var/maximumBulletOverpenThreshld = 1
	// AI EDIT: was a plain "var/bIntegrity = 100" - a second, disconnected integrity number that never
	// matched what the atom's real health/damage system (atom_integrity/max_integrity, code/game/atom/
	// atoms.dm) showed or did, even for things that DO track real integrity (most /obj/structure and /obj/
	// machinery). Replaced with getBIntegrity()/setBIntegrity()/getBIntegrityMax() below - they read/write
	// through to atom_integrity when the atom actually uses_integrity (so shooting a structure/machine
	// enough now really damages and can break it through DD's own system, not just a hidden number), and
	// fall back to this standalone var otherwise - which covers both the bullet itself (a projectile never
	// sets uses_integrity) and walls (this codebase's walls don't use atom_integrity at all - they're
	// dismantled/broken through a separate mechanic).
	var/standalone_bIntegrity = 100

/// See standalone_bIntegrity above.
/atom/proc/getBIntegrity()
	if(uses_integrity)
		return atom_integrity
	return standalone_bIntegrity

/// See standalone_bIntegrity above.
/atom/proc/getBIntegrityMax()
	if(uses_integrity)
		return max_integrity
	return 100

/// See standalone_bIntegrity above. Goes through the real update_integrity() (damage overlays, breaking,
/// etc) when the atom uses_integrity, so this now has real, visible consequences instead of silently
/// tracking a number nothing else ever reads.
/atom/proc/setBIntegrity(value)
	if(uses_integrity)
		update_integrity(clamp(value, 0, max_integrity))
	else
		standalone_bIntegrity = clamp(value, 0, 100)

/turf
	var/wallIntegrity = 100

// AI EDIT: this used to also override /atom/New() (plus a bare "/atom \n atomHitbox = /datum/hitbox/standardWall"
// initializer), giving EVERY atom in the game a hitbox - mobs included. Since Impact() below diverts any hit on
// an atom with atomHitbox straight into this wall-integrity ricochet/frag/overpen math and often return TRUE
// before ever reaching the normal bullet_act()/apply_damage() path, that meant shooting a PLAYER could silently
// resolve as a "wall" hit and deal zero real damage - this matches the original bug report ("bullets... cleanly
// went through everything without doing damage") almost exactly. Scoped to walls plus other solid /obj/structure
// and /obj/machinery below (per request - "a lot of other objects" should get this), explicitly excluding mobs
// and the projectile itself.
/turf/closed/wall/New()
	. = ..()
	atomHitbox = new /datum/hitbox/standardWall(src)

/obj/structure/New()
	. = ..()
	if(!atomHitbox)
		atomHitbox = new /datum/hitbox/standardWall(src)

/obj/machinery/New()
	. = ..()
	if(!atomHitbox)
		atomHitbox = new /datum/hitbox/standardWall(src)

/datum/hitbox/standardWall
	hitboxLines = list(
		BM_LINE(0,0,0,32),
		BM_LINE(0,32,32,32),
		BM_LINE(32,32,32,0),
		BM_LINE(32,0,0,0),
	)
// stores a angle in simple 0 - 360 for maths
// always counter clockwise!!
/datum/worldAngle
	var/angle = 0

/datum/worldAngle/proc/reduce()
	angle = angle % 360

/datum/worldAngle/proc/fromAny(originalAngle)
	// AI EDIT: tempAngle was computed but never used - angle was set straight from the unreduced
	// originalAngle, so anything outside -360..360 (or exactly 0) didn't land in 0-360 at all.
	var/tempAngle = originalAngle % 360
	if(tempAngle < 0)
		tempAngle += 360 // DM's % can return negative results for a negative left operand
	angle = (360 - tempAngle) % 360

/// BulletTipType defines
// AI EDIT: was 1>>N (right-shift) for all five - right-shifting 1 by anything >=1 gives 0, so
// ROUNDED/ULTRASHARP/FRAGMENTED/FLAT all evaluated to the same value (0) and collided as the same
// key in every GLOBAL_LIST_INIT below. Needed 1<<N (left-shift) to actually produce distinct bitflags.
// Rifle grade sharp
#define BULLET_SHARP 1<<0
// Riot control
#define BULLET_ROUNDED 1<<1
// Very sharp. Tank Ammunition grade
#define BULLET_ULTRASHARP 1<<2
// Fragmented bullet tip, unpredictable performance.
#define BULLET_FRAGMENTED 1<<3
// A flat bullet head
#define BULLET_FLAT 1<<4

GLOBAL_LIST_INIT(bulletStandardRicochetAngles, list(
	"[BULLET_SHARP]" = 18,
	"[BULLET_ROUNDED]" = 35,
	"[BULLET_ULTRASHARP]" = 9,
	"[BULLET_FRAGMENTED]" = 20,
	"[BULLET_FLAT]" = 10 // much more likely to fragment instead.
))
// This is taken from the bullet Speed var. The differenc su sed to apply maluses/modifications to ricochet angle
#define BULLET_SPEED_BASELINE 1
// Minimum bullet speed , anything above this gets deleted
#define BULLET_SPEED_MINIMUM 0.3
// A increase/decrease in ricochet/fragment angles wheter the bullet is going slower/faster than the baseline. This is applied for every 0.1 unit of speed
GLOBAL_LIST_INIT(bulletSpeedAngleMalus, list(
	"[BULLET_SHARP]" = 2,
	"[BULLET_ROUNDED]" = 1,
	"[BULLET_ULTRASHARP]" = 3,
	"[BULLET_FRAGMENTED]" = 5,
	"[BULLET_FLAT]" = 5
))

// left-value is minimum , right angle is maximum
GLOBAL_LIST_INIT(bulletStandardFragmentAngles, list(
	"[BULLET_SHARP]" = list(60, 90),
	"[BULLET_ROUNDED]" = list(50, 90),
	"[BULLET_ULTRASHARP]" = list(80, 90),
	// no fragmentation of the fragmentation pls
	"[BULLET_FRAGMENTED]" = list(180, 180),
	"[BULLET_FLAT]" = list(50, 90)
))
// increases or decreases how much bullet integrity is lost
#define BULLET_INTEGRITYLOSSMULT 1
#define BULLET_INTEGRITYLOSS_RICOCHET 20 * BULLET_INTEGRITYLOSSMULT
#define BULLET_INTEGRITYLOSS_FRAGMENT 50 * BULLET_INTEGRITYLOSSMULT
/// Base integrity cost of hitting an organ (mojave/code/modules/mob/living/carbon/human/
/// bullet_penetration.dm), scaled by that hit's rigidity - hitting bone costs more integrity than a clean
/// pass, same idea as ricochet (20) and fragmenting (50) above but lighter, since a body isn't as abrupt a
/// stop as a wall.
#define MS13_BULLET_ORGAN_INTEGRITY_LOSS_BASE 15
/// Bullet Malus defines for fragmenting or expanding


// Begin Bullet Armors

#define BUCKSHOT list(BLUNT = 0, PUNCTURE = 100, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
#define SLUG list(BLUNT = 0, PUNCTURE = 75, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

#define SOFTPOINT_RIFLE list(BLUNT = 0, PUNCTURE = 35, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
#define SOFTPOINT_PISTOL list(BLUNT = 0, PUNCTURE = 50, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

#define FMJ_RIFLE list(BLUNT = 0, PUNCTURE = 50, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
#define FMJ_PISTOL list(BLUNT = 0, PUNCTURE = 60, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

#define HP_PISTOL list(BLUNT = 0, PUNCTURE = 40, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
#define HP_RIFLE list(BLUNT = 0, PUNCTURE = 50, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

#define HIGH_CAL_RIFLE list(BLUNT = 0, PUNCTURE = 120, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
#define HIGH_CAL_PISTOL list(BLUNT = 0, PUNCTURE = 150, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

#define GIANT_CAL_RIFLE list(BLUNT = 0, PUNCTURE = 200, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
#define GIANT_CAL_PISTOL list(BLUNT = 0, PUNCTURE = 230, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

#define AP_PISTOL list(BLUNT = 0, PUNCTURE = 130, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
#define AP_RIFLE list(BLUNT = 0, PUNCTURE = 100, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

#define HIGH_CAL_AP_PISTOL list(BLUNT = 0, PUNCTURE = 200, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)
#define HIGH_CAL_AP_RIFLE list(BLUNT = 0, PUNCTURE = 250, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

#define ANTI_MATERIEL list(BLUNT = 0, PUNCTURE = 350, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

// End Bullet Armors

// Begin Bullet Damages

#define SLUG_DAMAGE 80

#define SMALL_RIFLE_DAMAGE 35
#define MED_RIFLE_DAMAGE 60
#define BIG_RIFLE_DAMAGE 80

#define COMPACTPISTOL_DAMAGE 20
#define PISTOL_DAMAGE 30
#define MAGNUM_DAMAGE 50
#define GIANT_PISTOL_DAMAGE 70

#define GIANT_RIFLE_DAMAGE 100
#define ANTI_MATERIEL_RIFLE_DAMAGE 150
#define RAILGUN_DAMAGE 200

// End Bullet Damages


#define BULLET_FRAGMENT_MAXANGLEVARIATION  10
#define BULLET_FRAGMENT_SPEEDMALUS 0.1
#define BULLET_FRAGMENT_SPAWNCOUNT 8
/// A fragment computing below this much damage doesn't get spawned at all - see fragmentTowards() below.
#define BULLET_FRAGMENT_MIN_DAMAGE 1

#define BULLET_EXPAND_SPEEDMALUS 0.05

/// Mob overpenetration (mojave/code/modules/mob/living/carbon/human/bullet_penetration.dm) - fraction of a
/// bullet's damage that stays in the body vs continues through as leftover damage, by what internal
/// structure absorbed the hit. Denser structures transfer MORE, not less - they decelerate/deform the round
/// instead of letting it pass through. Shares get_own_hardness_ratio() below with wall overpenetration
/// (wall_integrity.dm) so the same round's construction matters consistently against either.
#define MS13_BULLET_TRANSFER_BONE 0.85
#define MS13_BULLET_TRANSFER_ORGAN 0.6
#define MS13_BULLET_TRANSFER_MUSCLE 0.5
#define MS13_BULLET_TRANSFER_VESSEL 0.4
#define MS13_BULLET_TRANSFER_CLEAN 0.3
/// What every structure's transfer fraction converges toward at low speed - a slow-moving round gets stopped
/// by almost anything in its path, dense or soft, so the structures stop mattering much. Speed then SPREADS
/// fractions apart from this point (not a uniform multiplier): a fast round makes bone transfer even MORE
/// (violent fragmentation) while soft tissue transfers even LESS (clean pass-through) - see
/// get_bullet_transfer_fraction() for the actual interpolation.
#define MS13_BULLET_TRANSFER_CONVERGENCE 0.55
/// Clamp on the spread factor - P.speed is a delay-per-tile (lower = faster), so the ratio used is
/// initial(P.speed)/P.speed. 1 = exactly the baseline MS13_BULLET_TRANSFER_* fractions above; below 1
/// compresses every structure toward MS13_BULLET_TRANSFER_CONVERGENCE, above 1 spreads them further apart.
#define MS13_BULLET_SPEED_SPREAD_MIN 0.4
#define MS13_BULLET_SPEED_SPREAD_MAX 1.8
/// The bullet's own construction, from two signals: bulletTipType (shape) and its own armor rating
/// (bulletArmorType via returnArmor()) - that rating represents the bullet's OWN toughness against
/// deforming/fragmenting on impact, not its ability to defeat a target's armor. Combined into one
/// hardness_ratio that DIVIDES the transfer fraction - a tougher round holds together and punches through
/// more (divides down), one that deforms/fragments easily dumps more energy instead (divides up, i.e. < 1).
GLOBAL_LIST_INIT(bulletTipHardness, list(
	"[BULLET_SHARP]" = 1.1,
	"[BULLET_ROUNDED]" = 0.8,
	"[BULLET_ULTRASHARP]" = 1.4,
	"[BULLET_FRAGMENTED]" = 0.5,
	"[BULLET_FLAT]" = 0.7,
))
/// "Neutral" reference toughness rating (FMJ_RIFLE/HP_RIFLE's PUNCTURE value, both 50 above) - a round's own
/// rating divided by this, then sqrt'd (get_bullet_transfer_fraction()), gives its hardness contribution.
/// sqrt because the raw ratings span a 10x range (35 to 350) that would otherwise either clip most tough
/// ammo to the same ceiling, or need a clamp so wide it makes ordinary ammo swing wildly - sqrt compresses
/// that to ~3x while keeping every ammo type distinguishable.
#define MS13_BULLET_HARDNESS_BASELINE 50
#define MS13_BULLET_HARDNESS_MIN 0.5
#define MS13_BULLET_HARDNESS_MAX 2.7
/// Splash: fraction of transferred_amount up for grabs by nearby organs (carved out of, not added to, the
/// struck organ's own share), and a multiplier on bullet_cross_section for the per-organ splash chance.
#define MS13_BULLET_SPLASH_SHARE 0.15
#define MS13_BULLET_SPLASH_CHANCE_MULT 60
/// Below this much leftover damage, the bullet just stops - not worth continuing as an overpenetration hit.
#define MS13_BULLET_OVERPEN_MIN_REMAINING 10

/// Wall overpenetration (mojave/code/game/turfs/wall_integrity.dm) - baseline fraction of a bullet's damage
/// that transfers into a "neutral" wall (same armor rating as MS13_BULLET_HARDNESS_BASELINE) before the
/// wall's own armor and the bullet's own construction (get_own_hardness_ratio()) adjust it. A tougher wall
/// pushes this UP (stops more of the round); a tougher/harder bullet divides it back DOWN (punches through).
#define MS13_WALL_BULLET_TRANSFER_BASE 0.5
#define MS13_WALL_BULLET_TRANSFER_MIN 0.1

#define BULLET_SPEED_SLOWER -0.05
#define BULLET_SPEED_PISTOL -0.1
#define BULLET_SPEED_MAGNUM -0.2
#define BULLET_SPEED_SMG -0.3
#define BULLET_SPEED_RIFLE -0.4
#define BULLET_SPEED_RIFLE_VFAST -0.5
#define BULLET_SPEED_INSANE -0.6
#define BULLET_SPEED_RAILGUN -0.8

#define BULLET_SPEED_SLOWED 0.1
#define BULLET_SPEED_SNAIL 0.4

// threshold at which bullet is too SLOW and should be deleted
#define BULLET_THRESHOLD_TOOSLOW 2

// AI EDIT: was BULLET_SPEED_INSANE (-0.5) - that's a per-gun tuning value, not a sane server-wide
// default. Since this var lives on the base /obj/item/gun and gets added to every fired projectile's
// speed in _firing.dm, defaulting it to a nonzero delta would slow down every gun in the entire game,
// including vanilla DD weapons that were never balanced against this system. 0 = no-op unless a specific
// gun opts in.
/obj/item/gun
	var/speedValueMod = 0

TYPEINFO_DEF(/obj/projectile)
	default_armor = list(BLUNT = 0, PUNCTURE = 50, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)


/obj/projectile
	var/speedLossPerTile = 0.1
	var/bulletTipType = BULLET_SHARP
	var/bulletArmorType = PUNCTURE
	var/canRicochet = TRUE
	var/canFragment = TRUE

/// The bullet's own toughness against deforming/fragmenting on impact - shared by the mob overpenetration
/// system (bullet_penetration.dm) and wall overpenetration (wall_integrity.dm) so the same round behaves
/// consistently against either. >1 = holds together, punches through more; <1 = deforms/dumps energy instead.
/obj/projectile/proc/get_own_hardness_ratio()
	var/tip_hardness = GLOB.bulletTipHardness["[bulletTipType]"] || 1
	var/datum/armor/bullet_armor = returnArmor()
	var/rating_hardness = (bullet_armor && bulletArmorType) ? clamp(sqrt(bullet_armor.vars[bulletArmorType] / MS13_BULLET_HARDNESS_BASELINE), MS13_BULLET_HARDNESS_MIN, MS13_BULLET_HARDNESS_MAX) : 1
	var/integrity_ratio = getBIntegrity() / getBIntegrityMax()
	return clamp(tip_hardness * rating_hardness * integrity_ratio, MS13_BULLET_HARDNESS_MIN, MS13_BULLET_HARDNESS_MAX)

// returns a exponential multiplier for calculations.
// AI EDIT: param was typed turf/closed/wall - now that /obj/structure and /obj/machinery also carry a
// hitbox (see /turf/closed/wall/New() above), a non-wall atom passed here would get silently coerced to
// null by DM's typed-param check, crashing target.bIntegrity below. Loosened to atom.
/obj/projectile/proc/getRelativeArmorRatingMultiplier(atom/target, datum/armor/targetArmor, datum/armor/bulletArmor)
	if(targetArmor == null || bulletArmor == null || bulletArmorType == "")
		return 0
	var/ratingDiff = (bulletArmor.vars[bulletArmorType] * getBIntegrity() / getBIntegrityMax()) * initial(speed) / speed - targetArmor.vars[bulletArmorType] * target.getBIntegrity() / target.getBIntegrityMax()
//message_admins("relative armor returning [ratingDiff / bulletArmor.vars[damage_type]]")
	return (ratingDiff+0.001) / bulletArmor.vars[bulletArmorType]

/obj/projectile/proc/fragmentTowards(atom/lastHit, fragmentCount, fragmentAngle, maxDeviation, fullLoopPossible)
	// AI EDIT: was "0 to fragmentCount" (off-by-one, fragmentCount+1 fragments) and fired every fragment
	// unconditionally - adjustIntegrity() below can qdel a fragment that inherited low bIntegrity from an
	// already-battered parent bullet, and calling .fire() on that qdeleted object right after was the
	// "Illegal forceMove()"/"Cannot read null.x"/qdeleted-datum crash spam. Root cause: every fragment
	// inherits THIS bullet's current (possibly already-depleted) bIntegrity, so a bullet that's already
	// spent most of its integrity ricocheting/overpenetrating would spawn a whole batch of fragments that
	// are all dead on arrival. bIntegrity doesn't change across this loop, so one check up front covers the
	// whole batch - don't bother fragmenting at all if there isn't enough integrity left for even one
	// fragment to survive being created. The per-fragment QDELETED check stays as a cheap backstop.
	if(getBIntegrity() <= BULLET_INTEGRITYLOSS_FRAGMENT)
		return
	// AI EDIT: fragment damage is a flat 20% of the parent's - a fragment that itself fragmented (before
	// canFragment=FALSE below existed) kept losing another 80% each generation, cascading into a fast-growing
	// swarm of 8x-per-hit projectiles doing next to nothing. Skip spawning entirely once that 20% would round
	// under BULLET_FRAGMENT_MIN_DAMAGE - there's no point creating, moving, and hit-testing a bullet that
	// can't deal a mark of damage.
	var/fragment_damage = damage * 0.2
	if(fragment_damage < BULLET_FRAGMENT_MIN_DAMAGE)
		return
	for(var/i = 1 to fragmentCount)
		var/obj/projectile/projectile = new /obj/projectile/bullet(get_turf(lastHit))
		projectile.setBIntegrity(getBIntegrity())
		projectile.speed = speed
		projectile.firer = src
		projectile.fired_from = lastHit
		projectile.impacted = list(lastHit)
		// AI EDIT: a fragment used to spawn as a plain /obj/projectile/bullet, which defaults canFragment to
		// TRUE - hitting another wall at the right angle let it fragment AGAIN, and each of its 8 children
		// could too, exponentially. "no fragmentation of the fragmentation" per this file's own
		// bulletStandardFragmentAngles comment - now actually enforced.
		projectile.canFragment = FALSE
		projectile.preparePixelProjectile(get_turf_in_angle(fragmentAngle, lastHit, 2), src)
		projectile.adjustSpeed(-BULLET_FRAGMENT_SPEEDMALUS)
		projectile.adjustIntegrity(-BULLET_INTEGRITYLOSS_FRAGMENT)
		if(QDELETED(projectile))
			continue
		projectile.damage = fragment_damage
		projectile.damage_type = damage_type
		projectile.fire(fragmentAngle + rand(0, maxDeviation) * sign(rand(-1,1)) + (fullLoopPossible ? rand(-1,1) > 0 : 0) * 180)

/obj/projectile/proc/adjustIntegrity(value)
	var/old_integrity = getBIntegrity()
	setBIntegrity(max(getBIntegrity() + value, 0))
	if(getBIntegrity() == 0)
		qdel(src)
		return
	// AI EDIT: a damaged bullet is less stable in flight and burns through its remaining potential faster -
	// modeled as less range left, not simulated drag/atmos. Proportional cut so this applies retroactively to
	// every existing integrity-loss source (ricochet, fragment, and mojave's organ-hit loss) for free.
	if(value < 0 && old_integrity > 0)
		range = round(range * (getBIntegrity() / old_integrity))

/obj/projectile/proc/adjustSpeed(value)
	speed = max(speed - value, 0.1)
	if(speed > BULLET_THRESHOLD_TOOSLOW)
		qdel(src)


// You can balance these by going to their wikipedia page and checking how much kinetic energy they have for the bullet(for how much the should pen)

// enough to go through 3-4 walls.
TYPEINFO_DEF(/obj/projectile/bullet/bmg50)
	default_armor = list(BLUNT = 0, PUNCTURE = 350, SLASH = 0, LASER = 0, ENERGY = 0 , BOMB = 0, BIO = 0, FIRE = 0, ACID = 0)

/obj/projectile/bullet/bmg50
	name = ".50 BMG"
	damage = 60
	armor_penetration = 10
	// AI EDIT: was `speed = BULLET_SPEED_INSANE` directly - BULLET_SPEED_* are deltas meant to be
	// measured against BULLET_SPEED_BASELINE (per this file's own comment on that define), not
	// assigned as the absolute speed. DD's real /obj/projectile/var/speed is a divisor for movement
	// step count (code/modules/projectiles/projectile.dm:86); assigning a bare negative delta made
	// it negative, breaking the movement math outright (the projectile never actually travels).
	speed = BULLET_SPEED_BASELINE + BULLET_SPEED_INSANE
	bulletTipType = BULLET_SHARP

