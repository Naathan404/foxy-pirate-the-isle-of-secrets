// Shared body of the destructible wind shaders. The quad always faces the camera.
// Define UPRIGHT_DEPTH before including to depth-test the sprite as if it stood upright
// (vertical, like character sprites), so a character beside a tall prop is never cut through
// by the tilted quad. It writes DEPTH, which costs early depth testing, so it is opt-in.

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sprite_width = 1.0;
uniform float wind_amplitude = 0.28;
uniform float wind_speed = 4.4;
uniform float gust_strength = 0.38;
uniform float root_height = 0.08;
uniform float bend_power = 1.35;
uniform float wind_phase = 0.0;
uniform float horizontal_uv_direction = 1.0;
uniform float vertical_uv_direction = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

#ifdef UPRIGHT_DEPTH
// Sprite origin and the upright plane's normal, both in view space.
varying vec3 pivot_view;
varying vec3 upright_normal_view;
#endif

void vertex() {
	float expansion = 1.0 + 2.0 * wind_amplitude * (1.0 + gust_strength) / sprite_width;
	VERTEX.x *= expansion;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
#ifdef UPRIGHT_DEPTH
	pivot_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	// Vertical plane through the sprite origin, turned toward the camera around world up.
	vec3 toward_camera = vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z);
	if (dot(toward_camera, toward_camera) < 1e-6) {
		toward_camera = vec3(0.0, 0.0, 1.0);
	}
	upright_normal_view = (VIEW_MATRIX * vec4(normalize(toward_camera), 0.0)).xyz;
#endif
}

void fragment() {
	float expansion = 1.0 + 2.0 * wind_amplitude * (1.0 + gust_strength) / sprite_width;
	float vertical_fraction = (UV.y - frame_uv.y) / frame_uv.w;
	float height = vertical_uv_direction > 0.0 ? 1.0 - vertical_fraction : vertical_fraction;
	float flex = pow(clamp((height - root_height) / (1.0 - root_height), 0.0, 1.0), bend_power);
	float phase = TIME * wind_speed + wind_phase;
	float gust = sin(phase * 1.73 + wind_phase * 0.37) * gust_strength;
	float offset = (sin(phase) + gust) * wind_amplitude * flex;
	float center_x = frame_uv.x + frame_uv.z * 0.5;
	vec2 sample_uv = UV;
	sample_uv.x = center_x + (UV.x - center_x) * expansion;
	sample_uv.x -= offset / sprite_width * frame_uv.z * horizontal_uv_direction;
	if (sample_uv.x < frame_uv.x || sample_uv.x > frame_uv.x + frame_uv.z) {
		discard;
	}
	vec4 texel = texture(sprite_texture, sample_uv);
	ALBEDO = mix(texel.rgb * COLOR.rgb, flash_color.rgb, flash_strength * flash_color.a);
	ALPHA = texel.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Compatibility (used by Web) keeps the mesh normal when vertex() rewrites
	// MODELVIEW_MATRIX, so lights between root and tip darkened half the card.
	NORMAL = vec3(0.0, 0.0, 1.0);
#endif
#ifdef UPRIGHT_DEPTH
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		// Orthographic shadow pass (a prop that still casts a shadow-map shadow): the camera
		// ray maths below assumes perspective, so keep the card's own depth.
		DEPTH = FRAGCOORD.z;
	} else {
		// Where the camera ray through this pixel meets the upright plane; use that depth.
		vec3 ray = normalize(VERTEX);
		float facing = dot(ray, upright_normal_view);
		float distance_along_ray = abs(facing) > 1e-4
			? dot(pivot_view, upright_normal_view) / facing
			: length(VERTEX);
		vec4 clip = PROJECTION_MATRIX * vec4(ray * distance_along_ray, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		// OpenGL clip depth spans -1..1, while DEPTH expects the 0..1 window range.
		DEPTH = clip.z / clip.w * 0.5 + 0.5;
#else
		DEPTH = clip.z / clip.w;
#endif
	}
#endif
}
