shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Jagged rays from a dark pit, drawn on a flat quad lying on the ground.
uniform vec4 crack_color : source_color = vec4(0.1, 0.065, 0.04, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform int ray_count : hint_range(3, 16) = 7;
uniform float seed = 0.0;
// Ray width at the pit and at the tips, in quad-radius units.
uniform float inner_width = 0.09;
uniform float outer_width = 0.015;
uniform float pit_radius = 0.14;
// How many kinks each ray has along its length.
uniform float kink_count = 5.0;

float hash(float value) {
	return fract(sin(value * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float rays = float(ray_count);
	float k = atan(p.y, p.x) / TAU * rays + hash(0.5) * rays;
	float cell = floor(k);
	float kink = floor(r * kink_count);
	// Each segment of a ray leans a little, which reads as a crack rather than a star.
	float offset = fract(k) - 0.5 + (hash(cell * 7.0 + kink) - 0.5) * 0.35;
	float distance_to_ray = abs(offset) * TAU * r / rays;
	float width = mix(inner_width, outer_width, r);
	float ray = 1.0 - smoothstep(width * 0.5, width, distance_to_ray);
	ray *= 1.0 - smoothstep(0.0, 0.08, r - (0.55 + hash(cell) * 0.4));
	float pit = 1.0 - smoothstep(pit_radius * 0.6, pit_radius, r);
	ALBEDO = crack_color.rgb;
	ALPHA = clamp(max(ray, pit) * opacity * crack_color.a, 0.0, 1.0);
}
