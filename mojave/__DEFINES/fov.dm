/// Field of vision defines.
#define FOV_60_DEGREES 60 //MOJAVE EDIT - Base TG only has 90, 180, 270
#define FOV_90_DEGREES 90
#define FOV_120_DEGREES 120 //MOJAVE EDIT - Base TG only has 90, 180, 270
#define FOV_180_DEGREES 180
#define FOV_270_DEGREES 270
/// The blind spots a view steps through, narrowest first. A visor costs its wearer steps along this.
#define FOV_STEPS list(FOV_60_DEGREES, FOV_90_DEGREES, FOV_120_DEGREES, FOV_180_DEGREES, FOV_270_DEGREES)

/// Base mask dimensions. They're like a client's view, only change them if you modify the mask to different dimensions.
#define BASE_FOV_MASK_X_DIMENSION 15
#define BASE_FOV_MASK_Y_DIMENSION 15

/// Range at which FOV effects treat nearsightness as blind and play
#define NEARSIGHTNESS_FOV_BLINDNESS 2

//Fullscreen overlay resolution in tiles for the clients view.
/// The fullscreen overlay in tiles for x axis
#define FULLSCREEN_OVERLAY_RESOLUTION_X 15
/// The fullscreen overlay in tiles for y axis
#define FULLSCREEN_OVERLAY_RESOLUTION_Y 15

/// Mobs and loose items. A viewer's field of vision masks this plane, which is then drawn into the game plane at mob layer.
#define GAME_PLANE_FOV_HIDDEN -4
/// The field of vision mask. Never drawn itself: only the plane above uses it, as a render source.
#define FIELD_OF_VISION_BLOCKER_PLANE -3
#define FIELD_OF_VISION_BLOCKER_RENDER_TARGET "*FIELD_OF_VISION_BLOCKER_RENDER_TARGET"
