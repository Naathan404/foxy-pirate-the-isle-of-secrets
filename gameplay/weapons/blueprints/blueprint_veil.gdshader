shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shadow_color : source_color = vec4(0.012, 0.026, 0.045, 1.0);
uniform float center_opacity = 0.22;
uniform float edge_opacity = 0.85;
uniform float inner_radius = 0.12;
uniform float outer_radius = 0.65;

void fragment() {
	float edge = smoothstep(inner_radius, outer_radius, length(UV - vec2(0.5, 0.42)));
	COLOR = vec4(shadow_color.rgb, mix(center_opacity, edge_opacity, edge) * strength);
}
