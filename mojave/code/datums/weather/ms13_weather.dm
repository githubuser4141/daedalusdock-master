//MOJAVE SUN WEATHER - vanilla's radiation storm protects a hardcoded list of station areas
//(maintenance, AI upload, emergency storage, shuttles...) that don't exist on this map, so nobody
//is ever actually protected from it. Disable it from occurring naturally, and add a version that
//protects anywhere indoors instead, using the same outdoors area var already relied on for the
//real MS13 area lighting fix - not a hardcoded area list.

// Disables the vanilla round-event trigger entirely (this is its only way to start - see
// code/modules/events/radiation_storm.dm and code/datums/weather/weather_types/radiation_storm.dm,
// whose own probability is 0, so it never fires on its own via SSweather's random rotation either).
/datum/round_event_control/radiation_storm
	weight = 0

/// Same radiation effects/telegraph/messages as vanilla (inherited as-is), but protects by whether
/// the area is actually indoors (area.outdoors == FALSE) instead of a hardcoded station area list,
/// and has a real probability so it can occur naturally through SSweather's own rotation instead of
/// needing a round event to trigger it.
/datum/weather/rad_storm/ms13
	protected_areas = list()
	protect_indoors = TRUE
	probability = 60
