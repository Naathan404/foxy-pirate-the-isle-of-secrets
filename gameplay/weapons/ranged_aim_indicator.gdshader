shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.15, 0.12, 1.0);
uniform vec4 charged_color : source_color = vec4(1.0, 0.65, 0.15, 1.0);

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - a - ab * t);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float shaft = segment_distance(p, vec2(0.0, 0.08), vec2(0.0, 0.9));
	float left = segment_distance(p, vec2(-0.46, 0.67), vec2(0.0, 0.92));
	float right = segment_distance(p, vec2(0.46, 0.67), vec2(0.0, 0.92));
	float edge_distance = min(shaft, min(left, right));
	float width = mix(0.024, 0.042, charge);
	float core = 1.0 - smoothstep(width, width + 0.012, edge_distance);
	float glow = exp(-edge_distance * 18.0) * (0.45 + charge * 0.3);
	float pulse = 1.0 + sin(TIME * 12.0) * 0.08 * charge;
	vec3 rim = mix(glow_color.rgb, charged_color.rgb, charge);
	ALBEDO = mix(rim, vec3(1.0, 0.96, 0.9), core) * (1.4 + charge * 0.5) * pulse;
	ALPHA = clamp(core + glow, 0.0, 1.0) * glow_color.a;
}
