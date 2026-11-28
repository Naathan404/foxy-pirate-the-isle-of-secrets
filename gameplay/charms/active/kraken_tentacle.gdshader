shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// UV.x: signed distance from the spine, UV.y: distance from the tip (both in metres), so the
// painted features travel with the flesh while it grows out of the ground.
// UV2.x: half width of the flesh, UV2.y: how far the red fringe may flare past it.

uniform vec3 rim_color : source_color = vec3(0.97, 0.045, 0.17);
uniform vec3 rim_shade_color : source_color = vec3(0.6, 0.0, 0.15);
uniform vec3 ink_color : source_color = vec3(0.055, 0.0, 0.028);
uniform vec3 flesh_color : source_color = vec3(0.29, 0.004, 0.095);
uniform vec3 sucker_color : source_color = vec3(0.93, 0.06, 0.19);
uniform float sucker_spacing_meters = 0.42;
uniform float sucker_side = 1.0;
uniform float flame_phase = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

float ellipse(vec2 p, vec2 radius) {
	return length(p / radius) - 1.0;
}

void fragment() {
	float x = UV.x;
	float along = UV.y;
	float core = UV2.x;
	float margin = UV2.y;
	float side = x < 0.0 ? -1.0 : 1.0;
	float outside = abs(x) - core;

	// Torn, hand-painted flames: two rows of hooked teeth crawling from root to tip.
	float crawl = along + TIME * 0.55 + side * 0.17 + flame_phase;
	float wobble = noise(vec2(crawl * 3.1, side * 4.0 + flame_phase));
	float tooth = fract(crawl * 3.3 + wobble * 0.9 - max(outside, 0.0) * 2.2);
	float big_tooth = pow(1.0 - tooth, 1.7) * (0.45 + 0.55 * noise(vec2(crawl * 1.7, side)));
	float small_tooth = pow(abs(fract(crawl * 7.9 + wobble) * 2.0 - 1.0), 3.0) * 0.3;
	float reach = margin * clamp(0.18 + big_tooth + small_tooth, 0.0, 1.0);
	if (outside > reach) {
		discard;
	}

	float rim_inset = 0.025 + 0.04 * noise(vec2(along * 6.0 - TIME * 2.0, side * 9.0));
	vec3 color;
	if (outside > -rim_inset) {
		float outer = smoothstep(0.0, max(reach, 0.001), outside);
		color = mix(rim_color, rim_shade_color, step(0.62, outer));
	} else {
		float across = x / max(core, 0.001) * sucker_side;
		float brush = noise(vec2(x * 9.0, along * 4.0 + flame_phase));
		color = mix(ink_color, flesh_color, step(0.5, across * 0.75 + brush * 0.55));

		float row = floor(along / sucker_spacing_meters);
		float size = min(core * 0.46, sucker_spacing_meters * 0.46) * (0.82 + 0.3 * hash(vec2(row)));
		vec2 center = vec2(
			sucker_side * core * (0.3 + 0.1 * hash(vec2(row, 3.0))),
			(row + 0.5) * sucker_spacing_meters
		);
		vec2 local = vec2(x, along) - center;
		float tilt = sucker_side * (0.35 + 0.25 * hash(vec2(row, 7.0)));
		local = mat2(vec2(cos(tilt), sin(tilt)), vec2(-sin(tilt), cos(tilt))) * local;
		if (size > 0.035 && along > 0.28) {
			vec2 radius = vec2(size, size * 0.74);
			if (ellipse(local, radius * 1.3) < 0.0) {
				color = ink_color;
			}
			if (ellipse(local, radius) < 0.0) {
				color = sucker_color;
			}
			if (ellipse(local, radius * vec2(0.62, 0.5)) < 0.0) {
				color = rim_shade_color;
			}
			if (ellipse(local, radius * vec2(0.55, 0.14)) < 0.0) {
				color = ink_color;
			}
		}
	}

	ALBEDO = mix(color, vec3(1.0, 0.82, 0.8), flash);
}
