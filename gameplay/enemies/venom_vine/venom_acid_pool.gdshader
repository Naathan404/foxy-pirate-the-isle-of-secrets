shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 outer_acid_color : source_color = vec4(0.16, 0.34, 0.12, 1.0);
uniform vec4 core_acid_color : source_color = vec4(0.54, 0.98, 0.24, 1.0);
uniform vec4 rim_neon_color : source_color = vec4(0.75, 1.0, 0.42, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.52;
uniform float fade_progress : hint_range(0.0, 1.0) = 1.0;
uniform float swirl_speed : hint_range(0.0, 2.0) = 0.42;
uniform float seed_offset = 0.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float r = length(centered);
	if (r > 1.0) {
		discard;
	}

	vec2 flow = world_xz * 1.25 + vec2(seed_offset, seed_offset * 0.63);
	float t = TIME * swirl_speed;
	float n1 = noise2(flow + vec2(t, -t * 0.7));
	float n2 = noise2(flow * 2.4 + vec2(-t * 0.9, t * 0.85) + vec2(n1 * 0.85));
	float pattern = n1 * 0.58 + n2 * 0.42;

	// Gợn sóng caustic phát quang lan nhẹ từ tâm ra mép vũng.
	float caustic_wave = 0.5 + 0.5 * sin(r * 13.0 - TIME * 3.6 + n1 * 3.5);
	float caustic_highlight = smoothstep(0.62, 0.95, caustic_wave * pattern) * (1.0 - r * 0.65);

	float dissolve_edge = mix(1.06, 0.05, fade_progress);
	float alive_mask = smoothstep(
		dissolve_edge - 0.18,
		dissolve_edge + 0.12,
		pattern + (1.0 - r) * 0.56
	);
	float radial_soft = 1.0 - smoothstep(0.52, 0.98, r + (n1 - 0.5) * 0.14);
	float rim_glow = smoothstep(0.62, 0.84, r) * (1.0 - smoothstep(0.84, 0.98, r));

	vec3 base_col = mix(outer_acid_color.rgb, core_acid_color.rgb, clamp(pattern * 0.85, 0.0, 1.0));
	vec3 lit_col = mix(base_col, rim_neon_color.rgb, clamp(caustic_highlight * 0.6 + rim_glow * 0.75, 0.0, 1.0));
	ALBEDO = lit_col;
	ALPHA = clamp((radial_soft * 0.85 + rim_glow * 0.45) * alive_mask * opacity * fade_progress, 0.0, 0.68);
	if (ALPHA < 0.005) {
		discard;
	}
}
