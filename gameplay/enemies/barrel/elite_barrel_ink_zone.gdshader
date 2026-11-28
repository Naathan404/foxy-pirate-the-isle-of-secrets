shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// A flat disc on the ground, used three ways: the filling danger warning, the ink shockwave
// that rolls out of a blast, and the pool it leaves behind. UV maps the full radius to 0..1.

uniform int mode = 0; // 0 warning, 1 shockwave, 2 pool
uniform vec4 ink_color : source_color = vec4(0.45, 0.14, 0.27, 1.0);
uniform vec4 deep_color : source_color = vec4(0.19, 0.05, 0.13, 1.0);
uniform vec4 danger_color : source_color = vec4(1.0, 0.25, 0.36, 1.0);
uniform vec4 foam_color : source_color = vec4(0.93, 0.62, 0.68, 1.0);
// Fill for the warning, front position for the shockwave; 0..1.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// Half angle of the covered cone around local +Z; PI covers the whole disc.
uniform float half_arc = 3.14159265;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	// PlaneMesh UV.y grows toward local +Z.
	float angle = atan(p.x, p.y);
	if (r > 1.0 || abs(angle) > half_arc) {
		discard;
	}
	vec2 around = vec2(cos(angle), sin(angle));
	float ragged = noise(around * 7.0 + seed) * 0.6 + noise(around * 19.0 - seed) * 0.4;
	float side = half_arc < 3.1 ? (half_arc - abs(angle)) * r : 1.0;
	vec3 color = ink_color.rgb;
	float alpha = 0.0;

	if (mode == 0) {
		float rim = smoothstep(0.92, 0.95, r) * (1.0 - smoothstep(0.985, 1.0, r));
		rim = max(rim, (1.0 - smoothstep(0.012, 0.03, side)) * step(0.12, r));
		float filled = 1.0 - smoothstep(progress - 0.025, progress, r);
		float front = exp(-pow((r - progress) * 34.0, 2.0));
		float bubble = smoothstep(0.62, 0.8, noise(p * 7.0 + vec2(0.0, -TIME * 2.2)));
		float blink = 0.8 + 0.2 * sin(TIME * mix(8.0, 26.0, progress));
		color = mix(deep_color.rgb, ink_color.rgb, bubble);
		color = mix(color, danger_color.rgb, max(rim, front));
		alpha = max(0.24 + filled * 0.34 + bubble * filled * 0.2, max(rim * blink, front * 0.9));
	} else if (mode == 1) {
		float front = progress * (0.9 + ragged * 0.1);
		float body = smoothstep(front - 0.34, front - 0.06, r) * (1.0 - step(front, r));
		float crest = smoothstep(front - 0.07, front - 0.035, r) * (1.0 - step(front, r));
		color = mix(deep_color.rgb, ink_color.rgb, smoothstep(front - 0.24, front, r));
		color = mix(color, foam_color.rgb, crest);
		alpha = max(body * 0.92, crest);
	} else {
		float edge = 0.62 + ragged * 0.3;
		float blob = 1.0 - smoothstep(edge - 0.025, edge, r);
		float rim = smoothstep(edge - 0.1, edge - 0.025, r) * blob;
		float gloss = smoothstep(0.68, 0.74, noise(p * 5.0 + seed)) * blob;
		color = mix(ink_color.rgb, deep_color.rgb, rim);
		color = mix(color, foam_color.rgb, gloss * 0.45);
		alpha = blob * 0.78;
	}

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0) * opacity;
}
