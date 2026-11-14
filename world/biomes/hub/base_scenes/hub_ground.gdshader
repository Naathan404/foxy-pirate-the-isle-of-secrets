shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D sprite_texture : source_color, filter_linear, repeat_disable;

void fragment() {
	vec4 sprite = texture(sprite_texture, UV);
	float brightest_channel = max(sprite.r, max(sprite.g, sprite.b));
	if (sprite.a < 0.5 || brightest_channel <= 0.002) {
		discard;
	}
	ALBEDO = sprite.rgb;
}
