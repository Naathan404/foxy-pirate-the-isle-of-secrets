shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D puddle_texture : source_color, filter_linear_mipmap;
uniform float pool_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(puddle_texture, UV);
	if (tex.a < 0.04) {
		discard;
	}
	// Chuyen sac axit xanh la sang doc tim thach anh dam, khu hoan toan sac xanh la/vang o diem sang.
	float lum = clamp(dot(tex.rgb, vec3(0.3, 0.59, 0.11)), 0.0, 1.0);
	vec3 purple_mapped = vec3(
		clamp(lum * 0.86 + tex.b * 0.25, 0.0, 1.0),
		clamp(lum * 0.24, 0.0, 0.42),
		clamp(lum * 1.18 + 0.16, 0.0, 1.0)
	);
	float ink_blend = smoothstep(0.12, 0.36, lum);
	vec3 dark_edge = tex.rgb * vec3(0.58, 0.36, 0.78);
	ALBEDO = mix(dark_edge, purple_mapped, ink_blend);
	ALPHA = clamp(tex.a * pool_alpha, 0.0, 1.0);
}
