shader_type canvas_item;
render_mode unshaded;

uniform vec4 ink_color : source_color = vec4(0.015, 0.012, 0.02, 1.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float screen_aspect = 1.7778;
uniform float splash_seed = 0.0;

const int SPLAT_COUNT = 5;
const int LARGE_SPLAT_COUNT = 2;
const vec2 SPLAT_MARGIN = vec2(0.12, 0.16);
const vec2 LARGE_RADIUS_RANGE = vec2(0.13, 0.19);
const vec2 SMALL_RADIUS_RANGE = vec2(0.04, 0.08);

float random_value(float value) {
	return fract(sin(value * 127.1 + 311.7) * 43758.5453);
}

float splat(vec2 uv, vec2 center, float radius, float shape_seed) {
	vec2 delta = (uv - center) * vec2(screen_aspect, 1.0);
	float angle = atan(delta.y, delta.x);
	float lobes = sin(angle * 7.0 + shape_seed) * 0.12;
	lobes += sin(angle * 13.0 - shape_seed * 1.7) * 0.06;
	return length(delta) - radius * (1.0 + lobes);
}

void fragment() {
	float distance_field = 10.0;
	for (int i = 0; i < SPLAT_COUNT; i++) {
		float key = splash_seed + float(i) * 11.0;
		vec2 center = mix(SPLAT_MARGIN, vec2(1.0) - SPLAT_MARGIN,
			vec2(random_value(key), random_value(key + 1.0)));
		vec2 radius_range = i < LARGE_SPLAT_COUNT ? LARGE_RADIUS_RANGE : SMALL_RADIUS_RANGE;
		float radius = mix(radius_range.x, radius_range.y, random_value(key + 2.0));
		float shape_seed = random_value(key + 3.0) * 6.2831853;
		distance_field = min(distance_field, splat(UV, center, radius, shape_seed));
	}
	float spread = mix(-0.2, 1.4, coverage);
	float mask = 1.0 - smoothstep(spread - 0.025, spread + 0.025, distance_field);
	mask = mix(mask, 1.0, smoothstep(0.85, 1.0, coverage));
	COLOR = vec4(ink_color.rgb, ink_color.a * opacity * mask);
}
