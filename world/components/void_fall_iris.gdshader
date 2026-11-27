shader_type canvas_item;
// Darkness closing in on Foxy as she drops into the void: a soft circle shrinking onto her,
// its rim rippling like water closing over her, with a faint glow along the rim.

// Centre of the circle, in screen UV.
uniform vec2 center = vec2(0.5);
// Radius of the open circle, in screen heights.
uniform float radius : hint_range(0.0, 2.0) = 1.5;
uniform float softness : hint_range(0.001, 0.5) = 0.12;
// Extra darkening over the whole screen, 0 to 1.
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shade_color : source_color = vec4(0.01, 0.02, 0.06, 1.0);
uniform vec4 rim_color : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.6;
// Ripple depth as a share of the radius, so a small circle is not torn into a star.
uniform float ripple_amount : hint_range(0.0, 0.3) = 0.06;
// Whole numbers only: the waves must meet where the angle wraps around.
uniform int ripple_count : hint_range(0, 24) = 9;

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 offset = (SCREEN_UV - center) * vec2(screen_size.x / screen_size.y, 1.0);
	float distance_to_center = length(offset);
	float angle = atan(offset.y, offset.x);
	float waves = float(ripple_count);
	float ripple = sin(angle * waves + TIME * 3.0) * 0.5
		+ sin(angle * float(max(ripple_count / 2, 1)) - TIME * 2.1) * 0.5;
	float edge = radius * (1.0 + ripple * ripple_amount);
	// The soft edge narrows with the circle, so the last moments still read as a circle.
	float soft = min(softness, radius * 0.6 + 0.001);
	float shade = smoothstep(edge - soft, edge, distance_to_center);
	float alpha = max(shade, darkness);
	float rim = exp(-pow((distance_to_center - edge + soft * 0.5) / (soft * 0.35), 2.0));
	rim *= rim_strength * (1.0 - darkness) * step(0.001, radius);
	vec3 color = mix(shade_color.rgb, rim_color.rgb, clamp(rim, 0.0, 1.0));
	COLOR = vec4(color, clamp(alpha + rim * 0.5, 0.0, 1.0));
}
