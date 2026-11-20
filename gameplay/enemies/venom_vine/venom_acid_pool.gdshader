shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 outer_acid_color : source_color = vec4(0.18, 0.34, 0.14, 1.0);
uniform vec4 core_acid_color : source_color = vec4(0.48, 0.92, 0.24, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.42;
uniform float fade_progress : hint_range(0.0, 1.0) = 1.0;
uniform float swirl_speed : hint_range(0.0, 2.0) = 0.35;
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

	vec2 flow = world_xz * 1.15 + vec2(seed_offset, seed_offset * 0.63);
	float t = TIME * swirl_speed;
	float n1 = noise2(flow + vec2(t, -t * 0.7));
	float n2 = noise2(flow * 2.3 + vec2(-t * 0.9, t * 0.8) + vec2(n1 * 0.8));
	float pattern = n1 * 0.6 + n2 * 0.4;

	float dissolve_edge = mix(1.05, 0.05, fade_progress);
	float alive_mask = smoothstep(dissolve_edge - 0.18, dissolve_edge + 0.12, pattern + (1.0 - r) * 0.55);
	float radial_soft = 1.0 - smoothstep(0.45, 0.98, r + (n1 - 0.5) * 0.16);
	float rim_glow = smoothstep(0.52, 0.82, r) * (1.0 - smoothstep(0.82, 0.98, r));

	vec3 col = mix(outer_acid_color.rgb, core_acid_color.rgb, clamp(pattern * 0.85 + rim_glow * 0.45, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(radial_soft * alive_mask * opacity * fade_progress, 0.0, 0.55);
	if (ALPHA < 0.005) {
		discard;
	}
}
