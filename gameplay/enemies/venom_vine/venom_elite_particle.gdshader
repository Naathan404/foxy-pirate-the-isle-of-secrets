shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D particle_texture : source_color, filter_linear_mipmap;
uniform vec4 dark_violet : source_color = vec4(0.42, 0.10, 0.86, 1.0);
uniform vec4 bright_orchid : source_color = vec4(0.92, 0.56, 1.0, 1.0);
uniform float intensity : hint_range(0.2, 3.0) = 1.25;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec4 tex = texture(particle_texture, UV);
	float alpha = tex.a * COLOR.a;
	if (alpha < 0.01) {
		discard;
	}
	float lum = clamp(dot(tex.rgb, vec3(0.3, 0.59, 0.11)), 0.0, 1.0);
	vec3 violet = mix(dark_violet.rgb, bright_orchid.rgb, smoothstep(0.18, 0.92, lum));
	// Giu anh trang nhe o loi hat cuc sang ma khong dinh sac xanh la goc cua sprite.
	ALBEDO = mix(violet, vec3(1.0, 0.86, 1.0), smoothstep(0.84, 1.0, lum) * 0.45) * COLOR.rgb * intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
