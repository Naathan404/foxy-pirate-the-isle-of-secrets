shader_type canvas_item;

// Flattens an icon to a single color so undiscovered entries show only their shape.
uniform vec4 silhouette_color : source_color = vec4(0.2, 0.17, 0.19, 1.0);

void fragment() {
	vec4 icon = texture(TEXTURE, UV);
	COLOR = vec4(silhouette_color.rgb, icon.a * silhouette_color.a * COLOR.a);
}
