shader_type spatial;
render_mode unshaded;

uniform vec4 base_ice : source_color = vec4(0.08, 0.29, 0.60, 1.0);
uniform vec4 clear_ice : source_color = vec4(0.31, 0.85, 1.0, 1.0);
uniform vec4 frost : source_color = vec4(0.92, 1.0, 1.0, 1.0);

varying float height_fraction;

void vertex() {
	// The mesh is a unit-height, five-sided prism. Keep a broad shoulder below its point.
	height_fraction = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float shoulder = 0.60;
	float width = mix(0.68, 1.0, min(height_fraction / shoulder, 1.0));
	width *= 1.0 - smoothstep(shoulder, 1.0, height_fraction);
	VERTEX.xz *= width;
	VERTEX.x += 0.15 * height_fraction * height_fraction;
}

void fragment() {
	float flank = floor(min(UV.x, 0.9999) * 5.0);
	float across = fract(UV.x * 5.0);
	float face_light = 0.5 + 0.5 * cos(flank * 2.513 + 0.6);
	float edge = 1.0 - smoothstep(0.015, 0.065, min(across, 1.0 - across));
	float glint = 1.0 - smoothstep(0.018, 0.062,
		abs(across - (0.28 + 0.54 * height_fraction)));
	vec3 body = mix(base_ice.rgb, clear_ice.rgb, 0.22 + 0.70 * height_fraction);
	body *= 0.48 + 0.56 * face_light;
	float tip = smoothstep(0.67, 0.99, height_fraction);
	float etched = glint * smoothstep(0.2, 0.55, height_fraction) * face_light;
	ALBEDO = mix(body, frost.rgb, clamp(0.58 * edge + 0.46 * etched + 0.75 * tip, 0.0, 1.0));
}
