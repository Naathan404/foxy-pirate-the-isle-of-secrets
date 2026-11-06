shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, fog_disabled;

uniform sampler2D spine_texture : filter_nearest;
uniform bool spine_camera_relative_depth = true;
uniform vec4 ghost_tint : source_color = vec4(0.65, 0.9, 1.0, 0.3);

varying float attachment_alpha;

void vertex() {
	if (spine_camera_relative_depth &&
			dot(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz,
				MODEL_NORMAL_MATRIX[2]) < 0.0) {
		VERTEX.z = -VERTEX.z;
	}
	attachment_alpha = CUSTOM0.a;
}

void fragment() {
	float alpha = texture(spine_texture, UV).a * attachment_alpha;
	if (alpha < 0.01) {
		discard;
	}
	ALBEDO = ghost_tint.rgb;
	ALPHA = alpha * ghost_tint.a;
}
