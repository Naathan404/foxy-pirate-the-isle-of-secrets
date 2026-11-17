shader_type canvas_item;
render_mode unshaded;

uniform float unfold : hint_range(0.0, 1.0) = 0.0;
uniform float sweep : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink_light : source_color = vec4(1.0, 0.84, 0.47, 1.0);
uniform float folded_width = 0.42;
uniform float crease_depth = 0.13;
uniform float sweep_width = 0.07;
uniform float sweep_brightness = 0.8;
uniform float drafting_spacing = 22.0;
uniform float drafting_brightness = 0.18;

void fragment() {
	vec4 modulation = COLOR;
	float width = mix(folded_width, 1.0, unfold);
	vec2 paper_uv = vec2((UV.x - 0.5) / width + 0.5, UV.y);
	vec4 paper = texture(TEXTURE, paper_uv);
	float edge = step(0.0, paper_uv.x) * step(paper_uv.x, 1.0);
	float crease = cos(paper_uv.x * TAU * 3.0) * (1.0 - unfold) * crease_depth;
	float sweep_position = mix(-0.2, 1.4, sweep);
	float light = exp(-pow((paper_uv.x + paper_uv.y * 0.35 - sweep_position) / sweep_width, 2.0));
	light *= sin(sweep * PI);
	vec2 grid = abs(fract(paper_uv * drafting_spacing) - 0.5);
	float drafting = (1.0 - smoothstep(0.015, 0.055, min(grid.x, grid.y)));
	paper.rgb *= 1.0 - crease;
	paper.rgb += ink_light.rgb * light * (sweep_brightness + drafting * drafting_brightness);
	COLOR = vec4(paper.rgb, paper.a * edge) * modulation;
}
