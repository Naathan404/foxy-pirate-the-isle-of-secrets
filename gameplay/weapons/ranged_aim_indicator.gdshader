shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.15, 0.12, 1.0);
uniform vec4 charged_color : source_color = vec4(1.0, 0.65, 0.15, 1.0);
// Match the mesh's world dimensions so distances keep the same aspect on both axes.
uniform vec2 canvas_size = vec2(1.65, 2.15);
uniform float arrow_scale : hint_range(0.5, 1.5) = 1.0;
uniform float shaft_width : hint_range(0.04, 0.16) = 0.085;
uniform float head_half_width : hint_range(0.2, 0.55) = 0.38;
uniform float glow_radius : hint_range(0.04, 0.3) = 0.13;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - a - ab * t);
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * canvas_size / arrow_scale;
	float width = shaft_width * mix(1.0, 1.2, charge);
	// A short, substantial shaft and a broad spear-shaped chevron.
	float shaft = segment_distance(p, vec2(0.0, -0.42), vec2(0.0, 0.48)) - width;
	float left = segment_distance(p, vec2(-head_half_width, 0.16), vec2(0.0, 0.64));
	float right = segment_distance(p, vec2(head_half_width, 0.16), vec2(0.0, 0.64));
	float blade = min(left, right) - width * 1.15;
	float body_distance = min(shaft, blade);
	// Separate tail marks add a sense of direction without lengthening the shaft.
	float tail = segment_distance(p, vec2(0.0, -0.66), vec2(0.0, -0.59)) - width * 0.6;
	float tail_end = segment_distance(p, vec2(0.0, -0.87), vec2(0.0, -0.83)) - width * 0.35;
	float edge_distance = min(body_distance, min(tail, tail_end));
	float aa = max(fwidth(edge_distance), 0.001);
	float fill = 1.0 - smoothstep(-aa, aa, edge_distance);
	float hot_core = 1.0 - smoothstep(-width * 0.65, -width * 0.15, body_distance);
	float halo = exp(-pow(max(edge_distance, 0.0) / glow_radius, 2.0));
	float rim_light = exp(-pow((edge_distance - 0.015) / 0.035, 2.0));
	float tail_fade = mix(0.45, 1.0, smoothstep(-0.9, -0.45, p.y));
	float pulse = 1.0 + sin(TIME * 7.0) * 0.045 * charge;
	vec3 rim = mix(glow_color.rgb, charged_color.rgb, charge);
	ALBEDO = mix(rim, vec3(1.0, 0.96, 0.86), hot_core) * (1.25 + charge * 0.35) * pulse;
	ALPHA = clamp(fill * 0.92 + rim_light * 0.25 + halo * (0.22 + charge * 0.12), 0.0, 1.0)
		* glow_color.a * tail_fade;
}
