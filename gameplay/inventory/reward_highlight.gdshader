shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// One shader for both parts of a special reward's halo: the standing beam and the ground ring.

uniform vec4 tint : source_color = vec4(1.0, 0.76, 0.25, 1.0);
uniform bool ground_ring = false;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Runs from 0 to 1 once while the landing shockwave spreads.
uniform float burst : hint_range(0.0, 1.0) = 1.0;

float hash(float n) {
	return fract(sin(n * 78.233) * 43758.5453);
}

float ring_alpha(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float rim = exp(-pow((radius - 0.46) * 22.0, 2.0));
	float rays = pow(max(0.0, cos(angle * 8.0 + TIME * 1.6)), 10.0);
	rays *= smoothstep(0.8, 0.45, radius) * smoothstep(0.18, 0.45, radius);
	float glow = exp(-radius * radius * 7.0) * 0.45;
	float wave = exp(-pow((radius - mix(0.2, 0.96, burst)) * 16.0, 2.0)) * (1.0 - burst);
	return (rim * 0.8 + rays * 0.55 + glow + wave * 1.5) * smoothstep(1.0, 0.9, radius);
}

float beam_alpha(vec2 uv) {
	float across = uv.x * 2.0 - 1.0;
	float height = 1.0 - uv.y;
	float column = exp(-across * across * 9.0) * pow(max(0.0, 1.0 - height), 1.2) * 1.35;
	column *= 0.55 + 0.1 * sin(TIME * 3.0 + height * 9.0);
	// Thin sparks drifting up inside the column.
	float lane = floor(uv.x * 9.0);
	float rise = fract(height * 1.4 - TIME * (0.45 + 0.35 * hash(lane)) + hash(lane + 4.0));
	vec2 spark_at = vec2((fract(uv.x * 9.0) - 0.5) * 2.4, (rise - 0.5) * 14.0);
	float spark = max(0.0, 1.0 - length(spark_at)) * (1.0 - height) * step(abs(across), 0.75);
	return (column + spark * 1.3) * smoothstep(0.0, 0.07, height) * (1.0 + (1.0 - burst) * 0.8);
}

void fragment() {
	float alpha = ground_ring ? ring_alpha(UV) : beam_alpha(UV);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.96, 0.88), clamp(alpha - 0.7, 0.0, 0.8)) * 1.5;
	ALPHA = clamp(alpha, 0.0, 1.0) * strength * tint.a;
}
