shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D atlas_texture : source_color, filter_linear;
uniform vec2 grid = vec2(4.0, 2.0);
uniform vec4 frame_region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	vec4 pixel = texture(atlas_texture, UV);
	vec2 cell = fract(UV * grid);
	// Softly terminate wisps at each frame's border; no neighbouring-frame bleed.
	float edge = min(min(cell.x - frame_region.x, frame_region.z - cell.x),
		min(cell.y - frame_region.y, frame_region.w - cell.y));
	float alpha = pixel.a * smoothstep(0.0, 0.035, edge);
	if (alpha < 0.015) {
		discard;
	}
	ALBEDO = pixel.rgb;
	ALPHA = alpha;
}
