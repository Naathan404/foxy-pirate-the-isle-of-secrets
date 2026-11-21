shader_type canvas_item;
render_mode blend_add;

// Soft breathing glow drawn behind the featured icon of a detail panel.
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.42, 0.5);
uniform float pulse_speed = 1.6;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	float falloff = smoothstep(0.5, 0.0, distance(UV, vec2(0.5)));
	float pulse = 1.0 - pulse_amount + pulse_amount * sin(TIME * pulse_speed);
	COLOR = vec4(glow_color.rgb, glow_color.a * falloff * falloff * pulse);
}
