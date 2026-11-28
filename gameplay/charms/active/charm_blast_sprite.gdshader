shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Camera-facing shapes for the delayed charm blasts, drawn from UV so no texture is needed:
// 0 = shadow shard (thin diamond), 1 = petal (teardrop), 2 = flower that opens with `open`.
// Particles tint it through COLOR (their colour ramp); the flower uses `tint`.

uniform int shape = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 ink : source_color = vec4(0.1, 0.03, 0.08, 1.0);
uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform int petals = 6;
uniform bool billboard_particles = true;

void vertex() {
	if (billboard_particles) {
		// Particle billboard keeping the particle's spin and scale.
		mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		face = face * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
			vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		float size = length(MODEL_MATRIX[0].xyz);
		face[0] *= size;
		face[1] *= size;
		MODELVIEW_MATRIX = VIEW_MATRIX * face;
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

// Signed coverage helpers: >0 inside.
float shard(vec2 p) {
	// Thin diamond pointing up and down.
	return 1.0 - (abs(p.x) * 3.2 + abs(p.y) * 1.05);
}

float petal(vec2 p) {
	// Teardrop: round bottom, pointed top.
	p.y += 0.15;
	float width = 0.55 * (1.0 - smoothstep(-0.6, 0.9, p.y)) + 0.05;
	return 1.0 - length(vec2(p.x / max(width, 0.05), p.y * 1.15));
}

float flower(vec2 p, out float centre) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float reach = mix(0.28, 0.95, open);
	float lobes = pow(abs(cos(a * float(petals) * 0.5)), 0.5);
	centre = 1.0 - smoothstep(0.16, 0.2, r);
	return max(reach * lobes - r, centre * 0.3);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float body;
	float centre = 0.0;
	if (shape == 0) {
		body = shard(p);
	} else if (shape == 1) {
		body = petal(p);
	} else {
		body = flower(p, centre);
	}
	float fill = smoothstep(0.0, 0.04, body);
	// A darker rim gives every shape the ink outline of the painted props.
	float inner = smoothstep(0.04, 0.08, body);
	vec4 colour = shape == 2 ? tint : COLOR;
	vec3 lit = mix(colour.rgb * 1.35, vec3(1.0, 0.95, 0.85), centre * 0.8);
	ALBEDO = mix(ink.rgb, lit, inner);
	ALPHA = fill * colour.a;
}
