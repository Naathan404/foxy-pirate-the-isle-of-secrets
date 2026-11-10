shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ripple_color : source_color = vec4(0.88, 1.0, 0.93, 1.0);

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float radius = length(centered);
	float ring_radius = mix(0.12, 0.92, progress);
	float ring = 1.0 - smoothstep(0.025, 0.10, abs(radius - ring_radius));
	float inner_ring = 1.0 - smoothstep(0.02, 0.08, abs(radius - ring_radius * 0.58));
	vec2 foot = centered * vec2(1.75, 1.12);
	float imprint = 1.0 - smoothstep(0.3, 0.53, length(foot));
	imprint *= 1.0 - smoothstep(0.0, 0.38, progress);
	float fade = (1.0 - progress) * (1.0 - progress);
	float brightness = ring * 0.7 + inner_ring * 0.25 + imprint * 0.4;
	ALBEDO = ripple_color.rgb;
	ALPHA = clamp(brightness * fade * 0.7, 0.0, 0.75);
	if (ALPHA < 0.012) {
		discard;
	}
}
