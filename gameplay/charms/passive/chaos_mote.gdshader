shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A camera-facing Chaos ember: a four-point star with a hot core and a dark ink rim, inside a
// soft halo of its colour, so it reads on bright sand and on red enemies alike.

uniform vec4 tint : source_color = vec4(1.0, 0.4, 0.24, 1.0);
uniform vec4 ink : source_color = vec4(0.2, 0.04, 0.03, 1.0);
uniform float halo_strength : hint_range(0.0, 1.0) = 0.55;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	// Pinched sides between four long arms.
	float star = pow(abs(p.x), 0.62) + pow(abs(p.y), 0.62);
	float fill = 1.0 - smoothstep(0.92, 1.02, star);
	float body = 1.0 - smoothstep(0.7, 0.78, star);
	float core = 1.0 - smoothstep(0.04, 0.2, length(p));
	float halo = pow(max(0.0, 1.0 - length(p)), 1.6) * halo_strength;
	vec3 star_colour = mix(ink.rgb, tint.rgb, body);
	star_colour = mix(star_colour, vec3(1.0, 0.82, 0.35), core);
	float solid = max(fill, core);
	ALBEDO = mix(tint.rgb, star_colour, solid);
	ALPHA = max(solid, halo) * tint.a;
}
