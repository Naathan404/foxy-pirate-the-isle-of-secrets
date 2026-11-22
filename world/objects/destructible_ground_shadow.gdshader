shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Fake sun shadow of a camera-facing sprite: the sprite's own outline laid flat on the ground.
// Width stays on the x axis like the sprite, so the shadow's base is exactly the base the player
// sees; each metre of height shifts the outline by `shadow_offset_per_meter`. Real shadow maps
// cast billboards from the light's side, so their base runs across the sprite's base instead.
// The quad is rebuilt in vertex() from its UV, so any 1×1 QuadMesh works.

uniform sampler2D sprite_texture : filter_linear, repeat_disable;
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
// Sprite image in prop space, metres: (left, bottom, width, height). Height is above the ground.
uniform vec4 sprite_rect = vec4(-0.5, 0.0, 1.0, 1.0);
uniform float sprite_depth_meters = 0.0;
// Ground shift (x, z) per metre of sprite height: the shadow's direction and length.
// Negative z leans it away from the camera (up the screen).
uniform vec2 shadow_offset_per_meter = vec2(0.8, -0.6);
uniform float ground_lift_meters = 0.03;
uniform vec4 shadow_color : source_color = vec4(0.04, 0.05, 0.08, 0.6);
// Shadow fades toward the tip; 1 keeps it uniform.
uniform float tip_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float alpha_threshold = 0.5;
uniform bool flip_h = false;
uniform bool flip_v = false;

varying float height_fraction;


void vertex() {
	float x = sprite_rect.x + UV.x * sprite_rect.z;
	float y = sprite_rect.y + (1.0 - UV.y) * sprite_rect.w;
	vec2 ground = vec2(x, sprite_depth_meters) + shadow_offset_per_meter * y;
	VERTEX = vec3(ground.x, ground_lift_meters, ground.y);
	height_fraction = 1.0 - UV.y;
}


void fragment() {
	vec2 local_uv = vec2(flip_h ? 1.0 - UV.x : UV.x, flip_v ? 1.0 - UV.y : UV.y);
	float alpha = texture(sprite_texture, frame_uv.xy + local_uv * frame_uv.zw).a;
	float coverage = smoothstep(alpha_threshold - 0.15, alpha_threshold + 0.15, alpha);
	ALBEDO = shadow_color.rgb;
	ALPHA = coverage * shadow_color.a * mix(1.0, tip_opacity, clamp(height_fraction, 0.0, 1.0));
}
