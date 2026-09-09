//for things affected by weather
GLOBAL_LIST_EMPTY(weather_act_upon_list)
GLOBAL_LIST_EMPTY(sunlight_act_upon_list)

// AI EDIT: weather was never declared anywhere (not in this repo, not in MS's own live source), but its usage is
// consistent and clearly intentional - datum/particle_weather/weather_obj_act() sets it on objects in
// GLOB.weather_act_upon_list, weather_datum.dm's process() reads it the same way, and drying_rack.dm checks it
// on a turf - so declared on /atom to cover both cases in one place, matching how it's actually used.
/atom
	var/weather = FALSE
