shader_type canvas_item;

uniform vec4 ambient_tint : source_color = vec4(1.0, 0.72, 0.43, 1.0);
uniform vec4 water_tint : source_color = vec4(0.07, 0.53, 0.70, 1.0);
uniform float ambient_strength : hint_range(0.0, 0.3) = 0.035;
uniform float mote_strength : hint_range(0.0, 0.3) = 0.05;
uniform float water_amount : hint_range(0.0, 1.0) = 0.0;
uniform float water_tint_strength : hint_range(0.0, 0.5) = 0.08;
uniform float water_edge_strength : hint_range(0.0, 0.7) = 0.22;
uniform float water_shimmer_strength : hint_range(0.0, 0.5) = 0.13;
uniform float motion_speed : hint_range(0.0, 3.0) = 0.45;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	float t = TIME * motion_speed;
	vec2 centered = UV * 2.0 - 1.0;
	float edge = smoothstep(0.38, 1.18, length(centered * vec2(0.85, 1.0)));
	float ambient = ambient_strength * (0.45 + 0.55 * edge);

	// Slowly drifting, sparse airborne motes; the center stays mostly clear.
	vec2 cells = vec2(UV.x * 15.0 + t * 0.07, UV.y * 9.0 - t * 0.13);
	vec2 cell = floor(cells);
	vec2 point = fract(cells) - vec2(hash21(cell), hash21(cell + 19.7));
	float mote = (1.0 - smoothstep(0.012, 0.05, length(point))) * step(0.72, hash21(cell + 4.3));
	ambient += mote * mote_strength * (0.65 + 0.35 * sin(t + hash21(cell) * 6.28));

	// Soft, moving caustic streaks and cool edges suggest shallow water.
	float water = 0.0;
	if (water_amount > 0.001) {
		vec2 uv = UV;
		float wave_a = sin(uv.x * 24.0 + uv.y * 13.0 + sin(uv.y * 10.0 - t) * 1.8 + t);
		float wave_b = sin(uv.x * 16.0 - uv.y * 19.0 + sin(uv.x * 8.0 + t) * 1.4 - t * 0.7);
		float glints = pow(max(0.0, wave_a * wave_b), 5.0);
		water = water_amount * (water_tint_strength + edge * water_edge_strength + glints * water_shimmer_strength);
	}
	float total = clamp(ambient + water, 0.0, 0.65);
	vec3 color = mix(ambient_tint.rgb, water_tint.rgb, water / max(total, 0.0001));
	COLOR = vec4(color, total);
}
