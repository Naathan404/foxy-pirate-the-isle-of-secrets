shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 streak_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// Opacity at the brightest point of a fresh streak; lower is lighter.
uniform float peak_opacity : hint_range(0.0, 1.0) = 0.55;
// Pulls the streak toward the camera (view space, world units) so terrain behind Foxy's
// path, which the tilted camera sees in front of a trailing streak, does not hide it.
uniform float toward_camera_units : hint_range(0.0, 4.0) = 1.5;

void vertex() {
	vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_position.z += toward_camera_units;
	POSITION = PROJECTION_MATRIX * vec4(view_position, 1.0);
}

void fragment() {
	// UV.x runs from the faded tail (0) to the head (1); UV.y across the width.
	// Both ends taper to zero so the streak has no hard cap, and the width falls off as a
	// smooth bell instead of a sharp ridge.
	float along = smoothstep(0.0, 0.7, UV.x) * (1.0 - smoothstep(0.85, 1.0, UV.x));
	float across = smoothstep(0.0, 1.0, clamp(1.0 - abs(UV.y - 0.5) * 2.0, 0.0, 1.0));
	ALBEDO = streak_color.rgb;
	ALPHA = clamp(along * across * peak_opacity, 0.0, 1.0) * strength * streak_color.a;
}
