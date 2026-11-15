shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D chain_texture : source_color, filter_linear, repeat_enable;

void fragment() {
	vec4 pixel = texture(chain_texture, vec2(fract(UV.x), UV.y));
	if (pixel.a < 0.02) {
		discard;
	}
	ALBEDO = pixel.rgb;
	ALPHA = pixel.a;
}
