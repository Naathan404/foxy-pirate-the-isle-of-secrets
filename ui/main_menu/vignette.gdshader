shader_type canvas_item;

// Dark edges with a slow red pulse low on the screen, like lantern light on the waves.
uniform vec4 shade_color : source_color = vec4(0.02, 0.01, 0.015, 1.0);
uniform float edge_strength = 0.75;
uniform float inner_radius = 0.35;
uniform float outer_radius = 0.95;
uniform vec4 glow_color : source_color = vec4(0.85, 0.2, 0.24, 1.0);
uniform float glow_strength = 0.16;
uniform float pulse_speed = 0.8;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(1.25, 1.0);
	float edge = smoothstep(inner_radius, outer_radius, length(centered));
	float pulse = 0.65 + 0.35 * sin(TIME * pulse_speed);
	float low = smoothstep(0.45, 1.0, UV.y);
	vec3 color = mix(shade_color.rgb, glow_color.rgb, low * pulse * glow_strength / max(edge_strength, 0.01));
	float alpha = edge * edge_strength + low * pulse * glow_strength * 0.5;
	COLOR = vec4(color, clamp(alpha, 0.0, 1.0));
}
