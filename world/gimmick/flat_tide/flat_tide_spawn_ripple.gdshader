shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 ripple_color : source_color = vec4(0.55, 0.92, 1.0, 0.8);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float distance_from_center = length(UV - vec2(0.5)) * 2.0;
	float radius = mix(0.12, 0.92, progress);
	float width = mix(0.13, 0.045, progress);
	float ring = 1.0 - smoothstep(width * 0.4, width, abs(distance_from_center - radius));
	float fade = (1.0 - smoothstep(0.55, 1.0, progress)) * smoothstep(0.0, 0.08, progress);
	ALBEDO = ripple_color.rgb;
	ALPHA = ring * ripple_color.a * fade;
}
