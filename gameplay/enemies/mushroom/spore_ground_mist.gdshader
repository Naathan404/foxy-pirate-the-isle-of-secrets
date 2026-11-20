shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 outer_mist_color : source_color = vec4(0.36, 0.18, 0.48, 1.0);
uniform vec4 spore_core_color : source_color = vec4(0.54, 0.78, 0.34, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.25;
uniform float drift_speed : hint_range(0.0, 1.0) = 0.14;
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
	if (r > 0.98) {
		discard;
	}
	vec2 flow = world_xz * 0.65 + vec2(seed_offset, seed_offset * 0.7);
	float t = TIME * drift_speed;
	float n1 = noise2(flow + vec2(t, -t * 0.6));
	float n2 = noise2(flow * 2.1 + vec2(-t * 0.8, t * 0.9) + vec2(n1 * 0.9));
	float wisps = smoothstep(0.22, 0.82, n1 * 0.65 + n2 * 0.35);
	float warped_r = r + (n1 - 0.5) * 0.34 + (n2 - 0.5) * 0.14;
	float radial_fade = 1.0 - smoothstep(0.32, 0.94, warped_r);
	float density = radial_fade * mix(0.28, 1.0, wisps);
	float spore_pocket = smoothstep(0.54, 0.88, wisps) * (1.0 - smoothstep(0.0, 0.7, r));
	ALBEDO = mix(outer_mist_color.rgb, spore_core_color.rgb, spore_pocket * 0.52);
	ALPHA = clamp(density * opacity, 0.0, 0.32);
	if (ALPHA < 0.005) {
		discard;
	}
}
