shader_type canvas_item;

uniform vec4 edge_color : source_color = vec4(0.8, 0.025, 0.015, 1.0);
uniform float edge_start : hint_range(0.0, 1.0) = 0.35;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = abs(UV * 2.0 - 1.0);
	float edge = smoothstep(edge_start, 1.0, max(centered.x, centered.y));
	COLOR = vec4(edge_color.rgb, edge * edge_color.a * strength);
}
