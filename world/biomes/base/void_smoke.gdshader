shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 void_color : source_color = vec4(0.012, 0.009, 0.020, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.24, 0.19, 0.27, 1.0);
uniform float smoke_strength : hint_range(0.0, 1.0) = 0.7;
uniform float rise_speed : hint_range(0.0, 1.0) = 0.09;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise2(p) * weight;
		p = p * 2.03 + vec2(17.7, 9.2);
		weight *= 0.5;
	}
	return value;
}

void fragment() {
	// Negative world Z is higher on the camera view. Advancing the sampling
	// coordinate moves the smoke in that direction.
	vec2 p = vec2(world_xz.x * 0.22, world_xz.y * 0.115 + TIME * rise_speed);
	float bend = fbm(p * 0.7 + vec2(4.3, 12.8));
	p.x += (bend - 0.5) * 1.5;
	float broad = fbm(p);
	float detail = fbm(p * 2.2 + vec2(31.0, 7.0));
	float wisps = smoothstep(0.43, 0.70, broad * 0.78 + detail * 0.22);
	float breath = 0.82 + 0.18 * sin(TIME * 0.55 + world_xz.x * 0.15);
	ALBEDO = mix(void_color.rgb, smoke_color.rgb, wisps * smoke_strength * breath);
}
