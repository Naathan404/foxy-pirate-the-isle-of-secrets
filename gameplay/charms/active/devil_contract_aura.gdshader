shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Face each ember toward the camera while preserving its individual size and position.
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float taper = abs(p.x + 0.22 * sin(p.y * 3.0)) * 1.5 + abs(p.y);
	float core = 1.0 - smoothstep(0.10, 0.55, taper);
	ALBEDO = mix(COLOR.rgb, vec3(1.0, 0.86, 0.42), core);
	ALPHA = COLOR.a * (1.0 - smoothstep(0.80, 1.0, taper));
}
