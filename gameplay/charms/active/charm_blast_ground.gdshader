shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Ground area of a charm blast. The rim always marks the full radius; a fill spreads from the
// centre to the rim as `progress` runs (a fuse burning or a charge building), blinking faster
// near the end. `burst` throws the rim outwards as a shockwave and flashes the disc; `fade`
// takes the whole thing away without an explosion.

uniform vec4 tint : source_color = vec4(0.65, 0.32, 1.0, 1.0);
// 0 shadow (smoky swirl), 1 bloom (petals), 2 gold (sun rays), 3 tide (inward spiral),
// 4 spark (no pattern: plain rim, used for bursts).
uniform int kind = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform int petals = 6;
// The quad is larger than the radius so the burst ring has room to grow.
uniform float quad_overscan = 1.45;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float ring(float r, float at, float width) {
	return exp(-pow((r - at) / width, 2.0));
}

float pattern_for(float r, float angle) {
	if (kind == 0) {
		vec2 swirl = vec2(angle * 1.6 + r * 3.0 - TIME * 2.2, r * 2.5 - TIME * 0.6);
		return smoothstep(0.55, 0.85, noise(swirl * 2.0)) * (1.0 - smoothstep(0.75, 1.0, r));
	}
	if (kind == 1) {
		float bloom = pow(abs(cos(angle * float(petals) * 0.5 + TIME * 0.4)), 0.6);
		float reach = mix(0.25, 0.95, progress) * bloom;
		return (1.0 - smoothstep(reach - 0.06, reach, r)) * 0.8 * smoothstep(0.08, 0.2, r);
	}
	if (kind == 2) {
		// Sun rays turning slowly, and a dashed ring of runes halfway out.
		float rays = pow(abs(cos(angle * 6.0 + TIME * 0.7)), 14.0) * smoothstep(0.12, 0.3, r);
		float dashes = step(0.5, fract(angle * 6.0 / 3.14159 + TIME * 0.5));
		float runes = ring(r, 0.62, 0.025) * dashes;
		return (rays * 0.75 + runes) * (1.0 - smoothstep(0.85, 1.0, r));
	}
	if (kind == 3) {
		// Three arms of water spiralling into the eye.
		float arms = pow(max(0.0, sin(angle * 3.0 + r * 9.0 + TIME * 6.0)), 5.0);
		float foam = smoothstep(0.6, 0.9, noise(vec2(angle * 3.0 + TIME * 3.0, r * 8.0)));
		return (arms * 1.6 + foam * arms * 0.6) * smoothstep(0.06, 0.2, r)
			* (1.0 - smoothstep(0.9, 1.0, r));
	}
	return 0.0;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * quad_overscan;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float alive = 1.0 - burst;

	float blink = 0.65 + 0.35 * sin(TIME * mix(7.0, 26.0, progress * progress));
	float rim = ring(r, 1.0, 0.045) * (0.55 + 0.45 * blink);
	float fill = (1.0 - smoothstep(progress - 0.02, progress + 0.02, r)) * 0.22;
	float edge = ring(r, progress, 0.05) * 0.8 * step(0.02, progress);
	float pattern = pattern_for(r, angle) * 0.45 * (0.6 + 0.4 * blink) * step(r, 1.0);

	float shock = ring(r, 1.0 + burst * 0.4, 0.06 + burst * 0.1) * (1.0 - burst) * step(0.001, burst);
	float flash = (1.0 - smoothstep(0.0, 1.0, r)) * (1.0 - smoothstep(0.0, 0.35, burst))
		* step(0.001, burst);

	// Painted over the ground, not added to it, so it reads on bright sand: a shadow pool is
	// darker than the tint, every bright line lighter.
	vec3 body = kind == 0 ? tint.rgb * 0.35 : (kind == 3 ? tint.rgb * 0.45 : tint.rgb * 0.9);
	vec3 bright = mix(tint.rgb, vec3(1.0), 0.45);
	float lines = clamp(rim + edge + shock * 1.6, 0.0, 1.0);
	float wash = clamp((fill * 1.6 + pattern * 1.4) * alive, 0.0, 1.0);
	vec3 colour = mix(body, bright, lines);
	colour = mix(colour, vec3(1.0), clamp(flash, 0.0, 1.0) * 0.7);
	ALBEDO = colour;
	ALPHA = clamp(max(lines * (alive + shock), wash) + flash * 0.85, 0.0, 0.95) * fade;
}
