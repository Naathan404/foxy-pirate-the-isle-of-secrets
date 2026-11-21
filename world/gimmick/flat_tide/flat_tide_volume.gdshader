shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Shallow tide drawn as one ground-hugging sheet (no box walls). FlatTideZone supplies the
// geometry and timing; every height used here is mirrored on the CPU so gameplay, footprints
// and visuals agree. All calculations run in canonical flow space: the sea is at +X and the
// water advances toward -X, then the result is rotated into the zone's flow direction.

// Supplied by FlatTideZone.
uniform vec2 zone_size = vec2(12.0);
uniform int flow_direction = 0;
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float tide_time = 0.0;
uniform float tide_rising : hint_range(0.0, 1.0) = 0.0;
uniform float tide_falling : hint_range(0.0, 1.0) = 0.0;
uniform float surge : hint_range(0.0, 1.0) = 0.0;
uniform float shore_wave_amplitude = 0.3;
uniform float shore_wave_length = 5.0;
uniform float shore_wave_speed = 1.1;
uniform float shore_detail_amplitude = 0.08;
uniform float shore_detail_length = 2.4;
uniform float shore_detail_speed = 0.7;
uniform float surface_wave_height = 0.035;
uniform float surface_wave_length = 4.0;
uniform float surface_wave_speed = 1.2;
uniform float surface_detail_height = 0.015;
uniform float surface_detail_length = 2.5;
uniform float surface_detail_speed = 0.8;
uniform float rest_height = 0.16;
uniform float crest_height = 0.55;
uniform float crest_rise_length = 0.9;
uniform float crest_tail_length = 3.2;
uniform float rest_ramp_length = 1.2;
uniform float side_fade_length = 1.5;
uniform float source_fade_length = 2.5;
uniform float front_density = 1.7;

// Artist controls live on the zone's Water Material resource.
uniform vec4 color_shallow : source_color = vec4(0.36, 0.84, 0.8, 1.0);
uniform vec4 color_deep : source_color = vec4(0.05, 0.4, 0.52, 1.0);
uniform vec4 color_foam : source_color = vec4(0.94, 0.99, 0.95, 1.0);
uniform float depth_gradient_length : hint_range(0.1, 30.0) = 9.0;
uniform float surface_opacity : hint_range(0.0, 1.0) = 0.32;
uniform float deep_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float foam_width : hint_range(0.01, 2.0) = 0.45;
uniform float foam_strength : hint_range(0.0, 1.0) = 0.85;
uniform float crest_foam_strength : hint_range(0.0, 1.0) = 0.7;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.22;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.12;
uniform float streak_strength : hint_range(0.0, 1.0) = 0.35;
// Soft, noisy feather just inside the waterline; it never draws past the gameplay line.
uniform float edge_softness : hint_range(0.0, 1.0) = 0.22;
uniform float edge_breakup : hint_range(0.0, 1.0) = 0.3;
uniform float noise_scale : hint_range(0.01, 2.0) = 0.12;
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;

const float MIN_LENGTH = 0.001;
const float GROUND_LIFT = 0.02;

varying vec2 flow_xz;

float shore_position(float z, float amount) {
	float half_width = zone_size.x * 0.5;
	// Near full coverage the line pulls inside the zone by the wave reach so it stays wavy
	// instead of flattening against the zone edge. Mirrored by FlatTideZone._shore_at_vertex().
	float settle = smoothstep(0.85, 1.0, amount);
	float reach = abs(shore_wave_amplitude) + abs(shore_detail_amplitude);
	float envelope = max(sin(PI * amount), settle);
	float phase = TAU * z / max(shore_wave_length, MIN_LENGTH) + tide_time * shore_wave_speed;
	float detail_phase = TAU * z / max(shore_detail_length, MIN_LENGTH) - tide_time * shore_detail_speed;
	float waves = shore_wave_amplitude * sin(phase) + shore_detail_amplitude * sin(detail_phase);
	float line = half_width - zone_size.x * amount + reach * settle + envelope * waves;
	return clamp(line, -half_width, half_width);
}

// Mirrored by FlatTideZone._sheet_height(); keep both in sync.
float sheet_height(float x, float z, float front) {
	float d = x - front;
	if (fill <= 0.0 || d <= 0.0) {
		return GROUND_LIFT;
	}
	float body = smoothstep(0.0, max(rest_ramp_length, MIN_LENGTH), d);
	float rise = smoothstep(0.0, max(crest_rise_length, MIN_LENGTH), d);
	float tail = 1.0 - smoothstep(crest_rise_length, crest_rise_length + max(crest_tail_length, MIN_LENGTH), d);
	float height = rest_height * body + crest_height * surge * rise * tail;
	float phase = TAU * (x + z) / max(surface_wave_length, MIN_LENGTH);
	float detail_phase = TAU * (x - z) / max(surface_detail_length, MIN_LENGTH);
	float waves = surface_wave_height * sin(phase + tide_time * surface_wave_speed);
	waves += surface_detail_height * sin(detail_phase - tide_time * surface_detail_speed);
	height += waves * body;
	float side_distance = zone_size.y * 0.5 - abs(z);
	height *= smoothstep(0.0, max(side_fade_length, MIN_LENGTH), side_distance);
	return max(GROUND_LIFT, height);
}

void vertex() {
	float half_width = zone_size.x * 0.5;
	bool active = fill > 0.0;
	float z = VERTEX.z;
	float front = half_width;
	float row_front = half_width;
	if (fill > 0.0) {
		front = shore_position(z, fill);
		// The exact curved waterline is cut per pixel in fragment(); rows start one full wave
		// reach earlier so the straight edges between vertices never clip that curve.
		float reach = abs(shore_wave_amplitude) + abs(shore_detail_amplitude);
		row_front = max(-half_width, front - 2.0 * reach);
	}
	float u = UV.x;
	float x = mix(row_front, half_width, pow(u, max(front_density, 1.0)));
	float height = sheet_height(x, z, front);
	flow_xz = vec2(x, z);
	VERTEX = active ? vec3(x, height, z) : vec3(0.0);
	if (flow_direction == 1) {
		VERTEX.xz = -VERTEX.xz;
	} else if (flow_direction == 2) {
		VERTEX.xz = vec2(-VERTEX.z, VERTEX.x);
	} else if (flow_direction == 3) {
		VERTEX.xz = vec2(VERTEX.z, -VERTEX.x);
	}
}

float noise_at(vec2 p) {
	return texture(noise_texture, p * noise_scale).r;
}

void fragment() {
	float half_width = zone_size.x * 0.5;
	// Per-pixel waterline: the same smooth curve as FlatTideZone._shore_x(), never faceted.
	float front_x = fill > 0.0 ? shore_position(flow_xz.y, fill) : half_width;
	float d = flow_xz.x - front_x;
	// Noise wobbles the fade borders so zone sides and the sea edge never read as straight lines.
	float border_noise = noise_at(flow_xz * 0.7 + vec2(tide_time * 0.05, 0.0)) - 0.5;
	float side_distance = zone_size.y * 0.5 - abs(flow_xz.y) + border_noise * side_fade_length;
	float side_fade = smoothstep(0.0, max(side_fade_length, MIN_LENGTH), side_distance);
	float source_distance = half_width - flow_xz.x + border_noise * source_fade_length;
	float source_fade = smoothstep(0.0, max(source_fade_length, MIN_LENGTH), source_distance);
	// Water flows toward -X while rising and pulls back toward +X while falling.
	float flow_sign = tide_falling > 0.5 ? 1.0 : -1.0;
	float t = tide_time;
	vec2 streak_uv = vec2(flow_xz.x * 0.35 + flow_sign * t * 1.4, flow_xz.y * 2.4);
	float streak = smoothstep(0.62, 0.9, noise_at(streak_uv));
	float breakup = noise_at(flow_xz * 1.6 + vec2(t * 0.25, -t * 0.18));
	vec3 color;
	float alpha;
	if (d < 0.0 || fill <= 0.0) {
		// Dry ground: nothing is drawn once the water has left.
		discard;
	} else {
		float deep = smoothstep(0.0, max(depth_gradient_length, MIN_LENGTH), d);
		vec2 drift_a = vec2(t * 0.11 * flow_sign, t * 0.07);
		vec2 drift_b = vec2(-t * 0.08, t * 0.05 * flow_sign);
		float n_a = noise_at(flow_xz * 0.9 + drift_a);
		float n_b = noise_at(flow_xz * 1.7 + drift_b + vec2(13.1, 7.3));
		float caustic = smoothstep(0.7, 0.95, 1.0 - abs(n_a - n_b) * 3.0) * (1.0 - deep * 0.6);
		float motion = max(tide_rising, tide_falling);
		// Lacy visible edge: noise pulls it back (never forward) from the gameplay line.
		// Low-frequency, isotropic noise keeps the lace rounded instead of saw-toothed.
		float edge_noise = noise_at(flow_xz * 0.9 + vec2(t * 0.12, -t * 0.16));
		float edge_d = d - edge_breakup * smoothstep(0.2, 0.85, edge_noise);
		float lace = 1.0 - smoothstep(0.0, foam_width * mix(0.55, 1.5, breakup), max(edge_d, 0.0));
		float crest_band = smoothstep(0.0, crest_rise_length, d)
			* (1.0 - smoothstep(crest_rise_length, crest_rise_length + crest_tail_length * 0.5, d));
		float crest_foam = crest_band * surge * smoothstep(0.35, 0.75, breakup) * crest_foam_strength;
		// Lit, foaming face up to the peak, then a darker trough behind it: reads as a rolling wave.
		float crest_face = smoothstep(crest_rise_length * 0.2, crest_rise_length, d)
			* (1.0 - smoothstep(crest_rise_length, crest_rise_length * 1.35, d));
		float crest_back = smoothstep(crest_rise_length * 1.2, crest_rise_length * 1.8, d)
			* (1.0 - smoothstep(crest_rise_length * 1.8, crest_rise_length + crest_tail_length, d));
		float trailing_streaks = streak * streak_strength * mix(0.35, 1.0, motion) * (1.0 - deep * 0.5);
		float foam = clamp(lace * foam_strength + crest_foam, 0.0, 1.0);
		color = mix(color_shallow.rgb, color_deep.rgb, deep);
		color += color_foam.rgb * (caustic * caustic_strength + highlight_strength * (n_a - 0.5));
		color = mix(color, color_deep.rgb * 0.8, crest_back * surge * 0.45);
		color = mix(color, color_foam.rgb, clamp(foam + trailing_streaks * 0.5, 0.0, 1.0));
		color = mix(color, color_foam.rgb, crest_face * surge * mix(0.45, 0.85, breakup));
		float body_alpha = mix(surface_opacity, deep_opacity, deep);
		body_alpha += (crest_band * 0.25 + crest_face * 0.3 + crest_back * 0.15) * surge;
		alpha = max(body_alpha, foam * 0.95);
		alpha += trailing_streaks * 0.15;
		// Soft, irregular contact line instead of a hard cut.
		alpha *= smoothstep(0.0, max(edge_softness, 0.02), edge_d);
		alpha *= side_fade * mix(source_fade, 1.0, foam * 0.5);
	}
	if (alpha <= 0.002) {
		discard;
	}
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
