shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

// Painted tropical water: world-space pixels, depth colour, moving shore foam,
// refracted shallows and restrained highlights. Optional screen-space object reflections.
uniform float pixel_size : hint_range(0.0, 0.5) = 0.16;
uniform vec4 color_deep : source_color = vec4(0.055, 0.39, 0.52, 1.0);
uniform vec4 color_mid : source_color = vec4(0.08, 0.64, 0.66, 1.0);
uniform vec4 color_shallow : source_color = vec4(0.38, 0.82, 0.73, 1.0);
uniform vec4 color_foam : source_color = vec4(0.9, 0.98, 0.91, 1.0);
uniform vec4 reflection_tint : source_color = vec4(0.49, 0.75, 0.86, 1.0);
uniform float beers_law : hint_range(0.05, 2.0) = 0.32;
uniform float depth_offset = 0.0;
uniform float deep_amount : hint_range(0.1, 3.0) = 1.0;
uniform float refraction : hint_range(0.0, 0.3) = 0.06;
uniform float foam_amount : hint_range(0.0, 0.15) = 0.045;
uniform float emission_strength : hint_range(0.0, 0.3) = 0.02;
uniform float shallow_visibility : hint_range(0.0, 0.6) = 0.24;
uniform float caustic_strength : hint_range(0.0, 0.5) = 0.12;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.2;
uniform bool object_reflections_enabled = true;
uniform float object_reflection_strength : hint_range(0.0, 1.0) = 0.45;
uniform float object_reflection_distance : hint_range(2.0, 48.0) = 24.0;
uniform int object_reflection_steps : hint_range(8, 64) = 32;
uniform float object_reflection_thickness : hint_range(0.05, 2.0) = 0.65;

uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_height : hint_range(0.0, 0.5) = 0.18;
uniform vec4 wave_a = vec4(1.0, 0.4, 0.2, 10.0);
uniform vec4 wave_b = vec4(-0.4, 0.4, 0.12, 7.0);
uniform vec4 wave_c = vec4(0.4, -1.0, 0.1, 15.0);

uniform vec2 sampler_scale = vec2(0.25, 0.25);
uniform vec2 sampler_direction = vec2(0.05, -0.04);
uniform vec2 uv_sampler_scale = vec2(0.035, 0.035);
uniform float uv_sampler_strength = 0.08;
uniform vec2 surface_size = vec2(24.0, 4.0);
uniform vec2 surface_direction = vec2(0.32, -0.18);
uniform vec2 surface_direction2 = vec2(-0.21, 0.27);
uniform float surface_exp : hint_range(1.0, 12.0) = 4.0;
uniform float surface_multiplier : hint_range(0.0, 6.0) = 1.3;
uniform int color_steps : hint_range(2, 12) = 6;

uniform sampler2D uv_sampler : filter_linear, repeat_enable;
uniform sampler2D noise_sampler : hint_default_black, filter_linear, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;

varying vec3 water_world;
varying vec3 normal_world;

vec2 pixel_grid(vec2 position) {
	float size = max(pixel_size, 0.001);
	return pixel_size > 0.0 ? (floor(position / size) + 0.5) * size : position;
}

vec3 gerstner(vec4 parameter, vec2 position, float time, inout vec3 dx, inout vec3 dz) {
	vec2 direction = parameter.xy / max(length(parameter.xy), 0.001);
	float steepness = clamp(parameter.z, -0.5, 0.5);
	float k = 6.2831853 / max(abs(parameter.w), 0.2);
	float phase = k * (dot(direction, position) - sqrt(9.8 / k) * time);
	float s = sin(phase);
	float c = cos(phase);
	float amplitude = steepness / k;
	dx += vec3(-direction.x * direction.x * steepness * s,
		direction.x * steepness * c * wave_height, -direction.x * direction.y * steepness * s);
	dz += vec3(-direction.x * direction.y * steepness * s,
		direction.y * steepness * c * wave_height, -direction.y * direction.y * steepness * s);
	return vec3(direction.x * amplitude * c, amplitude * s * wave_height, direction.y * amplitude * c);
}

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dx = vec3(1.0, 0.0, 0.0);
	vec3 dz = vec3(0.0, 0.0, 1.0);
	float time = TIME * wave_speed;
	vec3 displacement = gerstner(wave_a, origin.xz, time, dx, dz);
	displacement += gerstner(wave_b, origin.xz, time, dx, dz);
	displacement += gerstner(wave_c, origin.xz, time, dx, dz);
	water_world = origin + displacement;
	normal_world = normalize(cross(dz, dx));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(water_world, 1.0)).xyz;
	NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * normal_world);
	UV = origin.xz;
}

vec3 reconstruct_view(mat4 inverse_projection, vec2 uv, float depth) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 position = inverse_projection * vec4(ndc, 1.0);
	return position.xyz / position.w;
}

bool is_background(float depth) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return depth > 0.99999;
#else
	return depth < 0.00001;
#endif
}

vec2 project_to_screen(mat4 projection, vec3 point) {
	vec4 clip = projection * vec4(point, 1.0);
	return clip.xy / clip.w * 0.5 + 0.5;
}

vec4 reflected_scene(vec3 origin, vec3 direction, mat4 projection, mat4 inverse_projection,
	mat4 inverse_view, float surface_height, vec2 distortion) {
	int steps = clamp(object_reflection_steps, 8, 64);
	float stride = max(object_reflection_distance, 0.1) / float(steps);
	float previous_distance = 0.05;
	for (int index = 0; index < 64; index++) {
		if (index >= steps) { break; }
		float distance = 0.05 + stride * float(index + 1);
		vec3 point = origin + direction * distance;
		if (point.z >= -0.05) { break; }
		vec2 uv = project_to_screen(projection, point);
		if (any(lessThan(uv, vec2(0.002))) || any(greaterThan(uv, vec2(0.998)))) { break; }
		float raw_depth = texture(depth_texture, uv).r;
		if (!is_background(raw_depth)) {
			vec3 scene = reconstruct_view(inverse_projection, uv, raw_depth);
			float gap = scene.z - point.z;
			if (gap >= 0.0) {
				float near_distance = previous_distance;
				float far_distance = distance;
				// Refine depth crossings so thin sprites can be found between coarse steps.
				for (int refine = 0; refine < 5; refine++) {
					float middle = (near_distance + far_distance) * 0.5;
					vec3 candidate = origin + direction * middle;
					vec2 candidate_uv = project_to_screen(projection, candidate);
					float candidate_depth = texture(depth_texture, candidate_uv).r;
					vec3 candidate_scene = reconstruct_view(inverse_projection, candidate_uv, candidate_depth);
					if (!is_background(candidate_depth) && candidate_scene.z - candidate.z >= 0.0) {
						far_distance = middle;
					} else {
						near_distance = middle;
					}
				}
				vec3 hit = origin + direction * far_distance;
				vec2 hit_uv = project_to_screen(projection, hit);
				float hit_depth = texture(depth_texture, hit_uv).r;
				vec3 hit_scene = reconstruct_view(inverse_projection, hit_uv, hit_depth);
				vec3 world_hit = (inverse_view * vec4(hit_scene, 1.0)).xyz;
				float error = abs(hit_scene.z - hit.z);
				if (!is_background(hit_depth) && world_hit.y > surface_height + 0.03
					&& error < object_reflection_thickness) {
					vec2 edge = min(hit_uv, vec2(1.0) - hit_uv);
					float confidence = smoothstep(0.0, 0.06, min(edge.x, edge.y));
					confidence *= 1.0 - smoothstep(0.65, 1.0, far_distance / object_reflection_distance);
					confidence *= 1.0 - smoothstep(object_reflection_thickness * 0.5,
						object_reflection_thickness, error);
					vec2 image_uv = clamp(hit_uv + distortion * 0.004, vec2(0.001), vec2(0.999));
					return vec4(texture(screen_texture, image_uv).rgb, confidence);
				}
			}
		}
		previous_distance = distance;
	}
	return vec4(0.0);
}

void fragment() {
	float time = TIME * wave_speed;
	vec2 grid = pixel_grid(UV);
	vec2 flow = sampler_direction * time;
	float broad_noise = texture(uv_sampler, grid * uv_sampler_scale + flow).r;
	float cross_noise = texture(uv_sampler, grid * uv_sampler_scale * 1.31 - flow + vec2(0.37, 0.61)).r;
	vec2 wobble = (vec2(broad_noise, cross_noise) * 2.0 - 1.0) * uv_sampler_strength;
	// Small screen-space offsets; never pull a foreground object into the water.
	vec2 refracted_uv = clamp(SCREEN_UV + wobble * refraction * 0.2, vec2(0.001), vec2(0.999));
	float raw_depth = texture(depth_texture, refracted_uv).r;
	vec3 floor_view = reconstruct_view(INV_PROJECTION_MATRIX, refracted_uv, raw_depth);
	vec3 floor_world = (INV_VIEW_MATRIX * vec4(floor_view, 1.0)).xyz;
	if (!is_background(raw_depth) && (floor_world.y > water_world.y + 0.05 || floor_view.z > VERTEX.z)) {
		refracted_uv = SCREEN_UV;
		raw_depth = texture(depth_texture, SCREEN_UV).r;
		floor_view = reconstruct_view(INV_PROJECTION_MATRIX, SCREEN_UV, raw_depth);
		floor_world = (INV_VIEW_MATRIX * vec4(floor_view, 1.0)).xyz;
	}
	bool no_floor = is_background(raw_depth);
	float depth = no_floor ? 40.0 : max(water_world.y - floor_world.y + depth_offset, 0.0);
	float absorption = 1.0 - exp(-depth * beers_law / max(deep_amount, 0.1));
	// More colour bands with a tiny noise dither prevent large flat contour stripes.
	float bands = float(max(color_steps - 1, 1));
	float band = clamp(floor(absorption * bands + 0.5 + (broad_noise - 0.5) * 0.3) / bands, 0.0, 1.0);
	vec3 colour = mix(color_shallow.rgb, color_mid.rgb, smoothstep(0.0, 0.5, band));
	colour = mix(colour, color_deep.rgb, smoothstep(0.3, 1.0, band));
	colour *= 0.94 + broad_noise * 0.12;
	float swell = sin(dot(grid, vec2(0.92, 0.39)) * 1.7 - time * 0.9 + broad_noise * 5.0);
	float crossing_swell = sin(dot(grid, vec2(-0.45, 0.89)) * 0.9 + time * 0.8 + cross_noise * 6.0);
	float currents = smoothstep(0.35, 0.85, swell * 0.65 + crossing_swell * 0.35);
	colour = mix(colour, color_mid.rgb, currents * 0.065);
	vec3 below = texture(screen_texture, refracted_uv).rgb;
	colour = mix(colour, below * color_shallow.rgb, exp(-depth * 0.7) * shallow_visibility);

	// Intersecting light ribbons over shallow sand, fading out in deep water.
	vec2 floor_grid = no_floor ? grid : pixel_grid(floor_world.xz);
	float ca = texture(noise_sampler, floor_grid * sampler_scale * 0.25 + flow * 0.7).r;
	float cb = texture(noise_sampler, floor_grid.yx * sampler_scale * 0.31 - flow * 0.5 + vec2(0.23)).r;
	float caustics = max(1.0 - smoothstep(0.015, 0.065, abs(ca - 0.5)),
		1.0 - smoothstep(0.015, 0.065, abs(cb - 0.5)));
	colour += color_shallow.rgb * caustics * caustic_strength * exp(-depth * 0.45) * smoothstep(0.12, 0.6, depth);
	if (object_reflections_enabled && object_reflection_strength > 0.0) {
		vec3 view_normal = normalize((VIEW_MATRIX * vec4(mix(vec3(0.0, 1.0, 0.0), normal_world, 0.2), 0.0)).xyz);
		vec3 incident = PROJECTION_MATRIX[3][3] > 0.5 ? vec3(0.0, 0.0, -1.0) : normalize(VERTEX);
		vec3 reflected_direction = normalize(reflect(incident, view_normal));
		vec4 reflection = reflected_scene(VERTEX + view_normal * 0.04, reflected_direction,
			PROJECTION_MATRIX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, water_world.y, wobble);
		vec3 reflected_colour = reflection.rgb * vec3(0.78, 0.92, 1.0);
		colour = mix(colour, reflected_colour, reflection.a * object_reflection_strength);
	}

	// Sparse drifting wavelets, rather than uniform rows of white dots.
	vec2 scale = max(abs(surface_size), vec2(0.1));
	float n1 = texture(noise_sampler, (grid + surface_direction * time + wobble) / scale).r;
	float n2 = texture(noise_sampler, (grid.yx + surface_direction2 * time) / (scale * 0.73) + vec2(0.37, 0.19)).r;
	float wavelet = pow(clamp(max(n1, n2 * 0.92), 0.0, 1.0), max(surface_exp, 1.0));
	float highlights = smoothstep(0.28, 0.48, wavelet) * surface_multiplier * 0.06;
	float crest = sin(dot(grid, vec2(0.92, 0.39)) * 4.0 - time * 1.4 + cross_noise * 7.0);
	float broken_crest = smoothstep(0.94, 0.995, crest) * smoothstep(0.48, 0.78, broad_noise);
	highlights = max(highlights, broken_crest * surface_multiplier * 0.1);
	colour = mix(colour, color_foam.rgb, clamp(highlights, 0.0, 0.3));
	vec3 to_camera = normalize(CAMERA_POSITION_WORLD - water_world);
	float fresnel = pow(1.0 - max(dot(normalize(normal_world), to_camera), 0.0), 3.0);
	colour = mix(colour, reflection_tint.rgb, fresnel * reflection_strength);

	// A thin contact edge plus a broken incoming foam band, measured in world units.
	float width = max(foam_amount * 12.0, 0.001);
	float shore_noise = texture(noise_sampler, grid * 0.13 + flow * 0.35).r;
	float contact = 1.0 - smoothstep(0.025, width * (0.35 + shore_noise * 0.7), depth);
	float shore_phase = depth / width * 5.0 - time * 1.8 + shore_noise * 3.0;
	float incoming = smoothstep(0.6, 0.92, sin(shore_phase));
	incoming *= (1.0 - smoothstep(width * 0.7, width * 2.8, depth));
	incoming *= smoothstep(0.38, 0.7, shore_noise);
	float foam = max(contact * (0.65 + shore_noise * 0.35), incoming * 0.7);
	foam *= step(0.0001, foam_amount);
	colour = mix(colour, color_foam.rgb, clamp(foam, 0.0, 1.0));
	ALBEDO = colour;
	EMISSION = colour * emission_strength;
	ALPHA = 1.0;
}
