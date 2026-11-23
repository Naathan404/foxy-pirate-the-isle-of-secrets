shader_type canvas_item;

// Ink-spread reveal for the menu background: a noisy circle grows from the center with a
// red rim. progress 0 = hidden, 1 = fully shown.
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D noise : repeat_enable;
uniform vec4 rim_color : source_color = vec4(0.85, 0.2, 0.24, 1.0);
uniform float rim_width = 0.05;
uniform float softness = 0.06;
uniform float noise_strength = 0.35;
uniform float aspect = 1.7778;
// When true the ink sweeps in from the left edge instead of growing from the center.
uniform bool from_left = false;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float dist = length((UV - 0.5) * vec2(aspect, 1.0)) / length(vec2(aspect, 1.0) * 0.5);
	float jitter = (texture(noise, UV * 1.6).r - 0.5) * noise_strength;
	float d = (from_left ? UV.x : dist) + jitter;
	// Past progress 1 the front sits beyond every pixel, so no rim remains on screen.
	float front = progress * (1.0 + noise_strength + rim_width + softness * 2.0) - softness;
	float shown = 1.0 - smoothstep(front - softness, front, d);
	float rim = smoothstep(front - rim_width - softness, front - rim_width, d) * shown;
	COLOR = vec4(mix(base.rgb, rim_color.rgb, rim * rim_color.a), base.a * shown);
}
