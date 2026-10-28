shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform float energy = 1.0;
uniform int shape = 0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float mask = 0.0;
	if (shape == 0) {
		// Broken circular slash with a fine inner ring.
		float angle = atan(p.y, p.x) + phase;
		float arcs = smoothstep(-0.6, 0.2, sin(angle * 3.0));
		float ring = 1.0 - smoothstep(0.025, 0.13, abs(radius - 0.75));
		float inner = 1.0 - smoothstep(0.012, 0.045, abs(radius - 0.54));
		mask = ring * arcs + inner * 0.22;
	} else if (shape == 1) {
		// A sharp four-point glint, not an opaque square around the blade.
		float cross_shape = min(abs(p.x), abs(p.y));
		float rays = exp(-cross_shape * 38.0) * pow(max(0.0, 1.0 - radius), 2.0);
		float core = exp(-dot(p, p) * 70.0);
		mask = rays + core;
	} else if (shape == 2) {
		// Ribbon UV.x runs from the fading tail to the bright blade.
		float edge = pow(max(0.0, 1.0 - abs(p.y)), 1.7);
		float filament = exp(-p.y * p.y * 95.0);
		mask = (edge * 0.5 + filament * 0.65) * smoothstep(0.0, 0.22, UV.x);
	} else {
		// Directional cut: a hot thin blade and a shorter crossing fracture.
		float cut = exp(-p.y * p.y * 250.0) * pow(max(0.0, 1.0 - abs(p.x)), 0.45);
		float crossing = exp(-pow(p.y + p.x * 0.75, 2.0) * 180.0);
		mask = cut + crossing * max(0.0, 1.0 - radius) * 0.65;
	}
	float fade = (1.0 - progress) * (1.0 - progress);
	ALBEDO = mix(tint.rgb, vec3(1.0), clamp(mask - 0.6, 0.0, 0.65)) * energy;
	ALPHA = clamp(mask, 0.0, 1.0) * tint.a * COLOR.a * fade;
}
