shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 crust_rim_color : source_color = vec4(0.11, 0.14, 0.04, 1.0);
uniform vec4 deep_toxin_color : source_color = vec4(0.22, 0.44, 0.06, 1.0);
uniform vec4 mid_acid_color : source_color = vec4(0.64, 0.96, 0.14, 1.0);
uniform vec4 hot_core_color : source_color = vec4(1.0, 0.94, 0.34, 1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 1.0, 0.84, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.92;
uniform float fade_progress : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_boost : hint_range(0.0, 1.5) = 0.0;
uniform float seed_offset = 0.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(41.3, 19.7)));
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise2(p);
		p = p * 2.07 + vec2(11.3, 7.1);
		a *= 0.5;
	}
	return v;
}

// Tạo các bọt khí axit sôi phình to, có viền sáng + điểm lóe specular rồi vỡ tan.
vec2 boiling_bubbles(vec2 uv_coord, float scale_grid, float speed, float offset_seed) {
	vec2 g = uv_coord * scale_grid;
	vec2 id = floor(g);
	vec2 local = fract(g) - vec2(0.5);
	float rnd = hash21(id + vec2(offset_seed));
	if (rnd < 0.35) {
		return vec2(0.0);
	}
	vec2 jitter = (hash22(id + vec2(offset_seed * 1.3)) - vec2(0.5)) * 0.42;
	float life = fract(TIME * speed * (0.65 + rnd * 0.6) + rnd * 13.7);
	float radius = mix(0.05, 0.36, pow(life, 0.65));
	float fade_life = smoothstep(0.0, 0.14, life) * (1.0 - smoothstep(0.76, 1.0, life));

	vec2 delta = local - jitter;
	float d = length(delta);
	float ring = smoothstep(radius, radius - 0.055, d) * smoothstep(radius - 0.13, radius - 0.045, d);
	float body = smoothstep(radius, radius - 0.06, d) * 0.48;
	float spec = smoothstep(radius * 0.36, 0.0, length(delta - vec2(-radius * 0.28, -radius * 0.28)));
	return vec2((ring * 0.85 + body) * fade_life, spec * fade_life);
}

float star_sparkles(vec2 uv_coord, float scale_grid, float offset_seed) {
	vec2 g = uv_coord * scale_grid;
	vec2 id = floor(g);
	vec2 local = fract(g) - vec2(0.5);
	float rnd = hash21(id + vec2(offset_seed));
	if (rnd < 0.58) {
		return 0.0;
	}
	vec2 jitter = (hash22(id * 1.9 + offset_seed) - vec2(0.5)) * 0.55;
	float d = length(local - jitter);
	float twinkle = 0.5 + 0.5 * sin(TIME * 6.2 + rnd * 29.0);
	return smoothstep(0.18, 0.015, d) * pow(twinkle, 2.4);
}

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float r = length(centered);
	if (r > 1.0) {
		discard;
	}

	float angle = atan(centered.y, centered.x);
	float lobe_wave = sin(angle * 5.0 + seed_offset) * 0.058
		+ sin(angle * 8.0 - seed_offset * 1.9 + TIME * 0.45) * 0.032;
	float edge_warp = (fbm(centered * 3.1 + vec2(seed_offset, -seed_offset)) - 0.5) * 0.16;
	float shape_dist = r - (lobe_wave + edge_warp);

	// Giọt bắn phụ nhỏ quanh mép vũng độc tạo dáng loang hữu cơ.
	float drop_noise = fbm(centered * 5.8 + vec2(seed_offset * 2.1, 3.7));
	float droplets = smoothstep(0.68, 0.78, drop_noise) * smoothstep(0.95, 0.76, r) * smoothstep(0.68, 0.77, r);

	float dissolve = mix(1.06, 0.15, fade_progress);
	float main_mask = 1.0 - smoothstep(0.75 - (1.0 - fade_progress) * 0.35, 0.80 - (1.0 - fade_progress) * 0.35, shape_dist);
	float pool_mask = clamp(main_mask + droplets * fade_progress, 0.0, 1.0);
	if (pool_mask < 0.01) {
		discard;
	}

	// Viền sẫm tương phản cao (dark corrosive rim) ôm sát rìa ngoài vũng độc.
	float rim_crust = smoothstep(0.64, 0.72, shape_dist) * main_mask;
	float inner_caustic_rim = smoothstep(0.56, 0.66, shape_dist) * (1.0 - smoothstep(0.66, 0.74, shape_dist));

	// Dòng chảy dịch axit xoáy bên trong lòng vũng.
	vec2 flow_uv = world_xz * 1.45 + vec2(seed_offset, -seed_offset * 0.65);
	float warp_a = fbm(flow_uv + vec2(TIME * 0.28, -TIME * 0.22));
	float warp_b = fbm(flow_uv * 2.15 + vec2(warp_a * 1.35) + vec2(-TIME * 0.34, TIME * 0.26));
	float acid_veins = smoothstep(0.32, 0.78, warp_b);
	float ripple_wave = 0.5 + 0.5 * sin(shape_dist * 18.0 - TIME * 4.2 + warp_a * 4.5);
	float caustic_glow = smoothstep(0.58, 0.94, ripple_wave * warp_b) * (1.0 - shape_dist * 0.5);

	// 2 tầng bọt khí sôi lục-vàng đang phình lên và vỡ trên mặt vũng.
	vec2 b_large = boiling_bubbles(centered + vec2(warp_a * 0.04), 3.8, 0.55, seed_offset);
	vec2 b_small = boiling_bubbles(centered + vec2(-warp_b * 0.03), 6.4, 0.82, seed_offset + 17.3);
	float bubble_body = clamp(b_large.x + b_small.x * 0.85, 0.0, 1.2);
	float bubble_spec = clamp(b_large.y + b_small.y * 0.9, 0.0, 1.3);
	float stars = star_sparkles(centered, 6.2, seed_offset + 5.1) * (1.0 - rim_crust * 0.8);

	vec3 fluid_col = mix(deep_toxin_color.rgb, mid_acid_color.rgb, acid_veins);
	fluid_col = mix(fluid_col, hot_core_color.rgb, clamp((1.0 - shape_dist) * 0.55 + caustic_glow * 0.65 + bubble_body * 0.55, 0.0, 1.0));
	fluid_col = mix(fluid_col, crust_rim_color.rgb, clamp(rim_crust * 0.88, 0.0, 1.0));
	fluid_col = mix(fluid_col, glint_color.rgb, clamp(inner_caustic_rim * 0.45 + bubble_spec * 0.95 + stars * 0.9 + pulse_boost * 0.4, 0.0, 1.0));

	float final_alpha = clamp(pool_mask * (0.76 + rim_crust * 0.2 + bubble_body * 0.14) * opacity * fade_progress, 0.0, 0.96);
	if (final_alpha < 0.01) {
		discard;
	}
	ALBEDO = fluid_col;
	ALPHA = final_alpha;
}
