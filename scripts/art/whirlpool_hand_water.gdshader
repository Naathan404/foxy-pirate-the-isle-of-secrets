shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float core = 0.64 * (1.0 - burst) * (1.0 + 0.045 * sin(3.0 * angle - phase));
	float body = 1.0 - smoothstep(core - 0.035, core, r);
	float rim = smoothstep(core * 0.75, core * 0.91, r);
	float edge = smoothstep(core * 0.91, core, r);
	float curl = sin(2.0 * angle + r * 9.0 - phase);
	float foam = smoothstep(0.80, 0.98, curl) * smoothstep(0.08, 0.24, r);

	vec3 ink = vec3(0.055, 0.22, 0.32);
	vec3 sea = mix(vec3(0.025, 0.34, 0.60), vec3(0.08, 0.78, 0.90),
		clamp(0.54 - 0.42 * p.y + 0.27 * curl, 0.0, 1.0));
	vec3 color = mix(sea, vec3(0.71, 0.99, 1.0), max(foam * 0.92, rim));
	color = mix(color, ink, edge);
	float glint = 1.0 - smoothstep(0.04, 0.13, length(p - vec2(-0.21, -0.28)));
	color = mix(color, vec3(0.94, 1.0, 1.0), glint);

	float spray = 0.0;
	for (int i = 0; i < 4; i++) {
		float a = float(i) * 1.5708 + phase * 0.65;
		vec2 radial = vec2(cos(a), sin(a));
		float orbit = 0.74 + 0.15 * burst + 0.04 * sin(phase + float(i));
		vec2 d = p - radial * orbit;
		vec2 drop = vec2(dot(d, radial), dot(d, vec2(-radial.y, radial.x)) * 0.62);
		spray = max(spray, 1.0 - smoothstep(0.032, 0.085, length(drop)));
	}
	COLOR = vec4(mix(color, vec3(0.66, 0.98, 1.0), spray),
		max(body * (1.0 - burst), spray * (1.0 - burst * burst)));
}
