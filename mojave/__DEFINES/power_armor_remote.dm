// Link type constants for remote-controlled power armor (mojave/code/modules/power_armor_remote/).
// Kept here rather than in remote_link.dm itself so they're available regardless of load order
// between that file and its sibling control_computer.dm/pa_antenna.dm/pa_module_remote.dm - all of
// mojave/__DEFINES/ loads before mojave/code/modules/, so this can never be order-dependent again.
#define MS13_PA_LINK_CABLE "cable"
#define MS13_PA_LINK_RADIO "radio"
