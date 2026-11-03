shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform bool telegraph = false;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edges = smoothstep(0.78, 0.95, abs(p.x));
	float ends = smoothstep(0.92, 0.99, abs(p.y));
	float mask;
	if (telegraph) {
		float dash = step(0.35, fract(UV.y * 9.0 - TIME * 3.0));
		mask = max(edges * dash, ends) * 0.8 + 0.07;
	} else {
		float core = exp(-p.x * p.x * 120.0);
		float glow = exp(-p.x * p.x * 9.0) * 0.5;
		mask = (core + glow) * (1.0 - smoothstep(0.55, 1.0, abs(p.y)));
	}
	ALBEDO = mix(vec3(1.0, 0.5, 0.04), vec3(1.0, 0.98, 0.65), exp(-p.x * p.x * 80.0)) * 1.6;
	ALPHA = clamp(mask * opacity, 0.0, 1.0);
}
