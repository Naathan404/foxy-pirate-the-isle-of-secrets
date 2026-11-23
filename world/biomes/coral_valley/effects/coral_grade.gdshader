shader_type canvas_item;
render_mode unshaded;

// Coral Valley screen grade, the sister of the hub's vintage_overlay: the same single
// screen read, but split-toned (cool lagoon shadows, warm coral highlights) and with a
// sea-tinted vignette instead of a black one.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float exposure : hint_range(0.5, 1.5) = 1.0;
uniform float saturation : hint_range(0.0, 1.5) = 0.85;
uniform vec4 shadow_tint : source_color = vec4(0.86, 0.98, 1.0, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.04, 0.97, 0.9, 1.0);
uniform vec4 vignette_color : source_color = vec4(0.02, 0.09, 0.12, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;


void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, saturation);
	color *= mix(shadow_tint.rgb, highlight_tint.rgb, smoothstep(0.15, 0.75, luminance));
	color *= exposure;
	vec2 edge = (UV - 0.5) * 2.0;
	float vignette = smoothstep(0.35, 1.5, dot(edge, edge));
	COLOR = vec4(mix(color, vignette_color.rgb, vignette * vignette_strength), 1.0);
}
