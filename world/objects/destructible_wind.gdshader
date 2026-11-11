shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, fog_disabled;

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sprite_width = 1.0;
uniform float wind_amplitude = 0.28;
uniform float wind_speed = 4.4;
uniform float gust_strength = 0.38;
uniform float root_height = 0.08;
uniform float bend_power = 1.35;
uniform float wind_phase = 0.0;
uniform float horizontal_uv_direction = 1.0;
uniform float vertical_uv_direction = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float expansion = 1.0 + 2.0 * wind_amplitude * (1.0 + gust_strength) / sprite_width;
	VERTEX.x *= expansion;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	float expansion = 1.0 + 2.0 * wind_amplitude * (1.0 + gust_strength) / sprite_width;
	float vertical_fraction = (UV.y - frame_uv.y) / frame_uv.w;
	float height = vertical_uv_direction > 0.0 ? 1.0 - vertical_fraction : vertical_fraction;
	float flex = pow(clamp((height - root_height) / (1.0 - root_height), 0.0, 1.0), bend_power);
	float phase = TIME * wind_speed + wind_phase;
	float gust = sin(phase * 1.73 + wind_phase * 0.37) * gust_strength;
	float offset = (sin(phase) + gust) * wind_amplitude * flex;
	float center_x = frame_uv.x + frame_uv.z * 0.5;
	vec2 sample_uv = UV;
	sample_uv.x = center_x + (UV.x - center_x) * expansion;
	sample_uv.x -= offset / sprite_width * frame_uv.z * horizontal_uv_direction;
	if (sample_uv.x < frame_uv.x || sample_uv.x > frame_uv.x + frame_uv.z) {
		discard;
	}
	vec4 texel = texture(sprite_texture, sample_uv);
	ALBEDO = mix(texel.rgb * COLOR.rgb, flash_color.rgb, flash_strength * flash_color.a);
	ALPHA = texel.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
