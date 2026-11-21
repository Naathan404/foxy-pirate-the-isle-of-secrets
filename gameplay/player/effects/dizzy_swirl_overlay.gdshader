shader_type canvas_item;
render_mode unshaded;

uniform vec4 swirl_color : source_color = vec4(0.24, 0.72, 0.22, 0.92);
uniform vec4 highlight_color : source_color = vec4(0.82, 1.0, 0.44, 1.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float screen_aspect = 1.7778;
uniform float splash_seed = 0.0;

const float ARM_COUNT = 5.0;
const float SUB_ARM_COUNT = 10.0;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(screen_aspect, 1.0);
	float dist = length(centered);
	float angle = atan(centered.y, centered.x);

	// Giữ phần trung tâm quanh Foxy tương đối thoáng, vòng xoáy rõ dần từ giữa ra viền màn hình.
	float center_clear = smoothstep(0.08, 0.42, dist);
	float perimeter_weight = smoothstep(0.22, 0.88, dist);

	float main_phase = angle * ARM_COUNT + dist * 12.0 - TIME * 4.4 + splash_seed;
	float main_spiral = smoothstep(0.28, 0.88, 0.5 + 0.5 * sin(main_phase));

	float sub_phase = angle * SUB_ARM_COUNT + dist * 18.0 - TIME * 6.8 + splash_seed * 1.3;
	float sub_spiral = smoothstep(0.6, 0.96, 0.5 + 0.5 * sin(sub_phase));

	float ripple = 0.5 + 0.5 * sin(dist * 24.0 - TIME * 5.2);
	float ring_haze = perimeter_weight * mix(0.28, 0.65, ripple);

	float reveal_limit = mix(0.05, 1.35, coverage);
	float reveal_mask = 1.0 - smoothstep(reveal_limit - 0.16, reveal_limit + 0.08, dist);

	float swirl_pattern = max(main_spiral * 0.78, ring_haze);
	float alpha = center_clear * swirl_pattern * reveal_mask * opacity * swirl_color.a * 0.72;
	vec3 color = mix(swirl_color.rgb, highlight_color.rgb, clamp(sub_spiral * 0.55 + main_spiral * 0.25, 0.0, 1.0));
	COLOR = vec4(color, clamp(alpha, 0.0, 0.72));
}
