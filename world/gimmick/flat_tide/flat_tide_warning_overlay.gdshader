shader_type canvas_item;

// Red glow on each screen edge a tide will come from (one per direction, up to 4). Driven by
// FlatTideWarningOverlay; `pulse` and `flow_phase` advance with the tide clock so pausing
// freezes the warning.

const int MAX_DIRECTIONS = 4;

uniform vec4 warning_color : source_color = vec4(0.95, 0.1, 0.06, 1.0);
// Screen-space directions (y down) pointing at the edges the water comes from.
uniform vec2 directions[MAX_DIRECTIONS];
// Strength of each direction; 0 disables that slot.
uniform float strengths[MAX_DIRECTIONS];
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.05, 1.0) = 0.38;
uniform float flow_phase = 0.0;
uniform float band_count = 5.0;
uniform float band_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float alpha = 0.0;
	for (int i = 0; i < MAX_DIRECTIONS; i++) {
		if (strengths[i] <= 0.0) {
			continue;
		}
		vec2 dir = normalize(directions[i] + vec2(0.00001));
		// 1 on the warned edge (or corner, for diagonal directions), falling off inward.
		float edge = dot(p, dir) / (abs(dir.x) + abs(dir.y));
		float glow = smoothstep(1.0 - edge_width, 1.0, edge);
		glow *= glow;
		// Soft bands travel inward so the direction reads even in a still frame.
		float bands = 0.5 + 0.5 * sin((1.0 - edge) * band_count * TAU - flow_phase);
		glow *= 1.0 - band_strength + band_strength * bands;
		// Separate edges never merge into one blob: take the strongest, not the sum.
		alpha = max(alpha, glow * strengths[i]);
	}
	alpha *= mix(0.55, 1.0, pulse);
	COLOR = vec4(warning_color.rgb, clamp(alpha, 0.0, 1.0));
}
