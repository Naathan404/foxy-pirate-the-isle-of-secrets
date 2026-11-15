shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform sampler2D sprite_texture : source_color, filter_linear, repeat_disable;

void fragment() {
	vec4 sprite = texture(sprite_texture, UV);
	float brightest_channel = max(sprite.r, max(sprite.g, sprite.b));
	// The Hub PNGs have an opaque, near-black backdrop.
	float backdrop_limit = OUTPUT_IS_SRGB ? 0.025 : 0.002;
	if (sprite.a < 0.5 || brightest_channel <= backdrop_limit) {
		discard;
	}
	ALBEDO = sprite.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
