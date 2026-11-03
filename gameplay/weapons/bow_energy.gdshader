shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// Shape 0: halo, 1: glint, 2: particle, 3: bloom, 4: ribbon, 5: impact cut.
uniform int shape = 0;
uniform bool billboard = true;
uniform vec4 glow_color : source_color = vec4(0.16, 0.65, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float phase = 0.0;
uniform float billboard_rotation = 0.0;
uniform float aspect = 1.0;
uniform float ring_radius = 0.7;
uniform float ring_width = 0.035;
uniform float arc_frequency = 3.0;
uniform float arc_breakup : hint_range(0.0, 1.0) = 0.65;
uniform float glow_softness = 0.13;
uniform float core_sharpness = 180.0;
uniform float ray_sharpness = 35.0;
uniform float brightness = 1.0;

void vertex() {
	if (billboard) {
		float angle_cos = cos(billboard_rotation);
		float angle_sin = sin(billboard_rotation);
		VERTEX.xy = mat2(vec2(angle_cos, angle_sin), vec2(-angle_sin, angle_cos)) * VERTEX.xy;
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float c = cos(phase);
	float s = sin(phase);
	p = mat2(vec2(c, -s), vec2(s, c)) * p;
	float radius = length(p);
	float core = 0.0;
	float halo = 0.0;
	if (shape == 0) {
		p.y /= max(aspect, 0.1);
		float distance_to_ring = abs(length(p) - ring_radius);
		float arcs = mix(1.0, smoothstep(-0.5, 0.7,
			sin(atan(p.y, p.x) * arc_frequency)), arc_breakup);
		core = (1.0 - smoothstep(ring_width * 0.25, ring_width, distance_to_ring)) * arcs;
		halo = exp(-pow(distance_to_ring / max(glow_softness, 0.001), 2.0)) * arcs;
	} else if (shape == 1) {
		float rays = exp(-min(abs(p.x), abs(p.y)) * ray_sharpness);
		core = rays * pow(max(0.0, 1.0 - radius), 2.0);
		halo = exp(-dot(p, p) * 12.0);
		core += exp(-dot(p, p) * core_sharpness);
	} else if (shape == 2) {
		float diamond = abs(p.x) + abs(p.y) * aspect;
		core = pow(max(0.0, 1.0 - diamond), 2.0);
		halo = exp(-dot(p, p) * 8.0) * 0.4;
	} else if (shape == 3) {
		halo = exp(-dot(p, p) * 6.0) * pow(max(0.0, 1.0 - radius), 2.0);
	} else if (shape == 5) {
		float length_fade = pow(max(0.0, 1.0 - abs(p.x)), 0.65);
		core = (1.0 - smoothstep(ring_width * 0.25, ring_width, abs(p.y))) * length_fade;
		halo = exp(-pow(p.y / max(glow_softness, 0.001), 2.0)) * length_fade;
	} else {
		// Ribbon has camera-facing geometry and UVs running from tail to arrowhead.
		float across = UV.y * 2.0 - 1.0;
		float ends = smoothstep(0.0, 0.22, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
		core = exp(-across * across * core_sharpness) * ends;
		halo = exp(-across * across / max(glow_softness, 0.001)) * ends;
	}
	float edge = 1.0 - smoothstep(0.85, 1.0, radius);
	if (shape == 4) { edge = 1.0; }
	float alpha = (core + halo * 0.45) * edge * opacity * COLOR.a;
	vec3 rim_color = shape == 4 ? COLOR.rgb : glow_color.rgb;
	ALBEDO = mix(rim_color, core_color.rgb, clamp(core, 0.0, 1.0)) * brightness;
	ALPHA = clamp(alpha, 0.0, 1.0) * glow_color.a;
}
