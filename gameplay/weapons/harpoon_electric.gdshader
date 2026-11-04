shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float brightness : hint_range(0.0, 6.0) = 2.4;

void fragment() {
	ALBEDO = COLOR.rgb * brightness;
	ALPHA = COLOR.a;
}
