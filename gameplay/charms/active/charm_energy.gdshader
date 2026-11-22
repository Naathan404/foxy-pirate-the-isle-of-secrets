shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.16, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform int style = 0;

float band(float distance_value, float width) {
	return 1.0 - smoothstep(width * 0.3, width, abs(distance_value));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float grain = sin(p.x * 63.0 + sin(p.y * 27.0)) * sin(p.y * 49.0 - phase * 22.0);
	float mask = 0.0;
	float fade = pow(1.0 - progress, 1.5);
	if (style == 0) {
		// Expanding broken shock front, hot core and outward flying splinters.
		float front = mix(0.12, 0.92, pow(progress, 0.45));
		float ring = band(r - front, 0.065) * (0.55 + 0.45 * sin(a * 11.0 + r * 23.0));
		float rays = pow(max(0.0, sin(a * 13.0 + sin(a * 5.0))), 22.0);
		float sparks = rays * band(r - front * 0.78, 0.24);
		mask = ring + sparks + exp(-r * r * 65.0) * (1.0 - progress);
	} else if (style == 1) {
		// Tapered filaments and turbulent wisps, with no rectangular silhouette.
		float taper = pow(max(0.0, sin(UV.x * 3.14159)), 0.6);
		float spine = band(p.y, 0.12 * taper + 0.004);
		float wisp = band(p.y + sin(UV.x * 22.0 - phase * 24.0) * 0.13, 0.16 * taper);
		mask = (spine + wisp * 0.4) * taper * smoothstep(0.0, 0.3, UV.x);
	} else if (style == 2) {
		// Inward rotating surf; thin foam crests expose the ground between arms.
		float spiral = sin(a * 4.0 + r * 18.0 + phase * 11.0);
		float arms = pow(max(0.0, spiral), 12.0);
		float rim = band(r - 0.86 + sin(a * 8.0 + phase * 5.0) * 0.025, 0.035);
		mask = (arms * 0.8 + rim * 0.6) * smoothstep(0.05, 0.2, r);
		mask *= 1.0 - smoothstep(0.87, 1.0, r);
	} else if (style == 3) {
		// Spectral anchor, its crossbar and curved flukes inside a broken seal.
		float stem = band(p.x, 0.035) * step(-0.48, p.y) * step(p.y, 0.42);
		float crossbar = band(p.y + 0.16, 0.035) * step(abs(p.x), 0.27);
		float eye = band(length(p - vec2(0.0, -0.4)) - 0.11, 0.03);
		float hook = band(length(p - vec2(0.0, 0.1)) - 0.4, 0.035) * step(0.16, p.y);
		float seal = band(r - 0.82, 0.025) * smoothstep(-0.5, 0.0, sin(a * 6.0 + phase));
		mask = stem + crossbar + eye + hook + seal * 0.6;
	} else if (style == 4) {
		float wave = fract(r * 2.5 + phase * 1.8);
		float rings = pow(wave, 18.0) * smoothstep(0.1, 0.65, r);
		float fire = pow(max(0.0, sin(a * 12.0 + r * 8.0 - phase * 9.0)), 14.0);
		mask = (rings + fire * r * 0.45) * (1.0 - smoothstep(0.84, 1.0, r));
	} else if (style == 5) {
		float ring = band(r - 0.9, 0.022);
		float ticks = pow(max(0.0, cos(a * 8.0)), 40.0) * band(r - 0.77, 0.09);
		float sweep = pow(max(0.0, cos(a - phase * 5.0)), 12.0) * band(r - 0.88, 0.05);
		mask = ring * 0.45 + ticks + sweep;
	} else if (style == 6) {
		// Six branching fractures open from the foot of the crystal.
		float sector = mod(a + 0.5236, 1.0472) - 0.5236;
		vec2 sector_pos = vec2(cos(sector), abs(sin(sector))) * r;
		float spine = band(sector_pos.y, mix(0.048, 0.012, r));
		float forks = band(sector_pos.y - (sector_pos.x - 0.32) * 0.64, 0.027);
		forks *= smoothstep(0.31, 0.39, sector_pos.x) * (1.0 - smoothstep(0.63, 0.78, r));
		float reach = mix(0.24, 1.03, smoothstep(0.0, 0.35, progress));
		mask = (spine + forks) * (1.0 - smoothstep(reach - 0.12, reach, r));
	} else {
		// Disconnected crystal tips leave space between telegraphs in adjacent rows.
		float sector = mod(a + 0.5236, 1.0472) - 0.5236;
		vec2 tip = vec2(cos(sector), abs(sin(sector))) * r;
		float inner = mix(0.64, 0.42, progress);
		float outline = band(tip.y - (tip.x - inner) * 0.36, 0.024);
		outline *= smoothstep(inner - 0.03, inner + 0.03, tip.x);
		outline *= 1.0 - smoothstep(0.74, 0.84, r);
		float seed = band(abs(p.x) + abs(p.y) * 0.72 - 0.10, 0.034);
		mask = outline + seed;
		fade = mix(0.46, 0.90, progress);
	}
	mask *= 0.88 + grain * 0.12;
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.98, 0.9), clamp(mask - 0.5, 0.0, 0.75)) * 1.7;
	ALPHA = clamp(mask, 0.0, 1.0) * tint.a * fade;
}
