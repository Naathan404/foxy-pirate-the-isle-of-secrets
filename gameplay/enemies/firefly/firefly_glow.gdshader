shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D sprite_texture : source_color, filter_linear_mipmap;
uniform vec4 rest_glow_color : source_color = vec4(1.0, 0.82, 0.24, 1.0);
uniform vec4 active_glow_color : source_color = vec4(0.84, 1.0, 0.22, 1.0);
uniform vec4 charge_glow_color : source_color = vec4(1.0, 0.56, 0.14, 1.0);
uniform float glow_strength : hint_range(0.0, 2.5) = 0.45;
uniform float active_mix : hint_range(0.0, 1.0) = 0.0;
uniform float charge_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec2 frame_uv_offset = vec2(0.0);
uniform vec2 frame_uv_size = vec2(1.0);
uniform float frame_aspect = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec4 tex = texture(sprite_texture, UV);
	if (tex.a < 0.05) {
		discard;
	}

	// Bắt sáng vào phần đuôi phát quang vàng-chanh / hổ phách (giữ thân nâu gụ dịu tự nhiên).
	float yellow_dominance = clamp((min(tex.r, tex.g) - tex.b * 0.95) * 2.4, 0.0, 1.0);
	float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float lantern_mask = yellow_dominance * smoothstep(0.38, 0.82, luminance);

	vec2 local_uv = (UV - frame_uv_offset) / max(frame_uv_size, vec2(0.0001));
	float pulse_speed = mix(2.6, 14.0, charge_mix);
	float pulse = 0.72 + 0.28 * sin(TIME * pulse_speed);
	float tail_glow = lantern_mask * glow_strength * pulse;

	vec2 centered = (local_uv - vec2(0.5, 0.62)) * vec2(frame_aspect, 1.0);
	float ring_dist = length(centered);
	float charge_halo = exp(-ring_dist * 4.2) * charge_mix * glow_strength * 0.28;

	vec3 base_col = mix(rest_glow_color.rgb, active_glow_color.rgb, active_mix);
	vec3 final_col = mix(base_col, charge_glow_color.rgb, charge_mix);
	ALBEDO = final_col;
	ALPHA = clamp(tail_glow + charge_halo, 0.0, 0.92);
	if (ALPHA < 0.005) {
		discard;
	}
}
