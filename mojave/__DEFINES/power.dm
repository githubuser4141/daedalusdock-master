// Grid voltage (mojave/code/modules/power/grid.dm). A powernet carries the highest level fed into it that tick.
#define MS13_VOLTAGE_NONE 0
/// House supply, what utility boxes are built for: house generators and working substations give this.
#define MS13_VOLTAGE_LOW 1
/// Transmission voltage straight from a power plant. It blows a utility box's lights and can burn it out.
#define MS13_VOLTAGE_HIGH 2

/// Sent to a rail feeder when its line goes live or dead: (live).
#define COMSIG_MS13_LINE_POWER_CHANGED "ms13_line_power_changed"
