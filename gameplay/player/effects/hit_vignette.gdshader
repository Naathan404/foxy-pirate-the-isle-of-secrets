shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = abs(UV * 2.0 - 1.0);
	float edge = smoothstep(0.3, 1.0, max(centered.x, centered.y));
	COLOR = vec4(0.8, 0.035, 0.015, edge * strength);
}
