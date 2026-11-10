shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Geometry and wave parameters are supplied by FlatTideZone.
uniform vec2 zone_size = vec2(12.0);
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float warning : hint_range(0.0, 1.0) = 0.0;
uniform float warning_width = 1.0;
uniform float tide_time = 0.0;
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

// Artist controls live on the zone's Water Material resource.
uniform vec4 color_shallow : source_color = vec4(0.35, 0.82, 0.78, 1.0);
uniform vec4 color_deep : source_color = vec4(0.035, 0.37, 0.49, 1.0);
uniform vec4 color_side : source_color = vec4(0.04, 0.32, 0.39, 1.0);
uniform vec4 color_foam : source_color = vec4(0.88, 0.98, 0.91, 1.0);
uniform float depth_gradient_length : hint_range(0.1, 30.0) = 7.0;
uniform float foam_width : hint_range(0.01, 2.0) = 0.38;
uniform float surface_opacity : hint_range(0.0, 1.0) = 0.72;
uniform float side_opacity : hint_range(0.0, 1.0) = 0.74;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.14;
uniform float caustic_sharpness : hint_range(1.0, 12.0) = 4.0;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.12;
uniform float foam_strength : hint_range(0.0, 1.0) = 0.65;
uniform float foam_variation_floor : hint_range(0.0, 1.0) = 0.7;
uniform float side_highlight_strength : hint_range(0.0, 1.0) = 0.35;
uniform float warning_opacity : hint_range(0.0, 1.0) = 0.5;
uniform float warning_pulse_floor : hint_range(0.0, 1.0) = 0.6;

const float MIN_LENGTH = 0.001;

varying vec2 local_xz;
varying float side_face;
varying float height_ratio;
varying float front_edge;

float shore_position(float z, float amount) {
	float half_width = zone_size.x * 0.5;
	float envelope = sin(PI * amount);
	float phase = TAU * z / max(shore_wave_length, MIN_LENGTH) + tide_time * shore_wave_speed;
	float detail_phase = TAU * z / max(shore_detail_length, MIN_LENGTH) - tide_time * shore_detail_speed;
	float waves = shore_wave_amplitude * sin(phase) + shore_detail_amplitude * sin(detail_phase);
	return clamp(half_width - zone_size.x * amount + envelope * waves, -half_width, half_width);
}

void vertex() {
	float preview_fill = min(warning_width / max(zone_size.x, MIN_LENGTH), 1.0) * warning;
	float visual_fill = fill > 0.0 ? fill : preview_fill;
	float front = shore_position(VERTEX.z, visual_fill);
	VERTEX.x = mix(front, zone_size.x * 0.5, UV.x);
	float phase = TAU * (VERTEX.x + VERTEX.z) / max(surface_wave_length, MIN_LENGTH);
	float detail_phase = TAU * (VERTEX.x - VERTEX.z) / max(surface_detail_length, MIN_LENGTH);
	float waves = surface_wave_height * sin(phase + tide_time * surface_wave_speed);
	waves += surface_detail_height * sin(detail_phase - tide_time * surface_detail_speed);
	VERTEX.y += COLOR.r * waves;
	local_xz = VERTEX.xz;
	front_edge = front;
	height_ratio = COLOR.r;
	side_face = COLOR.g;
}

void fragment() {
	if (fill <= 0.0 && warning <= 0.0) {
		discard;
	}
	if (fill <= 0.0) {
		float pulse = 0.5 + 0.5 * sin(tide_time * shore_wave_speed * TAU + local_xz.y);
		ALBEDO = mix(color_shallow.rgb, color_foam.rgb, pulse);
		ALPHA = surface_opacity * warning_opacity * mix(warning_pulse_floor, 1.0, pulse) * warning;
	} else {
		float shore_distance = max(0.0, local_xz.x - front_edge);
		float deepness = smoothstep(0.0, max(depth_gradient_length, MIN_LENGTH), shore_distance);
		float phase_a = TAU * (local_xz.x + local_xz.y) / max(surface_wave_length, MIN_LENGTH);
		float phase_b = TAU * (local_xz.x - local_xz.y) / max(shore_wave_length, MIN_LENGTH);
		float ripple = 0.5 + 0.5 * sin(phase_a + tide_time * surface_wave_speed);
		float crossing = 0.5 + 0.5 * sin(phase_b - tide_time * shore_wave_speed);
		float caustic = pow(ripple * crossing, caustic_sharpness) * caustic_strength * (1.0 - deepness);
		float foam = 1.0 - smoothstep(0.0, max(foam_width, MIN_LENGTH), shore_distance);
		foam *= mix(foam_variation_floor, 1.0, crossing);
		vec3 surface_color = mix(color_shallow.rgb, color_deep.rgb, deepness);
		surface_color += color_foam.rgb * (caustic + ripple * highlight_strength);
		surface_color = mix(surface_color, color_foam.rgb, foam * foam_strength);
		vec3 side_color = mix(color_side.rgb, color_shallow.rgb, height_ratio * side_highlight_strength);
		ALBEDO = mix(surface_color, side_color, side_face);
		ALPHA = mix(surface_opacity, side_opacity, side_face);
	}
}
