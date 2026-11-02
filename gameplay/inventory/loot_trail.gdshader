shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform bool landing_glint = false;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	if (landing_glint) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
}

void fragment() {
	float across = UV.y * 2.0 - 1.0;
	float core = exp(-across * across * 55.0);
	float glow = pow(max(0.0, 1.0 - abs(across)), 0.9);
	float tail = smoothstep(0.0, 0.2, UV.x);
	if (landing_glint) {
		vec2 p = UV * 2.0 - 1.0;
		float edge = pow(max(0.0, 1.0 - length(p)), 2.0);
		core = exp(-min(abs(p.x), abs(p.y)) * 32.0) * edge;
		glow = exp(-dot(p, p) * 10.0) * edge;
		tail = 1.0;
	}
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.97, 0.85), clamp(core * 1.5, 0.0, 1.0)) * 2.3;
	ALPHA = clamp(core + glow * 0.7, 0.0, 1.0) * tail * COLOR.a * tint.a * opacity;
}
