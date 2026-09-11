// DD's world.turf default (code/world.dm) is /turf/open/space/basic - correct for station maps, where
// anywhere a smaller map doesn't explicitly cover really is vacuum. Planetary maps (Mammoth etc.) declare a
// real ground baseturf per z-level instead, but any gap their .dmm doesn't cover (e.g. a sparse upper-floor
// layer with no content above some rooms) still silently falls back to that same real, unsimulated space
// turf - an infinite atmos sink the whole connected surface zone drains into, since it's all one contiguous
// zone with no walls to stop it.
//
// Swept once at boot, scoped to z-levels whose own baseturf isn't space-derived, so station z-levels (and
// deliberately-space z-levels on planetary maps, like the sky level above a mountain map) are untouched.
/turf/open/indestructible/void_filler
	name = "ground"
	desc = "Solid, unremarkable ground."
	simulated = TRUE
	initial_gas = null // no pre-seeded air - real neighboring zones equalize into it naturally on merge

/datum/controller/subsystem/mapping/proc/seal_planetary_gaps()
	for(var/z in 1 to length(z_list))
		var/real_baseturf = level_trait(z, ZTRAIT_BASETURF)
		if(!real_baseturf || ispath(real_baseturf, /turf/open/space))
			continue
		for(var/turf/open/space/basic/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
			T.ChangeTurf(/turf/open/indestructible/void_filler)
