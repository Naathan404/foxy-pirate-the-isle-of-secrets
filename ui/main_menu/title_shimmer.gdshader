shader_type canvas_item;

// A soft glint that sweeps across the title. It is keyed to screen space because Label glyphs
// are drawn as separate quads, so per-glyph UV would restart the sweep on every letter.
uniform float sweep : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glint_color : source_color = vec4(1.0, 0.86, 0.78, 1.0);
uniform float band_width = 0.07;
uniform float slant = 0.35;
uniform float strength = 0.85;

void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;
	float position = SCREEN_UV.x + SCREEN_UV.y * slant;
	float front = mix(-0.4, 1.4, sweep);
	float band = exp(-pow((position - front) / band_width, 2.0));
	glyph.rgb += glint_color.rgb * band * strength * glyph.a;
	COLOR = glyph;
}
