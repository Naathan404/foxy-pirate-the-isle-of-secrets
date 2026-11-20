shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D sprite_texture : source_color, filter_linear_mipmap;
uniform vec4 glow_color : source_color = vec4(0.55, 1.0, 0.25, 1.0);
uniform vec4 counter_color : source_color = vec4(1.0, 0.45, 0.18, 1.0);
uniform float idle_pulse_strength : hint_range(0.0, 2.0) = 0.0;
uniform float charge_strength : hint_range(0.0, 2.0) = 0.0;
uniform float counter_mix : hint_range(0.0, 1.0) = 0.0;
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

	// Chỉ bắt sáng vào phần lõi axit và mắt phát quang xanh lục rực của nụ hoa.
	float green_dominance = clamp((tex.g - max(tex.r * 0.85, tex.b * 1.35)) * 3.2, 0.0, 1.0);
	float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float core_mask = green_dominance * smoothstep(0.32, 0.78, luminance);

	vec2 local_uv = (UV - frame_uv_offset) / max(frame_uv_size, vec2(0.0001));
	float upper_mask = 1.0 - smoothstep(0.45, 0.72, local_uv.y);
	float pulse = 0.72 + 0.28 * sin(TIME * 3.4);

	float total_glow = core_mask * upper_mask * (idle_pulse_strength * pulse + charge_strength * 1.45);
	// Tạo điểm lấp lánh nhẹ chạy quanh vùng miệng nụ khi gồng.
	vec2 centered = (local_uv - vec2(0.5, 0.28)) * vec2(frame_aspect, 1.0);
	float ring_dist = length(centered);
	float aura_halo = exp(-ring_dist * 4.5) * charge_strength * 0.32 * upper_mask;

	vec3 active_col = mix(glow_color.rgb, counter_color.rgb, counter_mix);
	ALBEDO = active_col;
	ALPHA = clamp(total_glow + aura_halo, 0.0, 0.92);
	if (ALPHA < 0.005) {
		discard;
	}
}
