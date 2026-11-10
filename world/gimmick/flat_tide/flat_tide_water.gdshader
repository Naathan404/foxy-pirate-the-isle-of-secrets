shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float min_x = 0.0;
uniform float max_x = 15.0;
uniform float center_z = 0.0;
uniform float half_depth = 4.0;
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float warning : hint_range(0.0, 1.0) = 0.0;
uniform float tide_time = 0.0;

uniform vec4 color_shallow : source_color = vec4(0.29, 0.82, 0.75, 1.0);
uniform vec4 color_mid : source_color = vec4(0.07, 0.50, 0.57, 1.0);
uniform vec4 color_deep : source_color = vec4(0.02, 0.38, 0.51, 1.0);
uniform vec4 color_foam : source_color = vec4(0.91, 0.99, 0.88, 1.0);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

void fragment() {
	float taper = clamp((half_depth - abs(world_xz.y - center_z)) / 2.0, 0.0, 1.0);
	taper = taper * taper * (3.0 - 2.0 * taper);
	float reach = fill * taper;
	float front_x = mix(max_x, min_x, reach) + 0.15 * sin(world_xz.y * 1.3) * reach;

	if (fill <= 0.0 || world_xz.x < front_x) {
		if (warning <= 0.0 || world_xz.x < max_x - 2.0) {
			discard;
		}
		float pulse = 0.5 + 0.5 * sin(tide_time * 8.0 + world_xz.y * 2.0);
		ALBEDO = mix(color_shallow.rgb, color_foam.rgb, pulse);
		ALPHA = 0.22 + pulse * 0.27;
	} else {
	vec2 p = world_xz;
	float large_noise = noise2(p * 0.36 + vec2(tide_time * 0.13, -tide_time * 0.09));
	float fine_noise = noise2(p * 1.65 + vec2(-tide_time * 0.42, tide_time * 0.33));
	float distance_from_shore = max(0.0, p.x - front_x);
	float deepness = smoothstep(0.25, 8.5, distance_from_shore + (large_noise - 0.5) * 1.0);
	deepness *= 0.88 + 0.12 * taper;

	vec3 water_color = mix(color_shallow.rgb, color_mid.rgb, smoothstep(0.0, 0.62, deepness));
	water_color = mix(water_color, color_deep.rgb, smoothstep(0.43, 0.95, deepness));

	// Broken moving caustics sit over the seabed tint, then disappear in deep water.
	float caustic_a = sin(p.x * 2.7 + p.y * 1.5 + tide_time * 1.65 + large_noise * 3.0);
	float caustic_b = sin(p.x * -1.9 + p.y * 2.35 - tide_time * 1.1 + fine_noise * 2.0);
	float caustic = pow(clamp(caustic_a * caustic_b, 0.0, 1.0), 5.0);
	water_color += color_foam.rgb * caustic * (1.0 - deepness) * 0.23;

	// Thin reflective streaks make the top surface read separately from the sand.
	float streak = sin(p.x * 0.85 - p.y * 2.8 + tide_time * 1.9 + large_noise * 2.5);
	streak = smoothstep(0.73, 0.96, streak) * smoothstep(0.35, 0.75, fine_noise);
	water_color += color_shallow.rgb * streak * (0.07 + deepness * 0.11);

	float foam_breakup = noise2(vec2(p.y * 2.0, tide_time * 0.9 + p.x * 0.5));
	float foam = 1.0 - smoothstep(0.04, 0.65, distance_from_shore + (foam_breakup - 0.5) * 0.32);
	foam *= 0.55 + 0.45 * fine_noise;
	water_color = mix(water_color, color_foam.rgb, foam * 0.86);

	ALBEDO = water_color;
	ALPHA = clamp(0.46 + deepness * 0.42 + foam * 0.13, 0.0, 0.94);
	}
}
