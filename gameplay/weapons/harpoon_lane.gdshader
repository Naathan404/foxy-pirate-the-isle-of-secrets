shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform bool telegraph = false;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float mask;
	if (telegraph) {
		float length_fade = 1.0 - smoothstep(0.62, 1.0, abs(p.y));
		float pulse = 0.75 + 0.25 * sin(TIME * 13.0);
		mask = (exp(-p.x * p.x * 130.0) * 0.65
			+ exp(-p.x * p.x * 18.0) * 0.22) * length_fade * pulse;
	} else {
		float core = exp(-p.x * p.x * 120.0);
		float glow = exp(-p.x * p.x * 9.0) * 0.5;
		mask = (core + glow) * (1.0 - smoothstep(0.55, 1.0, abs(p.y)));
	}
	ALBEDO = mix(vec3(1.0, 0.5, 0.04), vec3(1.0, 0.98, 0.65), exp(-p.x * p.x * 80.0)) * 1.6;
	ALPHA = clamp(mask * opacity, 0.0, 1.0);
}
