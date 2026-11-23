shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

// The sea around a Coral Valley island, drawn on the void quad below the room. Everything is
// sampled where the camera ray meets the sand surface (`surface_height_meters`), so the shallows
// and foam hug the sand edge even though the quad sits lower. Cost per pixel: four texture
// reads, no loops.

// Distance to the shore, 0 at the sand edge and 1 at `shore_rect` margin, baked per room.
uniform sampler2D shore_distance : filter_linear, repeat_disable;
// World rect of `shore_distance`: (min x, min z, width, depth) in metres.
uniform vec4 shore_rect = vec4(-26.62, -30.02, 53.45, 63.6);
uniform float shore_reach_meters = 8.0;
// World height of the sand surface the shore field was baked for.
uniform float surface_height_meters = 0.0;
uniform sampler2D water_noise : filter_linear, repeat_enable;

uniform vec4 deep_color : source_color = vec4(0.02, 0.07, 0.11, 1.0);
uniform vec4 lagoon_color : source_color = vec4(0.04, 0.23, 0.28, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.14, 0.47, 0.47, 1.0);
uniform vec4 reef_color : source_color = vec4(0.28, 0.22, 0.32, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.62, 0.95, 0.88, 1.0);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 0.9, 1.0);

uniform float caustic_world_size_meters = 7.0;
uniform float caustic_speed = 0.05;
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.35;
uniform float reef_world_size_meters = 26.0;
uniform float reef_coverage : hint_range(0.0, 1.0) = 0.38;
uniform float reef_strength : hint_range(0.0, 1.0) = 0.35;
uniform float foam_width_meters = 0.45;
uniform float swash_meters = 0.35;
uniform float swash_speed = 0.9;
// Ripples that travel out from the shore: spacing and outward speed.
uniform float ring_spacing_meters = 2.6;
uniform float ring_speed_meters_per_second = 0.45;
uniform float ring_strength : hint_range(0.0, 1.0) = 0.22;

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec3 ray = world_position - CAMERA_POSITION_WORLD;
	float to_plane = (surface_height_meters - CAMERA_POSITION_WORLD.y) / min(ray.y, -0.0001);
	vec2 xz = CAMERA_POSITION_WORLD.xz + ray.xz * to_plane;

	vec2 shore_uv = (xz - shore_rect.xy) / shore_rect.zw;
	float shore = texture(shore_distance, shore_uv).r;
	float meters = shore * shore_reach_meters;

	vec3 color = mix(lagoon_color.rgb, deep_color.rgb, smoothstep(0.35, 1.0, shore));
	color = mix(color, shallow_color.rgb, 1.0 - smoothstep(0.0, 0.4, shore));

	// Reef shapes under the lagoon, fading out in the deep and in the bright shallows.
	float reef = texture(water_noise, xz / reef_world_size_meters + vec2(0.37, 0.11)).r;
	float reef_band = smoothstep(0.08, 0.3, shore) * (1.0 - smoothstep(0.55, 0.95, shore));
	float reef_mask = smoothstep(1.0 - reef_coverage, 1.04 - reef_coverage, reef) * reef_band;
	color = mix(color, reef_color.rgb, reef_mask * reef_strength);

	// Caustics: where two drifting copies of the noise cross, thin bright lines appear.
	vec2 caustic_uv = xz / caustic_world_size_meters;
	float a = texture(water_noise, caustic_uv + TIME * caustic_speed * vec2(1.0, 0.4)).r;
	float b = texture(water_noise, caustic_uv * 1.3 - TIME * caustic_speed * vec2(0.5, 1.0)).r;
	float caustic = pow(1.0 - clamp(abs(a - b) * 4.0, 0.0, 1.0), 6.0);
	float light_depth = 1.0 - smoothstep(0.2, 0.8, shore);
	color += caustic_color.rgb * caustic * caustic_strength * light_depth;

	// Swash: the foam line breathes in and out against the sand.
	float swash = (sin(TIME * swash_speed + a * 4.0) * 0.5 + 0.5) * swash_meters;
	float foam = 1.0 - smoothstep(foam_width_meters * 0.5, foam_width_meters, meters - swash);
	float rings = fract(meters / ring_spacing_meters - TIME * ring_speed_meters_per_second
		/ ring_spacing_meters);
	float ring = smoothstep(0.86, 0.94, rings) * (1.0 - smoothstep(0.94, 1.0, rings));
	ring *= (1.0 - smoothstep(0.1, 0.55, shore)) * ring_strength;
	color = mix(color, foam_color.rgb, clamp(foam * 0.85 + ring, 0.0, 1.0));

	ALBEDO = color;
}
