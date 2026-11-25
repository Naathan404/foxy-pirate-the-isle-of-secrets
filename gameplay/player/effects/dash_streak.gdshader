shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 streak_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// UV.x runs from the faded tail (0) to the bright head (1); UV.y across the width.
	float along = smoothstep(0.0, 0.85, UV.x);
	float across = pow(clamp(1.0 - abs(UV.y - 0.5) * 2.0, 0.0, 1.0), 1.6);
	ALBEDO = streak_color.rgb;
	ALPHA = clamp(along * across * 1.6, 0.0, 1.0) * strength * streak_color.a;
}
