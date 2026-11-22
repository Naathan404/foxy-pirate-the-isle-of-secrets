shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, fog_disabled;

// Same sway as destructible_wind.gdshader, depth-tested as an upright sprite.
#define UPRIGHT_DEPTH
#include "res://world/objects/destructible_wind.gdshaderinc"
