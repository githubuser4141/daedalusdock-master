// Grid voltage (mojave/code/modules/power/grid.dm). A powernet carries the highest level fed into it that tick.
#define MS13_VOLTAGE_NONE 0
/// House supply, what utility boxes are built for: house generators and working substations give this.
#define MS13_VOLTAGE_LOW 1
/// Transmission voltage straight from a power plant. It blows a utility box's lights and can burn it out.
#define MS13_VOLTAGE_HIGH 2
