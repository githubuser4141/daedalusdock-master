/// Run first each tick, as TG does, with a real share of it. Queued behind machines, mobs and pathfinding at priority 30,
/// a busy tick left it one round per fire, so a volley (and its fragments) hung in the air for seconds.
/datum/controller/subsystem/processing/projectiles
	flags = SS_NO_INIT|SS_HIBERNATE|SS_TICKER
	priority = 150 // Between do_afters and runechat.
