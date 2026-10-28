shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// Match the enemy's billboard, keeping its atlas UVs and authored scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	ALBEDO = vec3(1.0, 0.97, 0.9);
	ALPHA = texture(sprite_texture, UV).a * COLOR.a * strength;
}
