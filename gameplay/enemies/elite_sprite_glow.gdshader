shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

// This overlay is rendered by the original Sprite3D, not by a second node.
// The expanded quad and every mote therefore stay in the exact same billboard
// plane as the animated sprite at every camera angle.
uniform vec4 glow_color : source_color = vec4(0.52, 0.92, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.82;
uniform vec2 frame_uv_offset = vec2(0.0);
uniform vec2 frame_uv_size = vec2(1.0);
uniform float frame_aspect = 1.0;

const float BILLBOARD_PADDING = 1.25;
const int MOTE_COUNT = 12;


float hash11(float value) {
	return fract(sin(value * 127.1) * 43758.5453123);
}


void vertex() {
	// Give the motes breathing room around the body without adding or moving a
	// world-space node. UVs are intentionally untouched so atlas frames remain
	// aligned with the source Sprite3D.
	VERTEX.xy *= BILLBOARD_PADDING;

	// Keep the overlay in the same camera-facing space as Sprite3D.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}


void fragment() {
	// Sprite3D supplies atlas-space UVs. Convert them back to the current
	// frame's local UVs before making the procedural field, so every animation
	// frame gets the same correctly proportioned halo.
	vec2 local_uv = (UV - frame_uv_offset) / max(frame_uv_size, vec2(0.0001));
	vec2 point = (local_uv - vec2(0.5)) * 2.0;
	point.x *= frame_aspect;
	float time = TIME * 0.72;
	float motes = 0.0;

	// Slow independent orbits read as magical light motes rather than icons.
	for (int index = 0; index < MOTE_COUNT; index++) {
		float id = float(index) + 1.0;
		float seed = hash11(id * 13.17);
		float direction = mix(-1.0, 1.0, step(0.5, hash11(id * 5.91)));
		float angle = seed * TAU + direction * time * (0.34 + hash11(id * 9.23) * 0.24);
		float radius = mix(0.47, 0.70, hash11(id * 3.71));
		radius += sin(time * (1.35 + hash11(id * 4.83)) + seed * TAU) * 0.035;
		vec2 center = vec2(cos(angle) * frame_aspect, sin(angle)) * radius;
		center.y += sin(time * 1.7 + seed * 19.0) * 0.045;

		float distance_to_mote = length(point - center);
		float size = mix(0.012, 0.024, hash11(id * 7.07));
		float core = 1.0 - smoothstep(size * 0.3, size, distance_to_mote);
		float halo = 1.0 - smoothstep(size, size * 3.1, distance_to_mote);
		float flicker = 0.58 + 0.42 * sin(TIME * (2.8 + hash11(id * 2.47)) + seed * TAU);
		motes += (core + halo * 0.22) * flicker;
	}

	float light_amount = motes * glow_strength;
	float white_hot_core = clamp(motes * 1.7, 0.0, 1.0);
	ALBEDO = mix(glow_color.rgb, vec3(1.0), white_hot_core);
	ALPHA = clamp(light_amount * glow_color.a, 0.0, 1.0);
}
