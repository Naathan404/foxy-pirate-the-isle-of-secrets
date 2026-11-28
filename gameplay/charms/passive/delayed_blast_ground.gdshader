shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Ground warning of a delayed charm blast (Shadow Renment, Death Bloom). The rim always marks
// the full blast radius; a fill spreads from the centre to the rim as the fuse burns, blinking
// faster near the end. `burst` then throws the rim outwards and fades everything.

uniform vec4 tint : source_color = vec4(0.65, 0.32, 1.0, 1.0);
// 0 = shadow (smoky swirl), 1 = bloom (petals).
uniform int kind = 0;
// Fuse progress, 0 at planting, 1 at detonation.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Explosion progress, 0 until detonation, then 0 to 1.
uniform float burst : hint_range(0.0, 1.0) = 0.0;
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

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * quad_overscan;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float alive = 1.0 - burst;

	// Blink speeds up as the fuse runs out.
	float blink = 0.65 + 0.35 * sin(TIME * mix(7.0, 26.0, progress * progress));

	// Rim: the whole blast area, readable from the first frame.
	float rim = ring(r, 1.0, 0.045) * (0.55 + 0.45 * blink);

	// Fill spreading outwards with a bright leading edge.
	float front = progress;
	float fill = (1.0 - smoothstep(front - 0.02, front + 0.02, r)) * 0.22;
	float edge = ring(r, front, 0.05) * 0.8 * step(0.02, front);

	float pattern = 0.0;
	if (kind == 0) {
		// Smoke swirling inwards.
		vec2 swirl = vec2(angle * 1.6 + r * 3.0 - TIME * 2.2, r * 2.5 - TIME * 0.6);
		pattern = smoothstep(0.55, 0.85, noise(swirl * 2.0)) * (1.0 - smoothstep(0.75, 1.0, r));
	} else {
		// Petals opening with the fuse.
		float bloom = pow(abs(cos(angle * float(petals) * 0.5 + TIME * 0.4)), 0.6);
		float petal_reach = mix(0.25, 0.95, progress) * bloom;
		pattern = (1.0 - smoothstep(petal_reach - 0.06, petal_reach, r)) * 0.8;
		pattern *= smoothstep(0.08, 0.2, r);
	}
	pattern *= 0.45 * (0.6 + 0.4 * blink) * step(r, 1.0);

	// Detonation: the rim races outwards and the whole disc flashes.
	float shock = ring(r, 1.0 + burst * 0.4, 0.06 + burst * 0.1) * (1.0 - burst) * step(0.001, burst);
	float flash = (1.0 - smoothstep(0.0, 1.0, r)) * (1.0 - smoothstep(0.0, 0.35, burst))
		* step(0.001, burst);

	// Painted over the sand, not added to it, so it reads on bright ground: a shadow pool is
	// darker than the tint, petals and every bright line lighter.
	vec3 body = kind == 0 ? tint.rgb * 0.35 : tint.rgb * 0.9;
	vec3 bright = mix(tint.rgb, vec3(1.0), 0.45);
	float lines = clamp(rim + edge + shock * 1.6, 0.0, 1.0);
	float wash = clamp((fill * 1.6 + pattern * 1.4) * alive, 0.0, 1.0);
	vec3 colour = mix(body, bright, lines);
	colour = mix(colour, vec3(1.0), clamp(flash, 0.0, 1.0) * 0.7);
	ALBEDO = colour;
	ALPHA = clamp(max(lines * (alive + shock), wash) + flash * 0.85, 0.0, 0.95);
}
