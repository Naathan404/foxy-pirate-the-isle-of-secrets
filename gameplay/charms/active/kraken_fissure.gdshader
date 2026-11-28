shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never;

// UV.x: metres along the march, UV.y: signed metres across it.

uniform vec3 ink_color : source_color = vec3(0.036, 0.0, 0.018);
uniform vec3 rim_color : source_color = vec3(0.98, 0.05, 0.17);
uniform vec3 glow_color : source_color = vec3(0.55, 0.0, 0.15);
uniform float length_meters = 8.0;
uniform float half_width_meters = 0.74;
uniform float revealed_meters = 0.0;
uniform float openness : hint_range(0.0, 1.0) = 1.0;

float hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

// Straight segments between random heights: broken stone has corners, not curves.
float jagged(float x) {
	return mix(hash(floor(x)), hash(floor(x) + 1.0), fract(x));
}

void fragment() {
	float along = UV.x;
	float across = UV.y;
	float side = across < 0.0 ? 17.0 : 53.0;
	if (along > revealed_meters) {
		discard;
	}
	float ends = smoothstep(0.0, 0.9, along) * smoothstep(0.0, 0.9, length_meters - along);
	float tip = smoothstep(0.0, 0.7, revealed_meters - along);
	float wander = (jagged(along * 1.6 + 3.0) - 0.5) * 0.22;
	float offset = abs(across - wander);
	float teeth = jagged(along * 3.4 + side) * 0.5 + jagged(along * 8.5 + side) * 0.22;
	float spike = pow(max(0.0, 1.0 - abs(fract(along * 1.35 + side * 0.37) - 0.5) * 4.0), 2.0);
	float hole = half_width_meters * (0.34 + teeth * 0.55 + spike * 0.55) * ends * tip * openness;
	float rim = 0.075 * openness * min(1.0, ends * 3.0);
	float halo = 0.34;

	if (offset < hole) {
		ALBEDO = ink_color;
		ALPHA = 0.97;
	} else if (offset < hole + rim) {
		ALBEDO = rim_color * (0.85 + 0.15 * sin(TIME * 11.0 + along * 4.0));
		ALPHA = 1.0;
	} else {
		float fade = 1.0 - clamp((offset - hole - rim) / halo, 0.0, 1.0);
		ALBEDO = glow_color;
		ALPHA = fade * fade * 0.6 * ends * openness;
	}
}
