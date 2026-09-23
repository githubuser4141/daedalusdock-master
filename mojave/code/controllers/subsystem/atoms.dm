/// Each call late-initializes only what it created itself. Called during a map load that's still going (a wreck spawner
/// building its vehicle), it used to flush that load's pending LateInitialize()s too, before their neighbours existed.
/datum/controller/subsystem/atoms/InitializeAtoms(list/atoms, list/atoms_to_return)
	var/list/outer_late_loaders = late_loaders
	late_loaders = list()
	. = ..()
	late_loaders = outer_late_loaders
