shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Irregular ink stain with a few satellite drops, drawn on a flat quad lying on the ground.
uniform vec4 ink_color : source_color = vec4(0.58, 0.32, 0.38, 1.0);
uniform vec4 rim_color : source_color = vec4(0.36, 0.17, 0.24, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
// Blob radius and edge wobble, in quad-radius units.
uniform float blob_radius = 0.5;
uniform float wobble = 0.12;
uniform int drop_count : hint_range(0, 8) = 5;

float hash(float value) {
	return fract(sin(value * 91.7 + seed * 47.3) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float edge = blob_radius
		+ wobble * (sin(angle * 3.0 + seed) * 0.6 + sin(angle * 7.0 + seed * 2.3) * 0.4);
	float r = length(p);
	float blob = 1.0 - smoothstep(edge - 0.03, edge, r);
	float rim = smoothstep(edge - 0.12, edge - 0.03, r) * blob;
	float drops = 0.0;
	for (int i = 0; i < drop_count; i++) {
		float a = hash(float(i)) * TAU;
		float d = edge + 0.12 + hash(float(i) + 10.0) * 0.25;
		vec2 c = vec2(cos(a), sin(a)) * d;
		float size = 0.04 + hash(float(i) + 20.0) * 0.06;
		drops = max(drops, 1.0 - smoothstep(size - 0.02, size, length(p - c)));
	}
	float shape = max(blob, drops);
	ALBEDO = mix(ink_color.rgb, rim_color.rgb, max(rim, drops * 0.5));
	ALPHA = shape * opacity * ink_color.a;
}
