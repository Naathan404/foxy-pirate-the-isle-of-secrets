shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D atlas_texture : source_color, filter_linear;

void fragment() {
	vec4 pixel = texture(atlas_texture, UV);
	vec2 cell = fract(UV * vec2(4.0, 3.0));
	float edge = min(min(cell.x, 1.0 - cell.x), min(cell.y, 1.0 - cell.y));
	float alpha = pixel.a * smoothstep(0.0, 0.035, edge);
	if (alpha < 0.015) {
		discard;
	}
	ALBEDO = pixel.rgb;
	ALPHA = alpha;
}
